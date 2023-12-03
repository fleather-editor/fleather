import 'dart:math' as math;

import 'package:fleather/fleather.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:quill_delta/quill_delta.dart';

/// An [AutoFormat] is responsible for looking back for a pattern and apply a
/// formatting suggestion.
///
/// For example, identify a link a automatically wrap it with a link attribute or
/// apply formatting using Markdown shortcuts
abstract class AutoFormat {
  const AutoFormat();

  /// Indicates whether character trigger auto format is kept in document
  ///
  /// E.g: for link detections, '[space]' is kept whereas for Markdown block
  /// shortcuts, the '[space]' is not added to document
  bool get keepTriggerCharacter;

  /// Upon upon insertion of a space or new line run format detection and appy
  /// formatting to document
  /// Returns a [ActiveFormatResult].
  AutoFormatResult? apply(
      ParchmentDocument document, int position, String data);
}

/// Registry for [AutoFormats].
class AutoFormats {
  AutoFormats({required List<AutoFormat> autoFormats})
      : _autoFormats = autoFormats;

  /// Default set of auto formats.
  factory AutoFormats.fallback() {
    return AutoFormats(autoFormats: [
      const _AutoFormatLinks(),
      const _MarkdownShortCuts(),
      const _AutoTextDirection(),
    ]);
  }

  final List<AutoFormat> _autoFormats;

  AutoFormatResult? _activeSuggestion;

  int get undoPosition => _activeSuggestion!.undoPositionCandidate;

  Delta get activeSuggestionChange => _activeSuggestion!.change;

  bool get activeSuggestionKeepTriggerCharacter =>
      _activeSuggestion!.keepTriggerCharacter;

  bool get hasActiveSuggestion => _activeSuggestion != null;

  /// Perform detection of auto formats and apply changes to [document]
  ///
  /// Inserted data must be of type [String]
  TextSelection? run(ParchmentDocument document, int position, Object data) {
    if (data is! String || data.isEmpty) {
      return null;
    }

    for (final autoFormat in _autoFormats) {
      _activeSuggestion = autoFormat.apply(document, position, data);
      if (_activeSuggestion != null) {
        return _activeSuggestion!.selection;
      }
    }
    return null;
  }

  /// Remove auto format from [document] and de-activate current suggestion
  /// It will throw if [_activeSuggestion] is null.
  TextSelection undoActive(ParchmentDocument document) {
    final undoSelection = _activeSuggestion!.undoSelection;
    document.compose(_activeSuggestion!.undo, ChangeSource.local);
    _activeSuggestion = null;
    return undoSelection;
  }

  /// Cancel active auto format
  void cancelActive() {
    _activeSuggestion = null;
  }
}

/// An auto format result
class AutoFormatResult {
  AutoFormatResult({
    required this.selection,
    required this.change,
    required this.undoSelection,
    required this.undo,
    required this.undoPositionCandidate,
    required this.keepTriggerCharacter,
  });

  /// The selection after applying the auto format
  final TextSelection selection;

  /// The change that was applied
  final Delta change;

  /// The selection after undoing the formatting
  final TextSelection undoSelection;

  /// The changes to undo the formatting
  final Delta undo;

  /// The position at which an auto format can be canceled
  final int undoPositionCandidate;

  /// Whether the trigger character will be added to the document after applying
  /// the auto format
  final bool keepTriggerCharacter;
}

class _AutoFormatLinks extends AutoFormat {
  static final _urlRegex =
      RegExp(r'^(.?)((?:https?://|www\.)[^\s/$.?#].[^\s]*)');

  const _AutoFormatLinks();

  @override
  final bool keepTriggerCharacter = true;

