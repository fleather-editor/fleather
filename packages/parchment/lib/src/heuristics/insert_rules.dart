// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:intl/intl.dart' as intl;
import 'package:quill_delta/quill_delta.dart';

import '../document/attributes.dart';
import 'utils.dart';

/// The result of [_findNextNewline] function.
class _FindResult {
  /// The operation containing a newline character, can be null.
  final Operation? op;

  /// Total length of skipped characters before [op].
  final int? skippedLength;

  _FindResult(this.op, this.skippedLength);

  /// If true then no operation containing newline was found.
  bool get isEmpty => op == null;

  /// If false then no operation containing newline was found.
  bool get isNotEmpty => op != null;
}

/// Finds closest operation containing a newline character from current
/// position of [iterator].
_FindResult _findNextNewline(DeltaIterator iterator) {
  var skipped = 0;
  while (iterator.hasNext) {
    final op = iterator.next();
    final opText = op.data is String ? op.data as String : '';
    final lf = opText.indexOf('\n');
    if (lf >= 0) {
      return _FindResult(op, skipped);
    } else {
      skipped += op.length;
    }
  }
  return _FindResult(null, null);
}

/// A heuristic rule for insert operations.
abstract class InsertRule {
  /// Constant constructor allows subclasses to declare constant constructors.
  const InsertRule();

  /// Applies heuristic rule to an insert operation on a [document] and returns
  /// resulting [Delta].
  Delta? apply(Delta document, int index, Object data);
}

/// Fallback rule which simply inserts text as-is without any special handling.
class CatchAllInsertRule extends InsertRule {
  const CatchAllInsertRule();

  @override
  Delta apply(Delta document, int index, Object data) {
    return Delta()
      ..retain(index)
      ..insert(data);
  }
}

/// Preserves line format when user splits the line into two.
///
/// This rule ignores scenarios when the line is split on its edge, meaning
/// a newline is inserted at the beginning or the end of a line.
class PreserveLineStyleOnSplitRule extends InsertRule {
  const PreserveLineStyleOnSplitRule();

  bool isEdgeLineSplit(Operation? before, Operation after) {
    if (before == null) return true; // split at the beginning of a doc
    final textBefore = before.data is String ? before.data as String : '';
    final textAfter = after.data is String ? after.data as String : '';
    return textBefore.endsWith('\n') || textAfter.startsWith('\n');
  }

  @override
  Delta? apply(Delta document, int index, Object data) {
    if (data is! String) return null;

    if (data != '\n') return null;

    final iter = DeltaIterator(document);
    final before = iter.skip(index);
    final after = iter.next();
    if (isEdgeLineSplit(before, after)) return null;

    final result = Delta()..retain(index);
    if (after.data is! String) {
      result.insert('\n');
      return result;
    }

    final textAfter = after.data as String;
    if (textAfter.contains('\n')) {
      // It is not allowed to combine line and inline styles in insert
      // operation containing newline together with other characters.
      // The only scenario we get such operation is when the text is plain.
      assert(after.isPlain);
      // No attributes to apply so we simply create a new line.
      result.insert('\n');
      return result;
    }
    // Continue looking for a newline.
    final nextNewline = _findNextNewline(iter);
    final attributes = nextNewline.op?.attributes;

    return result..insert('\n', attributes);
  }
}

/// Resets format for a newly inserted line when insert occurred at the end
/// of a line (right before a newline).
///
/// This handles scenarios when a new line is added when at the end of a
/// heading line. The newly added line should be a regular paragraph.
class ResetLineFormatOnNewLineRule extends InsertRule {
  const ResetLineFormatOnNewLineRule();

  @override
  Delta? apply(Delta document, int index, Object data) {
    if (data is! String) return null;

    if (data != '\n') return null;

    final iter = DeltaIterator(document);
    iter.skip(index);
    final target = iter.next();

    // We have an embed right after us, ignore (embeds handled by a different rule).
    if (target.data is! String) return null;

    final targetText = target.data as String;

    if (targetText.startsWith('\n')) {
      if (target.attributes != null &&
          target.attributes!.containsKey(ParchmentAttribute.heading.key)) {
        final resetStyle = ParchmentAttribute.heading.unset.toJson();
        return Delta()
          ..retain(index)
          ..insert('\n', target.attributes)
          ..retain(1, resetStyle)
          ..trim();
      } else {
        // Nothing needs to be reset
        return null;
      }
    }
    return null;
  }
}

/// Heuristic rule to exit current block when user inserts two consecutive
/// newlines.
///
/// This rule is only applied when the cursor is on the last line of a block.
/// When the cursor is in the middle of a block we allow adding empty lines
/// and preserving the block's style.
class AutoExitBlockRule extends InsertRule {
  const AutoExitBlockRule();

