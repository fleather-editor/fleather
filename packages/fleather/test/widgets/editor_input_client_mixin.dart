import 'package:fleather/fleather.dart';
import 'package:fleather/src/widgets/editor_input_client_mixin.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRawEditor extends Mock implements RawEditor {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      super.toString();
}

class MockEditorState extends Mock implements EditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      super.toString();
}

class MockRawEditorState extends MockEditorState
    with RawEditorStateTextInputClientMixin {}

class MockTextEditingDelta extends Mock implements TextEditingDelta {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return '';
  }
}

class MockFleatherController extends Mock implements FleatherController {}

class MockTextEditingValue extends Mock implements TextEditingValue {
  @override
  Map<String, dynamic> toJSON() => {};
}

void main() {
  late MockRawEditorState editorState;
  late RawEditor rawEditor;
  late FleatherController controller;
  final initialTextEditingValue = MockTextEditingValue();

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    editorState = MockRawEditorState();
    rawEditor = MockRawEditor();
    controller = MockFleatherController();
    when(() => editorState.widget).thenReturn(rawEditor);
    when(() => editorState.textEditingValue)
        .thenReturn(initialTextEditingValue);
    when(() => rawEditor.controller).thenReturn(controller);
    when(() => rawEditor.readOnly).thenReturn(false);
    when(() => rawEditor.keyboardAppearance).thenReturn(Brightness.light);
    when(() => rawEditor.textCapitalization)
        .thenReturn(TextCapitalization.none);
    when(() => controller.replaceText(any(), any(), any(),
        selection: any(named: 'selection'))).thenReturn(null);
  });

  group('updateEditingValueWithDeltas', () {
    setUp(() => editorState.openConnectionIfNeeded());

    test('is readOnly or deltas are empty', () {
      when(() => rawEditor.readOnly).thenReturn(true);
      editorState.updateEditingValueWithDeltas([MockTextEditingDelta()]);
      editorState.updateEditingValueWithDeltas([]);
      verifyZeroInteractions(controller);
    });

    test('updated with TextEditingDeltaInsertion', () {
      const selection = TextSelection.collapsed(offset: 7);
      const delta = TextEditingDeltaInsertion(
        oldText: 'Add ',
        textInserted: 'Test',
        insertionOffset: 4,
        selection: selection,
        composing: TextRange.empty,
      );
      final updatedEditingValue = MockTextEditingValue();
      when(() => initialTextEditingValue.copyWith(
            selection: any(named: 'selection'),
            text: any(named: 'text'),
            composing: any(named: 'composing'),
          )).thenReturn(updatedEditingValue);
      editorState.updateEditingValueWithDeltas([delta]);
      verify(() => controller.replaceText(
            delta.insertionOffset,
            0,
            delta.textInserted,
            selection: selection,
          ));
      expect(editorState.currentTextEditingValue, updatedEditingValue);
    });

    test('updated with TextEditingDeltaDeletion', () {
      const selection = TextSelection.collapsed(offset: 3);
      const delta = TextEditingDeltaDeletion(
        oldText: 'Test',
        deletedRange: TextRange(start: 3, end: 4),
        selection: selection,
        composing: TextRange.empty,
      );
      final updatedEditingValue = MockTextEditingValue();
      when(() => initialTextEditingValue.copyWith(
            selection: any(named: 'selection'),
            text: any(named: 'text'),
            composing: any(named: 'composing'),
          )).thenReturn(updatedEditingValue);
      editorState.updateEditingValueWithDeltas([delta]);
      verify(() => controller.replaceText(
            delta.deletedRange.start,
            delta.deletedRange.end - delta.deletedRange.start,
            '',
            selection: selection,
          ));
      expect(editorState.currentTextEditingValue, updatedEditingValue);
    });

    test('updated with TextEditingDeltaReplacement', () {
      const selection = TextSelection.collapsed(offset: 4);
      const delta = TextEditingDeltaReplacement(
        oldText: 'Test',
        replacedRange: TextRange(start: 1, end: 3),
        replacementText: 'rea',
        selection: selection,
        composing: TextRange.empty,
      );
      final updatedEditingValue = MockTextEditingValue();
      when(() => initialTextEditingValue.copyWith(
            selection: any(named: 'selection'),
            text: any(named: 'text'),
            composing: any(named: 'composing'),
          )).thenReturn(updatedEditingValue);
      editorState.updateEditingValueWithDeltas([delta]);
      verify(() => controller.replaceText(
            delta.replacedRange.start,
            delta.replacedRange.end - delta.replacedRange.start,
            delta.replacementText,
            selection: selection,
          ));
      expect(editorState.currentTextEditingValue, updatedEditingValue);
    });

    test('updated with TextEditingDeltaNonTextUpdate', () {
      const selection = TextSelection.collapsed(offset: 4);
      const delta = TextEditingDeltaNonTextUpdate(
          oldText: 'Test', selection: selection, composing: TextRange.empty);
      final updatedEditingValue = delta.apply(initialTextEditingValue);
      editorState.updateEditingValueWithDeltas([delta]);
      verify(() => controller.replaceText(0, 0, '', selection: selection));
      expect(editorState.currentTextEditingValue, updatedEditingValue);
    });
  });
}
