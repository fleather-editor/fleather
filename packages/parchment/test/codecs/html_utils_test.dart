import 'package:parchment/src/codecs/html_utils.dart';
import 'package:test/test.dart';

void main() {
  group('CSS color to int color value', () {
    // https://developer.mozilla.org/docs/Web/CSS/color_value/rgb#syntaxe
    test('rgba(r,g,b)', () {
      final act = colorValueFromCSS('rgba(255,0,0)');
      expect(act, 0xFFFF0000);
    });

    test('rgba(r,g,b,a)', () {
      final act = colorValueFromCSS('rgba(255,0,0,1.0)');
      expect(act, 0xFFFF0000);
    });

    test('rgb(r g b)', () {
      final act = colorValueFromCSS('rgb(255 0 0)');
      expect(act, 0xFFFF0000);
    });

    test('rgb(r g b / a)', () {
      final act = colorValueFromCSS('rgb(255 0 0 / 1.0)');
      expect(act, 0xFFFF0000);
    });

    // https://developer.mozilla.org/en-US/docs/Web/CSS/hex-color#syntax
    test('#RGB', () {
      final act = colorValueFromCSS('#F00');
      expect(act, 0xFFFF0000);
    });

    test('#RGBA', () {
      final act = colorValueFromCSS('#F00F');
      expect(act, 0xFFFF0000);
    });

    test('#RRGGBB', () {
      final act = colorValueFromCSS('#FF0000');
      expect(act, 0xFFFF0000);
    });

    test('#RRGGBBAA', () {
      final act = colorValueFromCSS('#FF0000FF');
      expect(act, 0xFFFF0000);
    });
  });
}
