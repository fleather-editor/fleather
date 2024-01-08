import 'package:fleather/fleather.dart';
import 'package:fleather/src/widgets/editor_input_client_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../testing.dart';

void main() {
  group('sets style to TextInputConnection', () {
    final log = <TextInputConnectionStyle>[];

    void bind(WidgetTester tester) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.textInput, (MethodCall methodCall) async {
        if (methodCall.method == 'TextInput.setStyle') {
          final Map<String, dynamic> args =
              methodCall.arguments as Map<String, dynamic>;
          final fontFamily = args['fontFamily'];
          final fontSize = args['fontSize'];
          final fontWeightIndex = args['fontWeightIndex'];
          final textAlignIndex = args['textAlignIndex'];
          final textDirectionIndex = args['textDirectionIndex'];
          final TextInputConnectionStyle style = TextInputConnectionStyle(
              textStyle: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: fontSize,
                  fontWeight: fontWeightIndex != null
                      ? FontWeight.values[fontWeightIndex]
                      : null),
              textAlign: textAlignIndex != null
                  ? TextAlign.values[textAlignIndex]
                  : TextAlign.left,
              textDirection: textDirectionIndex != null
                  ? TextDirection.values[textDirectionIndex]
                  : TextDirection.ltr);
          log.add(style);
        }
        return null;
      });
    }

    setUp(() => log.clear());

    testWidgets('sets style on position 0 by default', (tester) async {
      bind(tester);
      final document = ParchmentDocument.fromJson([
        {'insert': 'some text\n'}
      ]);
      final editor = EditorSandBox(tester: tester, document: document);
      await editor.pump();
      await editor.tap();
      tester.binding.scheduleWarmUpFrame();
      expect(log.length, 1);
      expect(
          log.first,
          const TextInputConnectionStyle(
              textStyle: TextStyle(
                  inherit: true,
                  fontFamily: 'Roboto',
                  fontSize: 16.0,
                  fontWeight: FontWeight.w400),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left));
    });

    testWidgets('changing selection updates text input connection style',
        (tester) async {
      bind(tester);
      final document = ParchmentDocument.fromJson([
        {'insert': 'Heading 1'},
        {
          'insert': '\n',
          'attributes': {'heading': 1}
        },
        {'insert': 'Normal paragraph\n'},
      ]);
      final editor = EditorSandBox(tester: tester, document: document);
      await editor.pump();
      final context = tester.element(find.byType(RawEditor));
      final themeData = FleatherThemeData.fallback(context);
      await tester.tapAt(tester.getTopLeft(find.byType(FleatherEditor)) +
          Offset(20, themeData.heading1.spacing.top));
      tester.binding.scheduleWarmUpFrame();
      expect(log.length, 1);
      expect(
          log.first,
          TextInputConnectionStyle(
              textStyle: TextStyle(
                  inherit: true,
                  fontFamily: 'Roboto',
                  fontSize: themeData.heading1.style.fontSize,
                  fontWeight: themeData.heading1.style.fontWeight),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left));
      log.clear();
      final paragraphOffset = Offset(
          20,
          themeData.heading1.spacing.top +
              (themeData.heading1.style.fontSize ?? 0) +
              themeData.paragraph.spacing.top +
              10);
      await tester.tapAt(
          tester.getTopLeft(find.byType(FleatherEditor)) + paragraphOffset);
      tester.binding.scheduleWarmUpFrame();
      expect(log.length, 1);
      expect(
          log.first,
          TextInputConnectionStyle(
              textStyle: TextStyle(
                  inherit: true,
                  fontFamily: 'Roboto',
                  fontSize: themeData.paragraph.style.fontSize,
                  fontWeight: themeData.paragraph.style.fontWeight),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left));
    });

    testWidgets('sets style to TextInputConnection for all line/block styles',
        (tester) async {
      bind(tester);
      final coveredAttributes = [
        ParchmentAttribute.h2,
        ParchmentAttribute.h3,
        ParchmentAttribute.h4,
        ParchmentAttribute.h5,
        ParchmentAttribute.h6,
        ParchmentAttribute.code,
      ];
      TextBlockTheme themeFromAttribute(
          ParchmentAttribute attribute, FleatherThemeData themeData) {
        final styles = {
          ParchmentAttribute.h2: themeData.heading2,
          ParchmentAttribute.h3: themeData.heading3,
          ParchmentAttribute.h4: themeData.heading4,
          ParchmentAttribute.h5: themeData.heading5,
          ParchmentAttribute.h6: themeData.heading6,
          ParchmentAttribute.code: themeData.code
        };
        return styles[attribute]!;
      }

      for (final attribute in coveredAttributes) {
        final document = ParchmentDocument.fromJson([
          {'insert': 'text that will be tapped'},
          {
            'insert': '\n',
            'attributes': {attribute.key: attribute.value}
          },
        ]);
        final editor = EditorSandBox(tester: tester, document: document);
        await editor.pump();
        await editor.tap();
        final context = tester.element(find.byType(RawEditor));
        final themeData = FleatherThemeData.fallback(context);
        final themeDataItem = themeFromAttribute(attribute, themeData);
        tester.binding.scheduleWarmUpFrame();
        expect(log.length, 1);
        expect(
            log.first,
            TextInputConnectionStyle(
                textStyle: TextStyle(
                    inherit: true,
                    fontFamily: attribute == ParchmentAttribute.code
                        ? 'Roboto Mono'
                        : null,
                    fontSize: themeDataItem.style.fontSize,
                    fontWeight: themeDataItem.style.fontWeight),
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left));
        log.clear();
      }
    });

    testWidgets('sets style to TextInputConnection for RTL direction',
        (tester) async {
      bind(tester);
      final document = ParchmentDocument.fromJson([
        {'insert': 'text that will be tapped'},
        {
          'insert': '\n',
          'attributes': {
            ParchmentAttribute.rtl.key: ParchmentAttribute.rtl.value
          }
        },
      ]);
      final editor = EditorSandBox(tester: tester, document: document);
      await editor.pump();
      await editor.tap();
      final context = tester.element(find.byType(RawEditor));
      final themeData = FleatherThemeData.fallback(context);
      tester.binding.scheduleWarmUpFrame();
      expect(log.length, 1);
      expect(
          log.first,
          TextInputConnectionStyle(
              textStyle: TextStyle(
                  inherit: true,
                  fontFamily: 'Roboto',
                  fontSize: themeData.paragraph.style.fontSize,
                  fontWeight: themeData.paragraph.style.fontWeight),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.left));
    });

    testWidgets('sets style to TextInputConnection for all TextAlign',
        (tester) async {
      bind(tester);
      final coveredAlignments = {
        ParchmentAttribute.left: TextAlign.left,
        ParchmentAttribute.justify: TextAlign.justify,
        ParchmentAttribute.center: TextAlign.center,
        ParchmentAttribute.right: TextAlign.right
      };

      for (final alignmentMapping in coveredAlignments.entries) {
        final attribute = alignmentMapping.key;
        final alignment = alignmentMapping.value;
        final document = ParchmentDocument.fromJson([
          {'insert': 'text that will be tapped'},
          {
            'insert': '\n',
            'attributes': {attribute.key: attribute.value}
          },
        ]);
        final editor = EditorSandBox(tester: tester, document: document);
        await editor.pump();
        if (alignment == TextAlign.right) {
          await tester.tapAt(tester.getTopRight(find.byType(RawEditor)) +
              const Offset(-20, 10));
        } else {
          await editor.tap();
        }
        final context = tester.element(find.byType(RawEditor));
        final themeData = FleatherThemeData.fallback(context);
        tester.binding.scheduleWarmUpFrame();
        expect(log.length, 1);
        expect(
            log.first,
            TextInputConnectionStyle(
                textStyle: TextStyle(
                    inherit: true,
                    fontFamily: 'Roboto',
                    fontSize: themeData.paragraph.style.fontSize,
                    fontWeight: themeData.paragraph.style.fontWeight),
                textDirection: TextDirection.ltr,
                textAlign: alignment));
        log.clear();
      }
    });
  });
}
