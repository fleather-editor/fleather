import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget widget(FleatherController controller) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Expanded(child: FleatherEditor(controller: controller)),
          ],
        ),
      ),
    );
  }

  Future<void> testToggle(
      WidgetTester tester, ParchmentAttribute attribute, bool isMacos) async {
    LogicalKeyboardKey key(ParchmentAttribute attribute) {
      switch (attribute.key) {
        case 'b':
          return LogicalKeyboardKey.keyB;
        case 'i':
          return LogicalKeyboardKey.keyI;
        case 'u':
          return LogicalKeyboardKey.keyU;
        default:
          throw ArgumentError('Unsupported attribute');
      }
    }

    final delta = Delta()..insert('test\n');
    final controller =
        FleatherController(document: ParchmentDocument.fromDelta(delta));
    final editor = widget(controller);
    await tester.pumpWidget(editor);
    await tester
        .tapAt(tester.getTopLeft(find.byType(RawEditor)) + const Offset(1, 1));
    controller.updateSelection(TextSelection(baseOffset: 0, extentOffset: 4));
    await tester.pump();
    final controlKey =
        isMacos ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control;
    await tester.sendKeyDownEvent(controlKey);
    await tester.sendKeyEvent(key(attribute));
    await tester.sendKeyUpEvent(controlKey);
    await tester.pump(throttleDuration);
    final exp = Delta()
      ..insert('test', {attribute.key: true})
      ..insert('\n');
    expect(controller.document.toDelta(), exp);
  }

  Future<void> testIndentation(WidgetTester tester,
      {required bool addIndentation}) async {
    final delta = Delta();
    if (addIndentation) {
      delta.insert('test\n');
    } else {
      delta.insert('test');
      delta.insert('\n', {'indent': 1});
    }
    final controller =
        FleatherController(document: ParchmentDocument.fromDelta(delta));
    final editor = widget(controller);
    await tester.pumpWidget(editor);
    await tester
        .tapAt(tester.getTopLeft(find.byType(RawEditor)) + const Offset(1, 1));
    if (!addIndentation) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    if (!addIndentation) {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    }
    await tester.pump(throttleDuration);
    final exp = Delta();
    if (addIndentation) {
      exp.insert('test');
      exp.insert('\n', {'indent': 1});
    } else {
      exp.insert('test\n');
    }

    expect(controller.document.toDelta(), exp);
  }

  group('(macos) Shortcuts', () {
    testWidgets('(macos) Toggle bold', (tester) async {
      await testToggle(tester, ParchmentAttribute.bold, true);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('(macos) Toggle italie', (tester) async {
      await testToggle(tester, ParchmentAttribute.underline, true);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('(macos) Toggle underline', (tester) async {
      await testToggle(tester, ParchmentAttribute.underline, true);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('(macos) Add indentation', (tester) async {
      await testIndentation(tester, addIndentation: true);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('(macos) Remove indentation', (tester) async {
      await testIndentation(tester, addIndentation: false);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  group('(Windows) Shortcuts', () {
    testWidgets('(Windows) Toggle bold', (tester) async {
      await testToggle(tester, ParchmentAttribute.bold, true);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('(Windows) Toggle italie', (tester) async {
      await testToggle(tester, ParchmentAttribute.underline, true);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('(Windows) Toggle underline', (tester) async {
      await testToggle(tester, ParchmentAttribute.underline, true);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('(Windows) Add indentation', (tester) async {
      await testIndentation(tester, addIndentation: true);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('(Windows) Remove indentation', (tester) async {
      await testIndentation(tester, addIndentation: false);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  });
}
