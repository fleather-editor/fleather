import 'dart:async';

import 'package:fleather/fleather.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../testing.dart';

Future<void> receiveAction(String selectorName) async {
  return TestAsyncUtils.guard(() {
    final Completer<void> completer = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
          MethodCall('TextInputClient.performSelectors', <dynamic>[
        -1,
        [selectorName]
      ])),
      (ByteData? data) {
        assert(data != null);
        try {
          // Decoding throws a PlatformException if the data represents an
          // error, and that's all we care about here.
          SystemChannels.textInput.codec.decodeEnvelope(data!);
          // If we reach here then no error was found. Complete without issue.
          completer.complete();
        } catch (error) {
          // An exception occurred as a result of receiveAction()'ing. Report
          // that error.
          completer.completeError(error);
        }
      },
    );
    return completer.future;
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('$ExtendSelectionByCharacterIntent right', (tester) async {
    final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Some text\n'}
        ]));
    await editor.pumpAndTap();
    await editor.updateSelection(base: 0, extent: 1);
    await receiveAction('moveRightAndModifySelection:');
    await tester.pumpAndSettle();
    expect(
      editor.controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 2),
    );
  });

  testWidgets('$ExtendSelectionByCharacterIntent left', (tester) async {
    final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Some text\n'}
        ]));
    await editor.pumpAndTap();
    await editor.updateSelection(base: 2, extent: 1);
    await receiveAction('moveLeftAndModifySelection:');
    await tester.pumpAndSettle();
    expect(
      editor.controller.selection,
      const TextSelection(baseOffset: 2, extentOffset: 0),
    );
  });

  testWidgets('$ExtendSelectionByCharacterIntent left', (tester) async {
    final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Some text\n'}
        ]));
    await editor.pumpAndTap();
    await editor.updateSelection(base: 2, extent: 1);
    await receiveAction('moveLeftAndModifySelection:');
    await tester.pumpAndSettle();
    expect(
      editor.controller.selection,
      const TextSelection(baseOffset: 2, extentOffset: 0),
    );
  });

  testWidgets('$ExtendSelectionToNextWordBoundaryIntent right', (tester) async {
    final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Some text\n'}
        ]));
    await editor.pumpAndTap();
    await editor.updateSelection(base: 0, extent: 0);
    await receiveAction('moveWordRightAndModifySelection:');
    await tester.pumpAndSettle();
    expect(
      editor.controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 4),
    );
  });

  testWidgets('$ExtendSelectionToNextWordBoundaryIntent left', (tester) async {
    final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Some text\n'}
        ]));
    await editor.pumpAndTap();
    await editor.updateSelection(base: 3, extent: 3);
    await receiveAction('moveWordLeftAndModifySelection:');
    await tester.pumpAndSettle();
    expect(
      editor.controller.selection,
      const TextSelection(baseOffset: 3, extentOffset: 0),
    );
  });

  testWidgets('$ExpandSelectionToLineBreakIntent left', (tester) async {
    final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Some text\n'}
        ]));
    await editor.pumpAndTap();
    await editor.updateSelection(base: 6, extent: 6);
    await receiveAction('moveToLeftEndOfLineAndModifySelection:');
    await tester.pumpAndSettle();
    expect(
      editor.controller.selection,
      const TextSelection(baseOffset: 6, extentOffset: 0),
    );
  });

  testWidgets('$ExpandSelectionToLineBreakIntent left', (tester) async {
    final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Some text\n'}
        ]));
    await editor.pumpAndTap();
    await editor.updateSelection(base: 3, extent: 5);
    await receiveAction('moveToRightEndOfLineAndModifySelection:');
    await tester.pumpAndSettle();
    expect(
      editor.controller.selection,
      const TextSelection(baseOffset: 3, extentOffset: 9),
    );
  });

  testWidgets('$ExtendSelectionVerticallyToAdjacentLineIntent', (tester) async {
    final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Some text\nSome text\n'}
        ]));
    await editor.pumpAndTap();
    await editor.updateSelection(base: 3, extent: 3);
    await receiveAction('moveDownAndModifySelection:');
    await tester.pumpAndSettle();
    expect(
      editor.controller.selection,
      const TextSelection(baseOffset: 3, extentOffset: 13),
    );
  });

  testWidgets('$ExtendSelectionToDocumentBoundaryIntent to end',
      (tester) async {
    final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Some text\nSome text\n'}
        ]));
    await editor.pumpAndTap();
    await editor.updateSelection(base: 3, extent: 3);
    await receiveAction('moveToEndOfDocument:');
    await tester.pumpAndSettle();
    expect(
        editor.controller.selection,
        const TextSelection.collapsed(
            offset: 19, affinity: TextAffinity.upstream));
  });

  testWidgets('$ExtendSelectionToDocumentBoundaryIntent selection to end',
      (tester) async {
    final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Some text\nSome text\n'}
        ]));
    await editor.pumpAndTap();
    await editor.updateSelection(base: 3, extent: 3);
    await receiveAction('moveToEndOfDocumentAndModifySelection:');
    await tester.pumpAndSettle();
    expect(
        editor.controller.selection,
        const TextSelection(
            baseOffset: 3, extentOffset: 19, affinity: TextAffinity.upstream));
  });

  testWidgets('$ExtendSelectionToDocumentBoundaryIntent to beginning',
      (tester) async {
    final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Some text\nSome text\n'}
        ]));
    await editor.pumpAndTap();
    await editor.updateSelection(base: 13, extent: 13);
    await receiveAction('moveToBeginningOfDocument:');
    await tester.pumpAndSettle();
    expect(
        editor.controller.selection,
        const TextSelection.collapsed(
            offset: 0, affinity: TextAffinity.downstream));
  });

  testWidgets('$ExtendSelectionToDocumentBoundaryIntent selection to beginning',
      (tester) async {
    final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Some text\nSome text\n'}
        ]));
    await editor.pumpAndTap();
    await editor.updateSelection(base: 13, extent: 13);
    await receiveAction('moveToBeginningOfDocumentAndModifySelection:');
    await tester.pumpAndSettle();
    expect(
        editor.controller.selection,
        const TextSelection(
            baseOffset: 13, extentOffset: 0, affinity: TextAffinity.upstream));
  });

  testWidgets('$ExtendSelectionByPageIntent selection to end', (tester) async {
    final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Some text\nSome text\n'}
        ]));
    await editor.pumpAndTap();
    await editor.updateSelection(base: 3, extent: 3);
    await receiveAction('pageDownAndModifySelection:');
    await tester.pumpAndSettle();
    expect(
        editor.controller.selection,
        const TextSelection(
            baseOffset: 3, extentOffset: 19, affinity: TextAffinity.upstream));
  });

  testWidgets('$ExtendSelectionByPageIntent selection to end', (tester) async {
    final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Some text\nSome text\n'}
        ]));
    await editor.pumpAndTap();
    await editor.updateSelection(base: 3, extent: 3);
    await receiveAction('pageDownAndModifySelection:');
    await tester.pumpAndSettle();
    expect(
        editor.controller.selection,
        const TextSelection(
            baseOffset: 3, extentOffset: 19, affinity: TextAffinity.upstream));
  });

  testWidgets('$ScrollIntent page down', (tester) async {
    final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Some text\nSome text\n'}
        ]));
    await editor.pumpAndTap();
    await editor.updateSelection(base: 3, extent: 3);
    await receiveAction('scrollPageDown:');
    await tester.pumpAndSettle();
    expect(
        editor.controller.selection,
        const TextSelection(
            baseOffset: 3, extentOffset: 3, affinity: TextAffinity.downstream));
  });

  testWidgets(
      '$ExtendSelectionToNextParagraphBoundaryOrCaretLocationIntent next',
      (tester) async {
    final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Some text\nSome text\n'}
        ]));
    await editor.pumpAndTap();
    await editor.updateSelection(base: 3, extent: 3);
    await receiveAction('moveParagraphForwardAndModifySelection:');
    await tester.pumpAndSettle();
    expect(
        editor.controller.selection,
        const TextSelection(
            baseOffset: 3,
            extentOffset: 10,
            affinity: TextAffinity.downstream));
  });

  testWidgets(
      '$ExtendSelectionToNextParagraphBoundaryOrCaretLocationIntent previous',
      (tester) async {
    final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Some text\nSome text\n'}
        ]));
    await editor.pumpAndTap();
    await editor.updateSelection(base: 19, extent: 19);
    await receiveAction('moveParagraphBackwardAndModifySelection:');
    await tester.pumpAndSettle();
    expect(
        editor.controller.selection,
        const TextSelection(
            baseOffset: 19,
            extentOffset: 10,
            affinity: TextAffinity.downstream));
  });
}
