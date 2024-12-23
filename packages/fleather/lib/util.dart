/// Utility functions for Fleather.
library;

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

int _floatToInt8(double x) => (x * 255.0).round() & 0xff;

int colorTo32BitValue(Color color) {
  return _floatToInt8(color.a) << 24 |
      _floatToInt8(color.r) << 16 |
      _floatToInt8(color.g) << 8 |
      _floatToInt8(color.b) << 0;
}
