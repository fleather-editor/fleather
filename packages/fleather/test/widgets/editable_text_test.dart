import 'package:fleather/fleather.dart';
import 'package:fleather/src/widgets/checkbox.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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

    testWidgets(
        'Selection is correct after merging two blocks by deleting'
        'new line character between them', (tester) async {
      final document = ParchmentDocument.fromJson([
        {'insert': 'Test'},
        {
          'insert': '\n',
          'attributes': {'block': 'code'}
        },
        {'insert': 'Test'},
        {
          'insert': '\n',
          'attributes': {'block': 'quote'}
        },
      ]);
      final editor =
          EditorSandBox(tester: tester, document: document, autofocus: true);
      await editor.pump();
      // Tapping of editor ensure selectionOverlay is set in EditorState
      await editor.tap();
      await editor.updateSelection(base: 5, extent: 5);
      getInputClient().updateEditingValueWithDeltas([
        TextEditingDeltaDeletion(
          oldText: document.toPlainText(),
          deletedRange: const TextRange(start: 4, end: 5),
          selection: const TextSelection.collapsed(offset: 4),
          composing: TextRange.empty,
        )
      ]);
      await tester.pumpAndSettle(throttleDuration);
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

        await tester.tap(find.byType(FleatherCheckbox));
        await tester.pumpAndSettle(throttleDuration);
        expect(editor.document.toDelta().last,
            Operation.insert('\n', {'block': 'cl', 'checked': true}));
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

    testWidgets('headings', (tester) async {
      TextStyle levelToStyle(FleatherThemeData themeData, int level) {
        switch (level) {
          case 1:
            return themeData.heading1.style;
          case 2:
            return themeData.heading2.style;
          case 3:
            return themeData.heading3.style;
          case 4:
            return themeData.heading4.style;
          case 5:
            return themeData.heading5.style;
          case 6:
            return themeData.heading6.style;
          default:
            throw ArgumentError('Level must be lower or equal than 6');
        }
      }

      Future<void> runHeading(WidgetTester tester, int level,
          {bool inBlock = false}) async {
        // heading in block to account for spacing
        final delta = Delta()
          ..insert('a heading')
          ..insert('\n', {'heading': level, if (inBlock) 'block': 'quote'})
          ..insert('a paragraph')
          ..insert('\n', {if (inBlock) 'block': 'quote'});
        final editor = EditorSandBox(
            tester: tester, document: ParchmentDocument.fromDelta(delta));
        await editor.pump();
        final context = tester.element(find.byType(TextLine).first);
        final line = tester.widget<RichText>(find.byType(RichText).first);
        final theme = FleatherTheme.of(context)!;
        final expStyle = inBlock
            ? levelToStyle(theme, level).merge(theme.quote.style)
            : levelToStyle(theme, level);
        expect((line.text as TextSpan).style, expStyle,
            reason: 'Failed on heading $level ${inBlock ? 'in block' : ''}');
      }

      await runHeading(tester, 1, inBlock: true);
      await runHeading(tester, 2, inBlock: true);
      await runHeading(tester, 3, inBlock: true);
      await runHeading(tester, 4, inBlock: true);
      await runHeading(tester, 5, inBlock: true);
      await runHeading(tester, 6, inBlock: true);

      await runHeading(tester, 1);
      await runHeading(tester, 2);
      await runHeading(tester, 3);
      await runHeading(tester, 4);
      await runHeading(tester, 5);
      await runHeading(tester, 6);
    });
  });

  group('Inline format', () {
    testWidgets('Text color', (tester) async {
      final delta = Delta()
        ..insert('colore text', {'fg': 4278237952})
        ..insert('\n');
      final editor = EditorSandBox(
          tester: tester, document: ParchmentDocument.fromDelta(delta));
      await editor.pump();
      final widget = tester.widget<RichText>(find.byType(RichText));
      expect((widget.text as TextSpan).children?[0].style?.color?.value,
          4278237952);
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
