import 'package:fleather/fleather.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AutoFormats autoformats;

  setUp(() {
    autoformats = AutoFormats.fallback();
  });

  group('Link detection', () {
    test('Detects link with \'http\' and formats accordingly', () {
      final document = ParchmentDocument.fromJson([
        {'insert': 'Some long text and a https://fleather-editor.github.io\n'}
      ]);
      final selection = autoformats.run(document, 54, ' ');
      expect(selection, isNull);
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
      final selection = autoformats.run(document, 35, ' ');
      expect(selection, isNull);
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
      final selection = autoformats.run(document, 54, 'p');
      expect(selection, null);
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
      final selection = autoformats.run(document, 16, ' ');
      expect(selection, const TextSelection.collapsed(offset: 15));
      final attributes = document.toDelta().toList()[1].attributes;
      expect(attributes, isNotNull);
      expect(attributes!.containsKey(ParchmentAttribute.block.key), isTrue);
      expect(attributes[ParchmentAttribute.block.key],
          ParchmentAttribute.block.bulletList.value);
    });

    test('Detects 2 character shortcuts', () {
      final document = ParchmentDocument.fromJson([
        {'insert': 'Some long text\n1. \nthat continues\n'}
      ]);
      final selection = autoformats.run(document, 17, ' ');
      expect(selection, const TextSelection.collapsed(offset: 15));
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
      final selection = autoformats.run(document, 17, '`');
      expect(selection, const TextSelection.collapsed(offset: 15));
      final attributes = document.toDelta().toList()[1].attributes;
      expect(attributes, isNotNull);
      expect(attributes!.containsKey(ParchmentAttribute.block.key), isTrue);
      expect(attributes[ParchmentAttribute.block.key],
          ParchmentAttribute.block.code.value);
    });

    test('No trigger of detection if inserting other than space', () {
      final document = ParchmentDocument.fromJson([
        {'insert': 'Some long text\n* \nthat continues\n'}
      ]);
      final selection = autoformats.run(document, 16, 'p');
      expect(selection, null);
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
    test('Detection of RTL', () {
      final document = ParchmentDocument.fromJson([
        {'insert': 'some ltr text\nש\n'}
      ]);
      final selection = autoformats.run(document, 14, 'ש');
      expect(selection, isNull);
      final attributes = document.toDelta().toList()[1].attributes;
      expect(attributes, isNotNull);
      expect(attributes!.containsKey(ParchmentAttribute.direction.key), isTrue);
      expect(attributes[ParchmentAttribute.direction.key],
          ParchmentAttribute.direction.rtl.value);
    });
  });
}
