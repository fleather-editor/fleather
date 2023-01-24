import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_delta/quill_delta.dart';

import '../testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('$RawEditor', () {
    testWidgets('allows merging attribute theme data', (tester) async {
      var delta = Delta()
        ..insert(
          'Website',
          ParchmentAttribute.link.fromString('https://github.com').toJson(),
        )
        ..insert('\n');
      var doc = ParchmentDocument.fromDelta(delta);
      final BuildContext context = tester.element(find.byType(Container));
      var theme = FleatherThemeData.fallback(context)
          .copyWith(link: const TextStyle(color: Colors.red));
      var editor = EditorSandBox(tester: tester, document: doc, theme: theme);
      await editor.pumpAndTap();
      // await tester.pumpAndSettle();
      final p = tester.widget(find.byType(RichText).first) as RichText;
      final text = p.text as TextSpan;
      expect(text.children!.first.style!.color, Colors.red);
    });

    testWidgets('collapses selection when unfocused', (tester) async {
      final editor = EditorSandBox(tester: tester);
      await editor.pumpAndTap();
      await editor.updateSelection(base: 0, extent: 3);
      // expect(editor.findSelectionHandle(), findsNWidgets(2));
      await editor.unfocus();
      // expect(editor.findSelectionHandle(), findsNothing);
      expect(editor.selection, const TextSelection.collapsed(offset: 3));
    }, skip: true);

    testWidgets('toggle enabled state', (tester) async {
      final editor = EditorSandBox(tester: tester);
      await editor.pumpAndTap();
      await editor.updateSelection(base: 0, extent: 3);
      await editor.disable();
      final widget = tester.widget(find.byType(FleatherField)) as FleatherField;
      expect(widget.readOnly, true);
    });

    testWidgets('ability to paste upon long press on an empty document',
        (tester) async {
      // if Clipboard not initialize (status 'unknown'), an shrunken toolbar appears
      prepareClipboard();

      final editor = EditorSandBox(
          tester: tester, document: ParchmentDocument(), autofocus: true);
      await editor.pump();

      expect(find.text('Paste'), findsNothing);
      await tester.longPress(find.byType(FleatherEditor));
      await tester.pump();
      // Given current toolbar implementation in Flutter no other choice
      // than to search for "Paste" text
      final finder = find.text('Paste');
      expect(finder, findsOneWidget);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(editor.document.toPlainText(), '$clipboardText\n');
    });

    testWidgets('ability to paste upon double-tap on an empty document',
        (tester) async {
      // if Clipboard not initialize (status 'unknown'), an shrunken toolbar appears
      prepareClipboard();
      final editor = EditorSandBox(
          tester: tester, document: ParchmentDocument(), autofocus: true);
      await editor.pump();
      expect(find.text('Paste'), findsNothing);
      await tester.tap(find.byType(FleatherEditor));
      await tester.tap(find.byType(FleatherEditor));
      await tester.pump();
      final finder = find.text('Paste');
      expect(finder, findsOneWidget);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(editor.document.toPlainText(), '$clipboardText\n');
    });

    testWidgets('creating editor without focusNode does not throw _CastError',
        (tester) async {
      final widget =
          MaterialApp(home: FleatherEditor(controller: FleatherController()));
      await tester.pumpWidget(widget);
      // Fails if thrown
    });

    group('didUpdateWidget', () {
      testWidgets(
          'changes focus node when updating widget with internal focus node',
          (tester) async {
        final expFocus = FocusNode();
        final widget =
            MaterialApp(home: TestUpdateWidget(focusNodeAfterChange: expFocus));
        await tester.pumpWidget(widget);
        final initialState =
            tester.state<RawEditorState>(find.byType(RawEditor));
        final defaultFocusNode = initialState.effectiveFocusNode;
        expect(defaultFocusNode, isNot(expFocus));
        await tester.tap(find.byType(TextButton));
        await tester.pumpAndSettle();
        final endState = tester.state<RawEditorState>(find.byType(RawEditor));
        final actFocusNode = endState.effectiveFocusNode;
        expect(actFocusNode, expFocus);
      });
    });

    group('field', () {
      testWidgets('creating field without focusNode does not throw _CastError',
          (tester) async {
        final widget = MaterialApp(
          home: FleatherField(
            controller: FleatherController(),
          ),
        );
        await tester.pumpWidget(widget);
        // Fails if thrown
      });

      testWidgets(
          'changes focus node when updating widget with internal focus node',
          (tester) async {
        final expFocus = FocusNode();
        final widget = MaterialApp(
            home: TestUpdateWidget(
          focusNodeAfterChange: expFocus,
          testField: true,
        ));
        await tester.pumpWidget(widget);
        final initialState =
            tester.state<RawEditorState>(find.byType(RawEditor));
        final defaultFocusNode = initialState.effectiveFocusNode;
        expect(defaultFocusNode, isNot(expFocus));
        await tester.tap(find.byType(TextButton));
        await tester.pumpAndSettle();
        final endState = tester.state<RawEditorState>(find.byType(RawEditor));
        final actFocusNode = endState.effectiveFocusNode;
        expect(actFocusNode, expFocus);
      });
    });
  });
}

const clipboardText = 'copied text';

void prepareClipboard() {
  TestDefaultBinaryMessengerBinding.instance?.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (message) {
    if (message.method == 'Clipboard.getData') {
      return Future.value(<String, dynamic>{'text': clipboardText});
    }
    if (message.method == 'Clipboard.hasStrings') {
      return Future.value(<String, dynamic>{'value': true});
    }
    return null;
  });
}
