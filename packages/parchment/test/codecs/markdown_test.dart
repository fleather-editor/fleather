import 'dart:convert';

import 'package:parchment/codecs.dart';
import 'package:parchment/parchment.dart';
import 'package:test/test.dart';

void main() {
  group('ParchmentMarkdownCodec.decode', () {
    test('should convert empty markdown to valid empty document', () {
      final markdown = '';
      final newParchment = ParchmentDocument();
      final delta = parchmentMarkdown.decode(markdown).toDelta();
      expect(delta.length, 1);
      expect(delta.first.data, '\n');
      expect(delta, newParchment.toDelta());
    });

    test(
        'should convert invalid markdown with only line breaks to valid empty document',
        () {
      final markdown = '\n\n\n';
      final delta = parchmentMarkdown.decode(markdown).toDelta();
      expect(delta.length, 1);
      expect(delta.first.data, '\n');
      final newParchment = ParchmentDocument();
      expect(delta, newParchment.toDelta());
    });

    test('paragraphs', () {
      final markdown = 'First line\n\nSecond line\n\n';
      final document = parchmentMarkdown.decode(markdown);
      final delta = document.toDelta();
      expect(delta.elementAt(0).data, 'First line\nSecond line\n');
      final andBack = parchmentMarkdown.encode(document);
      expect(andBack, markdown);
    });

    test('italics', () {
      void runFor(String markdown, bool testEncode) {
        final document = parchmentMarkdown.decode(markdown);
        final delta = document.toDelta();
        expect(delta.elementAt(0).data, 'italics');
        expect(delta.elementAt(0).attributes?['i'], true);
        expect(delta.elementAt(0).attributes?['b'], null);
        if (testEncode) {
          final andBack = parchmentMarkdown.encode(document);
          expect(andBack, markdown);
        }
      }

      runFor('_italics_\n\n', true);
      runFor('*italics*\n\n', false);
    });

    test('multi-word italics', () {
      void runFor(String markdown, bool testEncode) {
        final document = parchmentMarkdown.decode(markdown);
        final delta = document.toDelta();
        expect(delta.elementAt(0).data, 'Okay, ');
        expect(delta.elementAt(0).attributes, null);

        expect(delta.elementAt(1).data, 'this is in italics');
        expect(delta.elementAt(1).attributes?['i'], true);
        expect(delta.elementAt(1).attributes?['b'], null);

        expect(delta.elementAt(3).data, 'so is all of _ this');
        expect(delta.elementAt(3).attributes?['i'], true);

        expect(delta.elementAt(4).data, ' but this is not\n');
        expect(delta.elementAt(4).attributes, null);
        if (testEncode) {
          final andBack = parchmentMarkdown.encode(document);
          expect(andBack, markdown);
        }
      }

      runFor(
          'Okay, _this is in italics_ and _so is all of _ this_ but this is not\n\n',
          true);
      runFor(
          'Okay, *this is in italics* and *so is all of _ this* but this is not\n\n',
          false);
    });

    test('bold', () {
      void runFor(String markdown, bool testEncode) {
        final document = parchmentMarkdown.decode(markdown);
        final delta = document.toDelta();
        expect(delta.elementAt(0).data, 'bold');
        expect(delta.elementAt(0).attributes?['b'], true);
        expect(delta.elementAt(0).attributes?['i'], null);
        if (testEncode) {
          final andBack = parchmentMarkdown.encode(document);
          expect(andBack, markdown);
        }
      }

      runFor('**bold**\n\n', true);
      runFor('__bold__\n\n', false);
    });

    test('multi-word bold', () {
      void runFor(String markdown, bool testEncode) {
        final document = parchmentMarkdown.decode(markdown);
        final delta = document.toDelta();
        expect(delta.elementAt(0).data, 'Okay, ');
        expect(delta.elementAt(0).attributes, null);

        expect(delta.elementAt(1).data, 'this is bold');
        expect(delta.elementAt(1).attributes?['b'], true);
        expect(delta.elementAt(1).attributes?['i'], null);

        expect(delta.elementAt(3).data, 'so is all of __ this');
        expect(delta.elementAt(3).attributes?['b'], true);

        expect(delta.elementAt(4).data, ' but this is not\n');
        expect(delta.elementAt(4).attributes, null);
        if (testEncode) {
          final andBack = parchmentMarkdown.encode(document);
          expect(andBack, markdown);
        }
      }

      runFor(
          'Okay, **this is bold** and **so is all of __ this** but this is not\n\n',
          true);
      runFor(
          'Okay, __this is bold__ and __so is all of __ this__ but this is not\n\n',
          false);
    });

    test('strike through', () {
      void runFor(String markdown, bool testEncode) {
        final document = parchmentMarkdown.decode(markdown);
        final delta = document.toDelta();
        expect(delta.elementAt(0).data, 'strike through');
        expect(delta.elementAt(0).attributes?['s'], true);
        if (testEncode) {
          final andBack = parchmentMarkdown.encode(document);
          expect(andBack, markdown);
        }
      }

      runFor('~~strike through~~\n\n', true);
    });

    test('intersecting inline styles', () {
      final markdown = 'This **house _is a_ circus**\n\n';
      final document = parchmentMarkdown.decode(markdown);
      final delta = document.toDelta();
      expect(delta.elementAt(1).data, 'house ');
      expect(delta.elementAt(1).attributes?['b'], true);
      expect(delta.elementAt(1).attributes?['i'], null);

      expect(delta.elementAt(2).data, 'is a');
      expect(delta.elementAt(2).attributes?['b'], true);
      expect(delta.elementAt(2).attributes?['i'], true);

      expect(delta.elementAt(3).data, ' circus');
      expect(delta.elementAt(3).attributes?['b'], true);
      expect(delta.elementAt(3).attributes?['i'], null);

      final andBack = parchmentMarkdown.encode(document);
      expect(andBack, markdown);
    });

    test('bold and italics alone', () {
      void runFor(String markdown) {
        final document = parchmentMarkdown.decode(markdown);
        final delta = document.toDelta();
        expect(delta.elementAt(0).data, 'this is bold and italic');
        expect(delta.elementAt(0).attributes?['b'], true);
        expect(delta.elementAt(0).attributes?['i'], true);

        expect(delta.elementAt(1).data, '\n');
        expect(delta.length, 2);
      }

      runFor('**_this is bold and italic_**\n\n');
      runFor('_**this is bold and italic**_\n\n');
      runFor('***this is bold and italic***\n\n');
      runFor('___this is bold and italic___\n\n');
    });

    test('bold and italics combinations', () {
      void runFor(String markdown) {
        final document = parchmentMarkdown.decode(markdown);
        final delta = document.toDelta();
        expect(delta.elementAt(0).data, 'this is bold');
        expect(delta.elementAt(0).attributes?['b'], true);
        expect(delta.elementAt(0).attributes?['i'], null);

        expect(delta.elementAt(2).data, 'this is in italics');
        expect(delta.elementAt(2).attributes?['b'], null);
        expect(delta.elementAt(2).attributes?['i'], true);

        expect(delta.elementAt(4).data, 'this is both');
        expect(delta.elementAt(4).attributes?['b'], true);
        expect(delta.elementAt(4).attributes?['i'], true);
      }

      runFor(
          '**this is bold** _this is in italics_ and **_this is both_**\n\n');
      runFor(
          '**this is bold** *this is in italics* and ***this is both***\n\n');
      runFor(
          '__this is bold__ _this is in italics_ and ___this is both___\n\n');
    });

    test('link', () {
      final markdown = 'This **house** is a [circus](https://github.com)\n\n';
      final document = parchmentMarkdown.decode(markdown);
      final delta = document.toDelta();

      expect(delta.elementAt(1).data, 'house');
      expect(delta.elementAt(1).attributes?['b'], true);
      expect(delta.elementAt(1).attributes?['a'], null);

      expect(delta.elementAt(3).data, 'circus');
      expect(delta.elementAt(3).attributes?['b'], null);
      expect(delta.elementAt(3).attributes?['a'], 'https://github.com');

      final andBack = parchmentMarkdown.encode(document);
      expect(andBack, markdown);
    });

    test('double link', () {
      final markdown =
          'This **house** is a [circus](https://github.com) and [home](https://github.com)\n\n';
      final document = parchmentMarkdown.decode(markdown);
      final delta = document.toDelta();

      expect(delta.elementAt(3).data, 'circus');
      expect(delta.elementAt(3).attributes?['b'], null);
      expect(delta.elementAt(3).attributes?['a'], 'https://github.com');

      expect(delta.elementAt(5).data, 'home');
      expect(delta.elementAt(5).attributes?['a'], 'https://github.com');

      final andBack = parchmentMarkdown.encode(document);
      expect(andBack, markdown);
    });

    test('complex link', () {
      final markdown =
          'This a complex link [1[2(3) 4]5 6](https://github.com/[abc]) and [normal one](https://github.com)\n\n';
      final document = parchmentMarkdown.decode(markdown);
      final delta = document.toDelta();

      expect(delta.elementAt(1).data, '1[2(3) 4]5 6');
      expect(delta.elementAt(1).attributes?['b'], null);
      expect(delta.elementAt(1).attributes?['a'], 'https://github.com/[abc]');

      expect(delta.elementAt(3).data, 'normal one');
      expect(delta.elementAt(3).attributes?['a'], 'https://github.com');

      final andBack = parchmentMarkdown.encode(document);
      expect(andBack, markdown);
    });

    test('style around link', () {
      final markdown =
          'This **house** is a **[circus](https://github.com)**\n\n';
      final delta = parchmentMarkdown.decode(markdown).toDelta();

      expect(delta.elementAt(1).data, 'house');
      expect(delta.elementAt(1).attributes?['b'], true);
      expect(delta.elementAt(1).attributes?['a'], null);

      expect(delta.elementAt(3).data, 'circus');
      expect(delta.elementAt(3).attributes?['b'], true);
      expect(delta.elementAt(3).attributes?['a'], 'https://github.com');
    });

    test('style within link', () {
      final markdown =
          'This **house** is a [**circus**](https://github.com)\n\n';
      final delta = parchmentMarkdown.decode(markdown).toDelta();

      expect(delta.elementAt(1).data, 'house');
      expect(delta.elementAt(1).attributes?['b'], true);
      expect(delta.elementAt(1).attributes?['a'], null);

      expect(delta.elementAt(2).data, ' is a ');
      expect(delta.elementAt(2).attributes, null);

      expect(delta.elementAt(3).data, 'circus');
      expect(delta.elementAt(3).attributes?['b'], true);
      expect(delta.elementAt(3).attributes?['a'], 'https://github.com');

      expect(delta.elementAt(4).data, '\n');
      expect(delta.length, 5);
    });

    test('inline code only', () {
      final markdown = 'This is `some code` that works\n';
      final delta = parchmentMarkdown.decode(markdown).toDelta();

      expect(delta.elementAt(0).data, 'This is ');
      expect(delta.elementAt(1).data, 'some code');
      expect(delta.elementAt(1).attributes?['c'], true);
      expect(delta.elementAt(2).data, ' that works\n');
    });

    test('inline code within style', () {
      final markdown = 'This **is `some code`** that works\n';
      final delta = parchmentMarkdown.decode(markdown).toDelta();

      expect(delta.elementAt(1).data, 'is ');
      expect(delta.elementAt(1).attributes?['b'], true);

      expect(delta.elementAt(2).data, 'some code');
      expect(delta.elementAt(2).attributes?['b'], true);
      expect(delta.elementAt(2).attributes?['c'], true);
    });

    test('inline code around style', () {
      final markdown = 'This is `**some code**` that works';
      final delta = parchmentMarkdown.decode(markdown).toDelta();

      expect(delta.elementAt(1).data, '**some code**');
      expect(delta.elementAt(1).attributes?['c'], true);
    });

    test('heading styles', () {
      void runFor(String markdown, int level) {
        final document = parchmentMarkdown.decode(markdown);
        final delta = document.toDelta();

        expect(
            delta,
            Delta()
              ..insert('This is an H$level')
              ..insert(
                  '\n', ParchmentAttribute.heading.withValue(level).toJson()));

        final andBack = parchmentMarkdown.encode(document);
        expect(andBack, markdown);
      }

      runFor('# This is an H1\n\n', 1);
      runFor('## This is an H2\n\n', 2);
      runFor('### This is an H3\n\n', 3);
      runFor('#### This is an H4\n\n', 4);
      runFor('##### This is an H5\n\n', 5);
      runFor('###### This is an H6\n\n', 6);
    });

    test('ul', () {
      var markdown = '* a bullet point\n* another bullet point\n\n';
      final act = parchmentMarkdown.decode(markdown).toDelta();
      final exp = Delta()
        ..insert('a bullet point')
        ..insert('\n', {'block': 'ul'})
        ..insert('another bullet point')
        ..insert('\n', {'block': 'ul'});
      expect(act, exp);
    });

    test('ol', () {
      var markdown = '1. Hello\n2. This is a\n3. List\n\n';
      final act = parchmentMarkdown.decode(markdown).toDelta();
      final exp = Delta()
        ..insert('Hello')
        ..insert('\n', {'block': 'ol'})
        ..insert('This is a')
        ..insert('\n', {'block': 'ol'})
        ..insert('List')
        ..insert('\n', {'block': 'ol'});
      expect(act, exp);
    });

    test('ol with indent', () {
      var markdown = '1. Hello\n  1. This is a\n2. List\n\n';
      final act = parchmentMarkdown.decode(markdown).toDelta();
      final exp = Delta()
        ..insert('Hello')
        ..insert('\n', {'block': 'ol'})
        ..insert('This is a')
        ..insert('\n', {'block': 'ol', 'indent': 1})
        ..insert('List')
        ..insert('\n', {'block': 'ol'});
      expect(act, exp);
    });

    test('cl', () {
      var markdown = '- [ ] Hello\n- [X] This is a\n- [ ] Checklist\n\n';
      final act = parchmentMarkdown.decode(markdown).toDelta();
      final exp = Delta()
        ..insert('Hello')
        ..insert('\n', {'block': 'cl'})
        ..insert('This is a')
        ..insert('\n', {'block': 'cl', 'checked': true})
        ..insert('Checklist')
        ..insert('\n', {'block': 'cl'});
      expect(act, exp);
    });

    test('simple bq', () {
      //      var markdown = '> quote\n> > nested\n>#Heading\n>**bold**\n>_italics_\n>* bullet\n>1. 1st point\n>1. 2nd point\n\n';
      var markdown =
          '> quote\n> # Heading in Quote\n> # **Styled** heading in _block quote_\n> **bold text**\n> _text in italics_\n\n';
      final document = parchmentMarkdown.decode(markdown);
      final delta = document.toDelta();

      expect(
        delta,
        Delta()
          ..insert('quote')
          ..insert('\n', ParchmentAttribute.bq.toJson())
          ..insert('Heading in Quote')
          ..insert('\n', {
            ...ParchmentAttribute.bq.toJson(),
            ...ParchmentAttribute.h1.toJson(),
          })
          ..insert('Styled', ParchmentAttribute.bold.toJson())
          ..insert(' heading in ')
          ..insert('block quote', ParchmentAttribute.italic.toJson())
          ..insert('\n', {
            ...ParchmentAttribute.bq.toJson(),
            ...ParchmentAttribute.h1.toJson(),
          })
          ..insert('bold text', ParchmentAttribute.bold.toJson())
          ..insert('\n', ParchmentAttribute.bq.toJson())
          ..insert('text in italics', ParchmentAttribute.italic.toJson())
          ..insert('\n', ParchmentAttribute.bq.toJson()),
      );

      final andBack = parchmentMarkdown.encode(document);
      expect(andBack, markdown);
    });

    test('nested blocks are ignored', () {
      var markdown = '> > nested\n>* bullet\n>1. 1st point\n>2. 2nd point\n\n';
      final delta = parchmentMarkdown.decode(markdown).toDelta();
      final exp = Delta()
        ..insert('> nested')
        ..insert('\n', {'block': 'quote'})
        ..insert('* bullet')
        ..insert('\n', {'block': 'quote'})
        ..insert('1. 1st point')
        ..insert('\n', {'block': 'quote'})
        ..insert('2. 2nd point')
        ..insert('\n', {'block': 'quote'});
      expect(delta, exp);
    });

    test('code in bq', () {
      var markdown = '> ```\n> print("Hello world!")\n> ```\n\n';
      final delta = parchmentMarkdown.decode(markdown).toDelta();
      final exp = Delta()
        ..insert('print("Hello world!")')
        ..insert('\n', {'block': 'code'});
      expect(delta, exp);
    });

    test('multiple styles', () {
      final delta = parchmentMarkdown.decode(markdown);
      final andBack = parchmentMarkdown.encode(delta);
      expect(andBack, markdown);
    });
  });

  group('ParchmentMarkdownCodec.encode', () {
    test('split adjacent paragraphs', () {
      final delta = Delta()..insert('First line\nSecond line\n');
      final result =
          parchmentMarkdown.encode(ParchmentDocument.fromDelta(delta));
      expect(result, 'First line\n\nSecond line\n\n');
    });

    test('bold italic strike though', () {
      void runFor(ParchmentAttribute<bool> attribute, String expected) {
        final delta = Delta()
          ..insert('This ')
          ..insert('house', attribute.toJson())
          ..insert(' is a ')
          ..insert('circus', attribute.toJson())
          ..insert('\n');

        final result =
            parchmentMarkdown.encode(ParchmentDocument.fromDelta(delta));
        expect(result, expected);
      }

      runFor(ParchmentAttribute.bold, 'This **house** is a **circus**\n\n');
      runFor(ParchmentAttribute.italic, 'This _house_ is a _circus_\n\n');
      runFor(ParchmentAttribute.strikethrough,
          'This ~~house~~ is a ~~circus~~\n\n');
    });

    test('intersecting inline styles', () {
      final b = ParchmentAttribute.bold.toJson();
      final i = ParchmentAttribute.italic.toJson();
      final bi = Map<String, dynamic>.from(b);
      bi.addAll(i);

      final delta = Delta()
        ..insert('This ')
        ..insert('house', b)
        ..insert(' is a ', bi)
        ..insert('circus', b)
        ..insert('\n');

      final result =
          parchmentMarkdown.encode(ParchmentDocument.fromDelta(delta));
      expect(result, 'This **house _is a_ circus**\n\n');
    });

    test('normalize inline styles', () {
      final b = ParchmentAttribute.bold.toJson();
      final i = ParchmentAttribute.italic.toJson();
      final delta = Delta()
        ..insert('This')
        ..insert(' house ', b)
        ..insert('is a')
        ..insert(' circus ', i)
        ..insert('\n');

      final result =
          parchmentMarkdown.encode(ParchmentDocument.fromDelta(delta));
      expect(result, 'This **house** is a _circus_ \n\n');
    });

    test('combined inline styles', () {
      final b = ParchmentAttribute.bold.toJson();
      final i = ParchmentAttribute.italic.toJson();
      final delta = Delta()
        ..insert('This')
        ..insert(' house ', b..addAll(i))
        ..insert('is a')
        ..insert(' circus ', i)
        ..insert('\n');

      final result =
          parchmentMarkdown.encode(ParchmentDocument.fromDelta(delta));
      expect(result, 'This **_house_** is a _circus_ \n\n');
    });

    test('links', () {
      final b = ParchmentAttribute.bold.toJson();
      final link = ParchmentAttribute.link.fromString('https://github.com');
      final delta = Delta()
        ..insert('This')
        ..insert(' house ', b)
        ..insert('is a')
        ..insert(' circus ', link.toJson())
        ..insert('\n');

      final result =
          parchmentMarkdown.encode(ParchmentDocument.fromDelta(delta));
      expect(result, 'This **house** is a [circus](https://github.com) \n\n');
    });

    test('heading styles', () {
      void runFor(
          ParchmentAttribute<int> attribute, String source, String expected) {
        final delta = Delta()
          ..insert(source)
          ..insert('\n', attribute.toJson());
        final result =
            parchmentMarkdown.encode(ParchmentDocument.fromDelta(delta));
        expect(result, expected);
      }

      runFor(ParchmentAttribute.h1, 'Title', '# Title\n\n');
      runFor(ParchmentAttribute.h2, 'Title', '## Title\n\n');
      runFor(ParchmentAttribute.h3, 'Title', '### Title\n\n');
      runFor(ParchmentAttribute.h4, 'Title', '#### Title\n\n');
      runFor(ParchmentAttribute.h5, 'Title', '##### Title\n\n');
      runFor(ParchmentAttribute.h6, 'Title', '###### Title\n\n');
    });

    test('block styles', () {
      void runFor(ParchmentAttribute<String> attribute, String source,
          String expected) {
        final delta = Delta()
          ..insert(source)
          ..insert('\n', attribute.toJson());
        final result =
            parchmentMarkdown.encode(ParchmentDocument.fromDelta(delta));
        expect(result, expected);
      }

      runFor(ParchmentAttribute.ul, 'List item', '* List item\n\n');
      runFor(ParchmentAttribute.ol, 'List item', '1. List item\n\n');
      runFor(ParchmentAttribute.bq, 'List item', '> List item\n\n');
      runFor(ParchmentAttribute.code, 'List item', '```\nList item\n```\n\n');
    });

    test('ol', () {
      final delta = Delta()
        ..insert('Hello')
        ..insert('\n', ParchmentAttribute.ol.toJson())
        ..insert('This is a')
        ..insert('\n', ParchmentAttribute.ol.toJson())
        ..insert('List')
        ..insert('\n', ParchmentAttribute.ol.toJson());
      final result =
          parchmentMarkdown.encode(ParchmentDocument.fromDelta(delta));
      final expected = '1. Hello\n2. This is a\n3. List\n\n';
      expect(result, expected);
    });

    test('ol with indent', () {
      final delta = Delta()
        ..insert('Hello')
        ..insert('\n', {'block': 'ol'})
        ..insert('This is a')
        ..insert('\n', {'block': 'ol', 'indent': 1})
        ..insert('List')
        ..insert('\n', {'block': 'ol'});
      final result =
          parchmentMarkdown.encode(ParchmentDocument.fromDelta(delta));
      final expected = '1. Hello\n  1. This is a\n2. List\n\n';
      expect(result, expected);
    });

    test('cl', () {
      final delta = Delta()
        ..insert('Hello')
        ..insert('\n', ParchmentAttribute.cl.toJson())
        ..insert(
          'This is a',
        )
        ..insert('\n', {
          ...ParchmentAttribute.cl.toJson(),
          ...ParchmentAttribute.checked.toJson(),
        })
        ..insert('Checklist')
        ..insert('\n', ParchmentAttribute.cl.toJson());
      final result =
          parchmentMarkdown.encode(ParchmentDocument.fromDelta(delta));
      final expected = '- [ ] Hello\n- [X] This is a\n- [ ] Checklist\n\n';
      expect(result, expected);
    });

    test('multiline blocks', () {
      void runFor(ParchmentAttribute<String> attribute, String source,
          String expected) {
        final delta = Delta()
          ..insert(source)
          ..insert('\n', attribute.toJson())
          ..insert(source)
          ..insert('\n', attribute.toJson());
        final result =
            parchmentMarkdown.encode(ParchmentDocument.fromDelta(delta));
        expect(result, expected);
      }

      runFor(ParchmentAttribute.ul, 'text', '* text\n* text\n\n');
      runFor(ParchmentAttribute.ol, 'text', '1. text\n2. text\n\n');
      runFor(ParchmentAttribute.bq, 'text', '> text\n> text\n\n');
      runFor(ParchmentAttribute.code, 'text', '```\ntext\ntext\n```\n\n');
    });

    test('multiple styles', () {
      final result =
          parchmentMarkdown.encode(ParchmentDocument.fromDelta(delta));
      expect(result, markdown);
    });
  });
}

