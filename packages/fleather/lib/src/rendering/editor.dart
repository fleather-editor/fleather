import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../fleather.dart';
import '../widgets/selection_utils.dart';
import 'cursor_painter.dart';
import 'editable_box.dart';

/// Signature for the callback that reports when the user changes the selection
/// (including the cursor location).
///
/// Used by [RenderEditor.onSelectionChanged].
typedef TextSelectionChangedHandler = void Function(
    TextSelection selection, SelectionChangedCause cause);

// The padding applied to text field. Used to determine the bounds when
// moving the floating cursor.
const EdgeInsets _kFloatingCursorAddedMargin = EdgeInsets.fromLTRB(4, 4, 4, 5);

// The additional size on the x and y axis with which to expand the prototype
// cursor to render the floating cursor in pixels.
const EdgeInsets _kFloatingCaretSizeIncrease =
    EdgeInsets.symmetric(horizontal: 0.5, vertical: 1.0);

/// Base interface for editable render objects.
abstract class RenderAbstractEditor implements TextLayoutMetrics {
  TextSelection selectWordAtPosition(TextPosition position);

  TextSelection selectLineAtPosition(TextPosition position);

  /// Returns preferred line height at specified `position` in text.
  double preferredLineHeight(TextPosition position);

  TextPosition getPositionForOffset(Offset offset);

  /// Returns [Rect] for caret in local coordinates
  ///
  /// Useful to enforce visibility of full caret at given position
  Rect getLocalRectForCaret(TextPosition position);

  /// Returns the local coordinates of the endpoints of the given selection.
  ///
  /// If the selection is collapsed (and therefore occupies a single point), the
  /// returned list is of length one. Otherwise, the selection is not collapsed
  /// and the returned list is of length two. In this case, however, the two
  /// points might actually be co-located (e.g., because of a bidirectional
  /// selection that contains some text but whose ends meet in the middle).
  List<TextSelectionPoint> getEndpointsForSelection(TextSelection selection);

  /// Sets the screen position of the floating cursor and the text position
  /// closest to the cursor.
  /// `resetLerpValue` drives the size of the floating cursor.
  /// See [EditorState.floatingCursorResetController].
  void setFloatingCursor(FloatingCursorDragState dragState,
      Offset lastBoundedOffset, TextPosition lastTextPosition,
      {double? resetLerpValue});

  /// Tracks the position of a secondary tap event.
  ///
  /// Should be called before attempting to change the selection based on the
  /// position of a secondary tap.
  void handleSecondaryTapDown(TapDownDetails details);

  /// If [ignorePointer] is false (the default) then this method is called by
  /// the internal gesture recognizer's [TapGestureRecognizer.onTapDown]
  /// callback.
  ///
  /// When [ignorePointer] is true, an ancestor widget must respond to tap
  /// down events by calling this method.
  void handleTapDown(TapDownDetails details);

  /// Selects the set words of a paragraph in a given range of global positions.
  ///
  /// The first and last endpoints of the selection will always be at the
  /// beginning and end of a word respectively.
  ///
  /// {@macro flutter.rendering.editable.select}
  void selectWordsInRange({
    required Offset from,
    Offset? to,
    required SelectionChangedCause cause,
  });

  /// Move the selection to the beginning or end of a word.
  ///
  /// {@macro flutter.rendering.editable.select}
  void selectWordEdge({required SelectionChangedCause cause});

  /// Select text between the global positions [from] and [to].
  ///
  /// Returns the new selection. Note that the returned value may not be
  /// yet reflected in the latest widget state.
  ///
  /// Returns null if no change occurred.
  TextSelection? selectPositionAt({
    required Offset from,
    Offset? to,
    required SelectionChangedCause cause,
  });

  /// Select a word around the location of the last tap down.
  ///
  /// {@macro flutter.rendering.editable.select}
  void selectWord({required SelectionChangedCause cause});

  /// Move selection to the location of the last tap down.
  ///
  /// {@template flutter.rendering.editable.select}
  /// This method is mainly used to translate user inputs in global positions
  /// into a [TextSelection]. When used in conjunction with a [EditableText],
  /// the selection change is fed back into [TextEditingController.selection].
  ///
  /// If you have a [TextEditingController], it's generally easier to
  /// programmatically manipulate its `value` or `selection` directly.
  /// {@endtemplate}
  void selectPosition({required SelectionChangedCause cause});

  /// Starts a [FleatherVerticalCaretMovementRun] at the given location in the text, for
  /// handling consecutive vertical caret movements.
  ///
  /// This can be used to handle consecutive upward/downward arrow key movements
  /// in an editor.
  FleatherVerticalCaretMovementRun startVerticalCaretMovement(
      TextPosition startPosition);
}

