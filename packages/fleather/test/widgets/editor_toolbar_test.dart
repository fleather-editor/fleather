import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../testing.dart';

Widget widget(FleatherController controller, {bool withBasic = false}) {
  FlutterError.onError = onErrorIgnoreOverflowErrors;
  Widget backgroundColorBuilder(context, value) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.mode_edit_outline_outlined,
            size: 16,
          ),
          Container(
            width: 18,
            height: 4,
            decoration: BoxDecoration(
              color: value,
              border: value == Colors.transparent
                  ? Border.all(
                      color: Theme.of(context).iconTheme.color ?? Colors.black)
                  : null,
            ),
          )
        ],
      );
  Widget textColorBuilder(context, value) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.text_fields_sharp,
            size: 16,
          ),
          Container(
            width: 18,
            height: 4,
            decoration: BoxDecoration(
              color: value,
              border: value == Colors.transparent
                  ? Border.all(
                      color: Theme.of(context).iconTheme.color ?? Colors.black)
                  : null,
            ),
          )
        ],
      );
  final editorKey = GlobalKey<EditorState>();
  return MaterialApp(
    home: Material(
      child: Column(children: [
        if (withBasic)
          FleatherToolbar.basic(controller: controller, editorKey: editorKey)
        else
          FleatherToolbar(
            editorKey: editorKey,
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
              ColorButton(
                controller: controller,
                attributeKey: ParchmentAttribute.backgroundColor,
                nullColorLabel: 'No color',
                builder: backgroundColorBuilder,
              ),
              ColorButton(
                controller: controller,
                attributeKey: ParchmentAttribute.foregroundColor,
                nullColorLabel: 'Automatic',
                builder: textColorBuilder,
              ),
              IndentationButton(controller: controller),
              IndentationButton(controller: controller, increase: false),
              SelectHeadingButton(controller: controller),
              LinkStyleButton(controller: controller),
              InsertEmbedButton(
                  controller: controller, icon: Icons.horizontal_rule),
              UndoRedoButton.undo(controller: controller),
              UndoRedoButton.redo(controller: controller),
            ],
          ),
        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        Expanded(
            child: FleatherEditor(
          controller: controller,
          maxContentWidth: 800,
          editorKey: editorKey,
        ))
      ]),
    ),
  );
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

      final editor = tester.state<RawEditorState>(find.byType(RawEditor));
      expect(editor.effectiveFocusNode.hasFocus, false);
      expect(editor.hasConnection, false);
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
      final selectHeadings = find.byType(SelectHeadingButton);
      controller.compose(Delta()..insert('Hello world'));
      await tester.pumpAndSettle(throttleDuration);
      await tester.tap(selectHeadings);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('heading_entry6')));
      await tester.pumpAndSettle(throttleDuration);

      expect(controller.document.toDelta().last,
          Operation.insert('\n', {'heading': 6}));

      final editor = tester.state<RawEditorState>(find.byType(RawEditor));
      expect(editor.effectiveFocusNode.hasFocus, true);
      expect(editor.hasConnection, true);
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

      final editor = tester.state<RawEditorState>(find.byType(RawEditor));
      expect(editor.effectiveFocusNode.hasFocus, true);
      expect(editor.hasConnection, true);
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

      final editor = tester.state<RawEditorState>(find.byType(RawEditor));
      expect(editor.effectiveFocusNode.hasFocus, true);
      expect(editor.hasConnection, true);
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

      final editor = tester.state<RawEditorState>(find.byType(RawEditor));
      expect(editor.effectiveFocusNode.hasFocus, true);
      expect(editor.hasConnection, true);
    });

    testWidgets('Basic toolbar', (tester) async {
      final controller = FleatherController();
      await tester.pumpWidget(widget(controller, withBasic: true));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.format_bold), findsOneWidget);
      expect(find.byIcon(Icons.format_italic), findsOneWidget);
      expect(find.byIcon(Icons.format_underline), findsOneWidget);
      expect(find.byIcon(Icons.format_strikethrough), findsOneWidget);
      // Inline + block
      expect(find.byIcon(Icons.code), findsNWidgets(2));
      expect(find.byIcon(Icons.format_textdirection_r_to_l), findsOneWidget);
      expect(find.byIcon(Icons.format_align_center), findsOneWidget);
      expect(find.byIcon(Icons.format_align_left), findsOneWidget);
      expect(find.byIcon(Icons.format_align_right), findsOneWidget);
      expect(find.byIcon(Icons.format_align_justify), findsOneWidget);
      expect(find.byType(SelectHeadingButton), findsOneWidget);
      // Increase + decrease
      expect(find.byType(IndentationButton), findsNWidgets(2));
      expect(find.byIcon(Icons.format_list_bulleted), findsOneWidget);
      expect(find.byIcon(Icons.format_list_numbered), findsOneWidget);
      expect(find.byIcon(Icons.checklist), findsOneWidget);
      expect(find.byIcon(Icons.format_quote), findsOneWidget);
      expect(find.byType(InsertEmbedButton), findsOneWidget);
      expect(find.byType(LinkStyleButton), findsOneWidget);
      // Undo + redo
      expect(find.byType(UndoRedoButton), findsNWidgets(2));
    });

    testWidgets('Background color', (tester) async {
      final controller = FleatherController();
      await tester.pumpWidget(widget(controller));
      await tester.pumpAndSettle();
      final backgroundButton = find.byType(ColorButton).first;
      controller.compose(Delta()..insert('Hello world'));
      await tester.pump(throttleDuration);
      controller
          .updateSelection(const TextSelection(baseOffset: 0, extentOffset: 5));

      await tester.pumpAndSettle();
      await tester.tap(backgroundButton);
      await tester.pumpAndSettle();
      final colorElement = find.descendant(
          of: find.byKey(const Key('color_selector')),
          matching: find.byType(RawMaterialButton));
      expect(colorElement, findsNWidgets(17));

      await tester.tap(find
          .descendant(
              of: find.byKey(const Key('color_selector')),
              matching: find.byType(RawMaterialButton))
          .last);
      await tester.pumpAndSettle(throttleDuration);
      expect(controller.document.toDelta().first,
          Operation.insert('Hello', {'bg': Colors.black.value}));

      final editor = tester.state<RawEditorState>(find.byType(RawEditor));
      expect(editor.effectiveFocusNode.hasFocus, true);
      expect(editor.hasConnection, true);
    });

    testWidgets('Text color', (tester) async {
      final controller = FleatherController();
      await tester.pumpWidget(widget(controller));
      await tester.pumpAndSettle();
      final backgroundButton = find.byType(ColorButton).last;
      controller.compose(Delta()..insert('Hello world'));
      await tester.pump(throttleDuration);
      controller
          .updateSelection(const TextSelection(baseOffset: 0, extentOffset: 5));

      await tester.pumpAndSettle();
      await tester.tap(backgroundButton);
      await tester.pumpAndSettle();
      final colorElement = find.descendant(
          of: find.byKey(const Key('color_selector')),
          matching: find.byType(RawMaterialButton));
      expect(
        colorElement,
        findsNWidgets(17),
      );

      await tester.tap(find
          .descendant(
              of: find.byKey(const Key('color_selector')),
              matching: find.byType(RawMaterialButton))
          .last);
      await tester.pumpAndSettle(throttleDuration);
      expect(controller.document.toDelta().first,
          Operation.insert('Hello', {'fg': Colors.black.value}));

      final editor = tester.state<RawEditorState>(find.byType(RawEditor));
      expect(editor.effectiveFocusNode.hasFocus, true);
      expect(editor.hasConnection, true);
    });

    testWidgets('updating editor toolbar remove overlay entry if any',
        (tester) async {
      Widget backgroundColorBuilder(context, value) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.mode_edit_outline_outlined,
                size: 16,
              ),
              Container(
                width: 18,
                height: 4,
                decoration: BoxDecoration(
                  color: value,
                  border: value == Colors.transparent
                      ? Border.all(
                          color:
                              Theme.of(context).iconTheme.color ?? Colors.black)
                      : null,
                ),
              )
            ],
          );
      final controller = FleatherController();
      final widget = MaterialApp(
        home: TestUpdateWidget(
          focusNodeAfterChange: FocusNode(),
          controller: controller,
          toolbarBuilder: (context) => FleatherToolbar(
            children: [
              ColorButton(
                  controller: controller,
                  attributeKey: ParchmentAttribute.backgroundColor,
                  nullColorLabel: 'No color',
                  builder: backgroundColorBuilder)
            ],
          ),
        ),
      );
      await tester.pumpWidget(widget);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.mode_edit_outline_outlined));
      await tester.pump();
      expect(find.byKey(const Key('color_selector')), findsOneWidget);
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(find.byKey(const Key('color_selector')), findsNothing);
      await tester.pumpAndSettle(throttleDuration);
    });
  });

  group('SelectorScope', () {
    testWidgets('Correctly places the selector in a visible area of screen',
        (WidgetTester tester) async {
      const padding = EdgeInsets.all(32);
      final controller = FleatherController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(),
          body: Column(
            children: [
              FleatherToolbar.basic(controller: controller),
            ],
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: padding),
          child: child!,
        ),
      ));
      final validRect = tester.getRect(find.byType(Scaffold)).deflate(32);
      await tester.tap(find.byType(SelectHeadingButton));
      await tester.pump();
      expect(
        validRect.expandToInclude(
            tester.getRect(find.byKey(const Key('heading_selector')))),
        equals(validRect),
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(),
          body: Column(
            children: [
              const Expanded(child: SizedBox()),
              FleatherToolbar.basic(controller: controller),
            ],
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: padding),
          child: child!,
        ),
      ));
      await tester.tap(find.byType(SelectHeadingButton));
      await tester.pump();
      expect(
        validRect.expandToInclude(
            tester.getRect(find.byKey(const Key('heading_selector')))),
        equals(validRect),
      );
      expect(
        tester.getRect(find.byKey(const Key('heading_selector'))).bottom,
        tester.getRect(find.byType(Scaffold)).bottom - padding.bottom - 8,
      );
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

  final editor = tester.state<RawEditorState>(find.byType(RawEditor));
  expect(editor.effectiveFocusNode.hasFocus, true);
  expect(editor.hasConnection, true);
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