  @override
  AutoFormatResult? apply(
      ParchmentDocument document, int position, String data) {
    // This rule applies to a space or newline inserted after a link, so we can ignore
    // everything else.
    if (data != ' ' && data != '\n') return null;

    final documentDelta = document.toDelta();
    final iter = DeltaIterator(documentDelta);
    final previous = iter.skip(position);
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

      final change = Delta()
        ..retain(position - candidate.length)
        ..retain(candidate.length, attributes);
      final undo = change.invert(documentDelta);
      document.compose(change, ChangeSource.local);
      return AutoFormatResult(
          selection: TextSelection.collapsed(offset: position + 1),
          change: change,
          undo: undo,
          undoSelection: TextSelection.collapsed(offset: position),
          keepTriggerCharacter: keepTriggerCharacter,
          undoPositionCandidate: position);
    } on FormatException {
      return null; // Our candidate is not a link.
    }
  }
}

/// Replaces certain Markdown shortcuts with actual line or block styles.
class _MarkdownShortCuts extends AutoFormat {
  static final rules = <String, ParchmentAttribute>{
    '-': ParchmentAttribute.block.bulletList,
    '*': ParchmentAttribute.block.bulletList,
    '1.': ParchmentAttribute.block.numberList,
    '[]': ParchmentAttribute.block.checkList,
    "'''": ParchmentAttribute.block.code,
    '```': ParchmentAttribute.block.code,
    '>': ParchmentAttribute.block.quote,
    '#': ParchmentAttribute.h1,
    '##': ParchmentAttribute.h2,
    '###': ParchmentAttribute.h3,
  };

  const _MarkdownShortCuts();

  @override
  final bool keepTriggerCharacter = false;

  String? _getLinePrefix(DeltaIterator iter, int index) {
    final prefixOps = skipToLineAt(iter, index);
    if (prefixOps.any((element) => element.data is! String)) return null;

    return prefixOps.map((e) => e.data).cast<String>().join();
  }

  (TextSelection, Delta)? _formatLine(
      DeltaIterator iter, int index, String prefix, ParchmentAttribute attr) {
    /// First, delete the shortcut prefix itself.
    final result = Delta()
      ..retain(index - prefix.length)
      ..delete(prefix.length + 1 /* '[space]' has been added */);

    int cursorPosition = index - prefix.length;

    // Scan to the end of line to apply the style attribute.
    while (iter.hasNext) {
      final op = iter.next();
      if (op.data is! String) {
        result.retain(op.length);
        cursorPosition += op.length;
        continue;
      }

      final text = op.data as String;
      // text starts with the inserted '[space]' that trigger the shortcut
      final pos = text.indexOf('\n') - 1;

      if (pos == -1) {
        result.retain(op.length);
        cursorPosition += op.length;
        continue;
      }

      result.retain(pos);
      cursorPosition += pos;

      final attrs = <String, dynamic>{};
      final currentLineAttrs = op.attributes;
      if (currentLineAttrs != null) {
        // the attribute already exists abort
        if (currentLineAttrs[attr.key] == attr.value) return null;
        attrs.addAll(currentLineAttrs);
      }
      attrs.addAll(attr.toJson());

      // cursor should be placed before new line feed
      result.retain(1, attrs);

      break;
    }

    return (TextSelection.collapsed(offset: cursorPosition), result);
  }

