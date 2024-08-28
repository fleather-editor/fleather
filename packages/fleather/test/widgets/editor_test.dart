import 'package:fleather/fleather.dart';
import 'package:fleather/src/services/spell_check_suggestions_toolbar.dart';
import 'package:fleather/src/widgets/checkbox.dart';
import 'package:fleather/src/widgets/keyboard_listener.dart';
import 'package:fleather/src/widgets/text_selection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('$RawEditor', () {
    testWidgets('Scrolls to reveal the cursor when keyboard pops up',
        (tester) async {
      final delta = Delta();
      for (int i = 0; i < 20; i++) {
        delta.insert('Test\n');
      }
      final controller =
          FleatherController(document: ParchmentDocument.fromDelta(delta));
      final editor = MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(child: FleatherEditor(controller: controller)),
            ],
          ),
        ),
      );
      await tester.pumpWidget(editor);
      await tester.tapAt(
          tester.getBottomRight(find.byType(RawEditor)) - const Offset(1, 1));
      await tester.pumpAndSettle();
      final renderEditor =
          tester.state<EditorState>(find.byType(RawEditor)).renderEditor;
      final endpoint =
          renderEditor.getEndpointsForSelection(renderEditor.selection);
      expect(
          tester.getRect(find.byType(FleatherEditor)).contains(
              renderEditor.localToGlobal(endpoint[0].point) +
                  renderEditor.paintOffset),
          isTrue);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await tester.pump();
      expect(
          tester.getRect(find.byType(FleatherEditor)).contains(
              renderEditor.localToGlobal(endpoint[0].point) +
                  renderEditor.paintOffset),
          isTrue);
      tester.view.viewInsets = FakeViewPadding.zero;
    });

    testWidgets(
        'Scrolls to reveal the bottom end of cursor when keyboard pops up and cursor is bigger than screen',
        (tester) async {
      final delta = Delta()
        ..insert('Test\n')
        ..insert(EmbeddableObject('image', inline: false))
        ..insert('\n');
      final controller =
          FleatherController(document: ParchmentDocument.fromDelta(delta));
      final embedHeight =
          (tester.view.physicalSize / tester.view.devicePixelRatio).height *
              1.5;
      final editor = MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: FleatherEditor(
                  controller: controller,
                  embedBuilder: (context, node) => SizedBox(
                    width: 100,
                    height: embedHeight,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(editor);
      await tester.tapAt(
          tester.getBottomRight(find.byType(RawEditor)) - const Offset(1, 1));
      await tester.pumpAndSettle();

      final renderEditor =
          tester.state<EditorState>(find.byType(RawEditor)).renderEditor;
      var scrollOffset = -renderEditor.paintOffset.dy;
      tester.view.viewInsets = const FakeViewPadding(bottom: 20);
      await tester.pump();
      expect(-renderEditor.paintOffset.dy > scrollOffset, isTrue);
      scrollOffset = -renderEditor.paintOffset.dy;
      tester.view.viewInsets = const FakeViewPadding(bottom: 40);
      await tester.pump();
      expect(-renderEditor.paintOffset.dy > scrollOffset, isTrue);
      tester.view.viewInsets = FakeViewPadding.zero;
    });

    testWidgets('Allows children to capture events when scrolled',
        (tester) async {
      Delta generateDelta({required bool withBoxChecked}) {
        var delta = Delta();
        List.generate(20, (_) => delta.insert('Test\n'));
        return delta
          ..insert('\n')
          ..insert('some check box')
          ..insert('\n', {'block': 'cl', 'checked': withBoxChecked});
      }

      final delta = generateDelta(withBoxChecked: false);
      final controller =
          FleatherController(document: ParchmentDocument.fromDelta(delta));
      final embedHeight =
          (tester.view.physicalSize / tester.view.devicePixelRatio).height *
              1.5;
      final scrollController = ScrollController();
      final editor = MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: FleatherEditor(
                  controller: controller,
                  scrollController: scrollController,
                  embedBuilder: (context, node) => SizedBox(
                    width: 100,
                    height: embedHeight,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(editor);
      final renderEditor =
          tester.state<EditorState>(find.byType(RawEditor)).renderEditor;
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final checkBox = find.byType(FleatherCheckbox);
      expect(checkBox, findsOneWidget);
      await tester.tapAt(tester.getCenter(checkBox) + renderEditor.paintOffset);
      await tester.pumpAndSettle();
      tester.binding.scheduleWarmUpFrame();
      await tester.pumpAndSettle();
      expect(
          controller.document.toDelta(), generateDelta(withBoxChecked: true));
    });

    testWidgets('Keep selectiontoolbar with editor bounds', (tester) async {
      final delta = Delta();
      for (int i = 0; i < 30; i++) {
        delta.insert('Test\n');
      }
      final scrollController = ScrollController();
      final controller =
          FleatherController(document: ParchmentDocument.fromDelta(delta));
      final editor = MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(width: 300, height: 150),
              Expanded(
                child: FleatherEditor(
                  controller: controller,
                  scrollController: scrollController,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(editor);
      // Double tap to show toolbar
      await tester.tapAt(
          tester.getTopLeft(find.byType(RawEditor)) + const Offset(1, 1));
      await tester.tapAt(
          tester.getTopLeft(find.byType(RawEditor)) + const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(find.byType(TextSelectionToolbar), findsOneWidget);
      // Scroll extent is > 500, toolbar position should be around -400 if not
      // capped
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final renderToolbarTextButton =
          tester.renderObject(find.byType(TextSelectionToolbarTextButton).first)
              as RenderBox;
      final toolbarTop = renderToolbarTextButton.localToGlobal(Offset.zero);
      expect(toolbarTop.dy, greaterThan(90));
    });

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

    testWidgets('changes to controller does not request keyboard',
        (tester) async {
      final editor = EditorSandBox(tester: tester);
      await editor.pump();
      await editor.updateSelection(base: 0, extent: 3);
      await tester.pump();
      expect(editor.focusNode.hasFocus, false);
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

    testWidgets(
        'Selection handles are disposed when selection overlay disposed',
        (tester) async {
      final focusNode = FocusNode();
      final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromDelta(Delta()..insert('Text\n')),
        focusNode: focusNode,
      );
      await editor.pump();
      await tester.tapAt(
          tester.getTopLeft(find.byType(RawEditor)) + const Offset(15, 5));
      focusNode.unfocus();
      await tester.pumpAndSettle();
      expect(editor.findSelectionHandles(), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('Selection handle is hidden when editor is read-only',
        (tester) async {
      final editor = EditorSandBox(
          tester: tester,
          document: ParchmentDocument.fromDelta(Delta()..insert('Text\n')));
      await editor.pump();
      await editor.disable();
      await tester.tapAt(
          tester.getTopLeft(find.byType(RawEditor)) + const Offset(15, 5));
      await tester.pumpAndSettle();
      final handle = tester.widget(editor.findSelectionHandles().first)
          as SelectionHandleOverlay;
      expect(handle.visibility?.value, false);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

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

    testWidgets('Copy intent sends data to clipboard manager', (tester) async {
      prepareClipboard();
      FleatherClipboardData? sentData;
      final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Test Text\n'}
        ]),
        autofocus: true,
        clipboardManager: FleatherCustomClipboardManager(
          getData: () => throw UnimplementedError(),
          setData: (data) async => sentData = data,
        ),
      );
      await editor.pump();
      final RawEditorState state =
          tester.state<RawEditorState>(find.byType(RawEditor));
      await editor.updateSelection(base: 3, extent: 6);
      state.showToolbar(createIfNull: true);
      await tester.pump();
      final finder = find.text('Copy');
      await tester.tap(finder);
      await tester.pumpAndSettle(throttleDuration);
      expect(sentData?.plainText, 't T');
      expect(sentData?.delta, Delta()..insert('t T'));
    });

    testWidgets(
        'Copy sends correct data to clipboard manager when selection extents are inverted',
        (tester) async {
      prepareClipboard();
      FleatherClipboardData? sentData;
      final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Test Text\n'}
        ]),
        autofocus: true,
        clipboardManager: FleatherCustomClipboardManager(
          getData: () => throw UnimplementedError(),
          setData: (data) async => sentData = data,
        ),
      );
      await editor.pump();
      final RawEditorState state =
          tester.state<RawEditorState>(find.byType(RawEditor));
      await editor.updateSelection(base: 6, extent: 3);
      state.showToolbar(createIfNull: true);
      await tester.pump();
      final finder = find.text('Copy');
      await tester.tap(finder);
      await tester.pumpAndSettle(throttleDuration);
      expect(sentData?.plainText, 't T');
      expect(sentData?.delta, Delta()..insert('t T'));
    });

    testWidgets('Cut intent sends data to clipboard manager', (tester) async {
      prepareClipboard();
      FleatherClipboardData? sentData;
      final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Test Text\n'}
        ]),
        autofocus: true,
        clipboardManager: FleatherCustomClipboardManager(
          getData: () => throw UnimplementedError(),
          setData: (data) async => sentData = data,
        ),
      );
      await editor.pump();
      final RawEditorState state =
          tester.state<RawEditorState>(find.byType(RawEditor));
      await editor.updateSelection(base: 3, extent: 6);
      state.showToolbar(createIfNull: true);
      await tester.pump();
      final finder = find.text('Cut');
      await tester.tap(finder);
      await tester.pumpAndSettle(throttleDuration);
      expect(sentData?.plainText, 't T');
      expect(sentData?.delta, Delta()..insert('t T'));
      expect(editor.selection, const TextSelection.collapsed(offset: 3));
    });

    testWidgets('Paste intent gets data from clipboard manager',
        (tester) async {
      prepareClipboard();
      var data = FleatherClipboardData(plainText: 'Test');
      final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument(),
        autofocus: true,
        clipboardManager: FleatherCustomClipboardManager(
          getData: () => Future.value(data),
          setData: (_) => throw UnimplementedError(),
        ),
      );
      await editor.pump();

      await sendPasteIntent(tester);
      expect(editor.document.toPlainText(), 'Test\n');

      data = FleatherClipboardData(
        plainText: 'Delta takes precedence to plainText',
        delta: Delta()..insert('Text', {'b': true}),
      );

      await sendPasteIntent(tester);
      expect(
          editor.document.toDelta(),
          Delta()
            ..insert('Test')
            ..insert('Text', {'b': true})
            ..insert('\n'));

      await tester.pumpAndSettle(throttleDuration);
    });

    testWidgets('Paste updates selection correctly', (tester) async {
      prepareClipboard();
      var data = FleatherClipboardData(plainText: 'Test');
      final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromJson([
          {'insert': 'Hello World!\n'}
        ]),
        autofocus: true,
        clipboardManager: FleatherCustomClipboardManager(
          getData: () => Future.value(data),
          setData: (_) => throw UnimplementedError(),
        ),
      );
      await editor.pump();
      await editor.updateSelection(base: 6, extent: 11);

      await sendPasteIntent(tester);
      expect(editor.document.toPlainText(), 'Hello Test!\n');
      expect(editor.selection, const TextSelection.collapsed(offset: 10));

      data = FleatherClipboardData(
        delta: Delta()..insert('Text', {'b': true}),
      );

      await editor.updateSelection(base: 6, extent: 10);
      await sendPasteIntent(tester);

      expect(editor.document.toPlainText(), 'Hello Text!\n');
      expect(editor.selection, const TextSelection.collapsed(offset: 10));

      await tester.pumpAndSettle(throttleDuration);
    });

    group('Text selection', () {
      testWidgets('disabled selection interaction disables associated gestures',
          (tester) async {
        final editor =
            EditorSandBox(tester: tester, enableSelectionInteraction: false);
        await editor.pump();
        expect(find.byType(TextSelectionGestureDetector), findsNothing);
      });

      testWidgets('hides toolbar and selection handles when text changed',
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
        tester.binding.scheduleWarmUpFrame();
        await tester.pump();
        expect(editor.findSelectionHandles(), findsNWidgets(2));
        expect(find.byType(TextSelectionToolbar), findsOneWidget);
        final state = tester.state(find.byType(RawEditor)) as RawEditorState;
        state.updateEditingValueWithDeltas([delta]);
        await tester.pump(throttleDuration);
        expect(editor.findSelectionHandles(), findsNothing);
        expect(find.byType(TextSelectionToolbar), findsNothing);
      });

      testWidgets(
          'Secondary tap opens toolbar and selects the word on mac/iOS when not focused or tap was different than selection',
          (tester) async {
        final document = ParchmentDocument.fromJson([
          {'insert': 'Test\n'}
        ]);
        final editor = EditorSandBox(tester: tester, document: document);
        await editor.pump();
        await tester.tapAt(
            tester.getTopLeft(find.byType(FleatherEditor)) + const Offset(1, 1),
            buttons: kSecondaryMouseButton);
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection(
                baseOffset: 0,
                extentOffset: 4,
                affinity: TextAffinity.upstream));
        expect(find.byType(CupertinoTextSelectionToolbar), findsOneWidget);
        await tester.tapAt(
            tester.getTopLeft(find.byType(FleatherEditor)) +
                const Offset(10, 1),
            buttons: kSecondaryMouseButton);
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection(
                baseOffset: 0,
                extentOffset: 4,
                affinity: TextAffinity.upstream));
        expect(find.byType(CupertinoTextSelectionToolbar), findsOneWidget);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

      testWidgets(
          'Secondary tap opens toolbar and selection is collapsed on mac/iOS when focused or tap position was the same as selection',
          (tester) async {
        final document = ParchmentDocument.fromJson([
          {'insert': 'Test\n'}
        ]);
        final editor = EditorSandBox(tester: tester, document: document);
        await editor.pump();
        await tester.tapAt(
            tester.getTopLeft(find.byType(FleatherEditor)) + const Offset(1, 1),
            buttons: kSecondaryMouseButton);
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection(
                baseOffset: 0,
                extentOffset: 4,
                affinity: TextAffinity.upstream));
        expect(
            find.byType(CupertinoDesktopTextSelectionToolbar), findsOneWidget);
        await tester.tapAt(
            tester.getTopLeft(find.byType(FleatherEditor)) + const Offset(1, 1),
            buttons: kPrimaryMouseButton);
        await tester.pump();
        expect(find.byType(CupertinoDesktopTextSelectionToolbar), findsNothing);
        await tester.tapAt(
            tester.getTopLeft(find.byType(FleatherEditor)) + const Offset(1, 1),
            buttons: kSecondaryMouseButton);
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection.collapsed(
                offset: 0, affinity: TextAffinity.downstream));
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

      testWidgets(
          'Secondary tap toggles toolbar on platforms other than mac/iOS',
          (tester) async {
        final document = ParchmentDocument.fromJson([
          {'insert': 'Test\n'}
        ]);
        final editor = EditorSandBox(tester: tester, document: document);
        await editor.pump();
        await tester.tapAt(
            tester.getTopLeft(find.byType(FleatherEditor)) +
                const Offset(10, 1),
            buttons: kSecondaryMouseButton);
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection.collapsed(
                offset: 1, affinity: TextAffinity.upstream));
        expect(find.byType(DesktopTextSelectionToolbar), findsOneWidget);
        await tester.tapAt(
            tester.getTopLeft(find.byType(FleatherEditor)) +
                const Offset(10, 1),
            buttons: kSecondaryMouseButton);
        await tester.pump();
        expect(find.byType(DesktopTextSelectionToolbar), findsNothing);
      }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

      testWidgets(
          'Shift tap selects from beginning when unfocused on macOS/iOS',
          (tester) async {
        final document = ParchmentDocument.fromJson([
          {'insert': 'Test\n'}
        ]);
        final editor = EditorSandBox(
            tester: tester,
            document: document,
            focusNode: FocusNode(canRequestFocus: false));
        await editor.pump();
        await editor.updateSelection(base: 1, extent: 1);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.tapAt(tester.getTopRight(find.byType(FleatherEditor)) +
            const Offset(-1, 1));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection(
                baseOffset: 0,
                extentOffset: 4,
                affinity: TextAffinity.upstream));
      },
          variant: const TargetPlatformVariant(
              {TargetPlatform.iOS, TargetPlatform.macOS}));

      testWidgets(
          'Shift tap selects from current selection when focused on macOS/iOS',
          (tester) async {
        final document = ParchmentDocument.fromJson([
          {'insert': 'Test\n'}
        ]);
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        await editor.updateSelection(base: 1, extent: 1);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.tapAt(tester.getBottomRight(find.byType(FleatherEditor)) -
            const Offset(1, 1));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection(
                baseOffset: 1,
                extentOffset: 4,
                affinity: TextAffinity.upstream));
      },
          variant: const TargetPlatformVariant(
              {TargetPlatform.macOS, TargetPlatform.iOS}));

      testWidgets('Mouse drag updates selection', (tester) async {
        final document = ParchmentDocument.fromJson([
          {'insert': 'Test\n'}
        ]);
        final editor = EditorSandBox(tester: tester, document: document);
        await editor.pump();
        final gesture = await tester.startGesture(
          tester.getTopLeft(find.byType(FleatherEditor)) + const Offset(10, 1),
          pointer: tester.nextPointer,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection.collapsed(
                offset: 1, affinity: TextAffinity.upstream));
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(
            editor.selection,
            const TextSelection(
                baseOffset: 1,
                extentOffset: 2,
                affinity: TextAffinity.upstream));
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

      testWidgets('Mouse drag with shift extends selection', (tester) async {
        final document = ParchmentDocument.fromJson([
          {'insert': 'Test test\n'}
        ]);
        final editor = EditorSandBox(tester: tester, document: document);
        await editor.pumpAndTap();
        await editor.updateSelection(base: 1, extent: 2);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        final gesture = await tester.startGesture(
          tester.getTopLeft(find.byType(FleatherEditor)) + const Offset(45, 1),
          pointer: tester.nextPointer,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection(
                baseOffset: 1,
                extentOffset: 3,
                affinity: TextAffinity.upstream));
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(
            editor.selection,
            const TextSelection(
                baseOffset: 1,
                extentOffset: 5,
                affinity: TextAffinity.upstream));
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

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
        );
        await editor.pump();
        await tester.tapAt(tester.getBottomRight(find.byType(FleatherEditor)) -
            const Offset(1, 1));
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection.collapsed(
                offset: text.length, affinity: TextAffinity.upstream));
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

      testWidgets(
          'Tapping after the beginning of a word moves cursor after word on iOS',
          (tester) async {
        final editor = EditorSandBox(tester: tester, autofocus: true);
        await editor.pump();
        await tester.tapAt(tester.getBottomLeft(find.byType(FleatherEditor)) +
            const Offset(10, -1));
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection.collapsed(
                offset: 4, affinity: TextAffinity.upstream));
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

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
        );
        await editor.pump();
        await tester.tapAt(tester.getBottomLeft(find.byType(FleatherEditor)) +
            const Offset(48, -1));
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection.collapsed(
                offset: 3, affinity: TextAffinity.upstream));
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

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
        final document = ParchmentDocument();
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        final rawEditor = tester.widget<RawEditor>(find.byType(RawEditor));
        expect(rawEditor.selectionControls,
            const TypeMatcher<CupertinoTextSelectionControls>());
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

      testWidgets('selection handles for macOS', (tester) async {
        final document = ParchmentDocument();
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        final rawEditor = tester.widget<RawEditor>(find.byType(RawEditor));
        expect(rawEditor.selectionControls,
            const TypeMatcher<CupertinoDesktopTextSelectionControls>());
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

      testWidgets('selection handles for Android', (tester) async {
        final document = ParchmentDocument();
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        final rawEditor = tester.widget<RawEditor>(find.byType(RawEditor));
        expect(rawEditor.selectionControls,
            const TypeMatcher<MaterialTextSelectionControls>());
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));

      testWidgets(
          'show single selection handle when setting cursor position (Android)',
          (tester) async {
        final document = ParchmentDocument.fromJson([
          {'insert': 'Some piece of text\n'}
        ]);
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        await tester.tapAt(tester.getTopLeft(find.byType(FleatherEditor)) +
            const Offset(30, 1));
        tester.binding.scheduleWarmUpFrame();
        await tester.pump();
        final handleOverlays = find.byType(SelectionHandleOverlay);
        expect(handleOverlays, findsOneWidget);
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));

      testWidgets('dragging collapsed selection shows magnifier',
          (tester) async {
        final document = ParchmentDocument.fromJson([
          {'insert': 'Some piece of text\n'}
        ]);
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        final gesture = await tester.startGesture(
            tester.getBottomLeft(find.byType(FleatherEditor)) +
                const Offset(10, -1));
        await gesture.moveBy(
            tester.getBottomLeft(find.byType(FleatherEditor)) +
                const Offset(40, 0),
            timeStamp: const Duration(seconds: 1));
        tester.binding.scheduleWarmUpFrame();
        await tester.pump();
        final magnifier = find.byType(TextMagnifier);
        expect(magnifier, findsOneWidget);
        await gesture.up();
        await tester.pump();
        expect(magnifier, findsNothing);
      });

      testWidgets('dragging selection end handle shows magnifier',
          (tester) async {
        final document = ParchmentDocument.fromJson([
          {'insert': 'Some piece of text\n'}
        ]);
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        await tester.tapAt(tester.getBottomLeft(find.byType(FleatherEditor)) +
            const Offset(10, -1));
        await tester.tapAt(tester.getBottomLeft(find.byType(FleatherEditor)) +
            const Offset(10, -1));
        await tester.pump();
        final handleOverlays = find.byType(SelectionHandleOverlay);
        expect(handleOverlays, findsNWidgets(2));
        final endHandle = find.descendant(
            of: handleOverlays.last, matching: find.byType(SizedBox));
        expect(endHandle, findsOneWidget);
        final gesture = await tester.startGesture(tester.getCenter(endHandle));
        await gesture.moveBy(const Offset(40, 0));
        await tester.pump();
        final magnifier = find.byType(TextMagnifier);
        expect(magnifier, findsOneWidget);
        await gesture.up();
        await tester.pump();
        expect(magnifier, findsNothing);
      });

      testWidgets('drag selection start handle shows magnifier',
          (tester) async {
        final document = ParchmentDocument.fromJson([
          {'insert': 'Some piece of text\n'}
        ]);
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        await tester.tapAt(tester.getBottomLeft(find.byType(FleatherEditor)) +
            const Offset(100, -1));
        await tester.tapAt(tester.getBottomLeft(find.byType(FleatherEditor)) +
            const Offset(100, -1));
        await tester.pump();
        final handleOverlays = find.byType(SelectionHandleOverlay);
        expect(handleOverlays, findsNWidgets(2));
        final startHandle = find.descendant(
            of: handleOverlays.first, matching: find.byType(SizedBox));
        expect(startHandle, findsOneWidget);
        final gesture =
            await tester.startGesture(tester.getCenter(startHandle));
        await gesture.moveBy(const Offset(-15, 0));
        await tester.pump();
        final magnifier = find.byType(TextMagnifier);
        expect(magnifier, findsOneWidget);
        await gesture.up();
        await tester.pump();
        expect(magnifier, findsNothing);
      });

      testWidgets('selection handles for Windows', (tester) async {
        final document = ParchmentDocument();
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        final rawEditor = tester.widget<RawEditor>(find.byType(RawEditor));
        expect(rawEditor.selectionControls,
            const TypeMatcher<DesktopTextSelectionControls>());
      }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

      testWidgets('selection handles for Linux', (tester) async {
        final document = ParchmentDocument();
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        final rawEditor = tester.widget<RawEditor>(find.byType(RawEditor));
        expect(rawEditor.selectionControls,
            const TypeMatcher<DesktopTextSelectionControls>());
      }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

      testWidgets('selectAll for macOS', (tester) async {
        final document = ParchmentDocument.fromJson([
          {'insert': 'Test\nAnother line\n'}
        ]);
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        await tester.tapAt(
            tester.getTopLeft(find.byType(FleatherEditor)) + const Offset(1, 1),
            buttons: kSecondaryMouseButton);
        tester.binding.scheduleWarmUpFrame();
        await tester.pump();
        expect(
            find.byType(CupertinoDesktopTextSelectionToolbar), findsOneWidget);
        await tester.tap(find.text('Select All')); // Select All in macOS
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection(
                baseOffset: 0,
                extentOffset: 17,
                affinity: TextAffinity.upstream));
        expect(find.byType(CupertinoDesktopTextSelectionToolbar), findsNothing);
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

      testWidgets('selectAll for Windows/Linux', (tester) async {
        final document = ParchmentDocument.fromJson([
          {'insert': 'Test\nAnother line\n'}
        ]);
        final editor = EditorSandBox(tester: tester, document: document);
        await editor.pump();
        await tester.tapAt(
            tester.getTopLeft(find.byType(FleatherEditor)) + const Offset(1, 1),
            buttons: kSecondaryMouseButton);
        await tester.pump();
        expect(find.byType(DesktopTextSelectionToolbar), findsOneWidget);
        await tester
            .tap(find.text('Select all')); // Select all in other than macOS
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection(
                baseOffset: 0,
                extentOffset: 17,
                affinity: TextAffinity.upstream));
        expect(find.byType(DesktopTextSelectionToolbar), findsNothing);
      },
          variant: const TargetPlatformVariant(
              {TargetPlatform.linux, TargetPlatform.windows}));

      testWidgets('Triple tap selects paragraph on platforms other than Linux',
          (tester) async {
        const text =
            'This is a relatively long paragraph with multiple lines that'
            ' we are going to triple tap on it in order to select it.';
        final document = ParchmentDocument.fromJson([
          {'insert': '$text\n'},
          {'insert': 'Some other text in another paragraph\n'},
        ]);
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        await tester.tapAt(tester.getTopLeft(find.byType(FleatherEditor)) +
            const Offset(1, 1));
        await tester.tapAt(tester.getTopLeft(find.byType(FleatherEditor)) +
            const Offset(1, 1));
        await tester.tapAt(tester.getTopLeft(find.byType(FleatherEditor)) +
            const Offset(1, 1));
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection(
                baseOffset: 0,
                extentOffset: 117,
                affinity: TextAffinity.upstream));
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

      testWidgets('Triple tap selects a line on Linux', (tester) async {
        const text =
            'This is a relatively long paragraph with multiple lines that'
            ' we are going to triple tap on it in order to select it.';
        final document = ParchmentDocument.fromJson([
          {'insert': '$text\n'},
          {'insert': 'Some other text in another paragraph\n'},
        ]);
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        await tester.tapAt(tester.getTopLeft(find.byType(FleatherEditor)) +
            const Offset(1, 1));
        await tester.tapAt(tester.getTopLeft(find.byType(FleatherEditor)) +
            const Offset(1, 1));
        await tester.tapAt(tester.getTopLeft(find.byType(FleatherEditor)) +
            const Offset(1, 1));
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection(
                baseOffset: 0,
                extentOffset: 50,
                affinity: TextAffinity.upstream));
      }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

      testWidgets(
          'Arrow keys move cursor to next/previous line at correct position',
          (tester) async {
        const text =
            'This is a relatively long paragraph with multiple lines and an inline embed: ';
        final document = ParchmentDocument.fromJson([
          {'insert': text},
          {
            'insert': {
              '_type': 'icon',
              '_inline': true,
              'codePoint': '0xf0653',
              'fontFamily': 'MaterialIcons',
              'color': '0xFF2196F3'
            }
          },
          {'insert': '\n\n'},
        ]);
        final editor = EditorSandBox(
          tester: tester,
          document: document,
          autofocus: true,
          embedBuilder: (BuildContext context, EmbedNode node) {
            if (node.value.type == 'icon') {
              final data = node.value.data;
              return Icon(
                IconData(int.parse(data['codePoint']),
                    fontFamily: data['fontFamily']),
                color: Color(int.parse(data['color'])),
                size: 100,
              );
            }
            throw UnimplementedError();
          },
        );
        await editor.pump();
        editor.controller.updateSelection(
            const TextSelection.collapsed(offset: text.length));
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        expect(editor.selection, const TextSelection.collapsed(offset: 27));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        expect(editor.selection,
            const TextSelection.collapsed(offset: text.length));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        expect(editor.selection, const TextSelection.collapsed(offset: 50));
      });

      testWidgets(
          'Arrow keys move cursor to next/previous block at correct position',
          (tester) async {
        const text =
            'This is a relatively long paragraph with multiple lines with inline embeds in next paragraph.';
        final document = ParchmentDocument.fromJson([
          {'insert': '$text\n'},
          {
            'insert': {
              '_type': 'something',
              '_inline': true,
            }
          },
          {
            'insert': {
              '_type': 'something',
              '_inline': true,
            }
          },
          {'insert': '\n'},
        ]);
        final editor = EditorSandBox(
          tester: tester,
          document: document,
          autofocus: true,
          embedBuilder: (BuildContext context, EmbedNode node) {
            if (node.value.type == 'something') {
              return const Padding(
                padding: EdgeInsets.only(left: 4, right: 2, top: 2, bottom: 2),
                child: SizedBox(
                  width: 300,
                  height: 300,
                ),
              );
            }
            throw UnimplementedError();
          },
        );
        await editor.pump();
        editor.controller.updateSelection(
            const TextSelection.collapsed(offset: text.length + 2));
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        expect(editor.selection, const TextSelection.collapsed(offset: 69));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        expect(editor.selection,
            const TextSelection.collapsed(offset: text.length + 2));
      });

      testWidgets('Arrow down moves cursor to lower line at correct position',
          (tester) async {
        const text =
            'This is a relatively long paragraph with multiple lines and an inline embed: ';
        final document = ParchmentDocument.fromJson([
          {'insert': text},
          {
            'insert': {
              '_type': 'icon',
              '_inline': true,
              'codePoint': '0xf0653',
              'fontFamily': 'MaterialIcons',
              'color': '0xFF2196F3'
            }
          },
          {'insert': '\n'},
        ]);
        final editor = EditorSandBox(
          tester: tester,
          document: document,
          autofocus: true,
          embedBuilder: (BuildContext context, EmbedNode node) {
            if (node.value.type == 'icon') {
              final data = node.value.data;
              return Icon(
                IconData(int.parse(data['codePoint']),
                    fontFamily: data['fontFamily']),
                color: Color(int.parse(data['color'])),
                size: 100,
              );
            }
            throw UnimplementedError();
          },
        );
        await editor.pump();
        editor.controller
            .updateSelection(const TextSelection.collapsed(offset: 27));
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        expect(editor.selection,
            const TextSelection.collapsed(offset: text.length));
      });
    });

    group('Spell check', () {
      final spellCheckService = FakeSpellCheckService();

      Future<EditorSandBox> prepareTest(
          WidgetTester tester, ParchmentDocument document) async {
        final editor = EditorSandBox(
            tester: tester,
            document: document,
            autofocus: true,
            spellCheckService: spellCheckService);
        await editor.pump();
        return editor;
      }

      testWidgets('suggests correction on initial load (Android)',
          (tester) async {
        spellCheckService.stub = (_, __) async {
          return [
            const SuggestionSpan(
              TextRange(start: 0, end: 4),
              ['Same', 'Some', 'Sales'],
            )
          ];
        };
        await prepareTest(
            tester,
            ParchmentDocument.fromJson([
              {'insert': 'Sole text\n'}
            ]));
        await tester.tapAt(tester.getTopLeft(find.byType(FleatherEditor)) +
            const Offset(1, 1));
        await tester.tapAt(tester.getTopLeft(find.byType(FleatherEditor)) +
            const Offset(1, 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.tapAt(tester.getTopLeft(find.byType(FleatherEditor)) +
            const Offset(1, 1));
        await tester.pump();
        expect(
            find.byType(FleatherSpellCheckSuggestionsToolbar), findsOneWidget);
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));

      testWidgets('suggests correction on initial load (iOS)', (tester) async {
        spellCheckService.stub = (_, __) async {
          return [
            const SuggestionSpan(
              TextRange(start: 0, end: 4),
              ['Same', 'Some', 'Sales'],
            )
          ];
        };
        await prepareTest(
            tester,
            ParchmentDocument.fromJson([
              {'insert': 'Sole text\n'}
            ]));
        await tester.tapAt(tester.getTopLeft(find.byType(FleatherEditor)) +
            const Offset(1, 1));
        await tester.pump();
        expect(find.byType(FleatherCupertinoSpellCheckSuggestionsToolbar),
            findsOneWidget);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

      testWidgets('replaces text with selected suggestion (Android)',
          (tester) async {
        spellCheckService.stub = (_, __) async {
          return [
            const SuggestionSpan(
              TextRange(start: 0, end: 4),
              ['Same', 'Some', 'Sales'],
            )
          ];
        };
        final editor = await prepareTest(
            tester,
            ParchmentDocument.fromJson([
              {'insert': 'Sole text\n'}
            ]));
        await tester.tapAt(tester.getTopLeft(find.byType(FleatherEditor)) +
            const Offset(1, 1));
        await tester.tapAt(tester.getTopLeft(find.byType(FleatherEditor)) +
            const Offset(1, 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.tapAt(tester.getTopLeft(find.byType(FleatherEditor)) +
            const Offset(1, 1));
        await tester.pump();
        await tester.tap(find.text('Some'));
        await tester.pump(throttleDuration);
        expect(editor.controller.document.toPlainText(), 'Some text\n');
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));

      testWidgets('deletes erroneous text (Android)', (tester) async {
        spellCheckService.stub = (_, __) async {
          return [
            const SuggestionSpan(
              TextRange(start: 0, end: 4),
              ['Same', 'Some', 'Sales'],
            )
          ];
        };
        final editor = await prepareTest(
            tester,
            ParchmentDocument.fromJson([
              {'insert': 'Sole text\n'}
            ]));
        await tester.tapAt(tester.getTopLeft(find.byType(FleatherEditor)) +
            const Offset(1, 1));
        await tester.tapAt(tester.getTopLeft(find.byType(FleatherEditor)) +
            const Offset(1, 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.tapAt(tester.getTopLeft(find.byType(FleatherEditor)) +
            const Offset(1, 1));
        await tester.pump();
        await tester.tap(find.text(const DefaultMaterialLocalizations()
            .deleteButtonTooltip
            .toUpperCase()));
        await tester.pump(throttleDuration);
        expect(editor.controller.document.toPlainText(), 'Sole text\n');
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));

      testWidgets('replaces text with selected suggestion (iOS)',
          (tester) async {
        spellCheckService.stub = (_, __) async {
          return [
            const SuggestionSpan(
              TextRange(start: 0, end: 4),
              ['Same', 'Some', 'Sales'],
            )
          ];
        };
        final editor = await prepareTest(
            tester,
            ParchmentDocument.fromJson([
              {'insert': 'Sole text\n'}
            ]));
        await tester.tapAt(tester.getTopLeft(find.byType(FleatherEditor)) +
            const Offset(1, 1));
        await tester.pump();
        await tester.tap(find.text('Some'));
        await tester.pump(throttleDuration);
        expect(editor.controller.document.toPlainText(), 'Some text\n');
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
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
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
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

Future<void> sendPasteIntent(WidgetTester tester) => (Actions.invoke(
    tester.state(find.byType(FleatherKeyboardListener)).context,
    const PasteTextIntent(SelectionChangedCause.longPress)) as Future);
