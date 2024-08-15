import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parchment/codecs.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Enter some text at the end', (tester) async {
    final document = ParchmentMarkdownCodec().decode(markdown * 100);
    final controller = FleatherController(document: document);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FleatherEditor(controller: controller),
      ),
    ));

    await binding.traceAction(
      () async {
        await tester.tap(find.byType(RawEditor));
        await tester.pump();
        controller.updateSelection(
            TextSelection.collapsed(offset: document.length - 1));
        await tester.pump();
        await tester.ime.typeText(iputText, finder: find.byType(RawEditor));
      },
      reportKey: 'editing_timeline',
    );
  });
}

final iputText =
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.';

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
