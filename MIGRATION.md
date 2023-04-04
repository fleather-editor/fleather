# Parchment

## 1.6.0 > 1.7.0

* Change `import 'package:parchment/convert.dart';` to `import 'package:parchment/codecs.dart';`
* Change `parchmentMarkdown.encode(delta);` to `parchmentMarkdown.encode(ParchmentDocument.fromDelta(delta));`
* Change `parchmentMarkdown.decode(markdown);` to `parchmentMarkdown.decode(markdown).toDelta()`
* Change `parchmentHtml.encode(delta);` to `parchmentHtml.encode(ParchmentDocument.fromDelta(delta));`
* Change `parchmentHtml.decode(html);` to `parchmentHtml.decode(html).toDelta()`
