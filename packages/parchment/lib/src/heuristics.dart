import 'package:parchment_delta/parchment_delta.dart';

import 'document.dart';
import 'document/attributes.dart';
import 'heuristics/delete_rules.dart';
import 'heuristics/format_rules.dart';
import 'heuristics/insert_rules.dart';

/// Registry for insert, format and delete heuristic rules used by
/// [ParchmentDocument] documents.
class ParchmentHeuristics {
  /// Default set of heuristic rules.
  ///
  /// Rule order matters.
  static const ParchmentHeuristics fallback = ParchmentHeuristics(
    formatRules: [
      FormatLinkAtCaretPositionRule(),
      ResolveLineFormatRule(),
      ResolveInlineFormatRule(),
      // No need in catch-all rule here since the above rules cover all
      // attributes.
    ],
    insertRules: [
      // Embeds
      InsertBlockEmbedsRule(),
      ForceNewlineForInsertsAroundBlockEmbedRule(),
      // Blocks
      AutoExitBlockRule(), // must go first
      PreserveBlockStyleOnInsertRule(),
      // Lines
      PreserveLineStyleOnSplitRule(),
      PreserveLineFormatOnNewLineRule(),
      // Inlines
      PreserveInlineStylesRule(),
      // Catch-all
      CatchAllInsertRule(),
    ],
    deleteRules: [
      EnsureEmbedLineRule(),
      PreserveLineStyleOnMergeRule(),
      CatchAllDeleteRule(),
    ],
  );

  const ParchmentHeuristics({
    required this.formatRules,
    required this.insertRules,
    required this.deleteRules,
  });

  /// List of format rules in this registry.
  final List<FormatRule> formatRules;

  /// List of insert rules in this registry.
  final List<InsertRule> insertRules;

  /// List of delete rules in this registry.
  final List<DeleteRule> deleteRules;

  /// Applies heuristic rules to specified insert operation based on current
  /// state of Parchment [document].
  Delta applyInsertRules(ParchmentDocument document, int index, Object data) {
    final delta = document.toDelta();
    for (var rule in insertRules) {
      final result = rule.apply(delta, index, data);
      if (result != null) return result..trim();
    }
    throw StateError('Failed to apply insert heuristic rules: none applied.');
  }

  /// Applies heuristic rules to specified format operation based on current
  /// state of Parchment [document].
  Delta applyFormatRules(ParchmentDocument document, int index, int length,
      ParchmentAttribute value) {
    final delta = document.toDelta();
    for (var rule in formatRules) {
      final result = rule.apply(delta, index, length, value);
      if (result != null) return result..trim();
    }
    throw StateError('Failed to apply format heuristic rules: none applied.');
  }

  /// Applies heuristic rules to specified delete operation based on current
  /// state of Parchment [document].
  Delta applyDeleteRules(ParchmentDocument document, int index, int length) {
    final delta = document.toDelta();
    for (var rule in deleteRules) {
      final result = rule.apply(delta, index, length);
      if (result != null) return result..trim();
    }
    throw StateError('Failed to apply delete heuristic rules: none applied.');
  }

  /// Creates a copy of this heuristics with rules from other appended.
  ParchmentHeuristics merge(ParchmentHeuristics other) {
    return ParchmentHeuristics(
      formatRules: formatRules..addAll(other.formatRules),
      insertRules: insertRules..addAll(other.insertRules),
      deleteRules: deleteRules..addAll(other.deleteRules),
    );
  }
}
