import 'dart:async';
import 'dart:math' as math;

import 'package:fleather/src/widgets/history.dart';
import 'package:fleather/util.dart';
import 'package:flutter/cupertino.dart';
import 'package:parchment/parchment.dart';
import 'package:quill_delta/quill_delta.dart';

/// List of style keys which can be toggled for insertion
List<String> _insertionToggleableStyleKeys = [
  ParchmentAttribute.bold.key,
  ParchmentAttribute.italic.key,
  ParchmentAttribute.underline.key,
  ParchmentAttribute.strikethrough.key,
  ParchmentAttribute.inlineCode.key,
];

class FleatherController extends ChangeNotifier {
  FleatherController([ParchmentDocument? document])
      : document = document ?? ParchmentDocument(),
        _history = HistoryStack.doc(document),
        _selection = const TextSelection.collapsed(offset: 0) {
    _throttledPush = _throttle(
      duration: throttleDuration,
      function: _history.push,
    );
  }

  /// Document managed by this controller.
  final ParchmentDocument document;

  // A list of changes applied to this doc. The changes could be undone or redone.
  final HistoryStack _history;

  late final _Throttled<Delta> _throttledPush;
  Timer? _throttleTimer;

  /// Currently selected text within the [document].
  TextSelection get selection => _selection;
  TextSelection _selection;

  /// Store any styles attribute that got toggled by the tap of a button
  /// and that has not been applied yet.
  /// It gets reset after each format action within the [document].
  ParchmentStyle get toggledStyles => _toggledStyles;
  ParchmentStyle _toggledStyles = ParchmentStyle();

  /// Returns true if there is at least one undo operation.
  bool get canUndo => _history.canUndo;

  /// Returns true if there is at least one redo operation.
  bool get canRedo => _history.canRedo;

  /// Returns style of specified text range.
  ///
  /// If nothing is selected but we've toggled an attribute,
  /// we also merge those in our style before returning.
  ParchmentStyle getSelectionStyle() {
    final start = _selection.start;
    final length = _selection.end - start;
    final effectiveStart =
        _selection.isCollapsed ? math.max(0, start - 1) : start;
    var lineStyle = document.collectStyle(effectiveStart, length);

    lineStyle = lineStyle.mergeAll(toggledStyles);

    return lineStyle;
  }

  bool _shouldApplyToggledStyles(Delta delta) =>
      toggledStyles.isNotEmpty &&
      delta.isNotEmpty &&
      ((delta.length <= 2 && // covers single insert and a retain+insert
              delta.last.isInsert) ||
          (delta.length <= 3 &&
              delta.last.isRetain // special case for AutoTextDirectionRule
          ));

  /// Replaces [length] characters in the document starting at [index] with
  /// provided [text].
  ///
  /// Resulting change is registered as produced by user action, e.g.
  /// using [ChangeSource.local].
  ///
  /// It also applies the toggledStyle if needed. And then it resets it
  /// in any cases as we don't want to keep it except on inserts.
  ///
  /// Optionally updates selection if provided.
  void replaceText(int index, int length, Object data,
      {TextSelection? selection}) {
    assert(data is String || data is EmbeddableObject);
    Delta? delta;

    final isDataNotEmpty = data is String ? data.isNotEmpty : true;
    if (length > 0 || isDataNotEmpty) {
      delta = document.replace(index, length, data);
      // If the delta is an insert operation and we have toggled
      // some styles, then apply those styles to the inserted text.
      if (_shouldApplyToggledStyles(delta)) {
        final dataLength = data is String ? data.length : 1;
        final retainDelta = Delta()
          ..retain(index)
          ..retain(dataLength, toggledStyles.toJson());
        document.compose(retainDelta, ChangeSource.local);
      }
    }

    // Always reset it after any user action, even if it has not been applied.
    _toggledStyles = ParchmentStyle();

    if (selection != null) {
      if (delta == null) {
        _updateSelectionSilent(selection, source: ChangeSource.local);
      } else {
        // need to transform selection position in case actual delta
        // is different from user's version (in deletes and inserts).
        final user = Delta()
          ..retain(index)
          ..insert(data)
          ..delete(length);
        var positionDelta = getPositionDelta(user, delta);
        _updateSelectionSilent(
          selection.copyWith(
            baseOffset: selection.baseOffset + positionDelta,
            extentOffset: selection.extentOffset + positionDelta,
          ),
          source: ChangeSource.local,
        );
      }
    }
    _updateHistory();
    notifyListeners();
  }

