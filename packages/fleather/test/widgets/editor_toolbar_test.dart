import 'package:flutter/material.dart';
import 'package:fleather/fleather.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_delta/quill_delta.dart';

Widget widget(FleatherController controller) {
  FlutterError.onError = onErrorIgnoreOverflowErrors;
  return MaterialApp(
      home: Column(children: [
    FleatherToolbar(
      children: [
        ToggleStyleButton(
          attribute: ParchmentAttribute.bold,
          icon: Icons.format_bold,
          controller: controller,
        ),
        ToggleStyleButton(
          attribute: ParchmentAttribute.italic,
          icon: Icons.format_italic,
          controller: controller,
        ),
        ToggleStyleButton(
          attribute: ParchmentAttribute.underline,
          icon: Icons.format_underline,
          controller: controller,
        ),
        ToggleStyleButton(
          attribute: ParchmentAttribute.strikethrough,
          icon: Icons.format_strikethrough,
          controller: controller,
        ),
        ToggleStyleButton(
          attribute: ParchmentAttribute.inlineCode,
          icon: Icons.code,
          controller: controller,
        ),
        IndentationButton(controller: controller),
        IndentationButton(controller: controller, increase: false),
        SelectHeadingStyleButton(controller: controller),
        LinkStyleButton(controller: controller),
        InsertEmbedButton(controller: controller, icon: Icons.horizontal_rule),
        UndoRedoButton.undo(controller: controller),
        UndoRedoButton.redo(controller: controller),
      ],
    ),
    Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
    Expanded(
        child: FleatherEditor(
      controller: controller,
      maxContentWidth: 800,
    ))
  ]));
}

