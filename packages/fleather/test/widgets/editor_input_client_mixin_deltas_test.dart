import 'package:fleather/fleather.dart';
import 'package:fleather/src/widgets/editor_input_client_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../rendering/rendering_tools.dart';

class MockRawEditor extends Mock implements RawEditor {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      super.toString();
}

class MockEditorState extends Mock implements EditorState {
  @override
  RenderEditor renderEditor = RenderEditor(
      document: ParchmentDocument.fromJson([
        {'insert': 'Some text\n'}
      ]),
      textDirection: TextDirection.ltr,
      hasFocus: true,
      selection: const TextSelection.collapsed(offset: 0),
      startHandleLayerLink: LayerLink(),
      endHandleLayerLink: LayerLink(),
      padding: EdgeInsets.zero,
      cursorController: CursorController(
          showCursor: ValueNotifier(true),
          style: const CursorStyle(
              color: Colors.black, backgroundColor: Colors.black),
          tickerProvider: FakeTickerProvider()));

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

Matcher matchesMethodCall(String method, {dynamic args}) =>
    _MatchesMethodCall(method,
        arguments: args == null ? null : wrapMatcher(args));

class _MatchesMethodCall extends Matcher {
  const _MatchesMethodCall(this.name, {this.arguments});

  final String name;
  final Matcher? arguments;

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is MethodCall && item.method == name) {
      return arguments?.matches(item.arguments, matchState) ?? true;
    }
    return false;
  }

  @override
  Description describe(Description description) {
    final Description newDescription =
        description.add('has method name: ').addDescriptionOf(name);
    if (arguments != null) {
      newDescription.add(' with arguments: ').addDescriptionOf(arguments);
    }
    return newDescription;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('updateEditingValueWithDeltas', () {
    late MockRawEditorState editorState;
    late RawEditor rawEditor;
    late FleatherController controller;
    final initialTextEditingValue = MockTextEditingValue();

    setUp(() {
      editorState = MockRawEditorState();
      rawEditor = MockRawEditor();
      controller = MockFleatherController();
      when(() => editorState.widget).thenReturn(rawEditor);
      when(() => editorState.textEditingValue)
          .thenReturn(initialTextEditingValue);
      when(() => editorState.themeData).thenReturn(FleatherThemeData(
          bold: const TextStyle(),
          italic: const TextStyle(),
          underline: const TextStyle(),
          strikethrough: const TextStyle(),
          inlineCode: InlineCodeThemeData(style: const TextStyle()),
          link: const TextStyle(),
          paragraph: TextBlockTheme(
              style: const TextStyle(), spacing: const VerticalSpacing()),
          heading1: TextBlockTheme(
              style: const TextStyle(), spacing: const VerticalSpacing()),
          heading2: TextBlockTheme(
              style: const TextStyle(), spacing: const VerticalSpacing()),
          heading3: TextBlockTheme(
              style: const TextStyle(), spacing: const VerticalSpacing()),
          heading4: TextBlockTheme(
              style: const TextStyle(), spacing: const VerticalSpacing()),
          heading5: TextBlockTheme(
              style: const TextStyle(), spacing: const VerticalSpacing()),
          heading6: TextBlockTheme(
              style: const TextStyle(), spacing: const VerticalSpacing()),
          lists: TextBlockTheme(
              style: const TextStyle(), spacing: const VerticalSpacing()),
          quote: TextBlockTheme(
              style: const TextStyle(), spacing: const VerticalSpacing()),
          code: TextBlockTheme(
              style: const TextStyle(), spacing: const VerticalSpacing())));
      when(() => rawEditor.controller).thenReturn(controller);
      when(() => rawEditor.readOnly).thenReturn(false);
      when(() => rawEditor.keyboardAppearance).thenReturn(Brightness.light);
      when(() => rawEditor.textCapitalization)
          .thenReturn(TextCapitalization.none);
      when(() => controller.replaceText(any(), any(), any(),
          selection: any(named: 'selection'))).thenReturn(null);
      editorState.openConnectionIfNeeded();
    });

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
