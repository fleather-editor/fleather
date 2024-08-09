/// Utility functions for Fleather.
library fleather.util;

import 'dart:math' as math;
import 'dart:ui';

import 'package:parchment/parchment.dart';

export 'src/fast_diff.dart';

int getPositionDelta(Delta user, Delta actual) {
  final userIter = DeltaIterator(user);
  final actualIter = DeltaIterator(actual);
  var diff = 0;
  while (userIter.hasNext || actualIter.hasNext) {
    final length = math.min(userIter.peekLength(), actualIter.peekLength());
    final userOp = userIter.next(length);
    final actualOp = actualIter.next(length);
    assert(userOp.length == actualOp.length);
    if (userOp.key == actualOp.key) continue;
    if (userOp.isInsert && actualOp.isRetain) {
      diff -= userOp.length;
    } else if (userOp.isDelete && actualOp.isRetain) {
      diff += userOp.length;
    } else if (userOp.isRetain && actualOp.isInsert) {
      final opText = actualOp.data is String ? actualOp.data as String : '';
      if (opText.startsWith('\n')) {
        // At this point user input reached its end (retain). If a heuristic
        // rule inserts a new line we should keep cursor on it's original position.
        continue;
      }
      diff += actualOp.length;
    } else if (userOp.isRetain && actualOp.isDelete) {
      // User skipped some text which was deleted by a heuristic rule, we
      // should shift the cursor backwards.
      diff -= userOp.length;
    } else {
      // TODO: this likely needs to cover more edge cases.
    }
  }
  return diff;
}

TextDirection getDirectionOfNode(StyledNode node) {
  final direction = node.style.get(ParchmentAttribute.direction);
  if (direction == ParchmentAttribute.rtl) {
    return TextDirection.rtl;
  }
  return TextDirection.ltr;
}

bool isDataOnlyNewLines(Object data) {
  if (data is! String || data.isEmpty) return false;
  return RegExp('^(\n)+\$').hasMatch(data);
}
