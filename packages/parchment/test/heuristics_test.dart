// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:parchment/parchment.dart';
import 'package:test/test.dart';

ParchmentDocument dartconfDoc() {
  return ParchmentDocument()..insert(0, 'DartConf\nLos Angeles');
}

final ul = ParchmentAttribute.ul.toJson();
final h1 = ParchmentAttribute.h1.toJson();

void main() {
  group('$ParchmentHeuristics', () {
    test('ensures heuristics are applied', () {
      final doc = dartconfDoc();
      final heuristics = ParchmentHeuristics(
        formatRules: [],
        insertRules: [],
        deleteRules: [],
      );

      expect(() {
        heuristics.applyInsertRules(doc, 0, 'a');
      }, throwsStateError);

      expect(() {
        heuristics.applyDeleteRules(doc, 0, 1);
      }, throwsStateError);

      expect(() {
        heuristics.applyFormatRules(doc, 0, 1, ParchmentAttribute.bold);
      }, throwsStateError);
    });
  });
}
