import 'package:fleather/fleather.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  late AutoFormats autoformats;

  setUp(() {
    autoformats = AutoFormats.fallback();
    registerFallbackValue(ParchmentDocument());
  });

  test('Can use custom formats with fallbacks', () {
    final document = ParchmentDocument();
    final formats = AutoFormats.fallback([FakeAutoFormat('.')]);
    expect(formats.run(document, 0, '.'), isTrue);
    expect(document.toDelta(), Delta()..insert('Fake\n'));
  });

  group('Link detection', () {
    test('Detects link with \'http\' and formats accordingly', () {
      final document = ParchmentDocument.fromJson([
        {'insert': 'Some long text and a https://fleather-editor.github.io\n'}
      ]);
      final performed = autoformats.run(document, 54, ' ');
      expect(performed, true);
      expect(autoformats.selection, isNull);
      final attributes = document.toDelta().toList()[1].attributes;
      expect(attributes, isNotNull);
      expect(attributes!.containsKey(ParchmentAttribute.link.key), isTrue);
      expect(attributes[ParchmentAttribute.link.key],
          'https://fleather-editor.github.io');
    });

    test('Detects link without \'http\' and formats accordingly', () {
      final document = ParchmentDocument.fromJson([
        {'insert': 'Some long text and a www.github.com\n'}
      ]);
      final performed = autoformats.run(document, 35, ' ');
      expect(performed, isTrue);
      expect(autoformats.selection, isNull);
      final attributes = document.toDelta().toList()[1].attributes;
      expect(attributes, isNotNull);
      expect(attributes!.containsKey(ParchmentAttribute.link.key), isTrue);
      // add https when missing
      expect(attributes[ParchmentAttribute.link.key], 'https://www.github.com');
      expect(autoformats.undoPosition, 35);
    });

    test('No trigger of detection if inserting other than space', () {
      final document = ParchmentDocument.fromJson([
        {'insert': 'Some long text and a https://fleather-editor.github.io\n'}
      ]);
      final performed = autoformats.run(document, 54, 'p');
      expect(performed, false);
      expect(autoformats.hasActiveSuggestion, isFalse);
    });

    test('Deleting at candidate position, undoes link formatting', () {
      const text = 'Some long text and a https://fleather-editor.github.io\n';
      final document = ParchmentDocument.fromJson([
        {'insert': text}
      ]);
      autoformats.run(document, 54, ' ');
      final undoSelection = autoformats.undoActive(document);
      expect(undoSelection, isNull);
      expect(document.toDelta().length, 1);
      expect(document.toDelta().first.isInsert, isTrue);
      expect(document.toDelta().first.data, text);
    });

    test('Cancels suggestion', () {
      final document = ParchmentDocument.fromJson([
        {'insert': 'Some long text and a https://fleather-editor.github.io\n'}
      ]);
      autoformats.run(document, 54, ' ');
      autoformats.cancelActive();
      expect(autoformats.hasActiveSuggestion, isFalse);
    });
  });

  group('Markdown shortcuts', () {
    test('Detects single character shortcuts', () {
      final document = ParchmentDocument.fromJson([
        {'insert': 'Some long text\n* \nthat continues\n'}
      ]);
      final performed = autoformats.run(document, 16, ' ');
      expect(performed, true);
      expect(autoformats.selection, const TextSelection.collapsed(offset: 15));
      final attributes = document.toDelta().toList()[1].attributes;
      expect(attributes, isNotNull);
      expect(attributes!.containsKey(ParchmentAttribute.block.key), isTrue);
      expect(attributes[ParchmentAttribute.block.key],
          ParchmentAttribute.block.bulletList.value);
    });

    test('Detects single character shortcuts before embed', () {
      final document = ParchmentDocument.fromJson([
        {'insert': 'Some long text\n* '},
        {
          'insert': SpanEmbed('some', data: {'ok': 'ok'}).toJson()
        },
        {'insert': '\nthat continues\n'}
      ]);
      final performed = autoformats.run(document, 16, ' ');
      expect(performed, true);
      expect(autoformats.selection, const TextSelection.collapsed(offset: 16));
      final attributes = document.toDelta().toList()[2].attributes;
      expect(attributes, isNotNull);
      expect(attributes!.containsKey(ParchmentAttribute.block.key), isTrue);
      expect(attributes[ParchmentAttribute.block.key],
          ParchmentAttribute.block.bulletList.value);
    });

    test('Detects 2 character shortcuts', () {
      final document = ParchmentDocument.fromJson([
        {'insert': 'Some long text\n1. \nthat continues\n'}
      ]);
      final performed = autoformats.run(document, 17, ' ');
      expect(performed, true);
      expect(autoformats.selection, const TextSelection.collapsed(offset: 15));
      final attributes = document.toDelta().toList()[1].attributes;
      expect(attributes, isNotNull);
      expect(attributes!.containsKey(ParchmentAttribute.block.key), isTrue);
      expect(attributes[ParchmentAttribute.block.key],
          ParchmentAttribute.block.numberList.value);
    });

    test('Detects 3 character shortcuts', () {
      final document = ParchmentDocument.fromJson([
        {'insert': 'Some long text\n```\nthat continues\n'}
      ]);
      final performed = autoformats.run(document, 17, '`');
      expect(performed, true);
      expect(autoformats.selection, const TextSelection.collapsed(offset: 15));
      final attributes = document.toDelta().toList()[1].attributes;
      expect(attributes, isNotNull);
      expect(attributes!.containsKey(ParchmentAttribute.block.key), isTrue);
      expect(attributes[ParchmentAttribute.block.key],
          ParchmentAttribute.block.code.value);
    });

    test('Detects italic shortcut', () {
      final document = ParchmentDocument.fromJson([
        {'insert': 'Some long text\n**Test*that continues\n'}
      ]);
      final performed = autoformats.run(document, 22, ' ');
      expect(performed, isTrue);
      expect(autoformats.selection, const TextSelection.collapsed(offset: 21));
      final attributes = document.toDelta().toList()[1].attributes;
      expect(attributes![ParchmentAttribute.italic.key], isTrue);
    });

    test('Detects bold shortcut', () {
      final document = ParchmentDocument.fromJson([
        {'insert': 'Some long text\n**Test**that continues\n'}
      ]);
      final performed = autoformats.run(document, 23, ' ');
      expect(performed, isTrue);
      expect(autoformats.selection, const TextSelection.collapsed(offset: 20));
      final attributes = document.toDelta().toList()[1].attributes;
      expect(attributes![ParchmentAttribute.bold.key], isTrue);
    });

    test('Detects inline code shortcut', () {
      const text = 'Some long text\n`Test`that continues\n';
      final document = ParchmentDocument.fromJson([
        {'insert': text}
      ]);
      final performed = autoformats.run(document, 21, ' ');
      expect(performed, isTrue);
      expect(autoformats.selection, const TextSelection.collapsed(offset: 20));
      final attributes = document.toDelta().toList()[1].attributes;
      expect(attributes![ParchmentAttribute.inlineCode.key], isTrue);
      final undoSelection = autoformats.undoActive(document);
      expect(undoSelection, const TextSelection.collapsed(offset: 22));
      expect(document.toDelta().first.data, text);
    });

    test('Detects strikethrough shortcut', () {
      const text = 'Some long text\n~~Test~~that continues\n';
      final document = ParchmentDocument.fromJson([
        {'insert': text}
      ]);
      final performed = autoformats.run(document, 23, '\n');
      expect(performed, isTrue);
      expect(autoformats.selection, const TextSelection.collapsed(offset: 20));
      final attributes = document.toDelta().toList()[1].attributes;
      expect(attributes![ParchmentAttribute.strikethrough.key], isTrue);
      final undoSelection = autoformats.undoActive(document);
      expect(undoSelection, const TextSelection.collapsed(offset: 24));
      expect(document.toDelta().first.data, text);
    });

    test('No trigger of detection if inserting other than space', () {
      final document = ParchmentDocument.fromJson([
        {'insert': 'Some long text\n* \nthat continues\n'}
      ]);
      final performed = autoformats.run(document, 16, 'p');
      expect(performed, false);
      expect(autoformats.hasActiveSuggestion, isFalse);
    });

    test('Deleting at candidate position, undoes link formatting', () {
      const text = 'Some long text\n* \nthat continues\n';
      final document = ParchmentDocument.fromJson([
        {'insert': text}
      ]);
      autoformats.run(document, 16, ' ');
      final undoSelection = autoformats.undoActive(document);
      expect(undoSelection, const TextSelection.collapsed(offset: 17));
      expect(document.toDelta().length, 1);
      expect(document.toDelta().first.isInsert, isTrue);
      expect(document.toDelta().first.data, text);
    });

    test('Cancels suggestion', () {
      final document = ParchmentDocument.fromJson([
        {'insert': 'Some long text\n* \nthat continues\n'}
      ]);
      autoformats.run(document, 54, ' ');
      autoformats.cancelActive();
      expect(autoformats.hasActiveSuggestion, isFalse);
    });
  });

  group('RTL detection', () {
    test('Detects RTL text when applied with no line style', () {
      final document = ParchmentDocument.fromJson([
        {'insert': 'some ltr text\nب\n'},
      ]);
      final performed = autoformats.run(document, 14, 'ب');
      expect(performed, true);
      expect(autoformats.selection, isNull);
      final attributes = document.toDelta().toList()[1].attributes;
      expect(attributes, isNotNull);
      expect(attributes!.containsKey(ParchmentAttribute.direction.key), isTrue);
      expect(attributes[ParchmentAttribute.direction.key],
          ParchmentAttribute.direction.rtl.value);
    });

    test('Detects RTL text when applied on an already styled line', () {
      final document = ParchmentDocument.fromJson([
        {'insert': 'some ltr text\nب'},
        {
          'insert': '\n',
          'attributes': {'checked': true}
        }
      ]);
      final performed = autoformats.run(document, 14, 'ب');
      expect(performed, true);
      expect(autoformats.selection, isNull);
      final attributes = document.toDelta().toList()[1].attributes;
      expect(attributes, isNotNull);
      expect(attributes!.containsKey(ParchmentAttribute.direction.key), isTrue);
      expect(attributes[ParchmentAttribute.direction.key],
          ParchmentAttribute.direction.rtl.value);
      expect(autoformats.canUndo, isTrue);
    });

    test('canUndo is false when line was already correctly styled', () {
      final document = ParchmentDocument.fromJson([
        {'insert': 'some ltr text\nب'},
        {
          'insert': '\n',
          'attributes': {'direction': 'rtl', 'alignment': 'right'}
        }
      ]);
      final performed = autoformats.run(document, 14, 'ب');
      expect(performed, true);
      expect(autoformats.selection, isNull);
      expect(autoformats.canUndo, isFalse);
    });
  });
}

class FakeAutoFormat extends AutoFormat {
  final String trigger;

  FakeAutoFormat(this.trigger);

  @override
  AutoFormatResult? apply(
      ParchmentDocument document, int position, String data) {
    if (data == trigger) {
      final change = Delta()
        ..retain(position)
        ..insert('Fake');
      document.compose(change, ChangeSource.local);
      return AutoFormatResult(
        change: change,
        undo: Delta()
          ..retain(position)
          ..delete(4),
        undoPositionCandidate: position,
      );
    }
    return null;
  }
}
