import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FleatherThemeData', () {
    test('merge combines properties from both instances', () {
      // Create two instances with different properties
      final theme1 = FleatherThemeData(
        bold: const TextStyle(fontWeight: FontWeight.bold),
        italic: const TextStyle(fontStyle: FontStyle.italic),
        underline: const TextStyle(decoration: TextDecoration.underline),
        strikethrough: const TextStyle(decoration: TextDecoration.lineThrough),
        inlineCode: InlineCodeThemeData(
          backgroundColor: Colors.grey.shade100,
          radius: const Radius.circular(3),
          style: const TextStyle(fontSize: 14, color: Colors.blue),
        ),
        link: const TextStyle(color: Colors.red),
        paragraph: TextBlockTheme(
            style: const TextStyle(fontSize: 16.0),
            spacing: const VerticalSpacing(top: 6.0, bottom: 10.0)),
        heading1: TextBlockTheme(
            style: const TextStyle(fontSize: 34.0),
            spacing: const VerticalSpacing(top: 16.0, bottom: 0.0)),
        heading2: TextBlockTheme(
            style: const TextStyle(fontSize: 24.0),
            spacing: const VerticalSpacing(bottom: 0.0, top: 8.0)),
        heading3: TextBlockTheme(
            style: const TextStyle(fontSize: 20.0),
            spacing: const VerticalSpacing(bottom: 0.0, top: 8.0)),
        heading4: TextBlockTheme(
            style: const TextStyle(fontSize: 18),
            spacing: const VerticalSpacing(bottom: 0.0, top: 8.0)),
        heading5: TextBlockTheme(
            style: const TextStyle(fontSize: 16.0),
            spacing: const VerticalSpacing(bottom: 0.0, top: 8.0)),
        heading6: TextBlockTheme(
            style: const TextStyle(fontSize: 16.0),
            spacing: const VerticalSpacing(bottom: 0.0, top: 8.0)),
        lists: TextBlockTheme(
            style: const TextStyle(fontSize: 16.0),
            spacing: const VerticalSpacing(top: 6.0, bottom: 10.0)),
        quote: TextBlockTheme(
            style: TextStyle(color: Colors.grey.shade600),
            spacing: const VerticalSpacing(top: 6, bottom: 2)),
        code: TextBlockTheme(
            style: TextStyle(
                color: Colors.blue.shade900.withOpacity(0.9), fontSize: 13.0),
            spacing: const VerticalSpacing(top: 6.0, bottom: 10.0)),
        horizontalRule:
            HorizontalRuleThemeData(height: 2, thickness: 2, color: Colors.red),
      );

      final theme2 = FleatherThemeData(
        bold: const TextStyle(fontWeight: FontWeight.w300),
        italic: const TextStyle(fontStyle: FontStyle.normal),
        underline: const TextStyle(decoration: TextDecoration.none),
        strikethrough: const TextStyle(decoration: TextDecoration.none),
        inlineCode: InlineCodeThemeData(
          backgroundColor: Colors.grey.shade200,
          radius: const Radius.circular(5),
          style: const TextStyle(fontSize: 12, color: Colors.green),
        ),
        link: const TextStyle(color: Colors.blue),
        paragraph: TextBlockTheme(
            style: const TextStyle(fontSize: 14.0),
            spacing: const VerticalSpacing(top: 4.0, bottom: 8.0)),
        heading1: TextBlockTheme(
            style: const TextStyle(fontSize: 32.0),
            spacing: const VerticalSpacing(top: 18.0, bottom: 0.0)),
        heading2: TextBlockTheme(
            style: const TextStyle(fontSize: 26.0),
            spacing: const VerticalSpacing(bottom: 0.0, top: 10.0)),
        heading3: TextBlockTheme(
            style: const TextStyle(fontSize: 22.0),
            spacing: const VerticalSpacing(bottom: 0.0, top: 10.0)),
        heading4: TextBlockTheme(
            style: const TextStyle(fontSize: 16),
            spacing: const VerticalSpacing(bottom: 0.0, top: 10.0)),
        heading5: TextBlockTheme(
            style: const TextStyle(fontSize: 14.0),
            spacing: const VerticalSpacing(bottom: 0.0, top: 10.0)),
        heading6: TextBlockTheme(
            style: const TextStyle(fontSize: 12.0),
            spacing: const VerticalSpacing(bottom: 0.0, top: 10.0)),
        lists: TextBlockTheme(
            style: const TextStyle(fontSize: 14.0),
            spacing: const VerticalSpacing(top: 4.0, bottom: 8.0)),
        quote: TextBlockTheme(
            style: TextStyle(color: Colors.grey.shade700),
            spacing: const VerticalSpacing(top: 4, bottom: 4)),
        code: TextBlockTheme(
            style: TextStyle(
                color: Colors.blue.shade800.withOpacity(0.9), fontSize: 12.0),
            spacing: const VerticalSpacing(top: 4.0, bottom: 8.0)),
        horizontalRule: HorizontalRuleThemeData(
            height: 4, thickness: 4, color: Colors.green),
      );

      // Merge the two instances
      final mergedTheme = theme1.merge(theme2);

      // Verify that the merged instance has the expected properties
      expect(mergedTheme.bold, equals(theme2.bold));
      expect(mergedTheme.italic, equals(theme2.italic));
      expect(mergedTheme.underline, equals(theme2.underline));
      expect(mergedTheme.strikethrough, equals(theme2.strikethrough));
      expect(mergedTheme.inlineCode, equals(theme2.inlineCode));
      expect(mergedTheme.link, equals(theme2.link));
      expect(mergedTheme.paragraph, equals(theme2.paragraph));
      expect(mergedTheme.heading1, equals(theme2.heading1));
      expect(mergedTheme.heading2, equals(theme2.heading2));
      expect(mergedTheme.heading3, equals(theme2.heading3));
      expect(mergedTheme.heading4, equals(theme2.heading4));
      expect(mergedTheme.heading5, equals(theme2.heading5));
      expect(mergedTheme.heading6, equals(theme2.heading6));
      expect(mergedTheme.lists, equals(theme2.lists));
      expect(mergedTheme.quote, equals(theme2.quote));
      expect(mergedTheme.code, equals(theme2.code));
    });
  });
}
