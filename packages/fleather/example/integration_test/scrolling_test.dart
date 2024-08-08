import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parchment/codecs.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Scroll to the end', (tester) async {
    final document = ParchmentMarkdownCodec().decode(markdown * 100);
    final controller = FleatherController(document: document);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FleatherEditor(controller: controller),
      ),
    ));

    final scrollableFinder = find.byType(Scrollable);
    final scrollable = tester.widget<Scrollable>(scrollableFinder);
    final scrollController = scrollable.controller!;

    await binding.traceAction(
      () async {
        while (scrollController.position.extentAfter != 0) {
          await tester.drag(scrollableFinder, const Offset(0, -200));
          await tester.pump();
        }
      },
      reportKey: 'scrolling_timeline',
    );
  });
}

final markdown = '''
# Fleather

_Soft and gentle rich text editing for Flutter applications._

Fleather is an **early preview** open source library.

- [ ] That even supports
- [X] Checklists

### Documentation

* Quick Start
* Data format and Document Model
* Style attributes
* Heuristic rules

## Clean and modern look

Fleather’s rich text editor is built with _simplicity and flexibility_ in mind. It provides clean interface for distraction-free editing. Think `Medium.com`-like experience.

```
import ‘package:flutter/material.dart’;
import ‘package:parchment/parchment.dart’;

void main() {
 print(“Hello world!”);
}
```

''';
