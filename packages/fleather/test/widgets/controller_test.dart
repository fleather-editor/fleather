import 'package:fake_async/fake_async.dart';
import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('$FleatherController', () {
    late FleatherController controller;

    setUp(() {
      final doc = ParchmentDocument();
      controller = FleatherController(document: doc);
    });

    test('dispose', () {
      controller.dispose();
      expect(controller.document.isClosed, isTrue);
    });

    test('selection', () {
      var notified = false;
      controller.addListener(() {
        notified = true;
      });
      controller.updateSelection(const TextSelection.collapsed(offset: 0));
      expect(notified, isTrue);
      expect(controller.selection, const TextSelection.collapsed(offset: 0));
      // expect(controller.lastChangeSource, ChangeSource.remote);
    });

    test('new selection reset toggled styles', () {
      controller = FleatherController(
          document: ParchmentDocument.fromJson([
        {'insert': 'Some text\n'}
      ]));
      controller.formatText(2, 0, ParchmentAttribute.bold);
      expect(controller.toggledStyles, ParchmentStyle.fromJson({'b': true}));
      controller.updateSelection(const TextSelection.collapsed(offset: 0));
      expect(controller.toggledStyles, ParchmentStyle());
    });

    test('compose', () {
      var notified = false;
      controller.addListener(() {
        notified = true;
      });
      const selection = TextSelection.collapsed(offset: 5);
      final change = Delta()..insert('Words');
      controller.compose(change, selection: selection);
      expect(notified, isTrue);
      expect(controller.selection, selection);
      expect(controller.document.toDelta(), Delta()..insert('Words\n'));
      // expect(controller.lastChangeSource, ChangeSource.remote);
    });

    test('compose and transform position', () {
      var notified = false;
      controller.addListener(() {
        notified = true;
      });
      const selection = TextSelection.collapsed(offset: 5);
      final change = Delta()..insert('Words');
      controller.compose(change, selection: selection);
      final change2 = Delta()..insert('More ');
      controller.compose(change2);
      expect(notified, isTrue);
      const expectedSelection = TextSelection.collapsed(offset: 10);
      expect(controller.selection, expectedSelection);
      expect(controller.document.toDelta(), Delta()..insert('More Words\n'));
      // expect(controller.lastChangeSource, ChangeSource.remote);
    });

    test('replaceText', () {
      var notified = false;
      controller.addListener(() {
        notified = true;
      });
      const selection = TextSelection.collapsed(offset: 5);
      controller.replaceText(0, 0, 'Words', selection: selection);
      expect(notified, isTrue);
      expect(controller.selection, selection);
      expect(controller.document.toDelta(), Delta()..insert('Words\n'));
      // expect(controller.lastChangeSource, ChangeSource.local);
    });

    test('formatText', () {
      var notified = false;
      controller.addListener(() {
        notified = true;
      });
      controller.replaceText(0, 0, 'Words');
      controller.formatText(0, 5, ParchmentAttribute.bold);
      expect(notified, isTrue);
      expect(
        controller.document.toDelta(),
        Delta()
          ..insert('Words', ParchmentAttribute.bold.toJson())
          ..insert('\n'),
      );
      // expect(controller.lastChangeSource, ChangeSource.local);
    });

    test('formatText with toggled style enabled', () {
      var notified = false;
      controller.addListener(() {
        notified = true;
      });
      controller.replaceText(0, 0, 'Words');
      controller.formatText(2, 0, ParchmentAttribute.bold);
      // Test that doing nothing does reset the toggledStyle.
      controller.replaceText(2, 0, '');
      controller.replaceText(2, 0, 'n');
      controller.formatText(3, 0, ParchmentAttribute.bold);
      controller.replaceText(3, 0, 'B');
      expect(notified, isTrue);

      expect(
        controller.document.toDelta(),
        Delta()
          ..insert('Won')
          ..insert('B', ParchmentAttribute.bold.toJson())
          ..insert('rds')
          ..insert('\n'),
      );
      // expect(controller.lastChangeSource, ChangeSource.local);
    });

    test('Toggleable styles', () {
      controller.formatText(0, 0, ParchmentAttribute.bold);
      controller.formatText(0, 0, ParchmentAttribute.italic);
      controller.formatText(0, 0, ParchmentAttribute.underline);
      controller.formatText(0, 0, ParchmentAttribute.strikethrough);
      controller.formatText(0, 0, ParchmentAttribute.inlineCode);
      controller.formatText(0, 0,
          ParchmentAttribute.backgroundColor.withColor(Colors.black.value));
      controller.formatText(0, 0,
          ParchmentAttribute.foregroundColor.withColor(Colors.black.value));
      expect(
          controller.toggledStyles,
          ParchmentStyle.fromJson({
            ...ParchmentAttribute.bold.toJson(),
            ...ParchmentAttribute.italic.toJson(),
            ...ParchmentAttribute.underline.toJson(),
            ...ParchmentAttribute.strikethrough.toJson(),
            ...ParchmentAttribute.inlineCode.toJson(),
            ...ParchmentAttribute.backgroundColor
                .withColor(Colors.black.value)
                .toJson(),
            ...ParchmentAttribute.foregroundColor
                .withColor(Colors.black.value)
                .toJson(),
          }));
    });

    test('replaceText only applies toggled styles to non new line parts', () {
      controller.replaceText(0, 0, 'Words');
      controller.formatText(2, 0, ParchmentAttribute.bold);
      controller.replaceText(2, 0, '\nTest\n');

      expect(
        controller.document.toDelta(),
        Delta()
          ..insert('Wo\n')
          ..insert('Test', ParchmentAttribute.bold.toJson())
          ..insert('\n')
          ..insert('rds')
          ..insert('\n'),
      );
    });

    test('insert text with toggled style unset', () {
      var notified = false;
      controller.addListener(() {
        notified = true;
      });
      controller.replaceText(0, 0, 'Words');
      controller.formatText(1, 0, ParchmentAttribute.bold);
      controller.replaceText(1, 0, 'B');
      controller.formatText(2, 0, ParchmentAttribute.bold.unset);
      controller.replaceText(2, 0, 'u');

      expect(notified, isTrue);
      expect(
        controller.document.toDelta(),
        Delta()
          ..insert('W')
          ..insert('B', ParchmentAttribute.bold.toJson())
          ..insert('uords')
          ..insert('\n'),
      );
      // expect(controller.lastChangeSource, ChangeSource.local);
    });

    test('formatSelection', () {
      var notified = false;
      controller.addListener(() {
        notified = true;
      });
      const selection = TextSelection(baseOffset: 0, extentOffset: 5);
      controller.replaceText(0, 0, 'Words', selection: selection);
      controller.formatSelection(ParchmentAttribute.bold);
      expect(notified, isTrue);
      expect(
        controller.document.toDelta(),
        Delta()
          ..insert('Words', ParchmentAttribute.bold.toJson())
          ..insert('\n'),
      );
      // expect(controller.lastChangeSource, ChangeSource.local);
    });

    test('getSelectionStyle', () {
      const selection = TextSelection.collapsed(offset: 3);
      controller.replaceText(0, 0, 'Words', selection: selection);
      controller.formatText(0, 5, ParchmentAttribute.bold);
      final result = controller.getSelectionStyle();
      expect(result.values, [ParchmentAttribute.bold]);
    });

    test('getSelectionStyle at end of formatted word', () {
      const selection = TextSelection.collapsed(offset: 5);
      controller.replaceText(0, 0, 'Words in bold', selection: selection);
      controller.formatText(0, 5, ParchmentAttribute.bold);
      final result = controller.getSelectionStyle();
      expect(result.values, [ParchmentAttribute.bold]);
    });

    test('getSelectionStyle at start of formatted line', () {
      const selection = TextSelection.collapsed(offset: 8);
      controller.replaceText(0, 0, 'Heading', selection: selection);
      controller.formatText(7, 0, ParchmentAttribute.heading.level1);
      controller.replaceText(7, 0, '\n');
      controller.formatText(8, 0, ParchmentAttribute.heading.unset);
      controller.replaceText(8, 0, 'normal');
      controller.updateSelection(selection);
      final result = controller.getSelectionStyle();
      expect(result.values, []);
    });

    test('getSelectionStyle with toggled style', () {
      const selection = TextSelection.collapsed(offset: 3);
      controller.replaceText(0, 0, 'Words', selection: selection);
      controller.formatText(3, 0, ParchmentAttribute.bold);

      final result = controller.getSelectionStyle();
      expect(result.values, [ParchmentAttribute.bold]);
    });

    test('getSelectionStyle at start of a new line', () {
      controller.replaceText(0, 0, 'Heading');
      controller.formatText(0, 7, ParchmentAttribute.bold);
      controller.replaceText(7, 0, '\n');
      controller.updateSelection(const TextSelection.collapsed(offset: 8));
      final result = controller.getSelectionStyle();
      expect(result.values, []);
    });

    test('preserve inline format when replacing text from the first character',
        () {
      var notified = false;
      controller.addListener(() {
        notified = true;
      });
      controller.formatText(0, 0, ParchmentAttribute.bold);
      controller.replaceText(0, 0, 'Word');
      expect(notified, isTrue);
      expect(
        controller.document.toDelta(),
        Delta()
          ..insert('Word', ParchmentAttribute.bold.toJson())
          ..insert('\n'),
      );
      // expect(controller.lastChangeSource, ChangeSource.local);
    });

    group('clear', () {
      test('closes the document by default', () {
        fakeAsync((async) {
          final doc = controller.document;
          controller.compose(Delta()..insert('word'),
              selection: const TextSelection.collapsed(offset: 4));
          async.flushTimers();
          var notified = false;
          controller.addListener(() => notified = true);
          controller.clear();
          expect(identical(controller.document, doc), isFalse);
          expect(controller.document.toDelta(), Delta()..insert('\n'));
          expect(doc.isClosed, isTrue);
          expect(
              controller.selection, const TextSelection.collapsed(offset: 0));
          expect(controller.canUndo, isFalse);
          expect(controller.canRedo, isFalse);
          expect(controller.toggledStyles, ParchmentStyle());
          expect(notified, isTrue);
        });
      });

      test('closeDocument is false', () {
        fakeAsync((async) {
          final doc = controller.document;
          controller.compose(Delta()..insert('word'),
              selection: const TextSelection.collapsed(offset: 4));
          async.flushTimers();
          var notified = false;
          controller.addListener(() => notified = true);
          controller.clear(closeDocument: false);
          expect(identical(controller.document, doc), isFalse);
          expect(controller.document.toDelta(), Delta()..insert('\n'));
          expect(doc.isClosed, isFalse);
          expect(
              controller.selection, const TextSelection.collapsed(offset: 0));
          expect(controller.canUndo, isFalse);
          expect(controller.canRedo, isFalse);
          expect(controller.toggledStyles, ParchmentStyle());
          expect(notified, isTrue);
        });
      });
    });

    group('history', () {
      group('empty stack', () {
        test('undo returns null', () {
          expect(controller.canUndo, false);
          final expDelta = controller.document.toDelta();
          controller.undo();
          expect(controller.document.toDelta(), expDelta);
        });

        test('redo returns null', () {
          expect(controller.canRedo, false);
          final expDelta = controller.document.toDelta();
          controller.redo();
          expect(controller.document.toDelta(), expDelta);
        });
      });

      test('undoes twice', () {
        fakeAsync((async) {
          controller.compose(Delta()..insert('Hello'));
          async.flushTimers();
          controller.compose(Delta()
            ..retain(5)
            ..insert(' world'));
          async.flushTimers();
          controller.compose(Delta()
            ..retain(11)
            ..insert(' ok'));
          async.flushTimers();
          expect(controller.canUndo, true);
          expect(controller.document.toDelta(),
              Delta()..insert('Hello world ok\n'));
          controller.undo();
          expect(
              controller.document.toDelta(), Delta()..insert('Hello world\n'));
          expect(controller.canUndo, true);
          controller.undo();
          expect(controller.document.toDelta(), Delta()..insert('Hello\n'));
        });
      });

      test('undoes too many times', () {
        fakeAsync((async) {
          controller.compose(Delta()..insert('Hello world'));
          async.flushTimers();
          controller.undo();
          expect(controller.document.toDelta(), Delta()..insert('\n'));
          expect(controller.canUndo, false);
          controller.undo();
          expect(controller.document.toDelta(), Delta()..insert('\n'));
        });
      });
    });

    group('autoformats', () {
      test('Link detection', () {
        const text = 'Some link https://fleather-editor.github.io';
        const selection = TextSelection.collapsed(offset: text.length);
        controller.replaceText(0, 0, text);
        controller.replaceText(text.length, 0, ' ', selection: selection);
        final attributes = controller.document.toDelta().toList()[1].attributes;
        expect(attributes!.containsKey(ParchmentAttribute.link.key), isTrue);
        expect(controller.selection, selection);
      });

      test('History undo of link detection', () {
        fakeAsync((async) {
          const text = 'Some link https://fleather-editor.github.io';
          const selection = TextSelection.collapsed(offset: text.length);
          controller.replaceText(0, 0, text,
              selection:
                  const TextSelection.collapsed(offset: text.length - 1));
          async.flushTimers();
          controller.replaceText(text.length, 0, ' ', selection: selection);
          async.flushTimers();
          controller.undo();
          expect(controller.document.toDelta().length, 1);
          expect(controller.document.toDelta()[0].data,
              'Some link https://fleather-editor.github.io\n');
          expect(controller.document.toDelta()[0].attributes, isNull);
        });
      });

      test('Undo link detection', () {
        const text = 'Some link https://fleather-editor.github.io';
        const selection = TextSelection.collapsed(offset: text.length);
        controller.replaceText(0, 0, text);
        controller.replaceText(text.length, 0, ' ', selection: selection);
        controller.replaceText(text.length, 1, '',
            selection: const TextSelection.collapsed(offset: text.length));
        final documentDelta = controller.document.toDelta();
        expect(documentDelta.length, 1);
        expect(documentDelta.first.attributes, isNull);
      });

      test('De-activate suggestion', () {
        const text = 'Some link https://fleather-editor.github.io';
        const selection = TextSelection.collapsed(offset: text.length);
        controller.replaceText(0, 0, text);
        controller.replaceText(text.length, 0, ' ', selection: selection);
        controller.replaceText(text.length + 1, 0, ' ', selection: selection);
        controller.replaceText(text.length + 1, 1, '',
            selection: const TextSelection.collapsed(offset: text.length + 1));
        controller.replaceText(text.length, 1, '',
            selection: const TextSelection.collapsed(offset: text.length));
        final attributes = controller.document.toDelta().toList()[1].attributes;
        expect(attributes!.containsKey(ParchmentAttribute.link.key), isTrue);
        expect(controller.selection, selection);
      });

      test('No de-activation when receiving non text update', () {
        const text = 'Some link https://fleather-editor.github.io';
        const selection = TextSelection.collapsed(offset: text.length);
        controller.replaceText(0, 0, text);
        controller.replaceText(text.length, 0, ' ', selection: selection);
        controller.replaceText(0, 0, '', selection: selection);
        controller.replaceText(text.length, 1, '',
            selection: const TextSelection.collapsed(offset: text.length));
        final expDelta = Delta()..insert('$text \n');
        expect(controller.document.toDelta(), expDelta);
        expect(controller.selection, selection);
      });

      test('Markdown shortcuts', () {
        const text = 'Some line\n*';
        const selection = TextSelection.collapsed(offset: text.length);
        controller.replaceText(0, 0, '$text\n');
        controller.replaceText(text.length, 0, ' ', selection: selection);
        final attributes = controller.document.toDelta().toList()[1].attributes;
        expect(attributes!.containsKey(ParchmentAttribute.block.key), isTrue);
        expect(attributes[ParchmentAttribute.block.key],
            ParchmentAttribute.block.bulletList.value);
        expect(controller.selection,
            const TextSelection.collapsed(offset: text.length - 1));
      });

      test('Undo markdown shortcuts', () {
        const text = 'Some line\n*';
        const selection = TextSelection.collapsed(offset: text.length);
        controller.replaceText(0, 0, '$text\n');
        controller.replaceText(text.length, 0, ' ', selection: selection);
        controller.replaceText('Some line\n'.length - 1, 1, '',
            selection: const TextSelection.collapsed(offset: text.length));
        final documentDelta = controller.document.toDelta();
        expect(documentDelta.length, 1);
        expect(documentDelta.first.attributes, isNull);
        expect(
            controller.selection,
            const TextSelection.collapsed(
                offset: text.length + 1 /* added space*/));
      });
    });
  });
}