  bool isEmptyLine(Operation? before, Operation after) {
    final textBefore = before?.data is String ? before!.data as String : '';
    final textAfter = after.data is String ? after.data as String : '';
    return (before == null || textBefore.endsWith('\n')) &&
        textAfter.startsWith('\n');
  }

  @override
  Delta? apply(Delta document, int index, Object data) {
    if (data is! String) return null;

    if (data != '\n') return null;

    final iter = DeltaIterator(document);
    final previous = iter.skip(index);
    final target = iter.next();
    final isInBlock = target.isNotPlain &&
        target.attributes!.containsKey(ParchmentAttribute.block.key);

    // We are not in a block, ignore.
    if (!isInBlock) return null;
    // We are not on an empty line, ignore.
    if (!isEmptyLine(previous, target)) return null;

    final blockStyle = target.attributes![ParchmentAttribute.block.key];

    // We are on an empty line. Now we need to determine if we are on the
    // last line of a block.
    // First check if `target` length is greater than 1, this would indicate
    // that it contains multiple newline characters which share the same style.
    // This would mean we are not on the last line yet.
    final targetText = target.value
        as String; // this is safe since we already called isEmptyLine and know it contains a newline

    if (targetText.length > 1) {
      // We are not on the last line of this block, ignore.
      return null;
    }

    // Keep looking for the next newline character to see if it shares the same
    // block style as `target`.
    final nextNewline = _findNextNewline(iter);
    if (nextNewline.isNotEmpty &&
        nextNewline.op!.attributes != null &&
        nextNewline.op!.attributes![ParchmentAttribute.block.key] ==
            blockStyle) {
      // We are not at the end of this block, ignore.
      return null;
    }

    // Here we now know that the line after `target` is not in the same block
    // therefore we can exit this block.
    final attributes = target.attributes ?? <String, dynamic>{};
    attributes.addAll(ParchmentAttribute.block.unset.toJson());
    return Delta()
      ..retain(index)
      ..retain(1, attributes);
  }
}

/// Preserves inline styles when user inserts text inside formatted segment.
class PreserveInlineStylesRule extends InsertRule {
  const PreserveInlineStylesRule();

  @override
  Delta? apply(Delta document, int index, Object data) {
    // There is no other text around embeds so no inline styles to preserve.
    if (data is! String) return null;

    // This rule is only applicable to characters other than newline.
    if (data.contains('\n')) return null;

    final iter = DeltaIterator(document);
    final previous = iter.skip(index);
    // If there is a newline in previous chunk, there should be no inline
    // styles. Also if there is no previous operation we are at the beginning
    // of the document so no styles to inherit from.
    if (previous == null) return null;
    final previousText = previous.data is String ? previous.data as String : '';
    if (previousText.contains('\n')) return null;

    final attributes = previous.attributes;
    final hasLink = (attributes != null &&
        attributes.containsKey(ParchmentAttribute.link.key));
    if (!hasLink) {
      return Delta()
        ..retain(index)
        ..insert(data, attributes);
    }
    // Special handling needed for inserts inside fragments with link attribute.
    // Link style should only be preserved if insert occurs inside the fragment.
    // Link style should NOT be preserved on the boundaries.
    var noLinkAttributes = previous.attributes!;
    noLinkAttributes.remove(ParchmentAttribute.link.key);
    final noLinkResult = Delta()
      ..retain(index)
      ..insert(data, noLinkAttributes.isEmpty ? null : noLinkAttributes);
    final next = iter.next();
    final nextAttributes = next.attributes ?? const <String, dynamic>{};
    if (!nextAttributes.containsKey(ParchmentAttribute.link.key)) {
      // Next fragment is not styled as link.
      return noLinkResult;
    }
    // We must make sure links are identical in previous and next operations.
    // ignore: unnecessary_non_null_assertion
    if (attributes![ParchmentAttribute.link.key] ==
        nextAttributes[ParchmentAttribute.link.key]) {
      return Delta()
        ..retain(index)
        ..insert(data, attributes);
    } else {
      return noLinkResult;
    }
  }
}

/// Applies link format to text segment (which looks like a link) when user
/// inserts space character after it.
class AutoFormatLinksRule extends InsertRule {
  const AutoFormatLinksRule();