final doc =
    r'[{"insert":"Fleather"},{"insert":"\n","attributes":{"heading":1}},{"insert":"Soft and gentle rich text editing for Flutter applications.","attributes":{"i":true}},{"insert":"\nFleather is an "},{"insert":"early preview","attributes":{"b":true}},{"insert":" open source library.\n"},{"insert":"That even supports"},{"insert":"\n","attributes":{"block":"cl"}},{"insert":"Checklists"},{"insert":"\n","attributes":{"checked":true,"block":"cl"}},{"insert":"Documentation"},{"insert":"\n","attributes":{"heading":3}},{"insert":"Quick Start"},{"insert":"\n","attributes":{"block":"ul"}},{"insert":"Data format and Document Model"},{"insert":"\n","attributes":{"block":"ul"}},{"insert":"Style attributes"},{"insert":"\n","attributes":{"block":"ul"}},{"insert":"Heuristic rules"},{"insert":"\n","attributes":{"block":"ul"}},{"insert":"Clean and modern look"},{"insert":"\n","attributes":{"heading":2}},{"insert":"Fleather’s rich text editor is built with "},{"insert": "simplicity and flexibility", "attributes":{"i":true}},{"insert":" in mind. It provides clean interface for distraction-free editing. Think "},{"insert": "Medium.com", "attributes":{"c":true}},{"insert": "-like experience.\nimport ‘package:flutter/material.dart’;"},{"insert":"\n","attributes":{"block":"code"}},{"insert":"import ‘package:parchment/parchment.dart’;"},{"insert":"\n\n","attributes":{"block":"code"}},{"insert":"void main() {"},{"insert":"\n","attributes":{"block":"code"}},{"insert":" print(“Hello world!”);"},{"insert":"\n","attributes":{"block":"code"}},{"insert":"}"},{"insert":"\n","attributes":{"block":"code"}}]';
final delta = Delta.fromJson(json.decode(doc) as List);

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
