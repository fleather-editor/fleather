import 'package:fleather/fleather.dart';
import 'package:fleather/src/widgets/checkbox.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_delta/quill_delta.dart';

import '../testing.dart';

void main() {
  group('FleatherEditableText', () {
    testWidgets('user input inserts text', (tester) async {
      final editor = EditorSandBox(tester: tester);
      await editor.pumpAndTap();
      final currentValue = editor.document.toPlainText();
      await insertText(tester, 'Added ', inText: currentValue);
      expect(editor.document.toPlainText(), 'Added This House Is A Circus\n');
    });

    testWidgets('user input deletes text', (tester) async {
      final editor = EditorSandBox(tester: tester);
      await editor.pumpAndTap();
      final currentValue = editor.document.toPlainText();
      await deleteText(tester, nbCharacters: 5, inText: currentValue);
      expect(editor.document.toPlainText(), 'House Is A Circus\n');
    });

    testWidgets('user input replaced text', (tester) async {
      final editor = EditorSandBox(tester: tester);
      await editor.pumpAndTap();
      final currentValue = editor.document.toPlainText();
      await replaceText(tester,
          inText: currentValue,
          range: const TextRange(start: 5, end: 5 + 'House'.length),
          withText: 'Place');
      expect(editor.document.toPlainText(), 'This Place Is A Circus\n');
    });

    testWidgets('autofocus', (tester) async {
      final editor = EditorSandBox(tester: tester, autofocus: true);
      await editor.pump();
      expect(editor.focusNode.hasFocus, isTrue);
    });

    testWidgets('no autofocus', (tester) async {
      final editor = EditorSandBox(tester: tester);
      await editor.pump();
      expect(editor.focusNode.hasFocus, isFalse);
    });

    group('lists', () {
      testWidgets('check list', (tester) async {
        final delta = Delta()
          ..insert('an item')
          ..insert('\n', {'block': 'cl'});
        final editor = EditorSandBox(
            tester: tester, document: ParchmentDocument.fromDelta(delta));
        await editor.pump();
        expect(find.byType(FleatherCheckbox), findsOneWidget);
      });

      testWidgets('bullet list', (tester) async {
        final delta = Delta()
          ..insert('an item')
          ..insert('\n', {'block': 'ul'});
        final editor = EditorSandBox(
            tester: tester, document: ParchmentDocument.fromDelta(delta));
        await editor.pump();
        expect(find.text('•', findRichText: true), findsOneWidget);
      });

      testWidgets('numbered list', (tester) async {
        final delta = Delta()
          ..insert('an item')
          ..insert('\n', {'block': 'ol'});
        final editor = EditorSandBox(
            tester: tester, document: ParchmentDocument.fromDelta(delta));
        await editor.pump();
        expect(find.text('1.', findRichText: true), findsOneWidget);
      });
    });
  });
}

Future<void> insertText(WidgetTester tester, String textInserted,
    {int atOffset = 0, String inText = ''}) async {
  return TestAsyncUtils.guard(() async {
    updateDeltaEditingValue(TextEditingDeltaInsertion(
        oldText: inText,
        textInserted: textInserted,
        insertionOffset: atOffset,
        selection: const TextSelection.collapsed(offset: 0),
        composing: TextRange.empty));
    // account for thottling of history stack update
    await tester.pump(throttleDuration);
    await tester.idle();
  });
}

Future<void> deleteText(WidgetTester tester,
    {required int nbCharacters, int at = 0, required String inText}) {
  return TestAsyncUtils.guard(() async {
    updateDeltaEditingValue(TextEditingDeltaDeletion(
        oldText: inText,
        deletedRange: TextRange(start: at, end: at + nbCharacters),
        selection: const TextSelection.collapsed(offset: 0),
        composing: TextRange.empty));
    // account for thottling of history stack update
    await tester.pump(throttleDuration);
    await tester.idle();
  });
}

Future<void> replaceText(WidgetTester tester,
    {required TextRange range,
    required String withText,
    required String inText}) {
  return TestAsyncUtils.guard(() async {
    updateDeltaEditingValue(TextEditingDeltaReplacement(
        oldText: inText,
        replacedRange: range,
        replacementText: withText,
        selection: const TextSelection.collapsed(offset: 0),
        composing: TextRange.empty));
    // account for thottling of history stack update
    await tester.pump(throttleDuration);
    await tester.idle();
  });
}

void updateDeltaEditingValue(TextEditingDelta delta, {int? client}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    SystemChannels.textInput.name,
    SystemChannels.textInput.codec.encodeMethodCall(
      MethodCall(
        'TextInputClient.updateEditingStateWithDeltas',
        <dynamic>[
          client ?? -1,
          {
            'deltas': [delta.toJSON()]
          }
        ],
      ),
    ),
    (ByteData? data) {
      /* ignored */
    },
  );
}

extension DeltaJson on TextEditingDelta {
  Map<String, dynamic> toJSON() {
    final json = <String, dynamic>{};
    json['composingBase'] = composing.start;
    json['composingExtent'] = composing.end;

    json['selectionBase'] = selection.baseOffset;
    json['selectionExtent'] = selection.extentOffset;
    json['selectionAffinity'] = selection.affinity.name;
    json['selectionIsDirectional'] = selection.isDirectional;

    json['oldText'] = oldText;

    if (this is TextEditingDeltaInsertion) {
      final insertion = this as TextEditingDeltaInsertion;
      json['deltaStart'] = insertion.insertionOffset;
      // Assumes no replacement, simply insertion here
      json['deltaEnd'] = insertion.insertionOffset;
      json['deltaText'] = insertion.textInserted;
    }

    if (this is TextEditingDeltaDeletion) {
      final deletion = this as TextEditingDeltaDeletion;
      json['deltaStart'] = deletion.deletedRange.start;
      // Assumes no replacement, simply insertion here
      json['deltaEnd'] = deletion.deletedRange.end;
      json['deltaText'] = '';
    }

    if (this is TextEditingDeltaReplacement) {
      final replacement = this as TextEditingDeltaReplacement;
      json['deltaStart'] = replacement.replacedRange.start;
      // Assumes no replacement, simply insertion here
      json['deltaEnd'] = replacement.replacedRange.end;
      json['deltaText'] = replacement.replacementText;
    }
    return json;
  }
}
