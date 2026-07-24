import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('registers and unregisters the editor as a Scribble client',
      (tester) async {
    final fixture = await _pumpEditor(tester);

    expect(TextInput.scribbleClients[fixture.state.elementIdentifier],
        same(fixture.state));

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(
        TextInput.scribbleClients.containsKey(fixture.state.elementIdentifier),
        isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('does not register Scribble when disabled or read only',
      (tester) async {
    final disabled = await _pumpEditor(tester, stylusHandwritingEnabled: false);
    expect(
        TextInput.scribbleClients.containsKey(disabled.state.elementIdentifier),
        isFalse);

    final readOnly = await _pumpEditor(tester, readOnly: true);
    expect(
        TextInput.scribbleClients.containsKey(readOnly.state.elementIdentifier),
        isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
      'Scribble focus keeps the selection and opens the input connection',
      (tester) async {
    final fixture = await _pumpEditor(tester);
    final editorRect = tester.getRect(find.byType(RawEditor));
    final textRect = tester.getRect(find.byType(TextLine).first);
    final blankPosition = Offset(editorRect.center.dx, editorRect.bottom - 20);
    fixture.controller
        .updateSelection(const TextSelection.collapsed(offset: 3));
    await tester.pump();

    expect(textRect.contains(blankPosition), isFalse);
    expect(fixture.state.bounds.contains(blankPosition), isTrue);
    expect(
        fixture.state.isInScribbleRect(
            Rect.fromCenter(center: blankPosition, width: 2, height: 2)),
        isTrue);
    final outsideRect = Rect.fromCenter(
        center: Offset(editorRect.center.dx, editorRect.bottom + 4),
        width: 2,
        height: 20);
    expect(fixture.state.bounds.overlaps(outsideRect), isTrue);
    expect(fixture.state.isInScribbleRect(outsideRect), isFalse);

    fixture.state.onScribbleFocus(blankPosition);
    await tester.pump();

    expect(fixture.focusNode.hasFocus, isTrue);
    expect(
        fixture.controller.selection, const TextSelection.collapsed(offset: 3));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('routes iOS system undo and redo to the Fleather history',
      (tester) async {
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.undoManager,
        (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.undoManager, null);
      UndoManager.client = null;
    });

    final fixture = await _pumpEditor(tester);
    final originalText = fixture.controller.document.toPlainText();
    fixture.state
        .onScribbleFocus(tester.getCenter(find.byType(TextLine).first));
    await tester.pump();
    fixture.controller.replaceText(0, 0, 'X',
        selection: const TextSelection.collapsed(offset: 1));
    await tester.pump(throttleDuration);

    expect(fixture.controller.canUndo, isTrue);
    expect(UndoManager.client, isNotNull);
    expect(
      calls.any(
        (call) =>
            call.method == 'UndoManager.setUndoState' &&
            (call.arguments as Map<Object?, Object?>)['canUndo'] == true,
      ),
      isTrue,
    );

    UndoManager.client!.handlePlatformUndo(UndoDirection.undo);
    expect(fixture.controller.document.toPlainText(), originalText);
    expect(fixture.controller.canRedo, isTrue);
    await tester.pump();

    UndoManager.client!.handlePlatformUndo(UndoDirection.redo);
    expect(fixture.controller.document.toPlainText(), 'X$originalText');
    await tester.pump();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('reports visible character geometry to the text input connection',
      (tester) async {
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.textInput, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.textInput, null);
      tester.testTextInput.register();
    });

    final fixture = await _pumpEditor(
      tester,
      document: ParchmentDocument.fromDelta(
        Delta()
          ..insert('你😀')
          ..insert('\n', ParchmentAttribute.block.bulletList.toJson())
          ..insert('A\n'),
      ),
    );
    fixture.state.onScribbleFocus(tester.getCenter(find.byType(RawEditor)));
    await tester.pump();
    await tester.pump();

    final geometryCalls = calls
        .where((call) => call.method == 'TextInput.setSelectionRects')
        .toList();
    expect(geometryCalls, isNotEmpty);
    final rects =
        (geometryCalls.last.arguments as List<Object?>).cast<List<Object?>>();
    final positions = rects.map((rect) => rect[4]).toList();
    expect(positions, containsAll(<int>[0, 1, 4]));
    expect(positions, isNot(contains(2)));
    expect(
        calls.any((call) => call.method == 'TextInput.setCaretRect'), isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('renders and removes a placeholder without changing the document',
      (tester) async {
    final fixture = await _pumpEditor(tester);
    fixture.controller
        .updateSelection(const TextSelection.collapsed(offset: 3));
    await tester.pump();
    final originalDelta = fixture.controller.document.toDelta().toJson();

    fixture.state.insertTextPlaceholder(const Size(120, 40));
    await tester.pump();

    expect(fixture.controller.document.toDelta().toJson(), originalDelta);
    expect(_linePlainText(tester).contains('\uFFFC'), isTrue);

    fixture.state.removeTextPlaceholder();
    await tester.pump();

    expect(fixture.controller.document.toDelta().toJson(), originalDelta);
    expect(_linePlainText(tester).contains('\uFFFC'), isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}

String _linePlainText(WidgetTester tester) {
  final richText = find
      .descendant(of: find.byType(TextLine), matching: find.byType(RichText))
      .first;
  return tester.widget<RichText>(richText).text.toPlainText();
}

Future<_EditorFixture> _pumpEditor(
  WidgetTester tester, {
  bool stylusHandwritingEnabled = true,
  bool readOnly = false,
  ParchmentDocument? document,
}) async {
  final controller = FleatherController(
    document: document ??
        ParchmentDocument.fromDelta(Delta()..insert('Hello Scribble\n')),
  );
  final focusNode = FocusNode();
  addTearDown(() {
    controller.dispose();
    focusNode.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          height: 200,
          child: FleatherEditor(
            controller: controller,
            focusNode: focusNode,
            expands: true,
            stylusHandwritingEnabled: stylusHandwritingEnabled,
            readOnly: readOnly,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return _EditorFixture(
    controller: controller,
    focusNode: focusNode,
    state: tester.state<RawEditorState>(find.byType(RawEditor)),
  );
}

class _EditorFixture {
  const _EditorFixture(
      {required this.controller, required this.focusNode, required this.state});

  final FleatherController controller;
  final FocusNode focusNode;
  final RawEditorState state;
}
