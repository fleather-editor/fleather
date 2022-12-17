// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:parchment/src/heuristics/utils.dart';
import 'package:quill_delta/quill_delta.dart';

/// A heuristic rule for delete operations.
abstract class DeleteRule {
  /// Constant constructor allows subclasses to declare constant constructors.
  const DeleteRule();

  /// Applies heuristic rule to a delete operation on a [document] and returns
  /// resulting [Delta].
  Delta? apply(Delta document, int index, int length);
}

class EnsureLastLineBreakDeleteRule extends DeleteRule {
  @override
  Delta? apply(Delta document, int index, int length) {
    final iter = DeltaIterator(document);
    iter.skip(index + length);

    return Delta()
      ..retain(index)
      ..delete(iter.hasNext ? length : length - 1);
  }
}

/// Fallback rule for delete operations which simply deletes specified text
/// range without any special handling.
class CatchAllDeleteRule extends DeleteRule {
  const CatchAllDeleteRule();

  @override
  Delta? apply(Delta document, int index, int length) {
    final iter = DeltaIterator(document);
    iter.skip(index + length);

    return Delta()
      ..retain(index)
      ..delete(iter.hasNext ? length : length - 1);
  }
}

/// Preserves line format when user deletes the line's newline character
/// effectively merging it with the next line.
///
/// This rule makes sure to apply all style attributes of deleted newline
/// to the next available newline, which may reset any style attributes
/// already present there.
class PreserveLineStyleOnMergeRule extends DeleteRule {
  const PreserveLineStyleOnMergeRule();

  @override
  Delta? apply(Delta document, int index, int length) {
    final iter = DeltaIterator(document);
    iter.skip(index);
    final target = iter.next(1);
    if (target.data != '\n') return null;

    iter.skip(length - 1);

    if (!iter.hasNext) {
      // User attempts to delete the last newline character, prevent it.
      return Delta()
        ..retain(index)
        ..delete(length - 1);
    }

    final result = Delta()
      ..retain(index)
      ..delete(length);

    // Look for next newline to apply the attributes
    while (iter.hasNext) {
      final op = iter.next();
      final opText = op.data is String ? op.data as String : '';
      final lf = opText.indexOf('\n');
      if (lf == -1) {
        result.retain(op.length);
        continue;
      }
      var attributes = _unsetAttributes(op.attributes);
      if (target.isNotPlain) {
        attributes ??= <String, dynamic>{};
        attributes.addAll(target.attributes!);
      }
      result
        ..retain(lf)
        ..retain(1, attributes);
      break;
    }
    return result;
  }

  Map<String, dynamic>? _unsetAttributes(Map<String, dynamic>? attributes) {
    if (attributes == null) return null;
    return attributes.map<String, dynamic>(
        (String key, dynamic value) => MapEntry<String, dynamic>(key, null));
  }
}

/// Prevents user from merging a line containing a block embed with other lines.
class EnsureEmbedLineRule extends DeleteRule {
  const EnsureEmbedLineRule();

  @override
  Delta? apply(Delta document, int index, int length) {
    final iter = DeltaIterator(document);

    final prev = iter.skip(index);
    // Text that we want to delete
    final target = iter.skip(length);

    final targetText = target?.data is String ? target!.data as String : '';
    if (targetText.endsWith('\n') || targetText.startsWith('\n')) {
      // Text or block that comes after deleted text
      final next = iter.next();

      final prevText = prev?.data is String ? prev!.data as String : '';
      final nextText = next.data is String ? next.data as String : '';
      if (prev == null || prevText.endsWith('\n') || nextText == '\n') {
        // Allow deleting in-between empty lines
        return null;
      }

      final canPrevGroup = isGroupBlockEmbed(prev.data);
      final canNextGroup = isGroupBlockEmbed(next.data);
      if (canPrevGroup && canNextGroup) {
        // Allow joining embeds that support grouping
        return null;
      }

      final isPrevBlock = isBlockEmbed(prev.data);
      final isNextBlock = isBlockEmbed(next.data);

      if (isPrevBlock) {
        if (nextText.startsWith('\n')) {
          // Block + \n + text  --> all good
          return _withDeletion(index, length);
        }

        // Block + text  --> keep single newline from target
        return _withSingleNewline(index, length, targetText);
      }

      if (isNextBlock) {
        if (prevText.endsWith('\n')) {
          // Text + \n + block  --> all good
          return _withDeletion(index, length);
        }

        // Text + block  --> keep single newline from target
        return _withSingleNewline(index, length, targetText);
      }
    }

    return null;
  }

  static Delta _withDeletion(int index, int length) {
    return Delta()
      ..retain(index)
      ..delete(length);
  }

  /// Delete target text but a single newline character.
  static Delta _withSingleNewline(int index, int length, String targetText) {
    if (targetText == '\n') {
      // No changes needed
      return Delta();
    }

    // TODO: we need to clear attributes from kept newline
    //       e.g. try deleting list next to embed

    if (targetText.startsWith('\n')) {
      // Keep leading newline
      return Delta()
        ..retain(index + 1)
        ..delete(length - 2);
    } else {
      // Keep trailing newline
      return Delta()
        ..retain(index)
        ..delete(length - 1);
    }
  }
}
