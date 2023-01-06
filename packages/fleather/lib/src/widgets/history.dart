import 'dart:async';

import 'package:fleather/fleather.dart';
import 'package:flutter/widgets.dart';
import 'package:quill_delta/quill_delta.dart';

/// Provides undo/redo capabilities for text editing.
///
/// Listens to [controller] as a [ValueNotifier] and saves relevant values for
/// undoing/redoing. The cadence at which values are saved is a best
/// approximation of the native behaviors of a hardware keyboard on Flutter's
/// desktop platforms, as there are subtle differences between each of these
/// platforms.
///
/// Listens to keyboard undo/redo shortcuts and send update to [controller].
class FleatherHistory extends StatefulWidget {
  /// Creates an instance of [FleatherHistory].
  const FleatherHistory(
      {super.key, required this.child, required this.controller});

  /// The child widget of [FleatherHistory].
  final Widget child;

  /// The [FleatherController] to save the state of over time.
  final FleatherController controller;

  @override
  State<FleatherHistory> createState() => _FleatherHistoryState();
}

class _FleatherHistoryState extends State<FleatherHistory> {
  late final _Throttled<Delta> _throttledPush;
  Timer? _throttleTimer;

  // This duration was chosen as a best fit for the behavior of Mac, Linux,
  // and Windows undo/redo state save durations, but it is not perfect for any
  // of them.
  static const Duration _kThrottleDuration = Duration(milliseconds: 500);

  void _undo(UndoTextIntent intent) {
    _update(widget.controller.history.undo());
  }

  void _redo(RedoTextIntent intent) {
    _update(widget.controller.history.redo());
  }

  void _update(Delta? changeDelta) {
    if (changeDelta == null || changeDelta.isEmpty) {
      return;
    }

    widget.controller.compose(changeDelta,
        selection: HistoryStack.selectionFromDelta(changeDelta),
        source: ChangeSource.local);
  }

  void _onLocalChanges() {
    if (widget.controller.plainTextEditingValue == TextEditingValue.empty) {
      return;
    }
    _throttleTimer = _throttledPush(widget.controller.document.toDelta());
  }

  @override
  void initState() {
    super.initState();
    _throttledPush = _throttle(
        duration: _kThrottleDuration, function: widget.controller.history.push);
    widget.controller.addListener(_onLocalChanges);
  }

  @override
  void didUpdateWidget(FleatherHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onLocalChanges);
      widget.controller.addListener(_onLocalChanges);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onLocalChanges);
    _throttleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        UndoTextIntent: Action<UndoTextIntent>.overridable(
            context: context,
            defaultAction: CallbackAction<UndoTextIntent>(onInvoke: _undo)),
        RedoTextIntent: Action<RedoTextIntent>.overridable(
            context: context,
            defaultAction: CallbackAction<RedoTextIntent>(onInvoke: _redo)),
      },
      child: widget.child,
    );
  }
}

/// A data structure representing a chronological list of states that can be
/// undone and redone.
/// Initial state of the stack contains the document [Delta] at the time of
/// instantiation
class HistoryStack {
  /// Creates an instance of [HistoryStack].
  HistoryStack(this._currentState);

  /// Creates an instance of [HistoryStack] from a [ParchmentDocument].
  HistoryStack.doc(ParchmentDocument? doc)
      : this(doc?.toDelta() ?? ParchmentDocument().toDelta());

  // List of historical changes made to document
  final List<_Change> _list = [];

  // The index of the current value, or -1 if the list is empty.
  int _currentIndex = -1;

  Delta _currentState;

  _Change? get _currentChange => _list.isEmpty ? null : _list[_currentIndex];

  /// Add a new document state change to the stack.
  void push(Delta newState) {
    final redoDelta = _currentState.diff(newState);

    if (redoDelta.isEmpty) return;

    final undoDelta = redoDelta.invert(_currentState);

    _currentState = newState;

    if (_list.isEmpty) {
      _currentIndex = 0;
      _list.add(_Change(undoDelta, redoDelta));
      return;
    }

    assert(_currentIndex < _list.length && _currentIndex >= -1);

    // If anything has been undone in this stack, remove those irrelevant states
    // before adding the new one.
    if (_currentIndex != _list.length - 1) {
      _list.removeRange(_currentIndex + 1, _list.length);
    }
    _list.add(_Change(undoDelta, redoDelta));
    _currentIndex = _list.length - 1;
  }

  /// Returns the current [_Change] to apply to current document to reach desired
  /// document state.
  ///
  /// An undo operation moves the current value to the previously pushed value,
  /// if any.
  ///
  /// Iff the stack is completely empty, then returns null.
  Delta? undo() {
    if (_list.isEmpty) {
      return null;
    }
    assert(_currentIndex < _list.length && _currentIndex >= -1);
    if (_currentIndex == -1) {
      return null;
    }
    final undoDelta = _currentChange!.undoDelta;
    _currentState = _currentState.compose(undoDelta);
    _currentIndex = _currentIndex - 1;
    return undoDelta;
  }

  /// Returns true if there is at least one undo operation.
  bool get canUndo {
    return _list.isNotEmpty && _currentIndex != -1;
  }

  /// Returns the current [_Change] to apply to current document to reach desired
  /// document state.
  ///
  /// A redo operation moves the current value to the value that was last
  /// undone, if any.
  ///
  /// Iff the stack is completely empty, then returns null.
  Delta? redo() {
    if (_list.isEmpty) {
      return null;
    }
    assert(_currentIndex < _list.length && _currentIndex >= -1);
    if (_currentIndex < _list.length - 1) {
      _currentIndex = _currentIndex + 1;
      final redoDelta = _currentChange!.redoDelta;
      _currentState = _currentState.compose(redoDelta);
      return redoDelta;
    }
    return null;
  }

  /// Returns true if there is at least one redo operation.
  bool get canRedo {
    return _list.isNotEmpty && (_currentIndex < _list.length - 1);
  }

  static TextSelection selectionFromDelta(Delta changeDelta) {
    assert(changeDelta.isNotEmpty);
    final firstOp = changeDelta.first;
    int baseOffset = 0;
    // change starts at index following first plain retain
    if (firstOp.isRetain && firstOp.attributes == null) {
      baseOffset = firstOp.length;
    }
    int extentOffset = baseOffset;
    final lastOp = changeDelta.last;
    // if change is a change in format, selection must cover the rest of the
    // change
    if (lastOp.isRetain && lastOp.attributes != null) {
      extentOffset = changeDelta.textLength;
    }
    // if change is an insertion, cursor is set at the end of the insertion
    if (lastOp.isInsert) {
      baseOffset = changeDelta.textLength;
      extentOffset = baseOffset;
    }
    return TextSelection(baseOffset: baseOffset, extentOffset: extentOffset);
  }
}

/// Stores undo & redo [Delta] from current document [Delta] state
/// Both need to be stored in order to replay or rewind history without
/// having to store complete versions of the document
class _Change {
  _Change(this.undoDelta, this.redoDelta);

  final Delta undoDelta;
  final Delta redoDelta;
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

extension on Delta {
  int get textLength {
    int length = 0;
    toList().forEach((op) {
      if (op.isDelete) {
        length -= op.length;
      } else {
        length += op.length;
      }
    });
    return length;
  }
}