/// Displays a Fleather document as a vertical list of document segments (lines
/// and blocks).
///
/// Children of [RenderEditor] must be instances of [RenderEditableBox].
class RenderEditor extends RenderEditableContainerBox
    with RelayoutWhenSystemFontsChangeMixin
    implements RenderAbstractEditor {
  RenderEditor({
    super.children,
    required super.padding,
    required super.textDirection,
    required ParchmentDocument document,
    required ViewportOffset offset,
    required bool hasFocus,
    required TextSelection selection,
    required LayerLink startHandleLayerLink,
    required LayerLink endHandleLayerLink,
    required CursorController cursorController,
    this.onSelectionChanged,
    EdgeInsets floatingCursorAddedMargin =
        const EdgeInsets.fromLTRB(4, 4, 4, 5),
    double? maxContentWidth,
  })  : _document = document,
        _offset = offset,
        _hasFocus = hasFocus,
        _selection = selection,
        _startHandleLayerLink = startHandleLayerLink,
        _endHandleLayerLink = endHandleLayerLink,
        _cursorController = cursorController,
        _maxContentWidth = maxContentWidth,
        super(
          node: document.root,
        );

  ParchmentDocument _document;

  ParchmentDocument get document => _document;

  set document(ParchmentDocument value) {
    if (_document == value) {
      return;
    }
    _document = value;
    markNeedsLayout();
  }

  /// Whether the editor is currently focused.
  bool get hasFocus => _hasFocus;
  bool _hasFocus = false;

  set hasFocus(bool value) {
    if (_hasFocus == value) {
      return;
    }
    _hasFocus = value;
    markNeedsSemanticsUpdate();
  }

  Offset get paintOffset => Offset(0.0, -offset.pixels);

  ViewportOffset get offset => _offset;
  ViewportOffset _offset;

  set offset(ViewportOffset value) {
    if (_offset == value) return;
    if (attached) _offset.removeListener(markNeedsPaint);
    _offset = value;
    if (attached) _offset.addListener(markNeedsPaint);
    markNeedsLayout();
  }

  double _maxScrollExtent = 0;

  // We need to check the paint offset here because during animation, the start of
  // the text may position outside the visible region even when the text fits.
  bool get _hasVisualOverflow =>
      _maxScrollExtent > 0 || paintOffset != Offset.zero;

  Offset? _lastSecondaryTapDownPosition;

  Offset? get lastSecondaryTapDownPosition => _lastSecondaryTapDownPosition;

  /// The region of text that is selected, if any.
  ///
  /// The caret position is represented by a collapsed selection.
  ///
  /// If [selection] is null, there is no selection and attempts to
  /// manipulate the selection will throw.
  TextSelection get selection => _selection;
  TextSelection _selection;

  set selection(TextSelection value) {
    if (_selection == value) return;
    _selection = value;
    markNeedsPaint();
  }

  /// The [LayerLink] of start selection handle.
  ///
  /// [RenderEditable] is responsible for calculating the [Offset] of this
  /// [LayerLink], which will be used as [CompositedTransformTarget] of start handle.
  LayerLink get startHandleLayerLink => _startHandleLayerLink;
  LayerLink _startHandleLayerLink;

  set startHandleLayerLink(LayerLink value) {
    if (_startHandleLayerLink == value) return;
    _startHandleLayerLink = value;
    markNeedsPaint();
  }

  /// The [LayerLink] of end selection handle.
  ///
  /// [RenderEditable] is responsible for calculating the [Offset] of this
  /// [LayerLink], which will be used as [CompositedTransformTarget] of end handle.
  LayerLink get endHandleLayerLink => _endHandleLayerLink;
  LayerLink _endHandleLayerLink;

  set endHandleLayerLink(LayerLink value) {
    if (_endHandleLayerLink == value) return;
    _endHandleLayerLink = value;
    markNeedsPaint();
  }

  double? _maxContentWidth;

  double? get maxContentWidth => _maxContentWidth;

  set maxContentWidth(double? value) {
    if (_maxContentWidth == value) return;
    _maxContentWidth = value;
    markNeedsLayout();
  }

  final CursorController _cursorController;

  /// Track whether position of the start of the selected text is within the viewport.
  ///
  /// For example, if the text contains "Hello World", and the user selects
  /// "Hello", then scrolls so only "World" is visible, this will become false.
  /// If the user scrolls back so that the "H" is visible again, this will
  /// become true.
  ///
  /// This bool indicates whether the text is scrolled so that the handle is
  /// inside the text field viewport, as opposed to whether it is actually
  /// visible on the screen.
  ValueListenable<bool> get selectionStartInViewport =>
      _selectionStartInViewport;
  final ValueNotifier<bool> _selectionStartInViewport =
      ValueNotifier<bool>(true);

  /// Track whether position of the end of the selected text is within the viewport.
  ///
  /// For example, if the text contains "Hello World", and the user selects
  /// "World", then scrolls so only "Hello" is visible, this will become
  /// 'false'. If the user scrolls back so that the "d" is visible again, this
  /// will become 'true'.
  ///
  /// This bool indicates whether the text is scrolled so that the handle is
  /// inside the text field viewport, as opposed to whether it is actually
  /// visible on the screen.
  ValueListenable<bool> get selectionEndInViewport => _selectionEndInViewport;
  final ValueNotifier<bool> _selectionEndInViewport = ValueNotifier<bool>(true);

  void _updateSelectionExtentsVisibility(Offset effectiveOffset) {
    final visibleRegion = Offset.zero & size;
    final startPosition =
        TextPosition(offset: selection.start, affinity: selection.affinity);
    final startOffset = _getOffsetForCaret(startPosition);
    // TODO(justinmc): https://github.com/flutter/flutter/issues/31495
    // Check if the selection is visible with an approximation because a
    // difference between rounded and unrounded values causes the caret to be
    // reported as having a slightly (< 0.5) negative y offset. This rounding
    // happens in paragraph.cc's layout and TextPainer's
    // _applyFloatingPointHack. Ideally, the rounding mismatch will be fixed and
    // this can be changed to be a strict check instead of an approximation.
    const visibleRegionSlop = 0.5;
    _selectionStartInViewport.value = visibleRegion
        .inflate(visibleRegionSlop)
        .contains(startOffset + effectiveOffset);

    final endPosition =
        TextPosition(offset: selection.end, affinity: selection.affinity);
    final endOffset = _getOffsetForCaret(endPosition);
    _selectionEndInViewport.value = visibleRegion
        .inflate(visibleRegionSlop)
        .contains(endOffset + effectiveOffset);
  }

  // returns offset relative to this at which the caret will be painted
  // given a global TextPosition
  Offset _getOffsetForCaret(TextPosition position) {
    final child = childAtPosition(position);
    final childPosition = child.globalToLocalPosition(position);
    final boxParentData = child.parentData as BoxParentData;
    final localOffsetForCaret = child.getOffsetForCaret(childPosition);
    return boxParentData.offset + localOffsetForCaret;
  }

  /// Finds the closest scroll offset that fully reveals the editing cursor.
  ///
  /// The `scrollOffset` parameter represents current scroll offset in the
  /// parent viewport.
  ///
  /// The `offsetInViewport` parameter represents the editor's vertical offset
  /// in the parent viewport. This value should normally be 0.0 if this editor
  /// is the only child of the viewport or if it's the topmost child. Otherwise
  /// it should be a positive value equal to total height of all siblings of
  /// this editor from above it.
  ///
  /// Returns `null` if the cursor is currently visible.
  double? getOffsetToRevealCursor(double viewportHeight, double scrollOffset) {
    const kMargin = 8.0;
    // Endpoints coordinates represents lower left or lower right corner of
    // the selection. If we want to scroll up to reveal the caret we need to
    // adjust the dy value by the height of the line. We also add a small margin
    // so that the caret is not too close to the edge of the viewport.
    final endpoints = getEndpointsForSelection(selection);
    if (endpoints.length == 1) {
      // Collapsed selection => caret
      final child = childAtPosition(selection.extent);
      final childPosition = TextPosition(
          offset: selection.extentOffset - child.node.documentOffset);
      final caretTop = endpoints.single.point.dy -
          child.preferredLineHeight(childPosition) -
          kMargin;
      final caretBottom = endpoints.single.point.dy + kMargin;
      final caretHeight = caretBottom - caretTop;
      double? dy;

      /// When caret is bigger than viewport, we reveal it's bottom.
      if (caretBottom > scrollOffset + viewportHeight ||
          caretHeight > viewportHeight) {
        dy = caretBottom - viewportHeight;
      } else if (caretTop < scrollOffset) {
        dy = caretTop;
      }
      if (dy == null) return null;
      // Clamping to 0.0 so that the content does not jump unnecessarily.
      return math.max(dy, 0.0);
    }
    // TODO: Implement for non-collapsed selection.
    return null;
  }

  @override
  List<TextSelectionPoint> getEndpointsForSelection(TextSelection selection) {
    // _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
    if (selection.isCollapsed) {
      final child = childAtPosition(selection.extent);
      final localPosition =
          TextPosition(offset: selection.extentOffset - child.node.offset);
      final localOffset = child.getOffsetForCaret(localPosition);
      final parentData = child.parentData as BoxParentData;
      final start = Offset(0.0, child.preferredLineHeight(localPosition)) +
          localOffset +
          parentData.offset;
      return <TextSelectionPoint>[TextSelectionPoint(start, null)];
    } else {
      final baseNode = node.lookup(selection.start).node;

      var baseChild = firstChild;
      while (baseChild != null) {
        if (baseChild.node == baseNode) {
          break;
        }
        baseChild = childAfter(baseChild);
      }
      assert(baseChild != null);

      final baseParentData = baseChild!.parentData as BoxParentData;
      final baseSelection =
          localSelection(baseChild.node, selection, fromParent: true);
      var basePoint = baseChild.getBaseEndpointForSelection(baseSelection);
      basePoint = TextSelectionPoint(
          basePoint.point + baseParentData.offset, basePoint.direction);

      final extentNode = node.lookup(selection.end).node;
      RenderEditableBox? extentChild = baseChild;
      while (extentChild != null) {
        if (extentChild.node == extentNode) {
          break;
        }
        extentChild = childAfter(extentChild);
      }
      assert(extentChild != null);

      final extentParentData = extentChild!.parentData as BoxParentData;
      final extentSelection =
          localSelection(extentChild.node, selection, fromParent: true);
      var extentPoint =
          extentChild.getExtentEndpointForSelection(extentSelection);
      extentPoint = TextSelectionPoint(
          extentPoint.point + extentParentData.offset, extentPoint.direction);

      return <TextSelectionPoint>[basePoint, extentPoint];
    }
  }

  Offset? _lastTapDownPosition;

  @override
  void handleSecondaryTapDown(TapDownDetails details) {
    _lastTapDownPosition = details.globalPosition;
    _lastSecondaryTapDownPosition = details.globalPosition;
  }

  @override
  void handleTapDown(TapDownDetails details) {
    _lastTapDownPosition = details.globalPosition;
  }

  /// Called when the selection changes.
  ///
  /// If this is null, then selection changes will be ignored.
  TextSelectionChangedHandler? onSelectionChanged;

  @override
  void selectWordsInRange({
    required Offset from,
    Offset? to,
    required SelectionChangedCause cause,
  }) {
    // _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
    if (onSelectionChanged == null) {
      return;
    }
    final firstPosition = getPositionForOffset(from);
    final firstWord = selectWordAtPosition(firstPosition);
    final lastWord =
        to == null ? firstWord : selectWordAtPosition(getPositionForOffset(to));

    _handleSelectionChange(
      TextSelection(
        baseOffset: firstWord.base.offset,
        extentOffset: lastWord.extent.offset,
        affinity: firstWord.affinity,
      ),
      cause,
    );
  }

  @override
  void selectWordEdge({required SelectionChangedCause cause}) {
    // _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
    assert(_lastTapDownPosition != null);
    if (onSelectionChanged == null) {
      return;
    }
    final position = getPositionForOffset(_lastTapDownPosition!);
    final child = childAtPosition(position);
    final nodeOffset = child.node.offset;
    final localPosition = TextPosition(
        offset: position.offset - nodeOffset, affinity: position.affinity);
    final localWord = child.getWordBoundary(localPosition);
    final word = TextRange(
        start: localWord.start + nodeOffset, end: localWord.end + nodeOffset);
    final TextSelection newSelection;
    if (position.offset <= word.start) {
      newSelection = TextSelection.collapsed(
          offset: word.start, affinity: TextAffinity.downstream);
    } else {
      newSelection = TextSelection.collapsed(
          offset: word.end, affinity: TextAffinity.upstream);
    }
    _handleSelectionChange(newSelection, cause);
  }

  @override
  TextSelection? selectPositionAt({
    required Offset from,
    Offset? to,
    required SelectionChangedCause cause,
  }) {
    // _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
    if (onSelectionChanged == null) {
      return null;
    }
    final fromPosition = getPositionForOffset(from);
    final toPosition = to == null ? null : getPositionForOffset(to);

    var baseOffset = fromPosition.offset;
    var extentOffset = fromPosition.offset;
    if (toPosition != null) {
      baseOffset = math.min(fromPosition.offset, toPosition.offset);
      extentOffset = math.max(fromPosition.offset, toPosition.offset);
    }

    final newSelection = TextSelection(
      baseOffset: baseOffset,
      extentOffset: extentOffset,
      affinity: fromPosition.affinity,
    );

    // Call [onSelectionChanged] only when the selection actually changed.
    _handleSelectionChange(newSelection, cause);
    return newSelection;
  }

  @override
  void selectWord({required SelectionChangedCause cause}) {
    selectWordsInRange(from: _lastTapDownPosition!, cause: cause);
  }

  @override
  void selectPosition({required SelectionChangedCause cause}) {
    selectPositionAt(from: _lastTapDownPosition!, cause: cause);
  }

  @override
  TextSelection selectWordAtPosition(TextPosition position) {
    final word = getWordBoundary(position);
    // When long-pressing past the end of the text, we want a collapsed cursor.
    if (position.offset >= word.end) {
      return TextSelection.fromPosition(position);
    }
    return TextSelection(baseOffset: word.start, extentOffset: word.end);
  }

  @override
  TextSelection selectLineAtPosition(TextPosition position) {
    final line = getLineAtOffset(position);

    // When long-pressing past the end of the text, we want a collapsed cursor.
    if (position.offset >= line.end) {
      return TextSelection.fromPosition(position);
    }
    return TextSelection(baseOffset: line.start, extentOffset: line.end);
  }

  // Call through to onSelectionChanged.
  void _handleSelectionChange(
    TextSelection nextSelection,
    SelectionChangedCause cause,
  ) {
    final bool selectionChanged = selection != nextSelection;
    // Changes made by the keyboard can sometimes be "out of band" for listening
    // components, so always send those events, even if we didn't think it
    // changed. Also, the user long pressing should always send a selection change
    // as well.
    if (selectionChanged || cause.forcesSelectionChanged) {
      onSelectionChanged?.call(nextSelection, cause);
    }
  }

  // Start RenderBox implementation

  @override
  void performLayout() {
    assert(() {
      if (constraints.hasBoundedWidth) return true;
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary(
            'RenderEditableContainerBox must have a bounded constraint for its cross axis.'),
        ErrorDescription(
            'RenderEditableContainerBox forces its children to expand to fit the RenderEditableContainerBox\'s container, '
            'so it must be placed in a parent that constrains the cross '
            'axis to a finite dimension.'),
      ]);
    }());

    resolvePadding();
    assert(resolvedPadding != null);

    var contentSize = resolvedPadding!.top;
    var child = firstChild;
    final innerConstraints = BoxConstraints.tightFor(
            width: math.min(
                _maxContentWidth ?? double.infinity, constraints.maxWidth))
        .deflate(resolvedPadding!);
    final leftOffset = _maxContentWidth == null
        ? 0.0
        : math.max((constraints.maxWidth - _maxContentWidth!) / 2, 0);
    while (child != null) {
      child.layout(innerConstraints, parentUsesSize: true);
      final childParentData = child.parentData as EditableContainerParentData;
      childParentData.offset =
          Offset(resolvedPadding!.left + leftOffset, contentSize);
      contentSize += child.size.height;
      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }
    contentSize += resolvedPadding!.bottom;
    size = constraints
        .constrain(Size(_maxContentWidth ?? constraints.maxWidth, contentSize));
    _maxScrollExtent = math.max(0.0, contentSize - size.height);
    offset.applyViewportDimension(size.height);
    offset.applyContentDimensions(0.0, _maxScrollExtent);

    assert(size.isFinite);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _offset.addListener(markNeedsPaint);
  }

  final LayerHandle<ClipRectLayer> _clipRectLayer =
      LayerHandle<ClipRectLayer>();

  @override
  void paint(PaintingContext context, Offset offset) {
    if (hasFocus &&
        _cursorController.showCursor.value &&
        !_cursorController.style.paintAboveText) {
      _paintFloatingCursor(context, offset);
    }
    if (_hasVisualOverflow) {
      _clipRectLayer.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        (context, offset) => defaultPaint(context, offset + paintOffset),
        clipBehavior: Clip.hardEdge,
        oldLayer: _clipRectLayer.layer,
      );
    } else {
      _clipRectLayer.layer = null;
      defaultPaint(context, offset);
    }
    _updateSelectionExtentsVisibility(offset + paintOffset);
    _paintHandleLayers(context, getEndpointsForSelection(selection));

    if (hasFocus &&
        _cursorController.showCursor.value &&
        _cursorController.style.paintAboveText) {
      _paintFloatingCursor(context, offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final Offset effectivePosition = position - paintOffset;
    return defaultHitTestChildren(result, position: effectivePosition);
  }

  void _paintHandleLayers(
      PaintingContext context, List<TextSelectionPoint> endpoints) {
    var startPoint = endpoints[0].point + paintOffset;
    startPoint = Offset(
      startPoint.dx.clamp(0.0, size.width),
      startPoint.dy.clamp(0.0, size.height),
    );
    context.pushLayer(
      LeaderLayer(link: startHandleLayerLink, offset: startPoint),
      super.paint,
      Offset.zero,
    );
    if (endpoints.length == 2) {
      var endPoint = endpoints[1].point + paintOffset;
      endPoint = Offset(
        endPoint.dx.clamp(0.0, size.width),
        endPoint.dy.clamp(0.0, size.height),
      );
      context.pushLayer(
        LeaderLayer(link: endHandleLayerLink, offset: endPoint),
        super.paint,
        Offset.zero,
      );
    } else if (selection.isCollapsed) {
      context.pushLayer(
        LeaderLayer(link: endHandleLayerLink, offset: startPoint + paintOffset),
        super.paint,
        Offset.zero,
      );
    }
  }

  @override
  double preferredLineHeight(TextPosition position) {
    final child = childAtPosition(position);
    final localPosition =
        TextPosition(offset: position.offset - child.node.offset);
    return child.preferredLineHeight(localPosition);
  }

  /// The `offset` parameter must be in global coordinates.
  @override
  TextPosition getPositionForOffset(Offset offset) {
    final local = globalToLocal(offset);
    final child = childAtOffset(local - paintOffset);

    final parentData = child.parentData as BoxParentData;
    final localOffset = local - parentData.offset - paintOffset;
    final localPosition = child.getPositionForOffset(localOffset);
    return TextPosition(
      offset: localPosition.offset + child.node.offset,
      affinity: localPosition.affinity,
    );
  }

  // Override needed to account for ViewPort-like behaviour of renderer
  @override
  RenderEditableBox childAtOffset(Offset offset) {
    assert(firstChild != null);
    resolvePadding();

    if (offset.dy <= resolvedPadding!.top) return firstChild!;
    if (offset.dy >= size.height + _maxScrollExtent - resolvedPadding!.bottom) {
      return lastChild!;
    }

    var child = firstChild;
    var dy = resolvedPadding!.top;
    var dx = -offset.dx;
    while (child != null) {
      if (child.size.contains(offset.translate(dx, -dy))) {
        return child;
      }
      dy += child.size.height;
      child = childAfter(child);
    }
    return lastChild!;
  }

  @override
  Rect getLocalRectForCaret(TextPosition position) {
    final targetChild = childAtPosition(position);
    final localPosition = targetChild.globalToLocalPosition(position);

    final childLocalRect = targetChild.getLocalRectForCaret(localPosition);

    final boxParentData = targetChild.parentData as BoxParentData;
    return childLocalRect.shift(Offset(
        resolvedPadding!.left, boxParentData.offset.dy + paintOffset.dy));
  }

  // Start floating cursor

  FloatingCursorPainter get _floatingCursorPainter => FloatingCursorPainter(
        floatingCursorRect: _floatingCursorRect,
        style: _cursorController.style,
      );

  bool _floatingCursorOn = false;
  Rect? _floatingCursorRect;

  TextPosition get floatingCursorTextPosition => _floatingCursorTextPosition;
  late TextPosition _floatingCursorTextPosition;

  // The relative origin in relation to the distance the user has theoretically
  // dragged the floating cursor offscreen. This value is used to account for the
  // difference in the rendering position and the raw offset value.
  Offset _relativeOrigin = Offset.zero;
  Offset? _previousOffset;
  bool _resetOriginOnLeft = false;
  bool _resetOriginOnRight = false;
  bool _resetOriginOnTop = false;
  bool _resetOriginOnBottom = false;

  /// Returns the position within the editor closest to the raw cursor offset.
  Offset calculateBoundedFloatingCursorOffset(
      Offset rawCursorOffset, double preferredLineHeight) {
    Offset deltaPosition = Offset.zero;
    final double topBound = _kFloatingCursorAddedMargin.top;
    final double bottomBound =
        size.height - preferredLineHeight + _kFloatingCursorAddedMargin.bottom;
    final double leftBound = _kFloatingCursorAddedMargin.left;
    final double rightBound = size.width - _kFloatingCursorAddedMargin.right;

    if (_previousOffset != null) {
      deltaPosition = rawCursorOffset - _previousOffset!;
    }

    // If the raw cursor offset has gone off an edge, we want to reset the relative
    // origin of the dragging when the user drags back into the field.
    if (_resetOriginOnLeft && deltaPosition.dx > 0) {
      _relativeOrigin =
          Offset(rawCursorOffset.dx - leftBound, _relativeOrigin.dy);
      _resetOriginOnLeft = false;
    } else if (_resetOriginOnRight && deltaPosition.dx < 0) {
      _relativeOrigin =
          Offset(rawCursorOffset.dx - rightBound, _relativeOrigin.dy);
      _resetOriginOnRight = false;
    }
    if (_resetOriginOnTop && deltaPosition.dy > 0) {
      _relativeOrigin =
          Offset(_relativeOrigin.dx, rawCursorOffset.dy - topBound);
      _resetOriginOnTop = false;
    } else if (_resetOriginOnBottom && deltaPosition.dy < 0) {
      _relativeOrigin =
          Offset(_relativeOrigin.dx, rawCursorOffset.dy - bottomBound);
      _resetOriginOnBottom = false;
    }

    final double currentX = rawCursorOffset.dx - _relativeOrigin.dx;
    final double currentY = rawCursorOffset.dy - _relativeOrigin.dy;
    final double adjustedX =
        math.min(math.max(currentX, leftBound), rightBound);
    final double adjustedY =
        math.min(math.max(currentY, topBound), bottomBound);
    final Offset adjustedOffset = Offset(adjustedX, adjustedY);

    if (currentX < leftBound && deltaPosition.dx < 0) {
      _resetOriginOnLeft = true;
    } else if (currentX > rightBound && deltaPosition.dx > 0) {
      _resetOriginOnRight = true;
    }
    if (currentY < topBound && deltaPosition.dy < 0) {
      _resetOriginOnTop = true;
    } else if (currentY > bottomBound && deltaPosition.dy > 0) {
      _resetOriginOnBottom = true;
    }

    _previousOffset = rawCursorOffset;

    return adjustedOffset;
  }

  @override
  void setFloatingCursor(FloatingCursorDragState dragState,
      Offset boundedOffset, TextPosition textPosition,
      {double? resetLerpValue}) {
    if (dragState == FloatingCursorDragState.Start) {
      _relativeOrigin = Offset.zero;
      _previousOffset = null;
      _resetOriginOnBottom = false;
      _resetOriginOnTop = false;
      _resetOriginOnRight = false;
      _resetOriginOnBottom = false;
    }
    _floatingCursorOn = dragState != FloatingCursorDragState.End;
    if (_floatingCursorOn) {
      _floatingCursorTextPosition = textPosition;
      final EdgeInsets sizeAdjustment = resetLerpValue != null
          ? EdgeInsets.lerp(
              _kFloatingCaretSizeIncrease, EdgeInsets.zero, resetLerpValue)!
          : _kFloatingCaretSizeIncrease;
      final child = childAtPosition(textPosition);
      final caretPrototype =
          child.getCaretPrototype(child.globalToLocalPosition(textPosition));
      _floatingCursorRect =
          sizeAdjustment.inflateRect(caretPrototype).shift(boundedOffset);
      _cursorController
          .setFloatingCursorTextPosition(_floatingCursorTextPosition);
    } else {
      _floatingCursorRect = null;
      _cursorController.setFloatingCursorTextPosition(null);
    }
    markNeedsPaint();
  }

  void _paintFloatingCursor(PaintingContext context, Offset offset) {
    _floatingCursorPainter.paint(context.canvas);
  }

  // End floating cursor

  // Start TextLayoutMetrics implementation

  /// Return a [TextSelection] containing the line of the given [TextPosition].
  @override
  TextSelection getLineAtOffset(TextPosition position) {
    final child = childAtPosition(position);
    final nodeOffset = child.node.offset;
    final localPosition = TextPosition(
        offset: position.offset - nodeOffset, affinity: position.affinity);
    final localLineRange = child.getLineBoundary(localPosition);
    final line = TextRange(
      start: localLineRange.start + nodeOffset,
      end: localLineRange.end + nodeOffset,
    );
    return TextSelection(baseOffset: line.start, extentOffset: line.end);
  }

  @override
  TextRange getWordBoundary(TextPosition position) {
    final child = childAtPosition(position);
    final nodeOffset = child.node.offset;
    final localPosition = TextPosition(
        offset: position.offset - nodeOffset, affinity: position.affinity);
    final localWord = child.getWordBoundary(localPosition);
    return TextRange(
      start: localWord.start + nodeOffset,
      end: localWord.end + nodeOffset,
    );
  }

  /// Returns the TextPosition above the given offset into the text.
  ///
  /// If the offset is already on the first line, the offset of the first
  /// character will be returned.
  @override
  TextPosition getTextPositionAbove(TextPosition position) {
    final child = childAtPosition(position);
    final localPosition =
        TextPosition(offset: position.offset - child.node.documentOffset);

    TextPosition? newPosition = child.getPositionAbove(localPosition);

    if (newPosition == null) {
      // There was no text above in the current child, check the direct
      // sibling.
      final sibling = childBefore(child);
      if (sibling == null) {
        // reached beginning of the document, move to the
        // first character
        newPosition = const TextPosition(offset: 0);
      } else {
        // TODO: in the case of a SpanEmbed, caret is drawn with "normal" line height
        // As the caret offset is used to get the position of the above line, when the embed is much higher than the
        // caret height the "above" position doesn't change
        final caretOffset = child.getOffsetForCaret(localPosition);
        final testPosition = TextPosition(offset: sibling.node.length - 1);
        final testOffset = sibling.getOffsetForCaret(testPosition);
        // The addition of 1 point to testOffset.dy is added because somehow
        // in Flutter 3.22 the TextPainter is yielding wrong text position
        // for the offset (1 line above the correct line).
        final finalOffset = Offset(caretOffset.dx, testOffset.dy + 1);
        final siblingPosition = sibling.getPositionForOffset(finalOffset);
        newPosition = TextPosition(
            offset: sibling.node.documentOffset + siblingPosition.offset);
      }
    } else {
      newPosition =
          TextPosition(offset: child.node.documentOffset + newPosition.offset);
    }
    return newPosition;
  }

  /// Returns the TextPosition below the given offset into the text.
  ///
  /// If the offset is already on the last line, the offset of the last
  /// character will be returned.
  @override
  TextPosition getTextPositionBelow(TextPosition position) {
    final child = childAtPosition(position);
    final localPosition =
        TextPosition(offset: position.offset - child.node.documentOffset);

    TextPosition? newPosition = child.getPositionBelow(localPosition);

    if (newPosition == null) {
      // There was no text above in the current child, check the direct
      // sibling.
      final sibling = childAfter(child);
      if (sibling == null) {
        // reached beginning of the document, move to the
        // last character
        newPosition = TextPosition(offset: _document.length - 1);
      } else {
        final caretOffset = child.getOffsetForCaret(localPosition);
        const textPosition = TextPosition(offset: 0);
        final textOffset = sibling.getOffsetForCaret(textPosition);
        final finalOffset = Offset(caretOffset.dx, textOffset.dy);
        final siblingPosition = sibling.getPositionForOffset(finalOffset);
        newPosition = TextPosition(
            offset: sibling.node.documentOffset + siblingPosition.offset);
      }
    } else {
      newPosition =
          TextPosition(offset: child.node.documentOffset + newPosition.offset);
    }
    return newPosition;
  }

  // End TextLayoutMetrics implementation

  @override
  FleatherVerticalCaretMovementRun startVerticalCaretMovement(
      TextPosition startPosition) {
    return FleatherVerticalCaretMovementRun._(
      this,
      startPosition,
    );
  }

  @override
  void systemFontsDidChange() {
    super.systemFontsDidChange();
    markNeedsLayout();
  }
}

