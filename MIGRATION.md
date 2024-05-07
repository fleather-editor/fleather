## Fleather 1.4.4 > 1.14.5+1

* Change `SelectorScope.of(context).pushSelector(selector, completer)` to `SelectorScope.showSelector(context, selector, completer)` or `SelectorScope.of(context).showSelector(context, selector, completer)`

## Fleather 1.13.2 > 1.14.0+1 | Parchment 1.13.0 > 1.14.0

* Change `quill_delta:` to `parchment_delta:` in `pubspec.yaml`
* Change `import 'package:quill_delta/quill_delta.dart';` to `import 'package:parchment_delta/parchment_delta.dart';`

## Fleather 1.11.0 > 1.12.0

* Change `FleatherController(document);` to `FleatherController(document: document);`

## Parchment 1.6.0 > 1.7.0

* Change `import 'package:parchment/convert.dart';` to `import 'package:parchment/codecs.dart';`
* Change `parchmentMarkdown.encode(delta);` to `parchmentMarkdown.encode(ParchmentDocument.fromDelta(delta));`
* Change `parchmentMarkdown.decode(markdown);` to `parchmentMarkdown.decode(markdown).toDelta();`
* Change `parchmentHtml.encode(delta);` to `parchmentHtml.encode(ParchmentDocument.fromDelta(delta));`
* Change `parchmentHtml.decode(html);` to `parchmentHtml.decode(html).toDelta();`
