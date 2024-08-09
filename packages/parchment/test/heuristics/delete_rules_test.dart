import 'package:parchment/parchment.dart';
import 'package:test/test.dart';

final ul = ParchmentAttribute.ul.toJson();
final bold = ParchmentAttribute.bold.toJson();

void main() {
  group('$PreserveLineStyleOnMergeRule', () {
    final rule = PreserveLineStyleOnMergeRule();
    test('preserves block style', () {
      final ul = ParchmentAttribute.ul.toJson();
      final doc = Delta()
        ..insert('Title\nOne')
        ..insert('\n', ul)
        ..insert('Two\n');
      final actual = rule.apply(doc, 9, 1);
      final expected = Delta()
        ..retain(9)
        ..delete(1)
        ..retain(3)
        ..retain(1, ul);
      expect(actual, expected);
    });

    test('resets block style', () {
      final unsetUl = ParchmentAttribute.block.unset.toJson();
      final doc = Delta()
        ..insert('Title\nOne')
        ..insert('\n', ParchmentAttribute.ul.toJson())
        ..insert('Two\n');
      final actual = rule.apply(doc, 5, 1);
      final expected = Delta()
        ..retain(5)
        ..delete(1)
        ..retain(3)
        ..retain(1, unsetUl);
      expect(actual, expected);
    });

    test('preserves last newline character', () {
      final doc = Delta()..insert('\n');
      final actual = rule.apply(doc, 0, 1);
      final expected = Delta();
      expect(actual, expected);
    });

    test('preserves last newline character on multi character delete', () {
      final doc = Delta()..insert('Document\nTitle\n');
      final actual = rule.apply(doc, 8, 7);
      final expected = Delta()
        ..retain(8)
        ..delete(6);
      expect(actual, expected);
    });
  });

  group('$CatchAllDeleteRule', () {
    final rule = CatchAllDeleteRule();

    test('applies change as-is', () {
      final doc = Delta()..insert('Document\n');
      final actual = rule.apply(doc, 3, 5);
      final expected = Delta()
        ..retain(3)
        ..delete(5);
      expect(actual, expected);
    });

    test('preserves last newline character', () {
      final doc = Delta()..insert('\n');
      final actual = rule.apply(doc, 0, 1);
      final expected = Delta();
      expect(actual, expected);
    });

    test('preserves last newline character on multi character delete', () {
      final doc = Delta()..insert('Document\n');
      final actual = rule.apply(doc, 3, 6);
      final expected = Delta()
        ..retain(3)
        ..delete(5);
      expect(actual, expected);
    });
  });

  group('$EnsureEmbedLineRule', () {
    final rule = EnsureEmbedLineRule();

    test('ensures line-break before embed', () {
      final doc = Delta()
        ..insert('Document\n')
        ..insert(BlockEmbed.horizontalRule)
        ..insert('\n');
      final actual = rule.apply(doc, 8, 1);
      final expected = Delta()..retain(8);
      expect(actual, expected);
    });

    test('ensures line-break after embed', () {
      final doc = Delta()
        ..insert('Document\n')
        ..insert(BlockEmbed.horizontalRule)
        ..insert('\n');
      final actual = rule.apply(doc, 10, 1);
      final expected = Delta()..retain(11);
      expect(actual, expected);
    });

    test('still deletes everything between embeds', () {
      final doc = Delta()
        ..insert('Document\n')
        ..insert(BlockEmbed.horizontalRule)
        ..insert('\nSome text\n')
        ..insert(BlockEmbed.horizontalRule)
        ..insert('\n');
      final actual = rule.apply(doc, 10, 11);
      final expected = Delta()
        ..retain(11)
        ..delete(9);
      expect(actual, expected);
    });

    test('allows deleting empty line after embed', () {
      final doc = Delta()
        ..insert('Document\n')
        ..insert(BlockEmbed.horizontalRule)
        ..insert('\n')
        ..insert('\n', ParchmentAttribute.block.bulletList.toJson())
        ..insert('Text')
        ..insert('\n');
      final actual = rule.apply(doc, 10, 1);
      final expected = Delta()
        ..retain(11)
        ..delete(1);
      expect(actual, expected);
    });

    test('allows deleting empty line(s) before embed', () {
      final doc = Delta()
        ..insert('Document\n')
        ..insert('\n')
        ..insert('\n')
        ..insert(BlockEmbed.horizontalRule)
        ..insert('\n')
        ..insert('Text')
        ..insert('\n');
      final actual = rule.apply(doc, 11, 1);
      expect(actual, isNull);
    });
  });
}
