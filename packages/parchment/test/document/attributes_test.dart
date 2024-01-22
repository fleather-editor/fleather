import 'package:test/test.dart';
import 'package:parchment/parchment.dart';

void main() {
  group('$ParchmentStyle', () {
    test('get', () {
      var attrs = ParchmentStyle.fromJson(<String, dynamic>{'block': 'ul'});
      var attr = attrs.get(ParchmentAttribute.block);
      expect(attr, ParchmentAttribute.ul);
    });

    test('get unset', () {
      var attrs = ParchmentStyle.fromJson(<String, dynamic>{'b': null});
      var attr = attrs.get(ParchmentAttribute.bold);
      expect(attr, ParchmentAttribute.bold.unset);
    });
  });

  group('$ParchmentAttribute', () {
    test('create background attribute with color', () {
      final attribute =
          ParchmentAttribute.backgroundColor.withColor(0xFFFF0000);
      expect(attribute.key, ParchmentAttribute.backgroundColor.key);
      expect(attribute.scope, ParchmentAttribute.backgroundColor.scope);
      expect(attribute.value, 0xFFFF0000);
    });

    test('create background attribute with transparent color', () {
      final attribute =
          ParchmentAttribute.backgroundColor.withColor(0x00000000);
      expect(attribute, ParchmentAttribute.backgroundColor.unset);
    });

    test('create foreground attribute with color', () {
      final attribute =
          ParchmentAttribute.foregroundColor.withColor(0x00FF0000);
      expect(attribute.key, ParchmentAttribute.foregroundColor.key);
      expect(attribute.scope, ParchmentAttribute.foregroundColor.scope);
      expect(attribute.value, 0x00FF0000);
    });

    test('create foreground attribute with black color', () {
      final attribute =
          ParchmentAttribute.foregroundColor.withColor(0x00000000);
      expect(attribute, ParchmentAttribute.foregroundColor.unset);
    });
  });
}
