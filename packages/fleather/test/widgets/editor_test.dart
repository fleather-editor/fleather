import 'package:fleather/fleather.dart';
import 'package:fleather/src/services/spell_check_suggestions_toolbar.dart';
import 'package:fleather/src/widgets/text_selection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
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
      tester.binding.scheduleWarmUpFrame();
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
      tester.binding.scheduleWarmUpFrame();
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

      testWidgetsWithPlatform(
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
      }, [TargetPlatform.iOS]);

      testWidgetsWithPlatform(
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
      }, [TargetPlatform.macOS]);

      testWidgetsWithPlatform(
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
      }, [TargetPlatform.windows]);

      testWidgetsWithPlatform(
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
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection(
                baseOffset: 0,
                extentOffset: 4,
                affinity: TextAffinity.upstream));
      }, [TargetPlatform.macOS, TargetPlatform.iOS]);

      testWidgetsWithPlatform(
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
        await tester.pump();
        expect(
            editor.selection,
            const TextSelection(
                baseOffset: 1,
                extentOffset: 4,
                affinity: TextAffinity.upstream));
      }, [TargetPlatform.macOS, TargetPlatform.iOS]);

      testWidgetsWithPlatform('Mouse drag updates selection', (tester) async {
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
      }, [TargetPlatform.macOS]);

      testWidgetsWithPlatform('Mouse drag with shift extends selection',
          (tester) async {
        final document = ParchmentDocument.fromJson([
          {'insert': 'Test test\n'}
        ]);
        final editor = EditorSandBox(tester: tester, document: document);
        await editor.pump();
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
      }, [TargetPlatform.macOS]);

      testWidgetsWithPlatform(
          'Can select last separated character in paragraph on iOS',
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
      }, [TargetPlatform.iOS]);

      testWidgetsWithPlatform(
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
      }, [TargetPlatform.iOS]);

      testWidgetsWithPlatform(
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
      }, [TargetPlatform.iOS]);

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

      testWidgetsWithPlatform('selection handles for iOS', (tester) async {
        final document = ParchmentDocument();
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        final rawEditor = tester.widget<RawEditor>(find.byType(RawEditor));
        expect(rawEditor.selectionControls,
            const TypeMatcher<CupertinoTextSelectionControls>());
      }, [TargetPlatform.iOS]);

      testWidgetsWithPlatform('selection handles for macOS', (tester) async {
        final document = ParchmentDocument();
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        final rawEditor = tester.widget<RawEditor>(find.byType(RawEditor));
        expect(rawEditor.selectionControls,
            const TypeMatcher<CupertinoDesktopTextSelectionControls>());
      }, [TargetPlatform.macOS]);

      testWidgetsWithPlatform('selection handles for Android', (tester) async {
        final document = ParchmentDocument();
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        final rawEditor = tester.widget<RawEditor>(find.byType(RawEditor));
        expect(rawEditor.selectionControls,
            const TypeMatcher<MaterialTextSelectionControls>());
      }, [TargetPlatform.android]);

      testWidgetsWithPlatform(
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
      }, [TargetPlatform.android]);

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
        tester.binding.scheduleWarmUpFrame();
        await tester.pump();
        final handleOverlays = find.byType(SelectionHandleOverlay);
        expect(handleOverlays, findsNWidgets(2));
        final endHandle = find.descendant(
            of: handleOverlays.last, matching: find.byType(SizedBox));
        expect(endHandle, findsOneWidget);
        final gesture = await tester.startGesture(
            tester.getBottomRight(endHandle) - const Offset(1, 1));
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
        tester.binding.scheduleWarmUpFrame();
        await tester.pump();
        final handleOverlays = find.byType(SelectionHandleOverlay);
        expect(handleOverlays, findsNWidgets(2));
        final startHandle = find.descendant(
            of: handleOverlays.first, matching: find.byType(SizedBox));
        expect(startHandle, findsOneWidget);
        final gesture = await tester.startGesture(
            tester.getBottomRight(startHandle) - const Offset(-1, 1));
        await gesture.moveBy(const Offset(-15, 0));
        await tester.pump();
        final magnifier = find.byType(TextMagnifier);
        expect(magnifier, findsOneWidget);
        await gesture.up();
        await tester.pump();
        expect(magnifier, findsNothing);
      });

      testWidgetsWithPlatform('selection handles for Windows', (tester) async {
        final document = ParchmentDocument();
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        final rawEditor = tester.widget<RawEditor>(find.byType(RawEditor));
        expect(rawEditor.selectionControls,
            const TypeMatcher<DesktopTextSelectionControls>());
      }, [TargetPlatform.windows]);

      testWidgetsWithPlatform('selection handles for Linux', (tester) async {
        final document = ParchmentDocument();
        final editor =
            EditorSandBox(tester: tester, document: document, autofocus: true);
        await editor.pump();
        final rawEditor = tester.widget<RawEditor>(find.byType(RawEditor));
        expect(rawEditor.selectionControls,
            const TypeMatcher<DesktopTextSelectionControls>());
      }, [TargetPlatform.linux]);

      testWidgetsWithPlatform('selectAll for macOS', (tester) async {
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
      }, [TargetPlatform.macOS]);

      testWidgetsWithPlatform('selectAll for Windows/Linux', (tester) async {
        final document = ParchmentDocument.fromJson([
          {'insert': 'Test\nAnother line\n'}
        ]);
        final editor = EditorSandBox(tester: tester, document: document);
        await editor.pump();
        await tester.tapAt(
            tester.getTopLeft(find.byType(FleatherEditor)) + const Offset(1, 1),
            buttons: kSecondaryMouseButton);
        tester.binding.scheduleWarmUpFrame();
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
      }, [TargetPlatform.linux, TargetPlatform.windows]);

      testWidgetsWithPlatform(
          'Triple tap selects paragraph on platforms other than Linux',
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
      }, [TargetPlatform.macOS]);

      testWidgetsWithPlatform('Triple tap selects a line on Linux',
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
                extentOffset: 50,
                affinity: TextAffinity.upstream));
      }, [TargetPlatform.linux]);

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
        editor.controller.updateSelection(
            const TextSelection.collapsed(offset: text.length));
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        expect(editor.selection, const TextSelection.collapsed(offset: 27));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        expect(editor.selection,
            const TextSelection.collapsed(offset: text.length));
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

      testWidgetsWithPlatform('suggests correction on initial load (Android)',
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
      }, [TargetPlatform.android]);

      testWidgetsWithPlatform('suggests correction on initial load (iOS)',
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
        await tester.pump();
        expect(find.byType(FleatherCupertinoSpellCheckSuggestionsToolbar),
            findsOneWidget);
      }, [TargetPlatform.iOS]);

      testWidgetsWithPlatform(
          'replaces text with selected suggestion (Android)', (tester) async {
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
      }, [TargetPlatform.android]);

      testWidgetsWithPlatform('deletes erroneous text (Android)',
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
        await tester.tap(find.text(const DefaultMaterialLocalizations()
            .deleteButtonTooltip
            .toUpperCase()));
        await tester.pump(throttleDuration);
        expect(editor.controller.document.toPlainText(), 'Sole text\n');
      }, [TargetPlatform.android]);

      testWidgetsWithPlatform('replaces text with selected suggestion (iOS)',
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
      }, [TargetPlatform.iOS]);
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

@isTest
Future<void> testWidgetsWithPlatform(String description,
    WidgetTesterCallback callback, List<TargetPlatform> platforms) async {
  testWidgets(description, (tester) async {
    for (final platform in platforms) {
      debugDefaultTargetPlatformOverride = platform;
      await callback(tester);
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
