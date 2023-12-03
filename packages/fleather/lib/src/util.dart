import 'package:quill_delta/quill_delta.dart';

extension DeltaExtension on Delta {
  int get textLength {
    int length = 0;
    toList().forEach((op) {
      if (op.isDelete) {
        length -= op.length;
      } else {
        length += op.length;
      }
    });
    return length;
  }
}
