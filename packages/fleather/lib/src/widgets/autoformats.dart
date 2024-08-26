import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:parchment/parchment.dart';

/// An [AutoFormat] is responsible for looking backwards for a pattern and
/// applying a formatting suggestion to a document.
///
/// For example, identifying a link and automatically wrapping it with a link
/// attribute or applying block formats using Markdown shortcuts
///
/// TODO: adapt to support changes made by a remote source
abstract class AutoFormat {
  const AutoFormat();

  /// Upon insertion of a trigger character, run format detection and apply
  /// formatting to document
  ///
  /// Returns a [AutoFormatResult].
  AutoFormatResult? apply(
      ParchmentDocument document, int position, String data);
}

/// Registry for [AutoFormats].
class AutoFormats {
  AutoFormats({required List<AutoFormat> autoFormats})
      : _autoFormats = autoFormats;

  /// Default set of auto formats.
  ///
  /// Use [additionalFormats] to add your autoformats to the default set.
  factory AutoFormats.fallback([List<AutoFormat>? additionalFormats]) {
    return AutoFormats(autoFormats: [
      const AutoFormatLinks(),
      const MarkdownInlineShortcuts(),
      const MarkdownLineShortcuts(),
      const AutoTextDirection(),
      ...?additionalFormats,
    ]);
  }

  final List<AutoFormat> _autoFormats;

  AutoFormatResult? _activeSuggestion;

  /// The selection override of the active formatting suggestion
  TextSelection? get selection => _activeSuggestion!.selection;

  /// The position at which the active suggestion can be deactivated
  int get undoPosition => _activeSuggestion!.undoPositionCandidate;

  /// `true` if there is an active suggestion; `false` otherwise
  bool get hasActiveSuggestion => _activeSuggestion != null;

  /// `true` if hasActiveSuggestion and undo delta is not empty;
  /// `false` otherwise
  bool get canUndo => hasActiveSuggestion && _activeSuggestion!.undo.isNotEmpty;

  /// Perform detection of auto formats and apply changes to [document].
  ///
  /// Inserted data must be of type [String].
  ///
  /// Returns `true` if auto format was activated; `false` otherwise
  bool run(ParchmentDocument document, int position, Object data) {
    if (data is! String || data.isEmpty) {
      return false;
    }

    for (final autoFormat in _autoFormats) {
      _activeSuggestion = autoFormat.apply(document, position, data);
      if (_activeSuggestion != null) {
        return true;
      }
    }
    return false;
  }

  /// Remove auto format from [document] and de-activate current suggestion.
  ///
  /// This will throw if [_activeSuggestion] is null.
  TextSelection? undoActive(ParchmentDocument document) {
    final undoSelection = _activeSuggestion!.undoSelection;
    document.compose(_activeSuggestion!.undo, ChangeSource.local);
    _activeSuggestion = null;
    return undoSelection;
  }

  /// Cancel active suggestion
  void cancelActive() {
    _activeSuggestion = null;
  }
}

/// The result of a [AutoFormat.apply] that has detected a pattern
class AutoFormatResult {
  AutoFormatResult({
    this.selection,
    required this.change,
    this.undoSelection,
    required this.undo,
    required this.undoPositionCandidate,
  });

  /// *Optional* [TextSelection] after applying the auto format.
  ///
  /// Useful for Markdown shortcuts for example
  final TextSelection? selection;

  /// The change that was applied
  final Delta change;

  /// *Optional* [TextSelection] after undoing the formatting
  ///
  /// Useful for Markdown shortcuts for example
  final TextSelection? undoSelection;

  /// The changes to undo the formatting
  final Delta undo;

  /// The position at which an auto format can be canceled
  final int undoPositionCandidate;
}

class AutoFormatLinks extends AutoFormat {
  static final _urlRegex =
      RegExp(r'^(.?)((?:https?://|www\.)[^\s/$.?#].[^\s]*)');

  const AutoFormatLinks();

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
        change: change, undo: undo, undoPositionCandidate: position);
  }
}

