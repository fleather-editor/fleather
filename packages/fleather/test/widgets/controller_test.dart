// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:fleather/fleather.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_delta/quill_delta.dart';

void main() {
  group('$FleatherController', () {
    late FleatherController controller;

    setUp(() {
      var doc = ParchmentDocument();
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
      var selection = const TextSelection.collapsed(offset: 5);
      var change = Delta()..insert('Words');
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
      var selection = const TextSelection.collapsed(offset: 5);
      var change = Delta()..insert('Words');
      controller.compose(change, selection: selection);
      var change2 = Delta()..insert('More ');
      controller.compose(change2);
      expect(notified, isTrue);
      var expectedSelection = const TextSelection.collapsed(offset: 10);
      expect(controller.selection, expectedSelection);
      expect(controller.document.toDelta(), Delta()..insert('More Words\n'));
      // expect(controller.lastChangeSource, ChangeSource.remote);
    });

    test('replaceText', () {
      var notified = false;
      controller.addListener(() {
        notified = true;
      });
      var selection = const TextSelection.collapsed(offset: 5);
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
      var selection = const TextSelection(baseOffset: 0, extentOffset: 5);
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
      var selection = const TextSelection.collapsed(offset: 3);
      controller.replaceText(0, 0, 'Words', selection: selection);
      controller.formatText(0, 5, ParchmentAttribute.bold);
      var result = controller.getSelectionStyle();
      expect(result.values, [ParchmentAttribute.bold]);
    });

    test('getSelectionStyle at end of formatted word', () {
      var selection = const TextSelection.collapsed(offset: 5);
      controller.replaceText(0, 0, 'Words in bold', selection: selection);
      controller.formatText(0, 5, ParchmentAttribute.bold);
      var result = controller.getSelectionStyle();
      expect(result.values, [ParchmentAttribute.bold]);
    });

    test('getSelectionStyle with toggled style', () {
      var selection = const TextSelection.collapsed(offset: 3);
      controller.replaceText(0, 0, 'Words', selection: selection);
      controller.formatText(3, 0, ParchmentAttribute.bold);

      var result = controller.getSelectionStyle();
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
  });
}