  static Delta? formatLink(Delta document, int index, Object data) {
    if (data is! String) return null;

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
      final link = Uri.parse(candidate);
      if (!['https', 'http'].contains(link.scheme)) {
        // TODO: might need a more robust way of validating links here.
        return null;
      }
      final attributes = previous.attributes ?? <String, dynamic>{};

      // Do nothing if already formatted as link.
      if (attributes.containsKey(ParchmentAttribute.link.key)) return null;

      attributes
          .addAll(ParchmentAttribute.link.fromString(link.toString()).toJson());
      return Delta()
        ..retain(index - candidate.length)
        ..retain(candidate.length, attributes);
    } on FormatException {
      return null; // Our candidate is not a link.
    }
  }

  @override
  Delta? apply(Delta document, int index, Object data) {
    final delta = formatLink(document, index, data);
    if (delta == null) {
      return null;
    }

    final iter = DeltaIterator(document);
    final previous = iter.skip(index);
    return delta..insert(data, previous?.attributes);
  }
}

/// Forces text inserted on the same line with a block embed (before or after it)
/// to be moved to a new line adjacent to the original line.
///
/// This rule assumes that a line is only allowed to have single block embed child.
class ForceNewlineForInsertsAroundBlockEmbedRule extends InsertRule {
  const ForceNewlineForInsertsAroundBlockEmbedRule();

  @override
  Delta? apply(Delta document, int index, Object data) {
    if (data is! String) return null;

    final iter = DeltaIterator(document);
    final previous = iter.skip(index);
    final target = iter.next();
    final cursorBeforeBlockEmbed = isBlockEmbed(target.data);
    final cursorAfterBlockEmbed =
        previous != null && isBlockEmbed(previous.data);

    if (cursorBeforeBlockEmbed || cursorAfterBlockEmbed) {
      final delta = Delta()..retain(index);
      if (cursorBeforeBlockEmbed && !data.endsWith('\n')) {
        return delta
          ..insert(data)
          ..insert('\n');
      }
      if (cursorAfterBlockEmbed && !data.startsWith('\n')) {
        return delta
          ..insert('\n')
          ..insert(data);
      }
      return delta..insert(data);
    }
    return null;
  }
}

/// Preserves block style when user inserts text containing newlines.
///
/// This rule handles:
///
///   * inserting a new line in a block
///   * pasting text containing multiple lines of text in a block
///
/// This rule may also be activated for changes triggered by auto-correct.
class PreserveBlockStyleOnInsertRule extends InsertRule {
  const PreserveBlockStyleOnInsertRule();

  bool isEdgeLineSplit(Operation? before, Operation after) {
    if (before == null) return true; // split at the beginning of a doc
    final textBefore = before.data is String ? before.data as String : '';
    final textAfter = after.data is String ? after.data as String : '';
    return textBefore.endsWith('\n') || textAfter.startsWith('\n');
  }

  @override
  Delta? apply(Delta document, int index, Object data) {
    // Embeds are handled by a different rule.
    if (data is! String) return null;

    if (!data.contains('\n')) {
      // Only interested in text containing at least one newline character.
      return null;
    }

    final iter = DeltaIterator(document);
    iter.skip(index);

    // Look for the next newline.
    final nextNewline = _findNextNewline(iter);
    final lineStyle = nextNewline.op?.attributes ?? <String, dynamic>{};

    // Are we currently in a block? If not then ignore.
    if (!lineStyle.containsKey(ParchmentAttribute.block.key)) return null;

    final blockStyle = <String, dynamic>{
      ParchmentAttribute.block.key: lineStyle[ParchmentAttribute.block.key]
    };

    Map<String, dynamic> resetStyle = {};
    // If current line had heading style applied to it we'll need to move this
    // style to the newly inserted line before it and reset style of the
    // original line.
    if (lineStyle.containsKey(ParchmentAttribute.heading.key)) {
      resetStyle.addAll(ParchmentAttribute.heading.unset.toJson());
    }

    // Similarly for the checked style
    if (lineStyle.containsKey(ParchmentAttribute.checked.key)) {
      resetStyle.addAll(ParchmentAttribute.checked.unset.toJson());
    }

    // Go over each inserted line and ensure block style is applied.
    final lines = data.split('\n');

    // Try to format link after hitting newline
    final linkDelta = AutoFormatLinksRule.formatLink(document, index, data);
    final result = linkDelta ?? (Delta()..retain(index));

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isNotEmpty) {
        result.insert(line);
      }
      if (i == 0) {
        // The first line should inherit the lineStyle entirely.
        result.insert('\n', lineStyle);
      } else if (i < lines.length - 1) {
        // we don't want to insert a newline after the last chunk of text, so -1
        result.insert('\n', blockStyle);
      }
    }

    // Reset style of the original newline character if needed.
    if (resetStyle.isNotEmpty) {
      result.retain(nextNewline.skippedLength!);
      final opText = nextNewline.op!.data as String;
      final lf = opText.indexOf('\n');
      result
        ..retain(lf)
        ..retain(1, resetStyle);
    }

    return result;
  }
}

/// Handles all format operations which manipulate block embeds.
class InsertBlockEmbedsRule extends InsertRule {
  const InsertBlockEmbedsRule();

