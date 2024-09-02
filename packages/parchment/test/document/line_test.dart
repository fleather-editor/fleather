import 'package:parchment/parchment.dart';
import 'package:test/test.dart';

final boldStyle = ParchmentStyle().merge(ParchmentAttribute.bold);
final h1Style = ParchmentStyle().merge(ParchmentAttribute.h1);
final h2Style = ParchmentStyle().merge(ParchmentAttribute.h2);
final ulStyle = ParchmentStyle().merge(ParchmentAttribute.ul);
final bqStyle = ParchmentStyle().merge(ParchmentAttribute.bq);
final rightStyle = ParchmentStyle().merge(ParchmentAttribute.right);

void main() {
  group('$LineNode', () {
    late ContainerNode root;
    setUp(() {
      root = RootNode();
    });

    test('empty', () {
      final node = LineNode();
      expect(node, isEmpty);
      expect(node.length, 1);
      expect(node.style, ParchmentStyle());
      expect(node.toDelta().toList(), [Operation.insert('\n')]);
    });

    test('hasBlockEmbed', () {
      final node = LineNode();
      expect(node.hasBlockEmbed, isFalse);
      node.add(EmbedNode(BlockEmbed.horizontalRule));
      expect(node.hasBlockEmbed, isTrue);
    });

    test('nextLine', () {
      root.insert(
          0, 'Hello world\nThis is my first multiline\nItem\ndocument.', null);
      root.retain(38, 1, ulStyle);
      root.retain(43, 1, bqStyle);
      final line = root.first as LineNode;
      expect(line.toPlainText(), 'Hello world\n');
      var next = line.nextLine!;
      expect(next.toPlainText(), 'This is my first multiline\n');
      next = next.nextLine!;
      expect(next.toPlainText(), 'Item\n');
      next = next.nextLine!;
      expect(next.toPlainText(), 'document.\n');
      expect(next.nextLine, isNull);
    });

    test('toString', () {
      final node = LineNode();
      node.insert(0, 'London "Grammar" - Hey Now', null);
      node.retain(0, 16, boldStyle);
      node.applyAttribute(ParchmentAttribute.h1);
      expect('$node', '¶ ⟨London "Grammar"⟩b → ⟨ - Hey Now⟩ ⏎ {heading: 1}');
    });

    test('splitAt with multiple text segments', () {
      root.insert(0, 'This house is a circus', null);
      root.retain(0, 4, boldStyle);
      root.retain(16, 6, boldStyle);
      final line = root.first as LineNode;
      final lastTextSegment = line.children.last;
      expect(lastTextSegment.offset, 16);
      final newLine = line.splitAt(10);
      expect(lastTextSegment.offset, 6);
      expect(line.toPlainText(), 'This house\n');
      expect(newLine.toPlainText(), ' is a circus\n');
    });

    test('insert into empty line', () {
      final node = LineNode();
      node.insert(0, 'London "Grammar" - Hey Now', null);
      expect(node, hasLength(27));
      expect(node.toDelta(), Delta()..insert('London "Grammar" - Hey Now\n'));
    });

    test('insert into empty line with styles', () {
      final node = LineNode();
      node.insert(0, 'London "Grammar" - Hey Now', null);
      node.retain(0, 16, boldStyle);
      node.applyAttribute(ParchmentAttribute.h1);
      expect(node, hasLength(27));
      expect(node.childCount, 2);

      final delta = Delta()
        ..insert('London "Grammar"', boldStyle.toJson())
        ..insert(' - Hey Now')
        ..insert('\n', ParchmentAttribute.h1.toJson());
      expect(node.toDelta(), delta);
    });

    test('insert into non-empty line', () {
      final node = LineNode();
      node.insert(0, 'Hello world', null);
      node.insert(11, '!!!', null);
      expect(node, hasLength(15));
      expect(node.childCount, 1);
      expect(node.toDelta(), Delta()..insert('Hello world!!!\n'));
    });

    test('insert text with line-break at the end of line', () {
      root.insert(0, 'Hello world', null);
      root.insert(11, '!!!\n', null);
      expect(root.childCount, 2);

      final line = root.first as LineNode;
      expect(line, hasLength(15));
      expect(line.toDelta(), Delta()..insert('Hello world!!!\n'));

      final line2 = root.last as LineNode;
      expect(line2, hasLength(1));
      expect(line2.toDelta(), Delta()..insert('\n'));
    });

    test('insert into second text segment', () {
      root.insert(0, 'Hello world', null);
      root.retain(6, 5, boldStyle);
      root.insert(11, '!!!', null);

      final line = root.first as LineNode;
      expect(line, hasLength(15));
      final delta = Delta()
        ..insert('Hello ')
        ..insert('world', boldStyle.toJson())
        ..insert('!!!\n');
      expect(line.toDelta(), delta);
    });

    test('format line', () {
      root.insert(0, 'Hello world\n', null);
      root.insert(12, 'Second headline\n', null);
      root.retain(11, 1, h1Style);
      root.retain(11, 1, rightStyle);

      final secondHeadline = root.first.next!;
      expect(secondHeadline.offset, 12);

      root.retain(27, 1, ParchmentStyle().merge(ParchmentAttribute.cl));
      expect(secondHeadline.offset, 0);

      final line = root.first as LineNode;
      expect(line, hasLength(12));

      final delta = Delta()
        ..insert('Hello world')
        ..insert('\n', {
          ParchmentAttribute.h1.key: ParchmentAttribute.h1.value,
          ParchmentAttribute.alignment.key: ParchmentAttribute.right.value,
        });
      expect(line.toDelta(), delta);
    });

    test('format line with inline attributes', () {
      root.insert(0, 'Hello world', null);
      expect(() {
        root.retain(11, 1, boldStyle);
      }, throwsA(const TypeMatcher<AssertionError>()));
    });

    test('format text inside line with block/line attributes', () {
      root.insert(0, 'Hello world', null);
      expect(() {
        root.retain(10, 2, h1Style);
      }, throwsA(const TypeMatcher<AssertionError>()));
    });

    test('format root line to unset block style', () {
      final unsetBlock = ParchmentStyle().put(ParchmentAttribute.block.unset);
      root.insert(0, 'Hello world', null);
      root.retain(11, 1, unsetBlock);
      expect(root.childCount, 1);
      expect(root.first, const TypeMatcher<LineNode>());
      final line = root.first as LineNode;
      expect(line.style.contains(ParchmentAttribute.block), isFalse);
    });

    test('format multiple empty lines', () {
      root.insert(0, 'Hello world\n\n\n', null);
      root.retain(11, 3, ulStyle);
      expect(root.children, hasLength(2));
      final block = root.first as BlockNode;
      expect(block.children, hasLength(3));
      expect(block.toPlainText(), 'Hello world\n\n\n');
    });

    test('delete a line', () {
      root.insert(0, 'Hello world', null);
      root.delete(0, 12);
      expect(root, isEmpty);
      // TODO: this should really enforce at least one empty line.
    });

    test('delete from the middle of a line', () {
      root.insert(0, 'Hello world', null);
      root.delete(4, 3);
      root.delete(6, 1);
      expect(root.childCount, 1);
      final line = root.first as LineNode;
      expect(line, hasLength(8));
      expect(line.childCount, 1);
      final lineDelta = Delta()..insert('Hellord\n');
      expect(line.toDelta(), lineDelta);
    });

    test('delete from non-first segment in line', () {
      root.insert(0, 'Hello world, Ab cd ef!', null);
      root.retain(6, 5, boldStyle);
      root.delete(10, 5);
      expect(root.childCount, 1);
      final line = root.first as LineNode;
      expect(line, hasLength(18));
      final lineDelta = Delta()
        ..insert('Hello ')
        ..insert('worl', boldStyle.toJson())
        ..insert(' cd ef!\n');
      expect(line.toDelta(), lineDelta);
    });

    test('delete on multiple lines', () {
      root.insert(0, 'delete\nmultiple\nlines', null);
      root.retain(21, 1, h2Style);
      root.delete(3, 15);
      expect(root.childCount, 1);
      final line = root.first as LineNode;
      expect(line.childCount, 1);
      final delta = Delta()
        ..insert('delnes')
        ..insert('\n', h2Style.toJson());
      expect(line.toDelta(), delta);
    });

    test('delete empty line', () {
      root.insert(
          0, 'Hello world\nThis is my first multiline\n\ndocument.', null);
      expect(root.childCount, 4);
      root.delete(39, 1);
      expect(root.childCount, 3);
    });

    test('delete line-break of non-empty line', () {
      root.insert(
          0, 'Hello world\nThis is my first multiline\n\ndocument.', null);
      root.retain(39, 1, h2Style);
      expect(root.childCount, 4);
      root.delete(38, 1);
      expect(root.childCount, 3);
      final line = root.children.elementAt(1) as LineNode;
      expect(line.style.get(ParchmentAttribute.heading), ParchmentAttribute.h2);
    });

    test('insert at the beginning of a line', () {
      root.insert(
          0, 'Hello world\nThis is my first multiline\ndocument.', null);
      root.insert(12, 'Boom! ', null);
      expect(root.childCount, 3);
      expect(root.children.elementAt(1), hasLength(33));
    });

    test('delete last character of a line', () {
      root.insert(
          0, 'Hello world\nThis is my first multiline\ndocument.', null);
      root.delete(37, 1);
      expect(root.childCount, 3);
      final line = root.children.elementAt(1) as LineNode;
      expect(line.toDelta(), Delta()..insert('This is my first multilin\n'));
    });

    test('collectStyle', () {
      // TODO: need more test cases for collectStyle
      root.insert(
          0, 'Hello world\nThis is my first multiline\n\ndocument.', null);
      root.retain(38, 1, h2Style);
      root.retain(23, 5, boldStyle);
      var result = root.lookup(20);
      final line = result.node as LineNode;
      var attrs = line.collectStyle(result.offset, 5);
      expect(attrs, h2Style);
    });

    test('collectStyle with embed nodes', () {
      root.insert(0, 'Hello world\n\nMore text.\n', null);
      root.insert(12, BlockEmbed.horizontalRule, null);

      var lookup = root.lookup(0);
      final line = lookup.node as LineNode;
      var result = line.collectStyle(lookup.offset, 15);
      expect(result, isEmpty);
    });
  });
}