  @override
  AutoFormatResult? apply(
      ParchmentDocument document, int position, String data) {
    // Special case: code blocks don't need a `space` to get formatted, we can
    // detect when the user types ``` (or ''') and apply the style immediately.
    if (data == '`' || data == "'") {
      final documentDelta = document.toDelta();
      final iter = DeltaIterator(documentDelta);
      final prefix = _getLinePrefix(iter, position);
      if (prefix == null || prefix.isEmpty) return null;
      final shortcut = '$prefix$data';
      if (shortcut == '```' || shortcut == "'''") {
        final result =
            _formatLine(iter, position, prefix, ParchmentAttribute.code);
        if (result == null) return null;
        final change = result.$2;
        final undo = change.invert(documentDelta);
        document.compose(change, ChangeSource.local);
        return AutoFormatResult(
            selection: result.$1,
            change: change,
            undoSelection:
                TextSelection.collapsed(offset: position + data.length),
            undo: undo,
            keepTriggerCharacter: keepTriggerCharacter,
            undoPositionCandidate: position - prefix.length - 1);
      }
    }

    // Standard case: triggered by a space character after the shortcut.
    if (data != ' ') return null;

    final documentDelta = document.toDelta();
    final iter = DeltaIterator(documentDelta);
    final prefix = _getLinePrefix(iter, position);

    if (prefix == null || prefix.isEmpty) return null;

    final attribute = rules[prefix];
    if (attribute == null) return null;

    final result = _formatLine(iter, position, prefix, attribute);
    if (result == null) return null;
    final change = result.$2;
    final undo = change.invert(documentDelta);
    document.compose(change, ChangeSource.local);
    return AutoFormatResult(
        selection: result.$1,
        change: change,
        // current position is after prefix, so need to add 1 for space
        undoSelection: TextSelection.collapsed(offset: position + 1),
        undo: undo,
        keepTriggerCharacter: keepTriggerCharacter,
        undoPositionCandidate: position - prefix.length - 1);
  }
}

/// Skips to the beginning of line containing position at specified [length]
/// and returns contents of the line skipped so far.
List<Operation> skipToLineAt(DeltaIterator iter, int length) {
  if (length == 0) {
    return List.empty(growable: false);
  }

  final prefix = <Operation>[];

  var skipped = 0;
  while (skipped < length && iter.hasNext) {
    final opLength = iter.peekLength();
    final skip = math.min(length - skipped, opLength);
    final op = iter.next(skip);
    if (op.data is! String) {
      prefix.add(op);
    } else {
      var text = op.data as String;
      var pos = text.lastIndexOf('\n');
      if (pos == -1) {
        prefix.add(op);
      } else {
        prefix.clear();
        prefix.add(Operation.insert(text.substring(pos + 1), op.attributes));
      }
    }
    skipped += op.length;
  }
  return prefix;
}

/// Infers text direction from the input when happens in the beginning of a line.
/// This rule also removes alignment and sets it based on inferred direction.
class _AutoTextDirection extends AutoFormat {
  const _AutoTextDirection();

  final _isRTL = intl.Bidi.startsWithRtl;

  @override
  final bool keepTriggerCharacter = true;

  bool _isAfterEmptyLine(Operation? previous) {
    final data = previous?.data;
    return data == null || (data is String ? data.endsWith('\n') : false);
  }

  bool _isBeforeEmptyLine(Operation next) {
    final data = next.data;
    return data is String ? data.startsWith('\n') : false;
  }

  bool _isInEmptyLine(Operation? previous, Operation next) =>
      _isAfterEmptyLine(previous) && _isBeforeEmptyLine(next);

  @override
  AutoFormatResult? apply(
      ParchmentDocument document, int position, String data) {
    if (data == '\n') return null;
    final documentDelta = document.toDelta();
    final iter = DeltaIterator(document.toDelta());
    final previous = iter.skip(position);
    final next = iter.next();

    if (!_isInEmptyLine(previous, next)) return null;

    final Map<String, dynamic> attributes;
    if (_isRTL(data)) {
      attributes = {
        ...ParchmentAttribute.rtl.toJson(),
        ...ParchmentAttribute.alignment.right.toJson(),
      };
    } else {
      attributes = {
        ...ParchmentAttribute.rtl.unset.toJson(),
        ...ParchmentAttribute.alignment.unset.toJson(),
      };
    }

    final change = Delta()
      ..retain(position)
      ..insert(data)
      ..retain(1, attributes);
    final undo = change.invert(documentDelta);
    return AutoFormatResult(
        selection: TextSelection.collapsed(offset: position + data.length),
        change: change,
        undoSelection: TextSelection.collapsed(offset: position),
        undo: undo,
        keepTriggerCharacter: keepTriggerCharacter,
        undoPositionCandidate: position);
  }
}
