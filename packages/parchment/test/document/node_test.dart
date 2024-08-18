import 'package:parchment/parchment.dart';
import 'package:test/test.dart';

void main() {
  group('$Node', () {
    late RootNode root;
    setUp(() {
      root = RootNode();
    });

    test('mounted', () {
      final line = LineNode();
      final text = TextNode();
      expect(text.mounted, isFalse);
      line.add(text);
      expect(text.mounted, isTrue);
    });

    test('offset', () {
      root.insert(0, 'First line\nSecond line', null);
      expect(root.children.first.offset, 0);
      expect(root.children.elementAt(1).offset, 11);
    });

    test('documentOffset', () {
      root.insert(0, 'First line\nSecond line\nThird line', null);
      final secondLine = root.children.first.next as LineNode;
      final thirdLine = root.children.last as LineNode;
      expect(thirdLine.documentOffset, 23);
      secondLine.insert(6, ' styled', ParchmentStyle.fromJson({'b': true}));
      final styledText = secondLine.first.next as TextNode;
      final lastText = secondLine.last as TextNode;
      expect(secondLine.documentOffset, 11);
      expect(thirdLine.documentOffset, 30);
      expect(styledText.documentOffset, 17);
      expect(lastText.documentOffset, 24);
      secondLine.remove(styledText);
      expect(lastText.documentOffset, 17);
      expect(thirdLine.documentOffset, 23);
    });

    test('containsOffset', () {
      root.insert(0, 'First line\nSecond line', null);
      final line = root.children.last as LineNode;
      final text = line.first as TextNode;
      expect(line.containsOffset(10), isFalse);
      expect(line.containsOffset(12), isTrue);
      expect(text.containsOffset(10), isFalse);
      expect(text.containsOffset(12), isTrue);
    });
  });
}