  void formatText(int index, int length, ParchmentAttribute attribute) {
    final change = document.format(index, length, attribute);
    // _lastChangeSource = ChangeSource.local;
    const source = ChangeSource.local;

    if (length == 0 && _insertionToggleableStyleKeys.contains(attribute.key)) {
      // Add the attribute to our toggledStyle. It will be used later upon insertion.
      _toggledStyles = toggledStyles.put(attribute);
    }

    // Transform selection against the composed change and give priority to
    // the change. This is needed in cases when format operation actually
    // inserts data into the document (e.g. embeds).
    final base = change.transformPosition(_selection.baseOffset);
    final extent = change.transformPosition(_selection.extentOffset);
    final adjustedSelection =
        _selection.copyWith(baseOffset: base, extentOffset: extent);
    if (_selection != adjustedSelection) {
      _updateSelectionSilent(adjustedSelection, source: source);
    }
    _updateHistory();
    notifyListeners();
  }

  /// Formats current selection with [attribute].
  void formatSelection(ParchmentAttribute attribute) {
    final index = _selection.start;
    final length = _selection.end - index;
    formatText(index, length, attribute);
  }

  /// Updates selection with specified [value].
  ///
  /// [value] and [source] cannot be `null`.
  void updateSelection(TextSelection value,
      {ChangeSource source = ChangeSource.remote}) {
    _updateSelectionSilent(value, source: source);
    _toggledStyles = ParchmentStyle();
    notifyListeners();
  }

  /// Composes [change] into document managed by this controller.
  ///
  /// This method does not apply any adjustments or heuristic rules to
  /// provided [change] and it is caller's responsibility to ensure this change
  /// can be composed without errors.
  ///
  /// If composing this change fails then this method throws [ComposeError].
  void compose(Delta change,
      {TextSelection? selection, ChangeSource source = ChangeSource.remote}) {
    if (change.isNotEmpty) {
      document.compose(change, source);
      if (source != ChangeSource.history) {
        _updateHistory();
      }
    }
    if (selection != null) {
      _updateSelectionSilent(selection, source: source);
    } else {
      // Transform selection against the composed change and give priority to
      // current position (force: false).
      final base =
          change.transformPosition(_selection.baseOffset, force: false);
      final extent =
          change.transformPosition(_selection.extentOffset, force: false);
      selection = _selection.copyWith(baseOffset: base, extentOffset: extent);
      if (_selection != selection) {
        _updateSelectionSilent(selection, source: source);
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    document.close();
    _throttleTimer?.cancel();
    super.dispose();
  }

  /// Updates selection without triggering notifications to listeners.
  void _updateSelectionSilent(TextSelection value,
      {ChangeSource source = ChangeSource.remote}) {
    _selection = value;
    _ensureSelectionBeforeLastBreak();
  }

  // Ensures that selection does not include last line break which
  // prevents deletion of the last line in the document.
  // This is required by Fleather document model.
  void _ensureSelectionBeforeLastBreak() {
    final end = document.length - 1;
    final base = math.min(_selection.baseOffset, end);
    final extent = math.min(_selection.extentOffset, end);
    _selection = _selection.copyWith(baseOffset: base, extentOffset: extent);
  }

  TextEditingValue get plainTextEditingValue {
    return TextEditingValue(
      text: document.toPlainText(),
      selection: selection,
      composing: TextRange.empty,
    );
  }
}

// This duration was chosen as a best fit for the behavior of Mac, Linux,
// and Windows undo/redo state save durations, but it is not perfect for any
// of them.
@visibleForTesting
const Duration throttleDuration = Duration(milliseconds: 500);

extension HistoryHandler on FleatherController {
  /// Sets current document state to it's previous state, if any.
  void undo() {
    _update(_history.undo());
  }

  /// Sets current document state to it's next state, if any.
  void redo() {
    _update(_history.redo());
  }

  void _update(Delta? changeDelta) {
    if (changeDelta == null || changeDelta.isEmpty) {
      return;
    }

    compose(changeDelta,
        selection: HistoryStack.selectionFromDelta(changeDelta),
        source: ChangeSource.history);
  }

  void _updateHistory() {
    if (plainTextEditingValue == TextEditingValue.empty) {
      return;
    }
    _throttleTimer = _throttledPush(document.toDelta());
  }
}

/// A function that can be throttled with the throttle function.
typedef _Throttleable<T> = void Function(T currentArg);

/// A function that has been throttled by [_throttle].
typedef _Throttled<T> = Timer Function(T currentArg);

/// Returns a _Throttled that will call through to the given function only a
/// maximum of once per duration.
///
/// Only works for functions that take exactly one argument and return void.
_Throttled<T> _throttle<T>({
  required Duration duration,
  required _Throttleable<T> function,
  // If true, calls at the start of the timer.
  bool leadingEdge = false,
}) {
  Timer? timer;
  bool calledDuringTimer = false;
  late T arg;

  return (T currentArg) {
    arg = currentArg;
    if (timer != null) {
      calledDuringTimer = true;
      return timer!;
    }
    if (leadingEdge) {
      function(arg);
    }
    calledDuringTimer = false;
    timer = Timer(duration, () {
      if (!leadingEdge || calledDuringTimer) {
        function(arg);
      }
      timer = null;
    });
    return timer!;
  };
}
