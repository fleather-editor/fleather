import 'package:fleather/fleather.dart';
import 'package:fleather/src/widgets/history.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_delta/quill_delta.dart';

import '../testing.dart';

Future<void> undo(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
  await tester.pumpAndSettle();
}

Future<void> redo(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
  await tester.pumpAndSettle();
}

void main() {
  group('History stack', () {
    late HistoryStack stack;

    setUp(() {
      stack = HistoryStack(Delta()..insert('Hello\n'));
    });

    group('empty stack', () {
      test('undo returns null', () {
        expect(stack.undo(), isNull);
      });

      test('redo returns null', () {
        expect(stack.redo(), isNull);
      });
    });

    test('undoes twice', () {
      final change = Delta()..insert('Hello world\n');
      final otherChange = Delta()..insert('Hello world ok\n');
      final exp = Delta()
        ..retain(5)
        ..delete(6);
      final expOther = Delta()
        ..retain(11)
        ..delete(3);
      stack.push(change);
      stack.push(otherChange);
      var act = stack.undo();
      expect(act, expOther);
      act = stack.undo();
      expect(act, exp);
    });

    test('undoes too many times', () {
      final change = Delta()..insert('Hello world\n');
      stack.push(change);
      var act = stack.undo();
      expect(act, isNotNull);
      act = stack.undo();
      expect(act, isNull);
    });

    test('redoes twice', () {
      final change = Delta()..insert('Hello world\n');
      final otherChange = Delta()..insert('Hello world ok\n');
      final exp = Delta()
        ..retain(5)
        ..insert(' world');
      final expOther = Delta()
        ..retain(11)
        ..insert(' ok');
      stack.push(change);
      stack.push(otherChange);
      stack.undo();
      stack.undo();
      var act = stack.redo();
      expect(act, exp);
      act = stack.redo();
      expect(act, expOther);
    });

    test('redoes too many times', () {
      final change = Delta()..insert('Hello world\n');
      stack.push(change);
      stack.undo();
      var act = stack.redo();
      expect(act, isNotNull);
      act = stack.redo();
      expect(act, isNull);
    });

    test('pushes new items while index is at start', () {
      final change = Delta()..insert('Hello world\n');
      stack.push(change);
      expect(stack.undo(), isNotNull);
      stack.push(change);
      expect(stack.redo(), isNull);
    });

    test('undoing formatting', () {
      final change = Delta()
        ..insert('Hello', {'b': true})
        ..insert('\n');
      stack.push(change);
      var act = stack.undo();
      expect(act, Delta()..retain(5, {'b': null}));
    });

    test('Delta', () {
      final base = Delta()..insert('Hello\n');
      final inc = Delta()..retain(5, {'b': true});
      expect(inc.invert(base), Delta()..retain(5, {'b': null}));
    });
  });

  group('History widget', () {
    testWidgets('undo/redo insertion', (tester) async {
      const initialLength = 'Something in the way mmmmm'.length;
      final documentDelta = Delta()
        ..insert('Something', {'b': true})
        ..insert(' in the way ')
        ..insert('mmmmm', {'i': true})
        ..insert('\n');
      final editor = EditorSandBox(
          tester: tester, document: ParchmentDocument.fromDelta(documentDelta));
      final endState = documentDelta.compose(Delta()
        ..retain(initialLength - 5)
        ..delete(5)
        ..insert('mmmmm,', {'i': true}));
      await editor.pump();
      await editor.enterText(const TextEditingValue(
          text: 'Something in the way mmmmm,\n',
          selection: TextSelection.collapsed(offset: 26)));
      // Throttle time of 500ms in history
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(editor.controller.document.toDelta(), endState);

      await undo(tester);
      expect(editor.controller.document.toDelta(), documentDelta);
      expect(editor.controller.selection,
          const TextSelection.collapsed(offset: initialLength));

      await redo(tester);
      expect(editor.controller.document.toDelta(), endState);
      expect(editor.controller.selection,
          const TextSelection.collapsed(offset: initialLength + 1));
    });

    testWidgets('undo/redo formatting', (tester) async {
      const initialLength = 'Something in the way mmmmm'.length;
      final documentDelta = Delta()
        ..insert('Something', {'b': true})
        ..insert(' in the way ')
        ..insert('mmmmm', {'i': true})
        ..insert('\n');
      final editor = EditorSandBox(
          tester: tester, document: ParchmentDocument.fromDelta(documentDelta));
      final endState = documentDelta.compose(Delta()
        ..retain(initialLength - 5)
        ..delete(5)
        ..insert('mmmmm'));
      await editor.pump();
      editor.controller
          .formatText(initialLength - 5, 5, ParchmentAttribute.italic.unset);
      // Throttle time of 500ms in history
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(editor.controller.document.toDelta(), endState);

      await undo(tester);
      expect(editor.controller.document.toDelta(), documentDelta);
      expect(
          editor.controller.selection,
          const TextSelection(
              baseOffset: initialLength - 5, extentOffset: initialLength));

      await redo(tester);
      expect(editor.controller.document.toDelta(), endState);
      expect(
          editor.controller.selection,
          const TextSelection(
              baseOffset: initialLength - 5, extentOffset: initialLength));
    });

    testWidgets('update widget', (tester) async {
      Future<void> showKeyboard() async {
        return TestAsyncUtils.guard<void>(() async {
          final editor = tester.state<RawEditorState>(find.byType(RawEditor));
          editor.requestKeyboard();
          await tester.pumpAndSettle();
        });
      }

      Future<void> enterText(TextEditingValue text) async {
        return TestAsyncUtils.guard<void>(() async {
          await showKeyboard();
          tester.binding.testTextInput.updateEditingValue(text);
          await tester.idle();
          await tester.pumpAndSettle();
        });
      }

      final documentDelta = Delta()..insert('Something in the way mmmmm\n');
      await tester.pumpWidget(
        MaterialApp(
          home: TestUpdateWidget(
            focusNodeAfterChange: FocusNode(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // update widget
      await tester.tap(find.byType(TextButton));

      await enterText(const TextEditingValue(
          text: 'Something in the way mmmmm\n',
          selection: TextSelection.collapsed(offset: 26)));
      // Throttle time of 500ms in history
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      var editorState = tester.state<RawEditorState>(find.byType(RawEditor));

      expect(editorState.controller.document.toDelta(), documentDelta);
      await undo(tester);
      editorState = tester.state<RawEditorState>(find.byType(RawEditor));
      expect(editorState.controller.document.toDelta(), Delta()..insert('\n'));
    });
  });
}
