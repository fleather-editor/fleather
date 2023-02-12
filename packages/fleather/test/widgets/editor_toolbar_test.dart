import 'package:flutter/material.dart';
import 'package:fleather/fleather.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_delta/quill_delta.dart';

Widget widget(FleatherController controller) {
  return MaterialApp(
      home: Column(children: [
    FleatherToolbar(
      children: [
        UndoRedoButton.undo(controller: controller),
        UndoRedoButton.redo(controller: controller)
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
      await tester.pump(throttleDuration);
      await tester.pumpAndSettle();
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
  });
}
