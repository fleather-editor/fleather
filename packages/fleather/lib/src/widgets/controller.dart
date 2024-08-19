import 'dart:async';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:parchment/parchment.dart';

import '../../util.dart';
import 'autoformats.dart';
import 'history.dart';

/// List of style keys which can be toggled for insertion
List<String> _toggleableStyleKeys = [
  ParchmentAttribute.bold.key,
  ParchmentAttribute.italic.key,
  ParchmentAttribute.underline.key,
  ParchmentAttribute.strikethrough.key,
  ParchmentAttribute.inlineCode.key,
  ParchmentAttribute.backgroundColor.key,
  ParchmentAttribute.foregroundColor.key,
];

class FleatherController extends ChangeNotifier {
  FleatherController({ParchmentDocument? document, AutoFormats? autoFormats})
      : _document = document ?? ParchmentDocument(),
        _history = HistoryStack.doc(document),
        _autoFormats = autoFormats ?? AutoFormats.fallback(),
        _selection = const TextSelection.collapsed(offset: 0) {
    _throttledPush = _throttle(
      duration: throttleDuration,
      function: _history.push,
    );
  }

  ParchmentDocument _document;

  /// Doument managed by this controller.
  ParchmentDocument get document => _document;

  // A list of changes applied to this doc. The changes could be undone or redone.
  HistoryStack _history;

  late _Throttled<Delta> _throttledPush;
  Timer? _throttleTimer;

  // The auto format handler
  final AutoFormats _autoFormats;

  /// Currently selected text within the [document].
  TextSelection get selection => _selection;
  TextSelection _selection;

  /// Store any styles attribute that got toggled by the tap of a button
  /// and that has not been applied yet.
  /// It gets reset after each format action within the [document].
  ParchmentStyle get toggledStyles => _toggledStyles;
  ParchmentStyle _toggledStyles = ParchmentStyle();

  /// Returns style of specified text range.
  ///
  /// If nothing is selected, the selection inline style is the style applied to the
  /// last character preceding the selection.
  ///
  /// If nothing is selected but we've toggled an attribute,
  /// we also merge those in our style before returning.
  ParchmentStyle getSelectionStyle() {
    int start = _selection.start;
    final length = _selection.end - start;

    // We decrement the start position to collect styles
    // before current selection position if selection is collaped and
    // it's not on the beginning of a new line.
    if (length == 0 && start > 0) {
      final data = document.toDelta().slice(start - 1, start).first.data;
      if (data is String && !data.endsWith('\n')) {
        start = start - 1;
      }
    }

    final inlineAttributes =
        document.collectStyle(start, length).inlineAttributes;
    final lineAttributes = document.collectStyle(start, length).lineAttributes;

    return ParchmentStyle()
        .putAll(inlineAttributes)
        .putAll(lineAttributes)
        .mergeAll(toggledStyles);
  }

  bool _shouldApplyToggledStyles(Delta delta) {
    if (toggledStyles.isNotEmpty && delta.isNotEmpty) {
      // covers single insert and a retain+insert
      if (delta.length <= 2 && delta.last.isInsert) {
        return true;
      }
    }
    return false;
  }

  void _applyToggledStyles(int index, Object data) {
    if (data is String && !isDataOnlyNewLines(data)) {
      var retainDelta = Delta()..retain(index);
      final segments = data.split('\n');
      segments.forEachIndexed((index, segment) {
        if (segment.isNotEmpty) {
          retainDelta.retain(segment.length, toggledStyles.toJson());
        }
        if (index != segments.length - 1) {
          retainDelta.retain(1);
        }
      });
      document.compose(retainDelta, ChangeSource.local);
    }
  }

  /// Replaces [length] characters in the document starting at [index] with
  /// provided [data].
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

    if (!_captureAutoFormatCancellationOrUndo(document, index, length, data)) {
      _updateHistory();
      notifyListeners();
      return;
    }

