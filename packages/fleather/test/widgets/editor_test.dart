import 'package:fleather/fleather.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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
      var editor =
          EditorSandBox(tester: tester, document: doc, fleatherTheme: theme);
      await editor.pumpAndTap();
      // await tester.pumpAndSettle();
      final p = tester.widget(find.byType(RichText).first) as RichText;
      final text = p.text as TextSpan;
      expect(text.children!.first.style!.color, Colors.red);
    });

    testWidgets('Hides toolbar and selection handles when text changed',
        (tester) async {
      const delta = TextEditingDeltaInsertion(
        oldText: 'Add ',
        textInserted: 'Test',
        insertionOffset: 0,
        selection: TextSelection.collapsed(offset: 0),
        composing: TextRange.empty,
      );
      final editor = EditorSandBox(tester: tester);
      await editor.pump();
      await tester.longPressAt(const Offset(20, 20));
      await tester.pump();
      expect(editor.findSelectionHandles(), findsNWidgets(2));
      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
      final state = tester.state(find.byType(RawEditor)) as RawEditorState;
      state.updateEditingValueWithDeltas([delta]);
      await tester.pump(throttleDuration);
      expect(editor.findSelectionHandles(), findsNothing);
      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
    });

    testWidgets('collapses selection when unfocused', (tester) async {
      final editor = EditorSandBox(tester: tester, autofocus: true);
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
      // account for throttling of history update
      await tester.pumpAndSettle(throttleDuration);
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
      // account for throttling of history update
      await tester.pumpAndSettle(throttleDuration);
      expect(editor.document.toPlainText(), '$clipboardText\n');
    });

    testWidgets('creating editor without focusNode does not throw _CastError',
        (tester) async {
      final widget =
          MaterialApp(home: FleatherEditor(controller: FleatherController()));
      await tester.pumpWidget(widget);
      // Fails if thrown
    });

    group('Text selection', () {
      testWidgets('Can select last separated character in paragraph on iOS',
          (tester) async {
        const text = 'Test.';
        final document = ParchmentDocument.fromJson([
          {'insert': '$text\n'}
        ]);
        final editor = EditorSandBox(
          tester: tester,
          document: document,
          autofocus: true,
          theme: ThemeData(platform: TargetPlatform.iOS),
        );
        await editor.pump();
        await tester.tapAt(tester.getBottomRight(find.byType(FleatherEditor)) -
            const Offset(1, 1));
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection.collapsed(
                offset: text.length, affinity: TextAffinity.upstream));
      });

      testWidgets(
          'Tapping after the beginning of a word moves cursor after word on iOS',
          (tester) async {
        final editor = EditorSandBox(
          tester: tester,
          autofocus: true,
          theme: ThemeData(platform: TargetPlatform.iOS),
        );
        await editor.pump();
        await tester.tapAt(tester.getBottomLeft(find.byType(FleatherEditor)) +
            const Offset(10, -1));
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection.collapsed(
                offset: 4, affinity: TextAffinity.upstream));
      });

      testWidgets(
          'Tapping before the beginning of a word moves cursor at the end of previous word on iOS',
          (tester) async {
        final document = ParchmentDocument.fromJson([
          {'insert': 'ab cd ef\n'}
        ]);
        final editor = EditorSandBox(
          tester: tester,
          document: document,
          autofocus: true,
          theme: ThemeData(platform: TargetPlatform.iOS),
        );
        await editor.pump();
        await tester.tapAt(tester.getBottomLeft(find.byType(FleatherEditor)) +
            const Offset(48, -1));
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection.collapsed(
                offset: 3, affinity: TextAffinity.downstream));
      });

      testWidgets(
          'Tapping moves the cursor right where user tapped on other platforms',
          (tester) async {
        final document = ParchmentDocument.fromJson([
          {'insert': 'Test\n'}
        ]);
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        await tester.tapAt(tester.getBottomLeft(find.byType(FleatherEditor)) +
            const Offset(10, -1));
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection.collapsed(
                offset: 1, affinity: TextAffinity.upstream));
      });

      testWidgets('selection handles for iOS', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final document = ParchmentDocument();
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        final rawEditor = tester.widget<RawEditor>(find.byType(RawEditor));
        expect(rawEditor.selectionControls,
            const TypeMatcher<CupertinoTextSelectionControls>());
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('selection handles for macOS', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        final document = ParchmentDocument();
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        final rawEditor = tester.widget<RawEditor>(find.byType(RawEditor));
        expect(rawEditor.selectionControls,
            const TypeMatcher<CupertinoDesktopTextSelectionControls>());
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('selection handles for Android', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final document = ParchmentDocument();
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        final rawEditor = tester.widget<RawEditor>(find.byType(RawEditor));
        expect(rawEditor.selectionControls,
            const TypeMatcher<MaterialTextSelectionControls>());
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('selection handles for Windows', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        final document = ParchmentDocument();
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        final rawEditor = tester.widget<RawEditor>(find.byType(RawEditor));
        expect(rawEditor.selectionControls,
            const TypeMatcher<DesktopTextSelectionControls>());
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('selection handles for Linux', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        final document = ParchmentDocument();
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        final rawEditor = tester.widget<RawEditor>(find.byType(RawEditor));
        expect(rawEditor.selectionControls,
            const TypeMatcher<DesktopTextSelectionControls>());
        debugDefaultTargetPlatformOverride = null;
      });
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
