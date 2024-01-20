import 'package:flutter/services.dart';
import 'package:quill_delta/quill_delta.dart';

abstract class ClipboardManager {
  const ClipboardManager();

  Future<void> setData(Delta delta);

  Future<Delta?> getData();
}

class PlainTextClipboardManager implements ClipboardManager {
  const PlainTextClipboardManager();

  @override
  Future<void> setData(Delta delta) {
    final plainText =
        delta.toList().map((e) => e.data is String ? e.data : '\uFFFC').join();
    return Clipboard.setData(ClipboardData(text: plainText));
  }

  @override
  Future<Delta?> getData() => Clipboard.getData(Clipboard.kTextPlain)
      .then((data) => data != null ? (Delta()..insert(data.text)) : null);
}