void main() {
  group('$FleatherToolbar', () {
    testWidgets('Undo/Redo', (tester) async {
      final controller = FleatherController();
      await tester.pumpWidget(widget(controller));
      await tester.pumpAndSettle();
      final undoButton = find.byType(UndoRedoButton).first;
      final rawUndoButton =
          find.descendant(of: undoButton, matching: find.byType(FLIconButton));
      final redoButton = find.byType(UndoRedoButton).last;
      final rawRedoButton =
          find.descendant(of: redoButton, matching: find.byType(FLIconButton));

      expect(tester.widget<FLIconButton>(rawUndoButton).onPressed, isNull);

      controller.compose(Delta()..insert('Hello world'));
      await tester.pumpAndSettle(throttleDuration);

      expect(tester.widget<FLIconButton>(rawUndoButton).onPressed, isNotNull);

      await tester.tap(undoButton);
      await tester.pumpAndSettle();

      expect(tester.widget<FLIconButton>(rawUndoButton).onPressed, isNull);
      expect(controller.document.toDelta(), Delta()..insert('\n'));
      expect(tester.widget<FLIconButton>(rawRedoButton).onPressed, isNotNull);

      await tester.tap(redoButton);
      await tester.pumpAndSettle();

      expect(tester.widget<FLIconButton>(rawRedoButton).onPressed, isNull);
      expect(controller.document.toDelta(), Delta()..insert('Hello world\n'));
    });

    testWidgets('Bold', (tester) async {
      final controller = FleatherController();
      await tester.pumpWidget(widget(controller));
      await tester.pumpAndSettle();
      final boldButton = find.byIcon(Icons.format_bold);
      await performToggle(tester, controller, boldButton, {'b': true});
    });

    testWidgets('Italic', (tester) async {
      final controller = FleatherController();
      await tester.pumpWidget(widget(controller));
      await tester.pumpAndSettle();
      final boldButton = find.byIcon(Icons.format_italic);
      await performToggle(tester, controller, boldButton, {'i': true});
    });

    testWidgets('Underlined', (tester) async {
      final controller = FleatherController();
      await tester.pumpWidget(widget(controller));
      await tester.pumpAndSettle();
      final boldButton = find.byIcon(Icons.format_underline);
      await performToggle(tester, controller, boldButton, {'u': true});
    });

    testWidgets('Strikethrough', (tester) async {
      final controller = FleatherController();
      await tester.pumpWidget(widget(controller));
      await tester.pumpAndSettle();
      final boldButton = find.byIcon(Icons.format_strikethrough);
      await performToggle(tester, controller, boldButton, {'s': true});
    });

    testWidgets('Inline code', (tester) async {
      final controller = FleatherController();
      await tester.pumpWidget(widget(controller));
      await tester.pumpAndSettle();
      final boldButton = find.byIcon(Icons.code);
      await performToggle(tester, controller, boldButton, {'c': true});
    });

    testWidgets('Headings', (tester) async {
      final controller = FleatherController();
      await tester.pumpWidget(widget(controller));
      await tester.pumpAndSettle();
      final selectHeadings = find.byType(SelectHeadingStyleButton);
      controller.compose(Delta()..insert('Hello world'));
      await tester.pumpAndSettle(throttleDuration);
      await tester.tap(selectHeadings);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuItem<ParchmentAttribute?>).last);
      await tester.pumpAndSettle(throttleDuration);

      expect(controller.document.toDelta().last,
          Operation.insert('\n', {'heading': 3}));
    });

    testWidgets('Indentation', (tester) async {
      final controller = FleatherController();
      await tester.pumpWidget(widget(controller));
      await tester.pumpAndSettle();
      final indent = find.byType(IndentationButton).first;
      final unindent = find.byType(IndentationButton).last;
      controller.compose(Delta()..insert('Hello world'));
      await tester.pumpAndSettle(throttleDuration);
      const textSelection = TextSelection.collapsed(offset: 0);
      controller.updateSelection(textSelection);
      await tester.pumpAndSettle(throttleDuration);

      await tester.tap(indent);
      await tester.pumpAndSettle(throttleDuration);
      expect(controller.document.toDelta().last,
          Operation.insert('\n', {'indent': 1}));

      await tester.tap(unindent);
      await tester.pumpAndSettle(throttleDuration);
      expect(controller.document.toDelta().last,
          Operation.insert('Hello world\n'));
    });

    testWidgets('Link', (tester) async {
      final controller = FleatherController();
      await tester.pumpWidget(widget(controller));
      await tester.pumpAndSettle();
      final linkButton = find.byType(LinkStyleButton);
      final rawLinkButton = find.descendant(
          of: linkButton, matching: find.byType(RawMaterialButton));
      controller.compose(Delta()..insert('Hello world'));
      await tester.pumpAndSettle(throttleDuration);

      expect(tester.widget<RawMaterialButton>(rawLinkButton).onPressed, isNull,
          reason: 'Button should be inactive when selection is collapsed');

      const textSelection = TextSelection(baseOffset: 0, extentOffset: 5);
      controller.updateSelection(textSelection);
      await tester.pumpAndSettle(throttleDuration);
      await tester.tap(linkButton);
      await tester.pumpAndSettle(throttleDuration);

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(
          find.byType(TextField), 'https://fleather-editor.github.io');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Apply'));
      await tester.pumpAndSettle(throttleDuration);

      expect(
          controller.document.toDelta().first,
          Operation.insert(
              'Hello', {'a': 'https://fleather-editor.github.io'}));
    });

    testWidgets('Horizontal rule', (tester) async {
      final controller = FleatherController();
      await tester.pumpWidget(widget(controller));
      await tester.pumpAndSettle();
      final insertButton = find.byType(InsertEmbedButton);
      controller.compose(Delta()..insert('Hello world'));
      await tester.pumpAndSettle(throttleDuration);

      const textSelection = TextSelection.collapsed(offset: 11);
      controller.updateSelection(textSelection);
      await tester.pumpAndSettle(throttleDuration);
      await tester.tap(insertButton);
      await tester.pumpAndSettle(throttleDuration);

      expect(controller.document.toDelta().elementAt(1),
          Operation.insert({'_type': 'hr', '_inline': false}));
    });
  });
}

Future<void> performToggle(WidgetTester tester, FleatherController controller,
    Finder button, Map<String, dynamic> expectedAttribute) async {
  controller.compose(Delta()..insert('Hello world'));
  await tester.pumpAndSettle(throttleDuration);
  const textSelection = TextSelection(baseOffset: 0, extentOffset: 5);
  controller.updateSelection(textSelection);
  await tester.pumpAndSettle(throttleDuration);
  await tester.tap(button);
  await tester.pumpAndSettle(throttleDuration);
  expect(controller.document.toDelta().first,
      Operation.insert('Hello', expectedAttribute));

  await tester.tap(button);
  await tester.pumpAndSettle(throttleDuration);
  expect(
      controller.document.toDelta().first, Operation.insert('Hello world\n'));
}

void onErrorIgnoreOverflowErrors(
  FlutterErrorDetails details, {
  bool forceReport = false,
}) {
  bool ifIsOverflowError = false;

  // Detect overflow error.
  var exception = details.exception;
  if (exception is FlutterError) {
    ifIsOverflowError = !exception.diagnostics.any(
        (e) => e.value.toString().startsWith('A RenderFlex overflowed by'));
  }

  // Ignore if is overflow error.
  if (!ifIsOverflowError) {
    FlutterError.dumpErrorToConsole(details, forceReport: forceReport);
  }
}
