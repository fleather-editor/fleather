import 'package:fleather/fleather.dart';
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
      var editor = EditorSandBox(tester: tester, document: doc, theme: theme);
      await editor.pumpAndTap();
      // await tester.pumpAndSettle();
      final p = tester.widget(find.byType(RichText).first) as RichText;
      final text = p.text as TextSpan;
      expect(text.children!.first.style!.color, Colors.red);
    });

    testWidgets('collapses selection when unfocused', (tester) async {
      final editor = EditorSandBox(tester: tester);
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

    testWidgets('show toolbar on long press with empty document',
        (tester) async {
      // if Clipboard not initialize (status 'unknown'), an shrunken toolbar appears
      TestDefaultBinaryMessengerBinding.instance?.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (message) {
        if (message.method == 'Clipboard.getData') {
          return Future.value(<String, dynamic>{});
        }
      });

      final editor =
          EditorSandBox(tester: tester, document: ParchmentDocument());
      await editor.pumpAndTap();
      expect(find.text('Select all'), findsNothing);
      await tester.longPress(find.byType(FleatherEditor));
      await tester.pumpAndSettle();
      // Given current toolbar implementation in Flutter no other choice
      // than search for "Select all"
      expect(find.text('Select all'), findsOneWidget);
    });
  });
}
