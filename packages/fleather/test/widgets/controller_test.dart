// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:fleather/fleather.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:quill_delta/quill_delta.dart';

void main() {
  group('$FleatherController', () {
    late FleatherController controller;

    setUp(() {
      final doc = ParchmentDocument();
      controller = FleatherController(doc);
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
      controller = FleatherController(ParchmentDocument.fromJson([
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
  });
}
