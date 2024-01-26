import 'package:flutter/services.dart';
import 'package:parchment_delta/parchment_delta.dart';

/// Encapsulates clipboard data
///
/// One of the properties should be non-null or null should be returned
/// from [FleatherCustomClipboardGetData].
/// When pasting data in editor, [delta] has precedence over [plainText].
class FleatherClipboardData {
  final String? plainText;
  final Delta? delta;

  FleatherClipboardData({this.plainText, this.delta})
      : assert(plainText != null || delta != null);

  bool get hasDelta => delta != null;

  bool get hasPlainText => plainText != null;

  bool get isEmpty => !hasPlainText && !hasDelta;
}

/// An abstract class for getting and setting data to clipboard
abstract class ClipboardManager {
  const ClipboardManager();

  Future<void> setData(FleatherClipboardData data);

  Future<FleatherClipboardData?> getData();
}

/// A [ClipboardManager] which only handles reading and setting
/// of [FleatherClipboardData.plainText] and used by default in editor.
class PlainTextClipboardManager extends ClipboardManager {
  const PlainTextClipboardManager();

  @override
  Future<void> setData(FleatherClipboardData data) async {
    if (data.hasPlainText) {
      await Clipboard.setData(ClipboardData(text: data.plainText!));
    }
  }

  @override
  Future<FleatherClipboardData?> getData() =>
      Clipboard.getData(Clipboard.kTextPlain).then((data) => data?.text != null
          ? FleatherClipboardData(plainText: data!.text!)
          : null);
}

/// Used by [FleatherCustomClipboardManager] to get clipboard data.
///
/// Null should be returned in case clipboard has no data
/// or data is invalid and both [FleatherClipboardData.plainText]
/// and [FleatherClipboardData.delta] are null.
typedef FleatherCustomClipboardGetData = Future<FleatherClipboardData?>
    Function();

/// Used by [FleatherCustomClipboardManager] to set clipboard data.
typedef FleatherCustomClipboardSetData = Future<void> Function(
    FleatherClipboardData data);

/// A [ClipboardManager] which delegates getting and setting data to user and
/// can be used to have rich clipboard.
final class FleatherCustomClipboardManager extends ClipboardManager {
  final FleatherCustomClipboardGetData _getData;
  final FleatherCustomClipboardSetData _setData;

  const FleatherCustomClipboardManager({
    required FleatherCustomClipboardGetData getData,
    required FleatherCustomClipboardSetData setData,
  })  : _getData = getData,
        _setData = setData;

  @override
  Future<void> setData(FleatherClipboardData data) => _setData(data);

  @override
  Future<FleatherClipboardData?> getData() => _getData();
}
