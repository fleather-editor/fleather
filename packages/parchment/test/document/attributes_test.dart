// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:test/test.dart';
import 'package:parchment/parchment.dart';

void main() {
  group('$ParchmentStyle', () {
    test('get', () {
      var attrs = ParchmentStyle.fromJson(<String, dynamic>{'block': 'ul'});
      var attr = attrs.get(ParchmentAttribute.block);
      expect(attr, ParchmentAttribute.ul);
    });

    test('get unset', () {
      var attrs = ParchmentStyle.fromJson(<String, dynamic>{'b': null});
      var attr = attrs.get(ParchmentAttribute.bold);
      expect(attr, ParchmentAttribute.bold.unset);
    });
  });
}
