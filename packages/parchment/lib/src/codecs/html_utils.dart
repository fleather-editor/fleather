({int R, int G, int B, int A}) toRGBA(int colorValue) {
  return (
    A: (0xff000000 & colorValue) >> 24,
    R: (0x00ff0000 & colorValue) >> 16,
    G: (0x0000ff00 & colorValue) >> 8,
    B: (0x000000ff & colorValue) >> 0
  );
}

int colorValueFromCSS(String cssColor) {
  // https://developer.mozilla.org/docs/Web/CSS/color_value/rgb
  if (cssColor.startsWith('rgba(') || cssColor.startsWith('rgb(')) {
    var split = _chooseSplit(cssColor);

    final hasAlpha = split.length == 4;
    final components = <int>[];
    for (var i = 0; i < split.length; i++) {
      var s = split[i];
      s = s.trim();
      s = s.replaceFirst('rgba(', '');
      s = s.replaceFirst('rgb(', '');
      s = s.replaceFirst(')', '');
      if (hasAlpha && i == 3) {
        if (s.endsWith('%')) {
          components.add(int.parse(s.split('%')[0]));
        } else {
          final rawValue = double.parse(s);
          if (rawValue > 1.0 || rawValue < 0) {
            throw ArgumentError('Alpha component must be between 0.0 and 1.0');
          }
          components.add((rawValue * 255).floor());
        }
      } else {
        components.add(int.parse(s));
      }
    }
    return (((components.length == 4 ? components[3] : 255 & 0xff) << 24) |
            ((components[0] & 0xff) << 16) |
            ((components[1] & 0xff) << 8) |
            ((components[2] & 0xff) << 0)) &
        0xFFFFFFFF;
  }

  // https://developer.mozilla.org/en-US/docs/Web/CSS/hex-color
  if (cssColor.startsWith('#')) {
    String sHexValue = cssColor.split('#')[1];
    if (sHexValue.length == 3) {
      String r = sHexValue[0];
      String g = sHexValue[1];
      String b = sHexValue[2];
      sHexValue = 'FF$r$r$g$g$b$b';
    } else if (sHexValue.length == 4) {
      String r = sHexValue[0];
      String g = sHexValue[1];
      String b = sHexValue[2];
      String a = sHexValue[3];
      sHexValue = '$a$a$r$r$g$g$b$b';
    } else if (sHexValue.length == 6) {
      sHexValue = 'FF$sHexValue';
    } else if (sHexValue.length == 8) {
      sHexValue = sHexValue.substring(6, 8) + sHexValue.substring(0, 6);
    } else {
      throw ArgumentError('Invalid hex value $cssColor');
    }
    return int.parse(sHexValue, radix: 16);
  }
  // hsl() not supported for the time being
  throw ArgumentError('Unsupported CSS color format : $cssColor');
}

List<String> _chooseSplit(String cssColor) {
  var split = cssColor.split(',');

  // it's rgb(r,g,b[,a])
  if (split.length >= 3) return split;

  // it's rgb(r g b [/ a])
  split = cssColor.split(' ');
  if (split.length < 3) {
    throw ArgumentError(
        'CSS color - rgb(a) must have at least 3 components. Received $cssColor');
  }

  final clean = <String>[];
  bool hasSlash = false;
  for (var s in split) {
    s = s.trim();
    if (s == '/') {
      hasSlash = true;
      continue;
    }
    if (s.isNotEmpty) {
      clean.add(s);
    }
  }
  if (hasSlash && clean.length != 4) {
    throw ArgumentError(
        'CSS color - expected 4 components. Received $cssColor');
  }
  if (!hasSlash && clean.length != 3) {
    throw ArgumentError(
        'CSS color : expecting 3 components. Received $cssColor');
  }
  return clean;
}
