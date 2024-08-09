import 'package:parchment/parchment.dart';
import 'package:test/test.dart';

final ul = ParchmentAttribute.ul.toJson();
final bold = ParchmentAttribute.bold.toJson();

void main() {
  group('$ResolveLineFormatRule', () {
    final rule = ResolveLineFormatRule();

    test('apply', () {
      final doc = Delta()..insert('Correct\nLine\nStyle\nRule\n');

      final actual = rule.apply(doc, 0, 20, ParchmentAttribute.ul);
      expect(actual, isNotNull);
      final ul = ParchmentAttribute.ul.toJson();
      final expected = Delta()
        ..retain(7)
        ..retain(1, ul)
        ..retain(4)
        ..retain(1, ul)
        ..retain(5)
        ..retain(1, ul)
        ..retain(4)
        ..retain(1, ul);
      expect(actual, expected);
    });

    test('apply with zero length (collapsed selection)', () {
      final doc = Delta()..insert('Correct\nLine\nStyle\nRule\n');
      final actual = rule.apply(doc, 0, 0, ParchmentAttribute.ul);
      expect(actual, isNotNull);
      final ul = ParchmentAttribute.ul.toJson();
      final expected = Delta()
        ..retain(7)
        ..retain(1, ul);
      expect(actual, expected);
    });

    test('apply with zero length in the middle of a line', () {
      final ul = ParchmentAttribute.ul.toJson();
      final doc = Delta()
        ..insert('Title\nOne')
        ..insert('\n', ul)
        ..insert('Two')
        ..insert('\n', ul)
        ..insert('Three!\n');
      final actual = rule.apply(doc, 7, 0, ParchmentAttribute.ul);
      final expected = Delta()
        ..retain(9)
        ..retain(1, ul);
      expect(actual, expected);
    });

    test('removing checklist style from a line also removes checked style', () {
      final cl = ParchmentAttribute.cl.toJson();
      final checkedCl = Map<String, dynamic>.from(cl)
        ..addAll(ParchmentAttribute.checked.toJson());
      final doc = Delta()
        ..insert('Title\nOne')
        ..insert('\n', checkedCl)
        ..insert('Two')
        ..insert('\n', cl)
        ..insert('End!\n');
      final actual = rule.apply(doc, 7, 0, ParchmentAttribute.cl.unset);
      final noBlockNoChecked = ParchmentAttribute.block.unset.toJson()
        ..addAll(ParchmentAttribute.checked.unset.toJson());
      final expected = Delta()
        ..retain(9)
        ..retain(1, noBlockNoChecked);
      expect(actual, expected);
    });
  });

  group('$ResolveInlineFormatRule', () {
    final rule = ResolveInlineFormatRule();

    test('apply', () {
      final doc = Delta()..insert('Correct\nLine\nStyle\nRule\n');

      final actual = rule.apply(doc, 0, 20, ParchmentAttribute.bold);
      expect(actual, isNotNull);
      final b = ParchmentAttribute.bold.toJson();
      final expected = Delta()
        ..retain(7, b)
        ..retain(1)
        ..retain(4, b)
        ..retain(1)
        ..retain(5, b)
        ..retain(1)
        ..retain(1, b);
      expect(actual, expected);
    });
  });

  group('$FormatLinkAtCaretPositionRule', () {
    final rule = FormatLinkAtCaretPositionRule();

    test('apply', () {
      final link = ParchmentAttribute.link
          .fromString('https://github.com/fleather-editor/bold');
      final newLink = ParchmentAttribute.link
          .fromString('https://github.com/fleather-editor/fleather');
      final doc = Delta()
        ..insert('Visit our ')
        ..insert('website', link.toJson())
        ..insert(' for more details.\n');

      final actual = rule.apply(doc, 13, 0, newLink);
      expect(actual, isNotNull);
      final expected = Delta()
        ..retain(10)
        ..retain(7, newLink.toJson());
      expect(actual, expected);
    });
  });
}