class FleatherVerticalCaretMovementRun implements Iterator<TextPosition> {
  FleatherVerticalCaretMovementRun._(
    this._editor,
    this._currentTextPosition,
  );

  TextPosition _currentTextPosition;

  final RenderEditor _editor;

  @override
  TextPosition get current {
    return _currentTextPosition;
  }

  @override
  bool moveNext() {
    final newCurrentTextPosition =
        _editor.getTextPositionBelow(_currentTextPosition);
    if (newCurrentTextPosition == _currentTextPosition) return false;
    _currentTextPosition = newCurrentTextPosition;
    return true;
  }

  /// Move back to the previous element.
  ///
  /// Returns `true` if previous exists and updates [current] if successful.
  bool movePrevious() {
    final newCurrentTextPosition =
        _editor.getTextPositionAbove(_currentTextPosition);
    if (newCurrentTextPosition == _currentTextPosition) return false;
    _currentTextPosition = newCurrentTextPosition;
    return true;
  }

  bool moveByOffset(double offset) {
    RenderEditableBox child = _editor.childAtPosition(_currentTextPosition);
    Offset currentOffset = child.localToGlobal(Offset.zero);
    final initialOffset = currentOffset;
    if (offset >= 0.0) {
      while (currentOffset.dy < initialOffset.dy + offset) {
        final didMove = moveNext();
        child = _editor.childAtPosition(_currentTextPosition);
        final lineHeight =
            child.preferredLineHeight(const TextPosition(offset: 0));
        currentOffset = child.localToGlobal(Offset(0, lineHeight));
        if (!didMove) {
          break;
        }
      }
    } else {
      while (currentOffset.dy > initialOffset.dy + offset) {
        final didMove = movePrevious();
        child = _editor.childAtPosition(_currentTextPosition);
        currentOffset = child.localToGlobal(Offset.zero);
        if (!didMove) {
          break;
        }
      }
    }
    return initialOffset != currentOffset;
  }
}

extension on SelectionChangedCause {
  bool get forcesSelectionChanged =>
      this == SelectionChangedCause.longPress ||
      this == SelectionChangedCause.keyboard ||
      this == SelectionChangedCause.doubleTap;
}
