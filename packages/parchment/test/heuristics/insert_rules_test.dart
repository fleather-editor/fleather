import 'package:parchment/parchment.dart';
import 'package:test/test.dart';

final ul = ParchmentAttribute.ul.toJson();
final bold = ParchmentAttribute.bold.toJson();

void main() {
  group('$CatchAllInsertRule', () {
    final rule = CatchAllInsertRule();

    test('applies change as-is', () {
      final doc = Delta()..insert('Document\n');
      final actual = rule.apply(doc, 8, '!');
      final expected = Delta()
        ..retain(8)
        ..insert('!');
      expect(actual, expected);
    });
  });

  group('$PreserveLineStyleOnSplitRule', () {
    final rule = PreserveLineStyleOnSplitRule();

    test('skips at the beginning of a document', () {
      final doc = Delta()..insert('One\n');
      final actual = rule.apply(doc, 0, '\n');
      expect(actual, isNull);
    });

    test('applies in a block', () {
      final doc = Delta()
        ..insert('One and two')
        ..insert('\n', ul)
        ..insert('Three')
        ..insert('\n', ul);
      final actual = rule.apply(doc, 8, '\n');
      final expected = Delta()
        ..retain(8)
        ..insert('\n', ul);
      expect(actual, isNotNull);
      expect(actual, expected);
    });

    test('applies before an embed', () {
      final doc = Delta()
        ..insert('Hello ')
        ..insert({'_type': 'icon', '_inline': true})
        ..insert('\n');
      final actual = rule.apply(doc, 6, '\n');
      final expected = Delta()
        ..retain(6)
        ..insert('\n');
      expect(actual, isNotNull);
      expect(actual, expected);
    });
  });

  group('$PreserveLineFormatOnNewLineRule', () {
    final rule = const PreserveLineFormatOnNewLineRule();

    test('applies when line-break is inserted at the end of line', () {
      final doc = Delta()
        ..insert('Hello world')
        ..insert('\n', ParchmentAttribute.h1.toJson());
      final actual = rule.apply(doc, 11, '\n');
      expect(actual, isNotNull);
      final expected = Delta()
        ..retain(11)
        ..insert('\n', ParchmentAttribute.h1.toJson())
        ..retain(1, ParchmentAttribute.heading.unset.toJson());
      expect(actual, expected);
    });

    test('applies without style reset if not needed', () {
      final doc = Delta()..insert('Hello world\n');
      final actual = rule.apply(doc, 11, '\n');
      expect(actual, isNotNull);
      final expected = Delta()
        ..retain(11)
        ..insert('\n');
      expect(actual, expected);
    });

    test('applies at the beginning of a document', () {
      final doc = Delta()..insert('\n', ParchmentAttribute.h1.toJson());
      final actual = rule.apply(doc, 0, '\n');
      expect(actual, isNotNull);
      final expected = Delta()
        ..insert('\n', ParchmentAttribute.h1.toJson())
        ..retain(1, ParchmentAttribute.heading.unset.toJson());
      expect(actual, expected);
    });

    test('applies and keeps block style', () {
      final style = ParchmentAttribute.ul.toJson();
      style.addAll(ParchmentAttribute.h1.toJson());
      final doc = Delta()
        ..insert('Hello world')
        ..insert('\n', style);
      final actual = rule.apply(doc, 11, '\n');
      expect(actual, isNotNull);
      final expected = Delta()
        ..retain(11)
        ..insert('\n', style)
        ..retain(1, ParchmentAttribute.heading.unset.toJson());
      expect(actual, expected);
    });

    test('applies to a line in the middle of a document', () {
      final doc = Delta()
        ..insert('Hello \nworld!\nMore lines here.')
        ..insert('\n', ParchmentAttribute.h2.toJson());
      final actual = rule.apply(doc, 30, '\n');
      expect(actual, isNotNull);
      final expected = Delta()
        ..retain(30)
        ..insert('\n', ParchmentAttribute.h2.toJson())
        ..retain(1, ParchmentAttribute.heading.unset.toJson());
      expect(actual, expected);
    });
  });

  group('$AutoExitBlockRule', () {
    final rule = AutoExitBlockRule();

    test('applies when newline is inserted on the last empty line in a block',
        () {
      final ul = ParchmentAttribute.ul.toJson();
      final doc = Delta()
        ..insert('Item 1')
        ..insert('\n', ul)
        ..insert('Item 2')
        ..insert('\n\n', ul);
      final actual = rule.apply(doc, 14, '\n');
      expect(actual, isNotNull);
      final expected = Delta()
        ..retain(14)
        ..retain(1, ParchmentAttribute.block.unset.toJson());
      expect(actual, expected);
    });

    test('applies only on empty line', () {
      final ul = ParchmentAttribute.ul.toJson();
      final doc = Delta()
        ..insert('Item 1')
        ..insert('\n', ul);
      final actual = rule.apply(doc, 6, '\n');
      expect(actual, isNull);
    });

    test('applies at the beginning of a document', () {
      final ul = ParchmentAttribute.ul.toJson();
      final doc = Delta()..insert('\n', ul);
      final actual = rule.apply(doc, 0, '\n');
      expect(actual, isNotNull);
      final expected = Delta()
        ..retain(1, ParchmentAttribute.block.unset.toJson());
      expect(actual, expected);
    });

    test('ignores non-empty line at the beginning of a document', () {
      final ul = ParchmentAttribute.ul.toJson();
      final doc = Delta()
        ..insert('Text')
        ..insert('\n', ul);
      final actual = rule.apply(doc, 0, '\n');
      expect(actual, isNull);
    });

    test('ignores empty lines in the middle of a block', () {
      final ul = ParchmentAttribute.ul.toJson();
      final doc = Delta()
        ..insert('Line1')
        ..insert('\n\n\n\n', ul);
      final actual = rule.apply(doc, 7, '\n');
      expect(actual, isNull);
    });
  });

  group('$PreserveInlineStylesRule', () {
    final rule = PreserveInlineStylesRule();
    test('apply', () {
      final doc = Delta()
        ..insert('Doc with ')
        ..insert('bold', bold)
        ..insert(' text');
      final actual = rule.apply(doc, 13, 'er');
      final expected = Delta()
        ..retain(13)
        ..insert('er', bold);
      expect(expected, actual);
    });

    test('apply preserve link formatting within link', () {
      final doc = Delta()
        ..insert('Doc with link')
        ..insert('http://fleather-editor.github.io',
            {'a': 'http://fleather-editor.github.io'})
        ..insert(' link');
      final actual = rule.apply(doc, 17, 's');
      final expected = Delta()
        ..retain(17)
        ..insert('s', {'a': 'http://fleather-editor.github.io'});
      expect(expected, actual);
    });

    test('apply remove link formatting on link boundaries', () {
      final doc = Delta()
        ..insert('Doc with link')
        ..insert('http://fleather-editor.github.io',
            {'a': 'http://fleather-editor.github.io'})
        ..insert(' link');
      final actual = rule.apply(doc, 13, 'like this ');
      final expected = Delta()
        ..retain(13)
        ..insert('like this ');
      expect(expected, actual);
    });

    test('apply at the beginning of a document', () {
      final doc = Delta()..insert('Doc with ');
      final actual = rule.apply(doc, 0, 'A ');
      expect(actual, isNull);
    });
  });

  group('$PreserveBlockStyleOnInsertRule', () {
    final rule = PreserveBlockStyleOnInsertRule();

    test('applies in a block', () {
      final doc = Delta()
        ..insert('One and two')
        ..insert('\n', ul)
        ..insert('Three')
        ..insert('\n', ul);
      final actual = rule.apply(doc, 8, 'also \n');
      final expected = Delta()
        ..retain(8)
        ..insert('also ')
        ..insert('\n', ul);
      expect(actual, isNotNull);
      expect(actual, expected);
    });

    test('applies for single newline insert', () {
      final doc = Delta()
        ..insert('One and two')
        ..insert('\n\n', ul)
        ..insert('Three')
        ..insert('\n', ul);
      final actual = rule.apply(doc, 12, '\n');
      final expected = Delta()
        ..retain(12)
        ..insert('\n', ul);
      expect(actual, expected);
    });

    test('applies for multi line insert', () {
      final doc = Delta()
        ..insert('One and two')
        ..insert('\n\n', ul)
        ..insert('Three')
        ..insert('\n', ul);
      final actual = rule.apply(doc, 8, '111\n222\n333');
      final expected = Delta()
        ..retain(8)
        ..insert('111')
        ..insert('\n', ul)
        ..insert('222')
        ..insert('\n', ul)
        ..insert('333');
      expect(actual, expected);
    });

    test('preserves heading style of the original line', () {
      final quote = ParchmentAttribute.block.quote.toJson();
      final h1Unset = ParchmentAttribute.heading.unset.toJson();
      final quoteH1 = ParchmentAttribute.block.quote.toJson();
      quoteH1.addAll(ParchmentAttribute.heading.level1.toJson());
      final doc = Delta()
        ..insert('One and two')
        ..insert('\n', quoteH1)
        ..insert('Three')
        ..insert('\n', quote);
      final actual = rule.apply(doc, 8, '111\n');
      final expected = Delta()
        ..retain(8)
        ..insert('111')
        ..insert('\n', quoteH1)
        ..retain(3)
        ..retain(1, h1Unset);
      expect(actual, expected);
    });

    test('preserves checked style of the original line', () {
      final cl = ParchmentAttribute.cl.toJson();
      final checkedUnset = ParchmentAttribute.checked.unset.toJson();
      final clChecked = ParchmentAttribute.cl.toJson();
      clChecked.addAll(ParchmentAttribute.checked.toJson());
      final doc = Delta()
        ..insert('One and two')
        ..insert('\n', clChecked)
        ..insert('Three')
        ..insert('\n', cl);
      final actual = rule.apply(doc, 8, '111\n');
      final expected = Delta()
        ..retain(8)
        ..insert('111')
        ..insert('\n', clChecked)
        ..retain(3)
        ..retain(1, checkedUnset);
      expect(actual, expected);
    });
  });

  group('$InsertBlockEmbedsRule', () {
    final rule = InsertBlockEmbedsRule();

    test('insert on an empty line', () {
      final doc = Delta()
        ..insert('One and two')
        ..insert('\n')
        ..insert('\n')
        ..insert('Three')
        ..insert('\n');
      final actual = rule.apply(doc, 12, BlockEmbed.horizontalRule);
      final expected = Delta()
        ..retain(12)
        ..insert(BlockEmbed.horizontalRule);
      expect(actual, isNotNull);
      expect(actual, expected);
    });

    test('insert in the beginning of a line', () {
      final doc = Delta()
        ..insert('One and two\n')
        ..insert('embed here\n')
        ..insert('Three')
        ..insert('\n');
      final actual = rule.apply(doc, 12, BlockEmbed.horizontalRule);
      final expected = Delta()
        ..retain(12)
        ..insert(BlockEmbed.horizontalRule)
        ..insert('\n');
      expect(actual, isNotNull);
      expect(actual, expected);
    });

    test('insert in the end of a line', () {
      final doc = Delta()
        ..insert('One and two\n')
        ..insert('embed here\n')
        ..insert('Three')
        ..insert('\n');
      final actual = rule.apply(doc, 11, BlockEmbed.horizontalRule);
      final expected = Delta()
        ..retain(11)
        ..insert('\n')
        ..insert(BlockEmbed.horizontalRule);
      expect(actual, isNotNull);
      expect(actual, expected);
    });

    test('insert in the middle of a line', () {
      final doc = Delta()
        ..insert('One and two\n')
        ..insert('embed here\n')
        ..insert('Three')
        ..insert('\n');
      final actual = rule.apply(doc, 17, BlockEmbed.horizontalRule);
      final expected = Delta()
        ..retain(17)
        ..insert('\n')
        ..insert(BlockEmbed.horizontalRule)
        ..insert('\n');
      expect(actual, isNotNull);
      expect(actual, expected);
    });

    test('inserted object is not block embed', () {
      final doc = Delta()
        ..insert('One and two\n')
        ..insert('embed here\n')
        ..insert('Three')
        ..insert('\n');
      expect(rule.apply(doc, 17, 'Some text'), isNull);
      expect(rule.apply(doc, 17, SpanEmbed('span')), isNull);
    });
  });
}