// Replaces certain Markdown shortcuts with actual inline styles.
class MarkdownInlineShortcuts extends AutoFormat {
  static final rules = <String, ParchmentAttribute>{
    '**': ParchmentAttribute.bold,
    '*': ParchmentAttribute.italic,
    '`': ParchmentAttribute.inlineCode,
    '~~': ParchmentAttribute.strikethrough,
  };

  const MarkdownInlineShortcuts();

  @override
  AutoFormatResult? apply(
      ParchmentDocument document, int position, String data) {
    if (data != ' ' && data != '\n') return null;

    final documentDelta = document.toDelta();
    final iter = DeltaIterator(documentDelta);
    final previous = iter.skip(position);
    // No previous operation means nothing to analyze.
    if (previous == null || previous.data is! String) return null;
    final previousText = previous.data as String;
    if (previousText.isEmpty) return null;

    final candidate = previousText.split('\n').last;

    for (final String rule in rules.keys) {
      if (candidate.endsWith(rule)) {
        final lastOffset = candidate.lastIndexOf(rule);
        final startOffset =
            candidate.substring(0, lastOffset).lastIndexOf(rule);
        final contentLength = lastOffset - startOffset - rule.length;
        if (startOffset != -1 && contentLength > 0) {
          final change = Delta()
            ..retain(position - candidate.length + startOffset)
            ..delete(rule.length)
            ..retain(contentLength, {...rules[rule]!.toJson()})
            ..delete(rule.length);
          final undo = change.invert(documentDelta);
          document.compose(change, ChangeSource.local);
          return AutoFormatResult(
            change: change,
            undo: undo,
            undoPositionCandidate: position - (rule.length * 2),
            selection: TextSelection.collapsed(
                offset: position - (rule.length * 2) + 1),
            undoSelection: TextSelection.collapsed(offset: position + 1),
          );
        }
      }
    }

    return null;
  }
}

// Replaces certain Markdown shortcuts with actual line or block styles.
class MarkdownLineShortcuts extends AutoFormat {
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

  const MarkdownLineShortcuts();

  String? _getLinePrefix(DeltaIterator iter, int index) {
    final prefixOps = skipToLineAt(iter, index);
    if (prefixOps.any((element) => element.data is! String)) return null;

    return prefixOps.map((e) => e.data).cast<String>().join();
  }

  // Skips to the beginning of line containing position at specified [length]
  // and returns contents of the line skipped so far.
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

  (TextSelection, Delta)? _formatLine(
      DeltaIterator iter, int index, String prefix, ParchmentAttribute attr) {
    /// First, delete the shortcut prefix itself.
    final result = Delta()
      ..retain(index - prefix.length)
      ..delete(prefix.length + 1 /* '[space]' has been added */);
    // Go after added [space] that triggers shortcut detection
    iter.skip(1);

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
      final pos = text.indexOf('\n');

      if (pos <= -1) {
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
        undoPositionCandidate: position - prefix.length - 1);
  }
}

// Infers text direction from the input when happens in the beginning of a line.
// This rule also removes alignment and sets it based on inferred direction.
class AutoTextDirection extends AutoFormat {
  const AutoTextDirection();

  final _isRTL = intl.Bidi.startsWithRtl;

  bool _isAfterEmptyLine(Operation? previous) {
    final data = previous?.data;
    return data == null || (data is String ? data.endsWith('\n') : false);
  }

  bool _isBeforeEmptyLine(Operation next, String data) {
    final nextData = next.data;
    return nextData is String ? nextData.startsWith('\n') : false;
  }

  bool _isInEmptyLine(Operation? previous, Operation next, String data) =>
      _isAfterEmptyLine(previous) && _isBeforeEmptyLine(next, data);

  @override
  AutoFormatResult? apply(
      ParchmentDocument document, int position, String data) {
    if (data == '\n') return null;
    final documentDelta = document.toDelta();
    final iter = DeltaIterator(document.toDelta());
    final previous = iter.skip(position);
    iter.skip(data.length);
    final next = iter.next();

    if (!_isInEmptyLine(previous, next, data)) return null;

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
      ..retain(position + data.length) //
      ..retain(1, attributes);
    final undo = change.invert(documentDelta);
    document.compose(change, ChangeSource.local);
    return AutoFormatResult(
        change: change, undo: undo, undoPositionCandidate: position);
  }
}
