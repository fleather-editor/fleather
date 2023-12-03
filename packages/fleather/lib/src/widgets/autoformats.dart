import 'package:fleather/fleather.dart';
import 'package:quill_delta/quill_delta.dart';

/// An [AutoFormat] is responsible for looking back for a pattern and apply a
/// formatting suggestion.
///
/// For example, identify a link a automatically wrap it with a link attribute or
/// apply formatting using Markdown shortcuts
abstract class AutoFormat {
  const AutoFormat();

  /// Upon upon insertion of a space or new line run format detection
  /// Returns a [Delta] with the resulting change to apply to th document
  Delta? apply(Delta document, int position, String data);
}

/// Registry for [AutoFormats].
class AutoFormats {
  AutoFormats({required List<AutoFormat> autoFormats})
      : _autoFormats = autoFormats;

  /// Default set of autoformats.
  factory AutoFormats.fallback() {
    return AutoFormats(autoFormats: [const _AutoFormatLinks()]);
  }

  final List<AutoFormat> _autoFormats;

  Delta? get activeSuggestion => _activeSuggestion;
  Delta? _activeSuggestion;
  Delta? _undoActiveSuggestion;

  bool get hasActiveSuggestion => _activeSuggestion != null;

  /// Perform detection of auto formats and apply changes to [document]
  ///
  /// Inserted data must be of type [String]
  void run(ParchmentDocument document, int position, Object data) {
    if (data is! String || data.isEmpty) return;

    Delta documentDelta = document.toDelta();
    for (final autoFormat in _autoFormats) {
      _activeSuggestion = autoFormat.apply(documentDelta, position, data)
        ?..trim();
      if (_activeSuggestion != null) {
        _undoActiveSuggestion = _activeSuggestion!.invert(documentDelta);
        document.compose(_activeSuggestion!, ChangeSource.local);
        return;
      }
    }
  }

  /// Remove auto format from [document] and de-activate current suggestion
  void undoActive(ParchmentDocument document) {
    if (_activeSuggestion == null) return;
    document.compose(_undoActiveSuggestion!, ChangeSource.local);
    _undoActiveSuggestion = null;
    _activeSuggestion = null;
  }

  /// Cancel active auto format
  void cancelActive() {
    _undoActiveSuggestion = null;
    _activeSuggestion = null;
  }
}

class _AutoFormatLinks extends AutoFormat {
  static final _urlRegex =
      RegExp(r'^(.?)((?:https?:\/\/|www\.)[^\s/$.?#].[^\s]*)');
  const _AutoFormatLinks();

  @override
  Delta? apply(Delta document, int index, String data) {
    // This rule applies to a space or newline inserted after a link, so we can ignore
    // everything else.
    if (data != ' ' && data != '\n') return null;

    final iter = DeltaIterator(document);
    final previous = iter.skip(index);
    // No previous operation means nothing to analyze.
    if (previous == null || previous.data is! String) return null;
    final previousText = previous.data as String;

    // Split text of previous operation in lines and words and take the last
    // word to test.
    final candidate = previousText.split('\n').last.split(' ').last;
    try {
      final match = _urlRegex.firstMatch(candidate);
      if (match == null) return null;

      final attributes = previous.attributes ?? <String, dynamic>{};

      // Do nothing if already formatted as link.
      if (attributes.containsKey(ParchmentAttribute.link.key)) return null;

      String url = candidate;
      if (!url.startsWith('http')) url = 'https://$url';
      attributes
          .addAll(ParchmentAttribute.link.fromString(url.toString()).toJson());

      return Delta()
        ..retain(index - candidate.length)
        ..retain(candidate.length, attributes);
    } on FormatException {
      return null; // Our candidate is not a link.
    }
  }
}