  @override
  Delta? apply(Delta document, int index, Object data) {
    // We are only interested in block embeddable objects.
    if (data is String || !isBlockEmbed(data)) return null;

    final result = Delta()..retain(index);
    final iter = DeltaIterator(document);
    final previous = iter.skip(index);
    final target = iter.next();

    // Check if [index] is on an empty line already.
    final textBefore = previous?.data is String ? previous!.data as String : '';
    final textAfter = target.data is String ? target.data as String : '';

    final isNewlineBefore = previous == null || textBefore.endsWith('\n');
    final isNewlineAfter = textAfter.startsWith('\n');
    final isOnEmptyLine = isNewlineBefore && isNewlineAfter;

    if (isOnEmptyLine) {
      return result..insert(data);
    }
    // We are on a non-empty line, split it (preserving style if needed)
    // and insert our embed.
    final lineStyle = _getLineStyle(iter, target);
    if (!isNewlineBefore) {
      result.insert('\n', lineStyle);
    }
    result.insert(data);
    if (!isNewlineAfter) {
      result.insert('\n');
    }
    return result;
  }

  Map<String, dynamic>? _getLineStyle(
      DeltaIterator iterator, Operation current) {
    final currentText = current.data is String ? current.data as String : '';

    if (currentText.contains('\n')) {
      return current.attributes;
    }
    // Continue looking for a newline.
    Map<String, dynamic>? attributes;
    while (iterator.hasNext) {
      final op = iterator.next();
      final opText = op.data is String ? op.data as String : '';
      final lf = opText.indexOf('\n');
      if (lf >= 0) {
        attributes = op.attributes;
        break;
      }
    }
    return attributes;
  }
}

/// Replaces certain Markdown shortcuts with actual line or block styles.
class MarkdownBlockShortcutsInsertRule extends InsertRule {
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

  const MarkdownBlockShortcutsInsertRule();

  String? _getLinePrefix(DeltaIterator iter, int index) {
    final prefixOps = skipToLineAt(iter, index);
    if (prefixOps.any((element) => element.data is! String)) return null;

    return prefixOps.map((e) => e.data).cast<String>().join();
  }

  Delta? _formatLine(
      DeltaIterator iter, int index, String prefix, ParchmentAttribute attr) {
    /// First, delete the shortcut prefix itself.
    final result = Delta()
      ..retain(index - prefix.length)
      ..delete(prefix.length);

    // Scan to the end of line to apply the style attribute.
    while (iter.hasNext) {
      final op = iter.next();
      if (op.data is! String) {
        result.retain(op.length);
        continue;
      }

      final text = op.data as String;
      final pos = text.indexOf('\n');

      if (pos == -1) {
        result.retain(op.length);
        continue;
      }

      result.retain(pos);

      final attrs = <String, dynamic>{};
      final currentLineAttrs = op.attributes;
      if (currentLineAttrs != null) {
        // the attribute already exists abort
        if (currentLineAttrs[attr.key] == attr.value) return null;
        attrs.addAll(currentLineAttrs);
      }
      attrs.addAll(attr.toJson());

      result.retain(1, attrs);

      break;
    }

    return result;
  }

  @override
  Delta? apply(Delta document, int index, Object data) {
    if (data is! String) return null;

    // Special case: code blocks don't need a `space` to get formatted, we can
    // detect when the user types ``` (or ''') and apply the style immediately.
    if (data == '`' || data == "'") {
      final iter = DeltaIterator(document);
      final prefix = _getLinePrefix(iter, index);
      if (prefix == null || prefix.isEmpty) return null;
      final shortcut = '$prefix$data';
      if (shortcut == '```' || shortcut == "'''") {
        return _formatLine(iter, index, prefix, ParchmentAttribute.code);
      }
    }

    // Standard case: triggered by a space character after the shortcut.
    if (data != ' ') return null;

    final iter = DeltaIterator(document);
    final prefix = _getLinePrefix(iter, index);

    if (prefix == null || prefix.isEmpty) return null;

    final attribute = rules[prefix];
    if (attribute == null) return null;

    return _formatLine(iter, index, prefix, attribute);
  }
}

/// Infers text direction from the input when happens in the beginning of a line.
/// This rule also removes alignment and sets it based on inferred direction.
class AutoTextDirectionRule extends InsertRule {
  final _isRTL = intl.Bidi.startsWithRtl;

  const AutoTextDirectionRule();

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
  Delta? apply(Delta document, int index, Object data) {
    if (data is! String || data == '\n') return null;

    final iter = DeltaIterator(document);
    final previous = iter.skip(index);
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

    return Delta()
      ..retain(index)
      ..insert(data)
      ..retain(1, attributes);
  }
}