    if (length > 0 || isDataNotEmpty) {
      delta = document.replace(index, length, data);
      if (_shouldApplyToggledStyles(delta)) {
        _applyToggledStyles(index, data);
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
        final autoFormatPerformed = _autoFormats.run(document, index, data);
        // Only update history when text is being updated
        // We do not want to update it when selection is changed
        _updateHistory();
        if (autoFormatPerformed && _autoFormats.selection != null) {
          _updateSelectionSilent(_autoFormats.selection!,
              source: ChangeSource.local);
        }
      }
    }
    notifyListeners();
  }

  // Capture auto format cancellation
  // Returns `true` is auto format undo should let deletion propagate to
  // document; `false` otherwise
  bool _captureAutoFormatCancellationOrUndo(
      ParchmentDocument document, int position, int length, Object data) {
    // Platform (iOS for example) may send TextEditingDeltaNonTextUpdate
    // before the TextEditingDeltaDeletion that may cancel all active autoformats
    // We ignore these changes
    if (length == 0 && data == '') return true;
    if (!_autoFormats.hasActiveSuggestion) return true;

    if (_autoFormats.canUndo) {
      final isDeletionOfOneChar = data is String && data.isEmpty && length == 1;
      if (isDeletionOfOneChar) {
        // Undo if deleting 1 character after retain of auto-format
        if (position == _autoFormats.undoPosition) {
          final undoSelection = _autoFormats.undoActive(document);
          if (undoSelection != null) {
            _updateSelectionSilent(undoSelection, source: ChangeSource.local);
          }
          return false;
        }
      }
    }
    // Cancel active nevertheless
    _autoFormats.cancelActive();
    return true;
  }

  void formatText(int index, int length, ParchmentAttribute attribute) {
    final change = document.format(index, length, attribute);
    // _lastChangeSource = ChangeSource.local;
    const source = ChangeSource.local;

    if (length == 0 && _toggleableStyleKeys.contains(attribute.key)) {
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
  ///
  /// If selection is not provided, new selection will be inferred with priority
  /// to current position which can be changed by setting [forceUpdateSelection]
  /// to true.
  void compose(
    Delta change, {
    TextSelection? selection,
    ChangeSource source = ChangeSource.remote,
    bool forceUpdateSelection = false,
  }) {
    if (change.isNotEmpty) {
      document.compose(change, source);
      if (source != ChangeSource.history) {
        _updateHistory();
      }
    }
    if (selection != null) {
      _updateSelectionSilent(selection, source: source);
    } else {
      final base = change.transformPosition(_selection.baseOffset,
          force: forceUpdateSelection);
      final extent = change.transformPosition(_selection.extentOffset,
          force: forceUpdateSelection);
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

  /// Clear the controller state.
  ///
  /// It creates a new empty [ParchmentDocument] and a clean edit history.
  /// The old [document] will be closed if [closeDocument] is true.
  ///
  /// Calling this will notify all the listeners of this [FleatherController]
  /// that they need to update (it calls [notifyListeners]). For this reason,
  /// this method should only be called between frames, e.g. in response to user
  /// actions, not during the build, layout, or paint phases.
  void clear({bool closeDocument = true}) {
    _throttleTimer?.cancel();
    _toggledStyles = ParchmentStyle();
    _selection = const TextSelection.collapsed(offset: 0);
    _autoFormats.cancelActive();
    if (closeDocument) {
      document.close();
    }
    _document = ParchmentDocument();
    _history = HistoryStack.doc(document);
    _throttledPush = _throttle(
      duration: throttleDuration,
      function: _history.push,
    );
    notifyListeners();
  }
}

// This duration was chosen as a best fit for the behavior of Mac, Linux,
// and Windows undo/redo state save durations, but it is not perfect for any
// of them.
@visibleForTesting
const Duration throttleDuration = Duration(milliseconds: 500);

extension HistoryHandler on FleatherController {
  /// Returns true if there is at least one undo operation.
  bool get canUndo => _history.canUndo;

  /// Returns true if there is at least one redo operation.
  bool get canRedo => _history.canRedo;

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
