// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../rendering/editor.dart';
import 'editor.dart';

/// The text position that a give selection handle manipulates. Dragging the
/// [start] handle always moves the [start]/[baseOffset] of the selection.
enum TextSelectionHandlePosition { start, end }

/// An object that manages a pair of text selection handles for a
/// [RenderEditable].
///
/// This class is a wrapper of [SelectionOverlay] to provide APIs specific for
/// [RenderEditable]s. To manage selection handles for custom widgets, use
/// [SelectionOverlay] instead.
class EditorTextSelectionOverlay {
  /// Creates an object that manages overlay entries for selection handles.
  ///
  /// The [context] must have an [Overlay] as an ancestor.
  EditorTextSelectionOverlay({
    required TextEditingValue value,
    required this.context,
    Widget? debugRequiredFor,
    required LayerLink toolbarLayerLink,
    required LayerLink startHandleLayerLink,
    required LayerLink endHandleLayerLink,
    required this.renderObject,
    this.selectionControls,
    bool handlesVisible = false,
    required this.selectionDelegate,
    DragStartBehavior dragStartBehavior = DragStartBehavior.start,
    VoidCallback? onSelectionHandleTapped,
    ClipboardStatusNotifier? clipboardStatus,
    required this.contextMenuBuilder,
    required TextMagnifierConfiguration magnifierConfiguration,
  })  : _handlesVisible = handlesVisible,
        _value = value {
    renderObject.selectionStartInViewport
        .addListener(_updateTextSelectionOverlayVisibilities);
    renderObject.selectionEndInViewport
        .addListener(_updateTextSelectionOverlayVisibilities);
    _updateTextSelectionOverlayVisibilities();
    _selectionOverlay = SelectionOverlay(
      magnifierConfiguration: magnifierConfiguration,
      context: context,
      renderEditor: renderObject,
      debugRequiredFor: debugRequiredFor,
      // The metrics will be set when show handles.
      startHandleType: TextSelectionHandleType.collapsed,
      startHandlesVisible: _effectiveStartHandleVisibility,
      lineHeightAtStart: 0.0,
      onStartHandleDragStart: _handleSelectionStartHandleDragStart,
      onStartHandleDragUpdate: _handleSelectionStartHandleDragUpdate,
      onEndHandleDragEnd: _handleAnyDragEnd,
      endHandleType: TextSelectionHandleType.collapsed,
      endHandlesVisible: _effectiveEndHandleVisibility,
      lineHeightAtEnd: 0.0,
      onEndHandleDragStart: _handleSelectionEndHandleDragStart,
      onEndHandleDragUpdate: _handleSelectionEndHandleDragUpdate,
      onStartHandleDragEnd: _handleAnyDragEnd,
      toolbarVisible: _effectiveToolbarVisibility,
      selectionEndpoints: const <TextSelectionPoint>[],
      selectionControls: selectionControls,
      selectionDelegate: selectionDelegate,
      clipboardStatus: clipboardStatus,
      startHandleLayerLink: startHandleLayerLink,
      endHandleLayerLink: endHandleLayerLink,
      toolbarLayerLink: toolbarLayerLink,
      onSelectionHandleTapped: onSelectionHandleTapped,
      dragStartBehavior: dragStartBehavior,
      toolbarLocation: renderObject.lastSecondaryTapDownPosition,
    );
  }

  /// {@template flutter.widgets.SelectionOverlay.context}
  /// The context in which the selection UI should appear.
  ///
  /// This context must have an [Overlay] as an ancestor because this object
  /// will display the text selection handles in that [Overlay].
  /// {@endtemplate}
  final BuildContext context;

  // TODO(mpcomplete): what if the renderObject is removed or replaced, or
  // moves? Not sure what cases I need to handle, or how to handle them.
  /// The editable line in which the selected text is being displayed.
  final RenderEditor renderObject;

  /// {@macro flutter.widgets.SelectionOverlay.selectionControls}
  final TextSelectionControls? selectionControls;

  /// {@macro flutter.widgets.SelectionOverlay.selectionDelegate}
  final TextSelectionDelegate selectionDelegate;

  late final SelectionOverlay _selectionOverlay;

  /// {@macro flutter.widgets.EditableText.contextMenuBuilder}
  final WidgetBuilder contextMenuBuilder;

  /// Retrieve current value.
  @visibleForTesting
  TextEditingValue get value => _value;

  TextEditingValue _value;

  TextSelection get _selection => _value.selection;

  final ValueNotifier<bool> _effectiveStartHandleVisibility =
      ValueNotifier<bool>(false);
  final ValueNotifier<bool> _effectiveEndHandleVisibility =
      ValueNotifier<bool>(false);
  final ValueNotifier<bool> _effectiveToolbarVisibility =
      ValueNotifier<bool>(false);

  void _updateTextSelectionOverlayVisibilities() {
    _effectiveStartHandleVisibility.value =
        _handlesVisible && renderObject.selectionStartInViewport.value;
    _effectiveEndHandleVisibility.value =
        _handlesVisible && renderObject.selectionEndInViewport.value;
    _effectiveToolbarVisibility.value =
        renderObject.selectionStartInViewport.value ||
            renderObject.selectionEndInViewport.value;
  }

  /// Whether selection handles are visible.
  ///
  /// Set to false if you want to hide the handles. Use this property to show or
  /// hide the handle without rebuilding them.
  ///
  /// Defaults to false.
  bool get handlesVisible => _handlesVisible;
  bool _handlesVisible = false;

  set handlesVisible(bool visible) {
    if (_handlesVisible == visible) {
      return;
    }
    _handlesVisible = visible;
    _updateTextSelectionOverlayVisibilities();
  }

  /// {@macro flutter.widgets.SelectionOverlay.showHandles}
  void showHandles() {
    _updateSelectionOverlay();
    _selectionOverlay.showHandles();
  }

  /// {@macro flutter.widgets.SelectionOverlay.hideHandles}
  void hideHandles() => _selectionOverlay.hideHandles();

  /// {@macro flutter.widgets.SelectionOverlay.showToolbar}
  void showToolbar() {
    _updateSelectionOverlay();
    assert(context.mounted);
    _selectionOverlay.showToolbar(
      context: context,
      contextMenuBuilder: contextMenuBuilder,
    );
  }

  /// {@macro flutter.widgets.SelectionOverlay.showMagnifier}
  void showMagnifier(Offset positionToShow) {
    final TextPosition position =
        renderObject.getPositionForOffset(positionToShow);
    _updateSelectionOverlay();
    _selectionOverlay.showMagnifier(
      _buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: positionToShow,
        renderEditor: renderObject,
      ),
    );
  }

  /// {@macro flutter.widgets.SelectionOverlay.updateMagnifier}
  void updateMagnifier(Offset positionToShow) {
    final TextPosition position =
        renderObject.getPositionForOffset(positionToShow);
    _updateSelectionOverlay();
    _selectionOverlay.updateMagnifier(
      _buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: positionToShow,
        renderEditor: renderObject,
      ),
    );
  }

  /// {@macro fleather.widgets.SelectionOverlay.hideMagnifier}
  void hideMagnifier() {
    _selectionOverlay.hideMagnifier();
  }

  /// Shows toolbar with spell check suggestions of misspelled words that are
  /// available for click-and-replace.
  void showSpellCheckSuggestionsToolbar(
      WidgetBuilder spellCheckSuggestionsToolbarBuilder) {
    _updateSelectionOverlay();
    assert(context.mounted);
    _selectionOverlay.showSpellCheckSuggestionsToolbar(
      context: context,
      builder: spellCheckSuggestionsToolbarBuilder,
    );
    hideHandles();
  }

  /// Updates the overlay after the selection has changed.
  ///
  /// If this method is called while the [SchedulerBinding.schedulerPhase] is
  /// [SchedulerPhase.persistentCallbacks], i.e. during the build, layout, or
  /// paint phases (see [WidgetsBinding.drawFrame]), then the update is delayed
  /// until the post-frame callbacks phase. Otherwise the update is done
  /// synchronously. This means that it is safe to call during builds, but also
  /// that if you do call this during a build, the UI will not update until the
  /// next frame (i.e. many milliseconds later).
  void update(TextEditingValue newValue) {
    if (_value == newValue) {
      return;
    }
    _value = newValue;
    SchedulerBinding.instance
        .addPostFrameCallback((_) => _updateSelectionOverlay());
    // _updateSelectionOverlay may not rebuild the selection overlay if the
    // text metrics and selection doesn't change even if the text has changed.
    // This rebuild is needed for the toolbar to update based on the latest text
    // value.
    _selectionOverlay.markNeedsBuild();
  }

  void _updateSelectionOverlay() {
    // Swap occurs when dragging start handle on Apple systems
    final isAppleSwapped =
        selectionDelegate.textEditingValue.selection.baseOffset >
            selectionDelegate.textEditingValue.selection.extentOffset;
    _selectionOverlay
      // Update selection handle metrics.
      ..startHandleType = _chooseType(
        renderObject.textDirection,
        TextSelectionHandleType.left,
        TextSelectionHandleType.right,
      )
      // TODO: use _getStartGlyphHeight when adapted from flutter
      ..lineHeightAtStart = renderObject.preferredLineHeight(isAppleSwapped
          ? selectionDelegate.textEditingValue.selection.extent
          : selectionDelegate.textEditingValue.selection.base)
      ..endHandleType = _chooseType(
        renderObject.textDirection,
        TextSelectionHandleType.right,
        TextSelectionHandleType.left,
      )
      // TODO: use _getEndGlyphHeight when adapted from flutter
      ..lineHeightAtEnd = renderObject.preferredLineHeight(isAppleSwapped
          ? selectionDelegate.textEditingValue.selection.base
          : selectionDelegate.textEditingValue.selection.extent)
      // Update selection toolbar metrics.
      ..selectionEndpoints = renderObject.getEndpointsForSelection(_selection)
      ..toolbarLocation = renderObject.lastSecondaryTapDownPosition;
  }

  /// Causes the overlay to update its rendering.
  ///
  /// This is intended to be called when the [renderObject] may have changed its
  /// text metrics (e.g. because the text was scrolled).
  void updateForScroll() {
    _updateSelectionOverlay();
    // This method may be called due to windows metrics changes. In that case,
    // non of the properties in _selectionOverlay will change, but a rebuild is
    // still needed.
    _selectionOverlay.markNeedsBuild();
  }

  /// Whether the handles are currently visible.
  bool get handlesAreVisible =>
      _selectionOverlay._handles != null && handlesVisible;

  /// {@macro flutter.widgets.SelectionOverlay.toolbarIsVisible}
  ///
  /// See also:
  ///
  ///   * [spellCheckToolbarIsVisible], which is only whether the spell check menu
  ///     specifically is visible.
  bool get toolbarIsVisible => _selectionOverlay.toolbarIsVisible;

  /// Whether the magnifier is currently visible.
  bool get magnifierIsVisible => _selectionOverlay._magnifierController.shown;

  /// Whether the spell check menu is currently visible.
  ///
  /// See also:
  ///
  ///   * [toolbarIsVisible], which is whether any toolbar is visible.
  bool get spellCheckToolbarIsVisible =>
      _selectionOverlay._spellCheckToolbarController.isShown;

  /// {@macro flutter.widgets.SelectionOverlay.hide}
  void hide() => _selectionOverlay.hide();

  /// {@macro flutter.widgets.SelectionOverlay.hideToolbar}
  void hideToolbar() => _selectionOverlay.hideToolbar();

  /// {@macro flutter.widgets.SelectionOverlay.dispose}
  void dispose() {
    _selectionOverlay.dispose();
    renderObject.selectionStartInViewport
        .removeListener(_updateTextSelectionOverlayVisibilities);
    renderObject.selectionEndInViewport
        .removeListener(_updateTextSelectionOverlayVisibilities);
    _effectiveToolbarVisibility.dispose();
    _effectiveStartHandleVisibility.dispose();
    _effectiveEndHandleVisibility.dispose();
    hideToolbar();
  }

  MagnifierInfo _buildMagnifier({
    required RenderEditor renderEditor,
    required Offset globalGesturePosition,
    required TextPosition currentTextPosition,
  }) {
    final Offset globalRenderEditableTopLeft =
        renderEditor.localToGlobal(Offset.zero);
    final Rect localCaretRect =
        renderEditor.getLocalRectForCaret(currentTextPosition);

    final TextSelection lineAtOffset =
        renderEditor.getLineAtOffset(currentTextPosition);
    final TextPosition positionAtEndOfLine = TextPosition(
      offset: lineAtOffset.extentOffset,
      affinity: TextAffinity.upstream,
    );

    // Default affinity is downstream.
    final TextPosition positionAtBeginningOfLine = TextPosition(
      offset: lineAtOffset.baseOffset,
    );

    final Rect lineBoundaries = Rect.fromPoints(
      renderEditor.getLocalRectForCaret(positionAtBeginningOfLine).topCenter,
      renderEditor.getLocalRectForCaret(positionAtEndOfLine).bottomCenter,
    );

    return MagnifierInfo(
      fieldBounds: globalRenderEditableTopLeft & renderEditor.size,
      globalGesturePosition: globalGesturePosition,
      caretRect: localCaretRect.shift(globalRenderEditableTopLeft),
      currentLineBoundaries: lineBoundaries.shift(globalRenderEditableTopLeft),
    );
  }

  // The contact position of the gesture at the current end handle location.
  // Updated when the handle moves.
  late double _endHandleDragPosition;

  // The distance from _endHandleDragPosition to the center of the line that it
  // corresponds to.
  late double _endHandleDragPositionToCenterOfLine;

  void _handleSelectionEndHandleDragStart(DragStartDetails details) {
    if (!renderObject.attached) {
      return;
    }

    // This adjusts for the fact that the selection handles may not
    // perfectly cover the TextPosition that they correspond to.
    _endHandleDragPosition = details.globalPosition.dy;
    final Offset endPoint = renderObject
        .localToGlobal(_selectionOverlay.selectionEndpoints.last.point);
    final double centerOfLine = endPoint.dy -
        renderObject.preferredLineHeight(
                selectionDelegate.textEditingValue.selection.extent) /
            2;
    _endHandleDragPositionToCenterOfLine =
        centerOfLine - _endHandleDragPosition;
    final TextPosition position = renderObject.getPositionForOffset(
      Offset(
        details.globalPosition.dx,
        centerOfLine,
      ),
    );

    _selectionOverlay.showMagnifier(
      _buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: details.globalPosition,
        renderEditor: renderObject,
      ),
    );
  }

  /// Given a handle position and drag position, returns the position of handle
  /// after the drag.
  ///
  /// The handle jumps instantly between lines when the drag reaches a full
  /// line's height away from the original handle position. In other words, the
  /// line jump happens when the contact point would be located at the same
  /// place on the handle at the new line as when the gesture started.
  double _getHandleDy(
      double dragDy, double handleDy, TextSelectionHandleType handleType) {
    final double distanceDragged = dragDy - handleDy;
    final int dragDirection = distanceDragged < 0.0 ? -1 : 1;
    final lineHeight = renderObject.preferredLineHeight(
        handleType == TextSelectionHandleType.left
            ? selectionDelegate.textEditingValue.selection.base
            : selectionDelegate.textEditingValue.selection.extent);
    final int linesDragged =
        dragDirection * (distanceDragged.abs() / lineHeight).floor();
    return handleDy + linesDragged * lineHeight;
  }

  void _handleSelectionEndHandleDragUpdate(DragUpdateDetails details) {
    if (!renderObject.attached) {
      return;
    }

    _endHandleDragPosition = _getHandleDy(details.globalPosition.dy,
        _endHandleDragPosition, TextSelectionHandleType.right);
    final Offset adjustedOffset = Offset(
      details.globalPosition.dx,
      _endHandleDragPosition + _endHandleDragPositionToCenterOfLine,
    );

    final TextPosition position =
        renderObject.getPositionForOffset(adjustedOffset);
    selectionDelegate.bringIntoView(position);

    if (_selection.isCollapsed) {
      _selectionOverlay.updateMagnifier(_buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: details.globalPosition,
        renderEditor: renderObject,
      ));

      final TextSelection currentSelection =
          TextSelection.fromPosition(position);
      _handleSelectionHandleChanged(currentSelection);
      return;
    }

    final TextSelection newSelection;
    switch (defaultTargetPlatform) {
      // On Apple platforms, dragging the base handle makes it the extent.
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        newSelection = TextSelection(
          extentOffset: position.offset,
          baseOffset: _selection.start,
        );
        if (position.offset <= _selection.start) {
          return; // Don't allow order swapping.
        }
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        newSelection = TextSelection(
          baseOffset: _selection.baseOffset,
          extentOffset: position.offset,
        );
        if (newSelection.baseOffset >= newSelection.extentOffset) {
          return; // Don't allow order swapping.
        }
    }

    _handleSelectionHandleChanged(newSelection);

    _selectionOverlay.updateMagnifier(_buildMagnifier(
      currentTextPosition: newSelection.extent,
      globalGesturePosition: details.globalPosition,
      renderEditor: renderObject,
    ));
  }

  // The contact position of the gesture at the current start handle location.
  // Updated when the handle moves.
  late double _startHandleDragPosition;

  // The distance from _startHandleDragPosition to the center of the line that
  // it corresponds to.
  late double _startHandleDragPositionToCenterOfLine;

  void _handleSelectionStartHandleDragStart(DragStartDetails details) {
    if (!renderObject.attached) {
      return;
    }

    // This adjusts for the fact that the selection handles may not
    // perfectly cover the TextPosition that they correspond to.
    _startHandleDragPosition = details.globalPosition.dy;
    final Offset startPoint = renderObject
        .localToGlobal(_selectionOverlay.selectionEndpoints.first.point);
    final double centerOfLine = startPoint.dy -
        renderObject.preferredLineHeight(
                selectionDelegate.textEditingValue.selection.extent) /
            2;
    _startHandleDragPositionToCenterOfLine =
        centerOfLine - _startHandleDragPosition;
    final TextPosition position = renderObject.getPositionForOffset(
      Offset(
        details.globalPosition.dx,
        centerOfLine,
      ),
    );

    _selectionOverlay.showMagnifier(
      _buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: details.globalPosition,
        renderEditor: renderObject,
      ),
    );
  }

  void _handleSelectionStartHandleDragUpdate(DragUpdateDetails details) {
    if (!renderObject.attached) {
      return;
    }

    _startHandleDragPosition = _getHandleDy(details.globalPosition.dy,
        _startHandleDragPosition, TextSelectionHandleType.left);
    final Offset adjustedOffset = Offset(
      details.globalPosition.dx,
      _startHandleDragPosition + _startHandleDragPositionToCenterOfLine,
    );
    final TextPosition position =
        renderObject.getPositionForOffset(adjustedOffset);
    selectionDelegate.bringIntoView(position);

    if (_selection.isCollapsed) {
      _selectionOverlay.updateMagnifier(_buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: details.globalPosition,
        renderEditor: renderObject,
      ));

      final TextSelection currentSelection =
          TextSelection.fromPosition(position);
      _handleSelectionHandleChanged(currentSelection);
      return;
    }

    final TextSelection newSelection;
    switch (defaultTargetPlatform) {
      // On Apple platforms, dragging the base handle makes it the extent.
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        newSelection = TextSelection(
          extentOffset: position.offset,
          baseOffset: _selection.end,
        );
        if (newSelection.extentOffset >= _selection.end) {
          return; // Don't allow order swapping.
        }
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        newSelection = TextSelection(
          baseOffset: position.offset,
          extentOffset: _selection.extentOffset,
        );
        if (newSelection.baseOffset >= newSelection.extentOffset) {
          return; // Don't allow order swapping.
        }
    }

    _selectionOverlay.updateMagnifier(_buildMagnifier(
      currentTextPosition: newSelection.extent.offset < newSelection.base.offset
          ? newSelection.extent
          : newSelection.base,
      globalGesturePosition: details.globalPosition,
      renderEditor: renderObject,
    ));

    _handleSelectionHandleChanged(newSelection);
  }

  void _handleAnyDragEnd(DragEndDetails details) {
    if (!context.mounted) {
      return;
    }

    _selectionOverlay.hideMagnifier();
    if (!_selection.isCollapsed) {
      _selectionOverlay.showToolbar(
        context: context,
        contextMenuBuilder: contextMenuBuilder,
      );
    }
    return;
  }

  void _handleSelectionHandleChanged(TextSelection newSelection) {
    selectionDelegate.userUpdateTextEditingValue(
      _value.copyWith(selection: newSelection),
      SelectionChangedCause.drag,
    );
  }

  TextSelectionHandleType _chooseType(
    TextDirection textDirection,
    TextSelectionHandleType ltrType,
    TextSelectionHandleType rtlType,
  ) {
    if (_selection.isCollapsed) {
      return TextSelectionHandleType.collapsed;
    }

    switch (textDirection) {
      case TextDirection.ltr:
        return ltrType;
      case TextDirection.rtl:
        return rtlType;
    }
  }
}

/// An object that manages a pair of selection handles and a toolbar.
///
/// The selection handles are displayed in the [Overlay] that most closely
/// encloses the given [BuildContext].
class SelectionOverlay {
  /// Creates an object that manages overlay entries for selection handles.
  ///
  /// The [context] must have an [Overlay] as an ancestor.
  SelectionOverlay({
    required this.context,
    required this.renderEditor,
    this.debugRequiredFor,
    required TextSelectionHandleType startHandleType,
    required double lineHeightAtStart,
    this.startHandlesVisible,
    this.onStartHandleDragStart,
    this.onStartHandleDragUpdate,
    this.onStartHandleDragEnd,
    required TextSelectionHandleType endHandleType,
    required double lineHeightAtEnd,
    this.endHandlesVisible,
    this.onEndHandleDragStart,
    this.onEndHandleDragUpdate,
    this.onEndHandleDragEnd,
    this.toolbarVisible,
    required List<TextSelectionPoint> selectionEndpoints,
    required this.selectionControls,
    @Deprecated(
      'Use `contextMenuBuilder` in `showToolbar` instead. '
      'This feature was deprecated after v3.3.0-0.5.pre.',
    )
    required this.selectionDelegate,
    required this.clipboardStatus,
    required this.startHandleLayerLink,
    required this.endHandleLayerLink,
    required this.toolbarLayerLink,
    this.dragStartBehavior = DragStartBehavior.start,
    this.onSelectionHandleTapped,
    @Deprecated(
      'Use `contextMenuBuilder` in `showToolbar` instead. '
      'This feature was deprecated after v3.3.0-0.5.pre.',
    )
    Offset? toolbarLocation,
    this.magnifierConfiguration = TextMagnifierConfiguration.disabled,
  })  : _startHandleType = startHandleType,
        _lineHeightAtStart = lineHeightAtStart,
        _endHandleType = endHandleType,
        _lineHeightAtEnd = lineHeightAtEnd,
        _selectionEndpoints = selectionEndpoints,
        _toolbarLocation = toolbarLocation,
        assert(debugCheckHasOverlay(context));

  /// {@macro flutter.widgets.SelectionOverlay.context}
  final BuildContext context;

  final RenderEditor renderEditor;

  final ValueNotifier<MagnifierInfo> _magnifierInfo =
      ValueNotifier<MagnifierInfo>(MagnifierInfo.empty);

  /// [MagnifierController.show] and [MagnifierController.hide] should not be called directly, except
  /// from inside [showMagnifier] and [hideMagnifier]. If it is desired to show or hide the magnifier,
  /// call [showMagnifier] or [hideMagnifier]. This is because the magnifier needs to orchestrate
  /// with other properties in [SelectionOverlay].
  final MagnifierController _magnifierController = MagnifierController();

  /// {@macro flutter.widgets.magnifier.TextMagnifierConfiguration.intro}
  ///
  /// {@macro flutter.widgets.magnifier.intro}
  ///
  /// By default, [SelectionOverlay]'s [TextMagnifierConfiguration] is disabled.
  ///
  /// {@macro flutter.widgets.magnifier.TextMagnifierConfiguration.details}
  final TextMagnifierConfiguration magnifierConfiguration;

  /// {@template flutter.widgets.SelectionOverlay.toolbarIsVisible}
  /// Whether the toolbar is currently visible.
  ///
  /// Includes both the text selection toolbar and the spell check menu.
  /// {@endtemplate}
  bool get toolbarIsVisible {
    return _contextMenuController.isShown ||
        _spellCheckToolbarController.isShown;
  }

  /// {@template flutter.widgets.SelectionOverlay.showMagnifier}
  /// Shows the magnifier, and hides the toolbar if it was showing when [showMagnifier]
  /// was called. This is safe to call on platforms not mobile, since
  /// a magnifierBuilder will not be provided, or the magnifierBuilder will return null
  /// on platforms not mobile.
  ///
  /// This is NOT the source of truth for if the magnifier is up or not,
  /// since magnifiers may hide themselves. If this info is needed, check
  /// [MagnifierController.shown].
  /// {@endtemplate}
  void showMagnifier(MagnifierInfo initialMagnifierInfo) {
    if (toolbarIsVisible) {
      hideToolbar();
    }

    // Start from empty, so we don't utilize any remnant values.
    _magnifierInfo.value = initialMagnifierInfo;

    // Pre-build the magnifiers so we can tell if we've built something
    // or not. If we don't build a magnifiers, then we should not
    // insert anything in the overlay.
    final Widget? builtMagnifier = magnifierConfiguration.magnifierBuilder(
      context,
      _magnifierController,
      _magnifierInfo,
    );

    if (builtMagnifier == null) {
      return;
    }

    _magnifierController.show(
        context: context,
        below: magnifierConfiguration.shouldDisplayHandlesInMagnifier
            ? null
            : _handles?.first,
        builder: (_) => builtMagnifier);
  }

  /// {@template flutter.widgets.SelectionOverlay.hideMagnifier}
  /// Hide the current magnifier.
  ///
  /// This does nothing if there is no magnifier.
  /// {@endtemplate}
  void hideMagnifier() {
    // This cannot be a check on `MagnifierController.shown`, since
    // it's possible that the magnifier is still in the overlay, but
    // not shown in cases where the magnifier hides itself.
    if (_magnifierController.overlayEntry == null) {
      return;
    }

    _magnifierController.hide();
  }

  /// The type of start selection handle.
  ///
  /// Changing the value while the handles are visible causes them to rebuild.
  TextSelectionHandleType get startHandleType => _startHandleType;
  TextSelectionHandleType _startHandleType;

  set startHandleType(TextSelectionHandleType value) {
    if (_startHandleType == value) {
      return;
    }
    _startHandleType = value;
    markNeedsBuild();
  }

  /// The line height at the selection start.
  ///
  /// This value is used for calculating the size of the start selection handle.
  ///
  /// Changing the value while the handles are visible causes them to rebuild.
  double get lineHeightAtStart => _lineHeightAtStart;
  double _lineHeightAtStart;

  set lineHeightAtStart(double value) {
    if (_lineHeightAtStart == value) {
      return;
    }
    _lineHeightAtStart = value;
    markNeedsBuild();
  }

  bool _isDraggingStartHandle = false;

  /// Whether the start handle is visible.
  ///
  /// If the value changes, the start handle uses [FadeTransition] to transition
  /// itself on and off the screen.
  ///
  /// If this is null, the start selection handle will always be visible.
  final ValueListenable<bool>? startHandlesVisible;

  /// Called when the users start dragging the start selection handles.
  final ValueChanged<DragStartDetails>? onStartHandleDragStart;

  void _handleStartHandleDragStart(DragStartDetails details) {
    assert(!_isDraggingStartHandle);
    // Calling OverlayEntry.remove may not happen until the following frame, so
    // it's possible for the handles to receive a gesture after calling remove.
    if (_handles == null) {
      _isDraggingStartHandle = false;
      return;
    }
    _isDraggingStartHandle = details.kind == PointerDeviceKind.touch;
    onStartHandleDragStart?.call(details);
  }

  void _handleStartHandleDragUpdate(DragUpdateDetails details) {
    // Calling OverlayEntry.remove may not happen until the following frame, so
    // it's possible for the handles to receive a gesture after calling remove.
    if (_handles == null) {
      _isDraggingStartHandle = false;
      return;
    }
    onStartHandleDragUpdate?.call(details);
  }

  /// Called when the users drag the start selection handles to new locations.
  final ValueChanged<DragUpdateDetails>? onStartHandleDragUpdate;

  /// Called when the users lift their fingers after dragging the start selection
  /// handles.
  final ValueChanged<DragEndDetails>? onStartHandleDragEnd;

  void _handleStartHandleDragEnd(DragEndDetails details) {
    _isDraggingStartHandle = false;
    // Calling OverlayEntry.remove may not happen until the following frame, so
    // it's possible for the handles to receive a gesture after calling remove.
    if (_handles == null) {
      return;
    }
    onStartHandleDragEnd?.call(details);
  }

  /// The type of end selection handle.
  ///
  /// Changing the value while the handles are visible causes them to rebuild.
  TextSelectionHandleType get endHandleType => _endHandleType;
  TextSelectionHandleType _endHandleType;

  set endHandleType(TextSelectionHandleType value) {
    if (_endHandleType == value) {
      return;
    }
    _endHandleType = value;
    markNeedsBuild();
  }

  /// The line height at the selection end.
  ///
  /// This value is used for calculating the size of the end selection handle.
  ///
  /// Changing the value while the handles are visible causes them to rebuild.
  double get lineHeightAtEnd => _lineHeightAtEnd;
  double _lineHeightAtEnd;

  set lineHeightAtEnd(double value) {
    if (_lineHeightAtEnd == value) {
      return;
    }
    _lineHeightAtEnd = value;
    markNeedsBuild();
  }

  bool _isDraggingEndHandle = false;

  /// Whether the end handle is visible.
  ///
  /// If the value changes, the end handle uses [FadeTransition] to transition
  /// itself on and off the screen.
  ///
  /// If this is null, the end selection handle will always be visible.
  final ValueListenable<bool>? endHandlesVisible;

  /// Called when the users start dragging the end selection handles.
  final ValueChanged<DragStartDetails>? onEndHandleDragStart;

  void _handleEndHandleDragStart(DragStartDetails details) {
    assert(!_isDraggingEndHandle);
    // Calling OverlayEntry.remove may not happen until the following frame, so
    // it's possible for the handles to receive a gesture after calling remove.
    if (_handles == null) {
      _isDraggingEndHandle = false;
      return;
    }
    _isDraggingEndHandle = details.kind == PointerDeviceKind.touch;
    onEndHandleDragStart?.call(details);
  }

  void _handleEndHandleDragUpdate(DragUpdateDetails details) {
    // Calling OverlayEntry.remove may not happen until the following frame, so
    // it's possible for the handles to receive a gesture after calling remove.
    if (_handles == null) {
      _isDraggingEndHandle = false;
      return;
    }
    onEndHandleDragUpdate?.call(details);
  }

  /// Called when the users drag the end selection handles to new locations.
  final ValueChanged<DragUpdateDetails>? onEndHandleDragUpdate;

  /// Called when the users lift their fingers after dragging the end selection
  /// handles.
  final ValueChanged<DragEndDetails>? onEndHandleDragEnd;

  void _handleEndHandleDragEnd(DragEndDetails details) {
    _isDraggingEndHandle = false;
    // Calling OverlayEntry.remove may not happen until the following frame, so
    // it's possible for the handles to receive a gesture after calling remove.
    if (_handles == null) {
      return;
    }
    onEndHandleDragEnd?.call(details);
  }

  /// Whether the toolbar is visible.
  ///
  /// If the value changes, the toolbar uses [FadeTransition] to transition
  /// itself on and off the screen.
  ///
  /// If this is null the toolbar will always be visible.
  final ValueListenable<bool>? toolbarVisible;

  /// The text selection positions of selection start and end.
  List<TextSelectionPoint> get selectionEndpoints => _selectionEndpoints;
  List<TextSelectionPoint> _selectionEndpoints;

  set selectionEndpoints(List<TextSelectionPoint> value) {
    if (!listEquals(_selectionEndpoints, value)) {
      markNeedsBuild();
      if (_isDraggingEndHandle || _isDraggingStartHandle) {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            HapticFeedback.selectionClick();
          case TargetPlatform.fuchsia:
          case TargetPlatform.iOS:
          case TargetPlatform.linux:
          case TargetPlatform.macOS:
          case TargetPlatform.windows:
            break;
        }
      }
    }
    _selectionEndpoints = value;
  }

  /// Debugging information for explaining why the [Overlay] is required.
  final Widget? debugRequiredFor;

  /// The object supplied to the [CompositedTransformTarget] that wraps the text
  /// field.
  final LayerLink toolbarLayerLink;

  /// The objects supplied to the [CompositedTransformTarget] that wraps the
  /// location of start selection handle.
  final LayerLink startHandleLayerLink;

  /// The objects supplied to the [CompositedTransformTarget] that wraps the
  /// location of end selection handle.
  final LayerLink endHandleLayerLink;

  /// {@template flutter.widgets.SelectionOverlay.selectionControls}
  /// Builds text selection handles and toolbar.
  /// {@endtemplate}
  final TextSelectionControls? selectionControls;

  /// {@template flutter.widgets.SelectionOverlay.selectionDelegate}
  /// The delegate for manipulating the current selection in the owning
  /// text field.
  /// {@endtemplate}
  @Deprecated(
    'Use `contextMenuBuilder` instead. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  final TextSelectionDelegate? selectionDelegate;

  /// Determines the way that drag start behavior is handled.
  ///
  /// If set to [DragStartBehavior.start], handle drag behavior will
  /// begin at the position where the drag gesture won the arena. If set to
  /// [DragStartBehavior.down] it will begin at the position where a down
  /// event is first detected.
  ///
  /// In general, setting this to [DragStartBehavior.start] will make drag
  /// animation smoother and setting it to [DragStartBehavior.down] will make
  /// drag behavior feel slightly more reactive.
  ///
  /// By default, the drag start behavior is [DragStartBehavior.start].
  ///
  /// See also:
  ///
  ///  * [DragGestureRecognizer.dragStartBehavior], which gives an example for the different behaviors.
  final DragStartBehavior dragStartBehavior;

  /// {@template flutter.widgets.SelectionOverlay.onSelectionHandleTapped}
  /// A callback that's optionally invoked when a selection handle is tapped.
  ///
  /// The [TextSelectionControls.buildHandle] implementation the text field
  /// uses decides where the handle's tap "hotspot" is, or whether the
  /// selection handle supports tap gestures at all. For instance,
  /// [MaterialTextSelectionControls] calls [onSelectionHandleTapped] when the
  /// selection handle's "knob" is tapped, while
  /// [CupertinoTextSelectionControls] builds a handle that's not sufficiently
  /// large for tapping (as it's not meant to be tapped) so it does not call
  /// [onSelectionHandleTapped] even when tapped.
  /// {@endtemplate}
  // See https://github.com/flutter/flutter/issues/39376#issuecomment-848406415
  // for provenance.
  final VoidCallback? onSelectionHandleTapped;

  /// Maintains the status of the clipboard for determining if its contents can
  /// be pasted or not.
  ///
  /// Useful because the actual value of the clipboard can only be checked
  /// asynchronously (see [Clipboard.getData]).
  final ClipboardStatusNotifier? clipboardStatus;

  /// The location of where the toolbar should be drawn in relative to the
  /// location of [toolbarLayerLink].
  ///
  /// If this is null, the toolbar is drawn based on [selectionEndpoints] and
  /// the rect of render object of [context].
  ///
  /// This is useful for displaying toolbars at the mouse right-click locations
  /// in desktop devices.
  @Deprecated(
    'Use the `contextMenuBuilder` parameter in `showToolbar` instead. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  Offset? get toolbarLocation => _toolbarLocation;
  Offset? _toolbarLocation;

  set toolbarLocation(Offset? value) {
    if (_toolbarLocation == value) {
      return;
    }
    _toolbarLocation = value;
    markNeedsBuild();
  }

  /// Controls the fade-in and fade-out animations for the toolbar and handles.
  static const Duration fadeDuration = Duration(milliseconds: 150);

  /// A pair of handles. If this is non-null, there are always 2, though the
  /// second is hidden when the selection is collapsed.
  List<OverlayEntry>? _handles;

  /// A copy/paste toolbar.
  OverlayEntry? _toolbar;

  // Manages the context menu. Not necessarily visible when non-null.
  final ContextMenuController _contextMenuController = ContextMenuController();

  final ContextMenuController _spellCheckToolbarController =
      ContextMenuController();

  /// {@template flutter.widgets.SelectionOverlay.showHandles}
  /// Builds the handles by inserting them into the [context]'s overlay.
  /// {@endtemplate}
  void showHandles() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_handles != null) {
        return;
      }
      _handles = <OverlayEntry>[
        OverlayEntry(builder: _buildStartHandle),
        OverlayEntry(builder: _buildEndHandle),
      ];
      Overlay.of(context, rootOverlay: true, debugRequiredFor: debugRequiredFor)
          .insertAll(_handles!);
    });
  }

  /// {@template flutter.widgets.SelectionOverlay.hideHandles}
  /// Destroys the handles by removing them from overlay.
  /// {@endtemplate}
  void hideHandles() {
    if (_handles != null) {
      _handles![0].remove();
      _handles![0].dispose();
      _handles![1].remove();
      _handles![1].dispose();
      _handles = null;
    }
  }

  /// Shows the toolbar by inserting it into the [context]'s overlay.
  void showToolbar(
      {required BuildContext context,
      required WidgetBuilder contextMenuBuilder}) {
    final RenderBox renderBox = context.findRenderObject()! as RenderBox;
    _contextMenuController.show(
      context: context,
      contextMenuBuilder: (BuildContext context) {
        return _SelectionToolbarWrapper(
          layerLink: toolbarLayerLink,
          offset: -renderBox.localToGlobal(Offset.zero) +
              Offset(0, renderEditor.offset?.pixels ?? 0.0),
          child: contextMenuBuilder(context),
        );
      },
    );
  }

  /// Shows toolbar with spell check suggestions of misspelled words that are
  /// available for click-and-replace.
  void showSpellCheckSuggestionsToolbar({
    BuildContext? context,
    required WidgetBuilder builder,
  }) {
    if (context == null) {
      return;
    }

    final RenderBox renderBox = context.findRenderObject()! as RenderBox;
    _spellCheckToolbarController.show(
      context: context,
      contextMenuBuilder: (BuildContext context) {
        return _SelectionToolbarWrapper(
          layerLink: toolbarLayerLink,
          offset: -renderBox.localToGlobal(Offset.zero) +
              Offset(0, renderEditor.offset?.pixels ?? 0.0),
          child: builder(context),
        );
      },
    );
  }

  bool _buildScheduled = false;

  /// Rebuilds the selection toolbar or handles if they are present.
  void markNeedsBuild() {
    if (_handles == null && _toolbar == null) {
      return;
    }
    // If we are in build state, it will be too late to update visibility.
    // We will need to schedule the build in next frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_buildScheduled) {
        return;
      }
      _buildScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((Duration duration) {
        _buildScheduled = false;
        if (_handles != null) {
          _handles![0].markNeedsBuild();
          _handles![1].markNeedsBuild();
        }
        _toolbar?.markNeedsBuild();
        if (_contextMenuController.isShown) {
          _contextMenuController.markNeedsBuild();
        } else if (_spellCheckToolbarController.isShown) {
          _spellCheckToolbarController.markNeedsBuild();
        }
      });
    } else {
      if (_handles != null) {
        _handles![0].markNeedsBuild();
        _handles![1].markNeedsBuild();
      }
      _toolbar?.markNeedsBuild();
      if (_contextMenuController.isShown) {
        _contextMenuController.markNeedsBuild();
      } else if (_spellCheckToolbarController.isShown) {
        _spellCheckToolbarController.markNeedsBuild();
      }
    }
  }

  /// Hides the entire overlay including the toolbar and the handles.
  void hide() {
    _magnifierController.hide();
    if (_handles != null) {
      _handles![0].remove();
      _handles![0].dispose();
      _handles![1].remove();
      _handles![1].dispose();
      _handles = null;
    }
    if (_toolbar != null ||
        _contextMenuController.isShown ||
        _spellCheckToolbarController.isShown) {
      hideToolbar();
    }
  }

  /// Hides the toolbar part of the overlay.
  ///
  /// To hide the whole overlay, see [hide].
  void hideToolbar() {
    _contextMenuController.remove();
    _spellCheckToolbarController.remove();
    if (_toolbar == null) {
      return;
    }
    _toolbar?.remove();
    _toolbar?.dispose();
    _toolbar = null;
  }

  /// Disposes this object and release resources.
  void dispose() {
    hide();
    _magnifierInfo.dispose();
  }

  Widget _buildStartHandle(BuildContext context) {
    final Widget handle;
    final TextSelectionControls? selectionControls = this.selectionControls;
    if (selectionControls == null) {
      handle = const SizedBox.shrink();
    } else {
      handle = SelectionHandleOverlay(
        type: _startHandleType,
        handleLayerLink: startHandleLayerLink,
        onSelectionHandleTapped: onSelectionHandleTapped,
        onSelectionHandleDragStart: _handleStartHandleDragStart,
        onSelectionHandleDragUpdate: _handleStartHandleDragUpdate,
        onSelectionHandleDragEnd: _handleStartHandleDragEnd,
        selectionControls: selectionControls,
        visibility: startHandlesVisible,
        preferredLineHeight: _lineHeightAtStart,
        dragStartBehavior: dragStartBehavior,
      );
    }
    return TextFieldTapRegion(
      child: ExcludeSemantics(
        child: handle,
      ),
    );
  }

  Widget _buildEndHandle(BuildContext context) {
    final Widget handle;
    final TextSelectionControls? selectionControls = this.selectionControls;
    if (selectionControls == null ||
        _startHandleType == TextSelectionHandleType.collapsed) {
      // Hide the second handle when collapsed.
      handle = const SizedBox.shrink();
    } else {
      handle = SelectionHandleOverlay(
        type: _endHandleType,
        handleLayerLink: endHandleLayerLink,
        onSelectionHandleTapped: onSelectionHandleTapped,
        onSelectionHandleDragStart: _handleEndHandleDragStart,
        onSelectionHandleDragUpdate: _handleEndHandleDragUpdate,
        onSelectionHandleDragEnd: _handleEndHandleDragEnd,
        selectionControls: selectionControls,
        visibility: endHandlesVisible,
        preferredLineHeight: _lineHeightAtEnd,
        dragStartBehavior: dragStartBehavior,
      );
    }
    return TextFieldTapRegion(
      child: ExcludeSemantics(
        child: handle,
      ),
    );
  }

  /// Update the current magnifier with new selection data, so the magnifier
  /// can respond accordingly.
  ///
  /// If the magnifier is not shown, this still updates the magnifier position
  /// because the magnifier may have hidden itself and is looking for a cue to reshow
  /// itself.
  ///
  /// If there is no magnifier in the overlay, this does nothing.
  void updateMagnifier(MagnifierInfo magnifierInfo) {
    if (_magnifierController.overlayEntry == null) {
      return;
    }

    _magnifierInfo.value = magnifierInfo;
  }
}

// TODO(justinmc): Currently this fades in but not out on all platforms. It
// should follow the correct fading behavior for the current platform, then be
// made public and de-duplicated with widgets/selectable_region.dart.
// https://github.com/flutter/flutter/issues/107732
// Wrap the given child in the widgets common to both contextMenuBuilder and
// TextSelectionControls.buildToolbar.
class _SelectionToolbarWrapper extends StatefulWidget {
  const _SelectionToolbarWrapper({
    required this.layerLink,
    required this.offset,
    required this.child,
  });

  final Widget child;
  final Offset offset;
  final LayerLink layerLink;

  @override
  State<_SelectionToolbarWrapper> createState() =>
      _SelectionToolbarWrapperState();
}

class _SelectionToolbarWrapperState extends State<_SelectionToolbarWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  Animation<double> get _opacity => _controller.view;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
        duration: SelectionOverlay.fadeDuration, vsync: this);

    _toolbarVisibilityChanged();
  }

  @override
  void didUpdateWidget(_SelectionToolbarWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _toolbarVisibilityChanged();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toolbarVisibilityChanged() {
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return TextFieldTapRegion(
      child: Directionality(
        textDirection: Directionality.of(this.context),
        child: FadeTransition(
          opacity: _opacity,
          child: CompositedTransformFollower(
            link: widget.layerLink,
            showWhenUnlinked: false,
            offset: widget.offset,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// This widget represents a single draggable text selection handle.
@visibleForTesting
class SelectionHandleOverlay extends StatefulWidget {
  const SelectionHandleOverlay({
    super.key,
    required this.type,
    required this.handleLayerLink,
    this.onSelectionHandleTapped,
    this.onSelectionHandleDragStart,
    this.onSelectionHandleDragUpdate,
    this.onSelectionHandleDragEnd,
    required this.selectionControls,
    this.visibility,
    required this.preferredLineHeight,
    this.dragStartBehavior = DragStartBehavior.start,
  });

  final LayerLink handleLayerLink;
  final VoidCallback? onSelectionHandleTapped;
  final ValueChanged<DragStartDetails>? onSelectionHandleDragStart;
  final ValueChanged<DragUpdateDetails>? onSelectionHandleDragUpdate;
  final ValueChanged<DragEndDetails>? onSelectionHandleDragEnd;
  final TextSelectionControls selectionControls;
  final ValueListenable<bool>? visibility;
  final double preferredLineHeight;
  final TextSelectionHandleType type;
  final DragStartBehavior dragStartBehavior;

  @override
  State<SelectionHandleOverlay> createState() => _SelectionHandleOverlayState();
}

class _SelectionHandleOverlayState extends State<SelectionHandleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  Animation<double> get _opacity => _controller.view;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
        duration: SelectionOverlay.fadeDuration, vsync: this);

    _handleVisibilityChanged();
    widget.visibility?.addListener(_handleVisibilityChanged);
  }

  void _handleVisibilityChanged() {
    if (widget.visibility?.value ?? true) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void didUpdateWidget(SelectionHandleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.visibility?.removeListener(_handleVisibilityChanged);
    _handleVisibilityChanged();
    widget.visibility?.addListener(_handleVisibilityChanged);
  }

  @override
  void dispose() {
    widget.visibility?.removeListener(_handleVisibilityChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Offset handleAnchor = widget.selectionControls.getHandleAnchor(
      widget.type,
      widget.preferredLineHeight,
    );
    final Size handleSize = widget.selectionControls.getHandleSize(
      widget.preferredLineHeight,
    );

    final Rect handleRect = Rect.fromLTWH(
      -handleAnchor.dx,
      -handleAnchor.dy,
      handleSize.width,
      handleSize.height,
    );

    // Make sure the GestureDetector is big enough to be easily interactive.
    final Rect interactiveRect = handleRect.expandToInclude(
      Rect.fromCircle(
          center: handleRect.center, radius: kMinInteractiveDimension / 2),
    );
    final RelativeRect padding = RelativeRect.fromLTRB(
      math.max((interactiveRect.width - handleRect.width) / 2, 0),
      math.max((interactiveRect.height - handleRect.height) / 2, 0),
      math.max((interactiveRect.width - handleRect.width) / 2, 0),
      math.max((interactiveRect.height - handleRect.height) / 2, 0),
    );

    return CompositedTransformFollower(
      link: widget.handleLayerLink,
      offset: interactiveRect.topLeft,
      showWhenUnlinked: true,
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          alignment: Alignment.topLeft,
          width: interactiveRect.width,
          height: interactiveRect.height,
          child: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: <Type, GestureRecognizerFactory>{
              PanGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
                () => PanGestureRecognizer(
                  debugOwner: this,
                  // Mouse events select the text and do not drag the cursor.
                  supportedDevices: <PointerDeviceKind>{
                    PointerDeviceKind.touch,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.unknown,
                  },
                ),
                (PanGestureRecognizer instance) {
                  instance
                    ..dragStartBehavior = widget.dragStartBehavior
                    ..onStart = widget.onSelectionHandleDragStart
                    ..onUpdate = widget.onSelectionHandleDragUpdate
                    ..onEnd = widget.onSelectionHandleDragEnd;
                },
              ),
            },
            child: Padding(
              padding: EdgeInsets.only(
                left: padding.left,
                top: padding.top,
                right: padding.right,
                bottom: padding.bottom,
              ),
              child: widget.selectionControls.buildHandle(
                context,
                widget.type,
                widget.preferredLineHeight,
                widget.onSelectionHandleTapped,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Delegate interface for the [EditorTextSelectionGestureDetectorBuilder].
///
/// The interface is usually implemented by textfield implementations wrapping
/// [RawEditor], that use a [EditorTextSelectionGestureDetectorBuilder] to build a
/// [EditorTextSelectionGestureDetector] for their [RawEditor]. The delegate provides
/// the builder with information about the current state of the textfield.
/// Based on these information, the builder adds the correct gesture handlers
/// to the gesture detector.
abstract class EditorTextSelectionGestureDetectorBuilderDelegate {
  /// [GlobalKey] to the [EditableText] for which the
  /// [EditorTextSelectionGestureDetectorBuilder] will build a [EditorTextSelectionGestureDetector].
  GlobalKey<EditorState> get editableTextKey;

  /// Whether the textfield should respond to force presses.
  bool get forcePressEnabled;

  /// Whether the user may select text in the textfield.
  bool get selectionEnabled;
}

/// Builds a [TextSelectionGestureDetector] to wrap an [RawEditor].
///
/// The class implements sensible defaults for many user interactions
/// with an [RawEditor] (see the documentation of the various gesture handler
/// methods, e.g. [onTapDown], [onForcePressStart], etc.). Subclasses of
/// [EditorTextSelectionGestureDetectorBuilder] can change the behavior performed in
/// responds to these gesture events by overriding the corresponding handler
/// methods of this class.
///
/// The resulting [TextSelectionGestureDetector] to wrap an [RawEditor] is
/// obtained by calling [buildGestureDetector].
///
/// A [EditorTextSelectionGestureDetectorBuilder] must be provided a
/// [EditorTextSelectionGestureDetectorBuilderDelegate], from which information about
/// the [RawEditor] may be obtained. Typically, the [State] of the widget
/// that builds the [RawEditor] implements this interface, and then passes
/// itself as the [delegate].
class EditorTextSelectionGestureDetectorBuilder {
  /// Creates a [EditorTextSelectionGestureDetectorBuilder].
  EditorTextSelectionGestureDetectorBuilder({
    required this.delegate,
  });

  static int _getEffectiveConsecutiveTapCount(int rawCount) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
        // From observation, these platform's reset their tap count to 0 when
        // the number of consecutive taps exceeds 3. For example on Debian Linux
        // with GTK, when going past a triple click, on the fourth click the
        // selection is moved to the precise click position, on the fifth click
        // the word at the position is selected, and on the sixth click the
        // paragraph at the position is selected.
        return rawCount <= 3
            ? rawCount
            : (rawCount % 3 == 0 ? 3 : rawCount % 3);
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        // From observation, these platform's either hold their tap count at 3.
        // For example on macOS, when going past a triple click, the selection
        // should be retained at the paragraph that was first selected on triple
        // click.
        return math.min(rawCount, 3);
      case TargetPlatform.windows:
        // From observation, this platform's consecutive tap actions alternate
        // between double click and triple click actions. For example, after a
        // triple click has selected a paragraph, on the next click the word at
        // the clicked position will be selected, and on the next click the
        // paragraph at the position is selected.
        return rawCount < 2 ? rawCount : 2 + rawCount % 2;
    }
  }

  /// The delegate for this [TextSelectionGestureDetectorBuilder].
  ///
  /// The delegate provides the builder with information about what actions can
  /// currently be performed on the text field. Based on this, the builder adds
  /// the correct gesture handlers to the gesture detector.
  ///
  /// Typically implemented by a [State] of a widget that builds an
  /// [editor].
  @protected
  final EditorTextSelectionGestureDetectorBuilderDelegate delegate;

  // Shows the magnifier on supported platforms at the given offset, currently
  // only Android and iOS.
  void _showMagnifierIfSupportedByPlatform(Offset positionToShow) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        editor.showMagnifier(positionToShow);
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
    }
  }

  // Hides the magnifier on supported platforms, currently only Android and iOS.
  void _hideMagnifierIfSupportedByPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        editor.hideMagnifier();
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
    }
  }

  /// Returns true if lastSecondaryTapDownPosition was on selection.
  bool get _lastSecondaryTapWasOnSelection {
    assert(renderEditor.lastSecondaryTapDownPosition != null);

    final TextPosition textPosition = renderEditor
        .getPositionForOffset(renderEditor.lastSecondaryTapDownPosition!);

    return renderEditor.selection.start <= textPosition.offset &&
        renderEditor.selection.end >= textPosition.offset;
  }

  bool _positionWasOnSelectionExclusive(TextPosition textPosition) {
    final TextSelection selection = renderEditor.selection;
    return selection.start < textPosition.offset &&
        selection.end > textPosition.offset;
  }

  bool _positionWasOnSelectionInclusive(TextPosition textPosition) {
    final TextSelection selection = renderEditor.selection;
    return selection.start <= textPosition.offset &&
        selection.end >= textPosition.offset;
  }

  /// Returns true if position was on selection.
  bool _positionOnSelection(Offset position, TextSelection? targetSelection) {
    if (targetSelection == null) {
      return false;
    }

    final TextPosition textPosition =
        renderEditor.getPositionForOffset(position);

    return targetSelection.start <= textPosition.offset &&
        targetSelection.end >= textPosition.offset;
  }

  // Expand the selection to the given global position.
  //
  // Either base or extent will be moved to the last tapped position, whichever
  // is closest. The selection will never shrink or pivot, only grow.
  //
  // If fromSelection is given, will expand from that selection instead of the
  // current selection in renderEditor.
  //
  // See also:
  //
  //   * [_extendSelection], which is similar but pivots the selection around
  //     the base.
  void _expandSelection(Offset offset, SelectionChangedCause cause,
      [TextSelection? fromSelection]) {
    final TextPosition tappedPosition =
        renderEditor.getPositionForOffset(offset);
    final TextSelection selection = fromSelection ?? renderEditor.selection;
    final bool baseIsCloser =
        (tappedPosition.offset - selection.baseOffset).abs() <
            (tappedPosition.offset - selection.extentOffset).abs();
    final TextSelection nextSelection = selection.copyWith(
      baseOffset: baseIsCloser ? selection.extentOffset : selection.baseOffset,
      extentOffset: tappedPosition.offset,
    );

    editor.userUpdateTextEditingValue(
      editor.textEditingValue.copyWith(selection: nextSelection),
      cause,
    );
  }

  // Extend the selection to the given global position.
  //
  // Holds the base in place and moves the extent.
  //
  // See also:
  //
  //   * [_expandSelection], which is similar but always increases the size of
  //     the selection.
  void _extendSelection(Offset offset, SelectionChangedCause cause) {
    final TextPosition tappedPosition =
        renderEditor.getPositionForOffset(offset);
    final TextSelection selection = renderEditor.selection;
    final TextSelection nextSelection = selection.copyWith(
      extentOffset: tappedPosition.offset,
    );

    editor.userUpdateTextEditingValue(
      editor.textEditingValue.copyWith(selection: nextSelection),
      cause,
    );
  }

  /// Whether to show the selection toolbar.
  ///
  /// It is based on the signal source when a [onTapDown] is called. This getter
  /// will return true if current [onTapDown] event is triggered by a touch or
  /// a stylus.
  bool get shouldShowSelectionToolbar => _shouldShowSelectionToolbar;
  bool _shouldShowSelectionToolbar = true;

  /// The [State] of the [editor] for which the builder will provide a
  /// [TextSelectionGestureDetector].
  @protected
  EditorState get editor => delegate.editableTextKey.currentState!;

  /// The [RenderObject] of the [editor] for which the builder will
  /// provide a [TextSelectionGestureDetector].
  @protected
  RenderEditor get renderEditor => editor.renderEditor;

  /// Whether the Shift key was pressed when the most recent [PointerDownEvent]
  /// was tracked by the [BaseTapAndDragGestureRecognizer].
  bool _isShiftPressed = false;

  /// The viewport offset pixels of any [Scrollable] containing the
  /// [renderEditor] at the last drag start.
  double _dragStartScrollOffset = 0.0;

  /// The viewport offset pixels of the [renderEditor] at the last drag start.
  double _dragStartViewportOffset = 0.0;

  double get _scrollPosition {
    final ScrollableState? scrollableState =
        delegate.editableTextKey.currentContext == null
            ? null
            : Scrollable.maybeOf(delegate.editableTextKey.currentContext!);
    return scrollableState == null ? 0.0 : scrollableState.position.pixels;
  }

  // For a shift + tap + drag gesture, the TextSelection at the point of the
  // tap. Mac uses this value to reset to the original selection when an
  // inversion of the base and offset happens.
  TextSelection? _dragStartSelection;

  // For tap + drag gesture on iOS, whether the position where the drag started
  // was on the previous TextSelection. iOS uses this value to determine if
  // the cursor should move on drag update.
  //
  // If the drag started on the previous selection then the cursor will move on
  // drag update. If the drag did not start on the previous selection then the
  // cursor will not move on drag update.
  bool? _dragBeganOnPreviousSelection;

  // For iOS long press behavior when the field is not focused. iOS uses this value
  // to determine if a long press began on a field that was not focused.
  //
  // If the field was not focused when the long press began, a long press will select
  // the word and a long press move will select word-by-word. If the field was
  // focused, the cursor moves to the long press position.
  bool _longPressStartedWithoutFocus = false;

  /// Handler for [TextSelectionGestureDetector.onTapTrackStart].
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onTapTrackStart], which triggers this
  ///    callback.
  @protected
  void onTapTrackStart() {
    _isShiftPressed = HardwareKeyboard.instance.logicalKeysPressed
        .intersection(<LogicalKeyboardKey>{
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight
    }).isNotEmpty;
  }

  /// Handler for [TextSelectionGestureDetector.onTapTrackReset].
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onTapTrackReset], which triggers this
  ///    callback.
  @protected
  void onTapTrackReset() {
    _isShiftPressed = false;
  }

  /// Handler for [TextSelectionGestureDetector.onTapDown].
  ///
  /// By default, it forwards the tap to [renderEditor.handleTapDown] and sets
  /// [shouldShowSelectionToolbar] to true if the tap was initiated by a finger or stylus.
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onTapDown], which triggers this callback.
  @protected
  void onTapDown(TapDragDownDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }
    // TODO(Renzo-Olivares): Migrate text selection gestures away from saving state
    // in renderEditor. The gesture callbacks can use the details objects directly
    // in callbacks variants that provide them [TapGestureRecognizer.onSecondaryTap]
    // vs [TapGestureRecognizer.onSecondaryTapUp] instead of having to track state in
    // renderEditor. When this migration is complete we should remove this hack.
    // See https://github.com/flutter/flutter/issues/115130.
    renderEditor
        .handleTapDown(TapDownDetails(globalPosition: details.globalPosition));
    // The selection overlay should only be shown when the user is interacting
    // through a touch screen (via either a finger or a stylus). A mouse shouldn't
    // trigger the selection overlay.
    // For backwards-compatibility, we treat a null kind the same as touch.
    final PointerDeviceKind? kind = details.kind;
    // TODO(justinmc): Should a desktop platform show its selection toolbar when
    // receiving a tap event?  Say a Windows device with a touchscreen.
    // https://github.com/flutter/flutter/issues/106586
    _shouldShowSelectionToolbar = kind == null ||
        kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus;

    // It is impossible to extend the selection when the shift key is pressed, if the
    // renderEditor.selection is invalid.
    final bool isShiftPressedValid = _isShiftPressed;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        // On mobile platforms the selection is set on tap up.
        editor.hideToolbar(false);
      case TargetPlatform.iOS:
        // On mobile platforms the selection is set on tap up.
        break;
      case TargetPlatform.macOS:
        editor.hideToolbar();
        // On macOS, a shift-tapped unfocused field expands from 0, not from the
        // previous selection.
        if (isShiftPressedValid) {
          final TextSelection? fromSelection = renderEditor.hasFocus
              ? null
              : const TextSelection.collapsed(offset: 0);
          _expandSelection(
            details.globalPosition,
            SelectionChangedCause.tap,
            fromSelection,
          );
          return;
        }
        // On macOS, a tap/click places the selection in a precise position.
        // This differs from iOS/iPadOS, where if the gesture is done by a touch
        // then the selection moves to the closest word edge, instead of a
        // precise position.
        renderEditor.selectPosition(cause: SelectionChangedCause.tap);
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        editor.hideToolbar();
        if (isShiftPressedValid) {
          _extendSelection(details.globalPosition, SelectionChangedCause.tap);
          return;
        }
        renderEditor.selectPosition(cause: SelectionChangedCause.tap);
    }
  }

  /// Handler for [TextSelectionGestureDetector.onForcePressStart].
  ///
  /// By default, it selects the word at the position of the force press,
  /// if selection is enabled.
  ///
  /// This callback is only applicable when force press is enabled.
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onForcePressStart], which triggers this
  ///    callback.
  @protected
  void onForcePressStart(ForcePressDetails details) {
    assert(delegate.forcePressEnabled);
    _shouldShowSelectionToolbar = true;
    if (delegate.selectionEnabled) {
      renderEditor.selectWordsInRange(
        from: details.globalPosition,
        cause: SelectionChangedCause.forcePress,
      );
    }
  }

  /// Handler for [TextSelectionGestureDetector.onForcePressEnd].
  ///
  /// By default, it selects words in the range specified in [details] and shows
  /// toolbar if it is necessary.
  ///
  /// This callback is only applicable when force press is enabled.
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onForcePressEnd], which triggers this
  ///    callback.
  @protected
  void onForcePressEnd(ForcePressDetails details) {
    assert(delegate.forcePressEnabled);
    renderEditor.selectWordsInRange(
      from: details.globalPosition,
      cause: SelectionChangedCause.forcePress,
    );
    if (shouldShowSelectionToolbar) {
      editor.showToolbar();
    }
  }

  /// Handler for [TextSelectionGestureDetector.onSingleTapUp].
  ///
  /// By default, it selects word edge if selection is enabled.
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onSingleTapUp], which triggers
  ///    this callback.
  @protected
  void onSingleTapUp(TapDragUpDetails details) {
    if (delegate.selectionEnabled) {
      // It is impossible to extend the selection when the shift key is pressed, if the
      // renderEditor.selection is invalid.
      final bool isShiftPressedValid = _isShiftPressed;
      switch (defaultTargetPlatform) {
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
          break;
        // On desktop platforms the selection is set on tap down.
        case TargetPlatform.android:
          if (isShiftPressedValid) {
            _extendSelection(details.globalPosition, SelectionChangedCause.tap);
            return;
          }
          renderEditor.selectPosition(cause: SelectionChangedCause.tap);
          editor.showSpellCheckSuggestionsToolbar();
        case TargetPlatform.fuchsia:
          if (isShiftPressedValid) {
            _extendSelection(details.globalPosition, SelectionChangedCause.tap);
            return;
          }
          renderEditor.selectPosition(cause: SelectionChangedCause.tap);
        case TargetPlatform.iOS:
          if (isShiftPressedValid) {
            // On iOS, a shift-tapped unfocused field expands from 0, not from
            // the previous selection.
            final TextSelection? fromSelection = renderEditor.hasFocus
                ? null
                : const TextSelection.collapsed(offset: 0);
            _expandSelection(
              details.globalPosition,
              SelectionChangedCause.tap,
              fromSelection,
            );
            return;
          }
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.trackpad:
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
              renderEditor.selectPosition(cause: SelectionChangedCause.tap);
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
              // Toggle the toolbar if the `previousSelection` is collapsed, the tap is on the selection, the
              // TextAffinity remains the same, and the editable is focused. The TextAffinity is important when the
              // cursor is on the boundary of a line wrap, if the affinity is different (i.e. it is downstream), the
              // selection should move to the following line and not toggle the toolbar.
              //
              // Toggle the toolbar when the tap is exclusively within the bounds of a non-collapsed `previousSelection`,
              // and the editable is focused.
              //
              // Selects the word edge closest to the tap when the editable is not focused, or if the tap was neither exclusively
              // or inclusively on `previousSelection`. If the selection remains the same after selecting the word edge, then we
              // toggle the toolbar. If the selection changes then we hide the toolbar.
              final TextSelection previousSelection = renderEditor.selection;
              final TextPosition textPosition =
                  renderEditor.getPositionForOffset(details.globalPosition);
              final bool isAffinityTheSame =
                  textPosition.affinity == previousSelection.affinity;
              final bool wordAtCursorIndexIsMisspelled =
                  editor.findSuggestionSpanAtCursorIndex(textPosition.offset) !=
                      null;
              if (wordAtCursorIndexIsMisspelled) {
                renderEditor.selectWord(cause: SelectionChangedCause.tap);
                if (previousSelection != editor.textEditingValue.selection) {
                  editor.showSpellCheckSuggestionsToolbar();
                } else {
                  editor.toggleToolbar(false);
                }
              } else if (((_positionWasOnSelectionExclusive(textPosition) &&
                          !previousSelection.isCollapsed) ||
                      (_positionWasOnSelectionInclusive(textPosition) &&
                          previousSelection.isCollapsed &&
                          isAffinityTheSame)) &&
                  renderEditor.hasFocus) {
                editor.toggleToolbar(false);
              } else {
                renderEditor.selectWordEdge(cause: SelectionChangedCause.tap);
                if (previousSelection == editor.textEditingValue.selection &&
                    renderEditor.hasFocus) {
                  editor.toggleToolbar(false);
                } else {
                  editor.hideToolbar(false);
                }
              }
          }
      }
    }
  }

  /// Handler for [TextSelectionGestureDetector.onSingleTapCancel].
  ///
  /// By default, it services as place holder to enable subclass override.
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onSingleTapCancel], which triggers
  ///    this callback.
  @protected
  void onSingleTapCancel() {
    /* Subclass should override this method if needed. */
  }

  /// Handler for [TextSelectionGestureDetector.onSingleLongTapStart].
  ///
  /// By default, it selects text position specified in [details] if selection
  /// is enabled.
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onSingleLongTapStart], which triggers
  ///    this callback.
  @protected
  void onSingleLongTapStart(LongPressStartDetails details) {
    if (delegate.selectionEnabled) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          if (!renderEditor.hasFocus) {
            _longPressStartedWithoutFocus = true;
            renderEditor.selectWord(cause: SelectionChangedCause.longPress);
          } else {
            renderEditor.selectPositionAt(
              from: details.globalPosition,
              cause: SelectionChangedCause.longPress,
            );
          }
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          renderEditor.selectWord(cause: SelectionChangedCause.longPress);
      }

      _showMagnifierIfSupportedByPlatform(details.globalPosition);

      _dragStartViewportOffset = renderEditor.offset?.pixels ?? 0;
      _dragStartScrollOffset = _scrollPosition;
    }
  }

  /// Handler for [TextSelectionGestureDetector.onSingleLongTapMoveUpdate].
  ///
  /// By default, it updates the selection location specified in [details] if
  /// selection is enabled.
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onSingleLongTapMoveUpdate], which
  ///    triggers this callback.
  @protected
  void onSingleLongTapMoveUpdate(LongPressMoveUpdateDetails details) {
    if (delegate.selectionEnabled) {
      // Adjust the drag start offset for possible viewport offset changes.
      final Offset editableOffset = Offset(
          0.0, (renderEditor.offset?.pixels ?? 0) - _dragStartViewportOffset);
      final Offset scrollableOffset = Offset(
        0.0,
        _scrollPosition - _dragStartScrollOffset,
      );

      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          if (_longPressStartedWithoutFocus) {
            renderEditor.selectWordsInRange(
              from: details.globalPosition -
                  details.offsetFromOrigin -
                  editableOffset -
                  scrollableOffset,
              to: details.globalPosition,
              cause: SelectionChangedCause.longPress,
            );
          } else {
            renderEditor.selectPositionAt(
              from: details.globalPosition,
              cause: SelectionChangedCause.longPress,
            );
          }
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          renderEditor.selectWordsInRange(
            from: details.globalPosition -
                details.offsetFromOrigin -
                editableOffset -
                scrollableOffset,
            to: details.globalPosition,
            cause: SelectionChangedCause.longPress,
          );
      }

      _showMagnifierIfSupportedByPlatform(details.globalPosition);
    }
  }

  /// Handler for [TextSelectionGestureDetector.onSingleLongTapEnd].
  ///
  /// By default, it shows toolbar if necessary.
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onSingleLongTapEnd], which triggers this
  ///    callback.
  @protected
  void onSingleLongTapEnd(LongPressEndDetails details) {
    _hideMagnifierIfSupportedByPlatform();
    if (shouldShowSelectionToolbar) {
      editor.showToolbar();
    }
    _longPressStartedWithoutFocus = false;
    _dragStartViewportOffset = 0.0;
    _dragStartScrollOffset = 0.0;
  }

  /// Handler for [TextSelectionGestureDetector.onSecondaryTap].
  ///
  /// By default, selects the word if possible and shows the toolbar.
  @protected
  void onSecondaryTap() {
    if (!delegate.selectionEnabled) {
      return;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        if (!_lastSecondaryTapWasOnSelection || !renderEditor.hasFocus) {
          renderEditor.selectWord(cause: SelectionChangedCause.tap);
        }
        if (shouldShowSelectionToolbar) {
          editor.hideToolbar();
          editor.showToolbar(createIfNull: true);
        }
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        if (!renderEditor.hasFocus) {
          renderEditor.selectPosition(cause: SelectionChangedCause.tap);
        }
        editor.toggleToolbar();
    }
  }

  /// Handler for [TextSelectionGestureDetector.onSecondaryTapDown].
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onSecondaryTapDown], which triggers this
  ///    callback.
  ///  * [onSecondaryTap], which is typically called after this.
  @protected
  void onSecondaryTapDown(TapDownDetails details) {
    // TODO(Renzo-Olivares): Migrate text selection gestures away from saving state
    // in renderEditor. The gesture callbacks can use the details objects directly
    // in callbacks variants that provide them [TapGestureRecognizer.onSecondaryTap]
    // vs [TapGestureRecognizer.onSecondaryTapUp] instead of having to track state in
    // renderEditor. When this migration is complete we should remove this hack.
    // See https://github.com/flutter/flutter/issues/115130.
    renderEditor.handleSecondaryTapDown(
        TapDownDetails(globalPosition: details.globalPosition));
    _shouldShowSelectionToolbar = true;
  }

  /// Handler for [TextSelectionGestureDetector.onDoubleTapDown].
  ///
  /// By default, it selects a word through [renderEditor.selectWord] if
  /// selectionEnabled and shows toolbar if necessary.
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onDoubleTapDown], which triggers this
  ///    callback.
  @protected
  void onDoubleTapDown(TapDragDownDetails details) {
    if (delegate.selectionEnabled) {
      renderEditor.selectWord(cause: SelectionChangedCause.doubleTap);
      if (shouldShowSelectionToolbar) {
        editor.showToolbar();
      }
    }
  }

  // Selects the set of paragraphs in a document that intersect a given range of
  // global positions.
  void _selectParagraphsInRange(
      {required Offset from,
      Offset? to,
      required SelectionChangedCause cause}) {
    final TextBoundary paragraphBoundary =
        ParagraphBoundary(editor.textEditingValue.text);
    _selectTextBoundariesInRange(
        boundary: paragraphBoundary, from: from, to: to, cause: cause);
  }

  // Selects the set of lines in a document that intersect a given range of
  // global positions.
  void _selectLinesInRange(
      {required Offset from,
      Offset? to,
      required SelectionChangedCause cause}) {
    final TextBoundary lineBoundary = LineBoundary(renderEditor);
    _selectTextBoundariesInRange(
        boundary: lineBoundary, from: from, to: to, cause: cause);
  }

  // Returns the location of a text boundary at `extent`. When `extent` is at
  // the end of the text, returns the previous text boundary's location.
  TextRange _moveToTextBoundary(
      TextPosition extent, TextBoundary textBoundary) {
    assert(extent.offset >= 0);
    // Use extent.offset - 1 when `extent` is at the end of the text to retrieve
    // the previous text boundary's location.
    final int start = textBoundary.getLeadingTextBoundaryAt(
            extent.offset == editor.textEditingValue.text.length
                ? extent.offset - 1
                : extent.offset) ??
        0;
    final int end = textBoundary.getTrailingTextBoundaryAt(extent.offset) ??
        editor.textEditingValue.text.length;
    return TextRange(start: start, end: end);
  }

  // Selects the set of text boundaries in a document that intersect a given
  // range of global positions.
  //
  // The set of text boundaries selected are not strictly bounded by the range
  // of global positions.
  //
  // The first and last endpoints of the selection will always be at the
  // beginning and end of a text boundary respectively.
  void _selectTextBoundariesInRange(
      {required TextBoundary boundary,
      required Offset from,
      Offset? to,
      required SelectionChangedCause cause}) {
    final TextPosition fromPosition = renderEditor.getPositionForOffset(from);
    final TextRange fromRange = _moveToTextBoundary(fromPosition, boundary);
    final TextPosition toPosition =
        to == null ? fromPosition : renderEditor.getPositionForOffset(to);
    final TextRange toRange = toPosition == fromPosition
        ? fromRange
        : _moveToTextBoundary(toPosition, boundary);
    final bool isFromBoundaryBeforeToBoundary = fromRange.start < toRange.end;

    final TextSelection newSelection = isFromBoundaryBeforeToBoundary
        ? TextSelection(baseOffset: fromRange.start, extentOffset: toRange.end)
        : TextSelection(baseOffset: fromRange.end, extentOffset: toRange.start);

    editor.userUpdateTextEditingValue(
      editor.textEditingValue.copyWith(selection: newSelection),
      cause,
    );
  }

  /// Handler for [TextSelectionGestureDetector.onTripleTapDown].
  ///
  /// By default, it selects a paragraph if
  /// [TextSelectionGestureDetectorBuilderDelegate.selectionEnabled] is true
  /// and shows the toolbar if necessary.
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onTripleTapDown], which triggers this
  ///    callback.
  @protected
  void onTripleTapDown(TapDragDownDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        _selectParagraphsInRange(
            from: details.globalPosition, cause: SelectionChangedCause.tap);
      case TargetPlatform.linux:
        _selectLinesInRange(
            from: details.globalPosition, cause: SelectionChangedCause.tap);
    }
    if (shouldShowSelectionToolbar) {
      editor.showToolbar();
    }
  }

  /// Handler for [TextSelectionGestureDetector.onDragSelectionStart].
  ///
  /// By default, it selects a text position specified in [details].
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onDragSelectionStart], which triggers
  ///    this callback.
  @protected
  void onDragSelectionStart(TapDragStartDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }
    final PointerDeviceKind? kind = details.kind;
    _shouldShowSelectionToolbar = kind == null ||
        kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus;

    _dragStartSelection = renderEditor.selection;
    _dragStartScrollOffset = _scrollPosition;
    _dragStartViewportOffset = renderEditor.offset?.pixels ?? 0;
    _dragBeganOnPreviousSelection =
        _positionOnSelection(details.globalPosition, _dragStartSelection);

    if (_getEffectiveConsecutiveTapCount(details.consecutiveTapCount) > 1) {
      // Do not set the selection on a consecutive tap and drag.
      return;
    }

    if (_isShiftPressed && renderEditor.selection.isValid) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          _expandSelection(details.globalPosition, SelectionChangedCause.drag);
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          _extendSelection(details.globalPosition, SelectionChangedCause.drag);
      }
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.trackpad:
              renderEditor.selectPositionAt(
                from: details.globalPosition,
                cause: SelectionChangedCause.drag,
              );
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
              // For iOS platforms, a touch drag does not initiate unless the
              // editable has focus and the drag began on the previous selection.
              assert(_dragBeganOnPreviousSelection != null);
              if (renderEditor.hasFocus && _dragBeganOnPreviousSelection!) {
                renderEditor.selectPositionAt(
                  from: details.globalPosition,
                  cause: SelectionChangedCause.drag,
                );
                _showMagnifierIfSupportedByPlatform(details.globalPosition);
              }
            case null:
          }
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.trackpad:
              renderEditor.selectPositionAt(
                from: details.globalPosition,
                cause: SelectionChangedCause.drag,
              );
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
              // For Android, Fucshia, and iOS platforms, a touch drag
              // does not initiate unless the editable has focus.
              if (renderEditor.hasFocus) {
                renderEditor.selectPositionAt(
                  from: details.globalPosition,
                  cause: SelectionChangedCause.drag,
                );
                _showMagnifierIfSupportedByPlatform(details.globalPosition);
              }
            case null:
          }
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
          renderEditor.selectPositionAt(
            from: details.globalPosition,
            cause: SelectionChangedCause.drag,
          );
      }
    }
  }

  /// Handler for [TextSelectionGestureDetector.onDragSelectionUpdate].
  ///
  /// By default, it updates the selection location specified in the provided
  /// details objects.
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onDragSelectionUpdate], which triggers
  ///    this callback./lib/src/material/text_field.dart
  @protected
  void onDragSelectionUpdate(TapDragUpdateDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }

    if (!_isShiftPressed) {
      // Adjust the drag start offset for possible viewport offset changes.
      final Offset editableOffset = Offset(
          0.0, (renderEditor.offset?.pixels ?? 0) - _dragStartViewportOffset);
      final Offset scrollableOffset = Offset(
        0.0,
        _scrollPosition - _dragStartScrollOffset,
      );
      final Offset dragStartGlobalPosition =
          details.globalPosition - details.offsetFromOrigin;

      // Select word by word.
      if (_getEffectiveConsecutiveTapCount(details.consecutiveTapCount) == 2) {
        renderEditor.selectWordsInRange(
          from: dragStartGlobalPosition - editableOffset - scrollableOffset,
          to: details.globalPosition,
          cause: SelectionChangedCause.drag,
        );

        switch (details.kind) {
          case PointerDeviceKind.stylus:
          case PointerDeviceKind.invertedStylus:
          case PointerDeviceKind.touch:
          case PointerDeviceKind.unknown:
            return _showMagnifierIfSupportedByPlatform(details.globalPosition);
          case PointerDeviceKind.mouse:
          case PointerDeviceKind.trackpad:
          case null:
            return;
        }
      }

      // Select paragraph-by-paragraph.
      if (_getEffectiveConsecutiveTapCount(details.consecutiveTapCount) == 3) {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
          case TargetPlatform.iOS:
            switch (details.kind) {
              case PointerDeviceKind.mouse:
              case PointerDeviceKind.trackpad:
                return _selectParagraphsInRange(
                  from: dragStartGlobalPosition -
                      editableOffset -
                      scrollableOffset,
                  to: details.globalPosition,
                  cause: SelectionChangedCause.drag,
                );
              case PointerDeviceKind.stylus:
              case PointerDeviceKind.invertedStylus:
              case PointerDeviceKind.touch:
              case PointerDeviceKind.unknown:
              case null:
                // Triple tap to drag is not present on these platforms when using
                // non-precise pointer devices at the moment.
                break;
            }
            return;
          case TargetPlatform.linux:
            return _selectLinesInRange(
              from: dragStartGlobalPosition - editableOffset - scrollableOffset,
              to: details.globalPosition,
              cause: SelectionChangedCause.drag,
            );
          case TargetPlatform.windows:
          case TargetPlatform.macOS:
            return _selectParagraphsInRange(
              from: dragStartGlobalPosition - editableOffset - scrollableOffset,
              to: details.globalPosition,
              cause: SelectionChangedCause.drag,
            );
        }
      }

      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          // With a touch device, nothing should happen, unless there was a double tap, or
          // there was a collapsed selection, and the tap/drag position is at the collapsed selection.
          // In that case the caret should move with the drag position.
          //
          // With a mouse device, a drag should select the range from the origin of the drag
          // to the current position of the drag.
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.trackpad:
              renderEditor.selectPositionAt(
                from:
                    dragStartGlobalPosition - editableOffset - scrollableOffset,
                to: details.globalPosition,
                cause: SelectionChangedCause.drag,
              );
              return;
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
              assert(_dragBeganOnPreviousSelection != null);
              if (renderEditor.hasFocus &&
                  _dragStartSelection!.isCollapsed &&
                  _dragBeganOnPreviousSelection!) {
                renderEditor.selectPositionAt(
                  from: details.globalPosition,
                  cause: SelectionChangedCause.drag,
                );
                return _showMagnifierIfSupportedByPlatform(
                    details.globalPosition);
              }
            case null:
              break;
          }
          return;
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
          // With a precise pointer device, such as a mouse, trackpad, or stylus,
          // the drag will select the text spanning the origin of the drag to the end of the drag.
          // With a touch device, the cursor should move with the drag.
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.trackpad:
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
              renderEditor.selectPositionAt(
                from:
                    dragStartGlobalPosition - editableOffset - scrollableOffset,
                to: details.globalPosition,
                cause: SelectionChangedCause.drag,
              );
              return;
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
              if (renderEditor.hasFocus) {
                renderEditor.selectPositionAt(
                  from: details.globalPosition,
                  cause: SelectionChangedCause.drag,
                );
                return _showMagnifierIfSupportedByPlatform(
                    details.globalPosition);
              }
            case null:
              break;
          }
          return;
        case TargetPlatform.macOS:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          renderEditor.selectPositionAt(
            from: dragStartGlobalPosition - editableOffset - scrollableOffset,
            to: details.globalPosition,
            cause: SelectionChangedCause.drag,
          );
          return;
      }
    }

    if (_dragStartSelection!.isCollapsed ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      return _extendSelection(
          details.globalPosition, SelectionChangedCause.drag);
    }

    // If the drag inverts the selection, Mac and iOS revert to the initial
    // selection.
    final TextSelection selection = editor.textEditingValue.selection;
    final TextPosition nextExtent =
        renderEditor.getPositionForOffset(details.globalPosition);
    final bool isShiftTapDragSelectionForward =
        _dragStartSelection!.baseOffset < _dragStartSelection!.extentOffset;
    final bool isInverted = isShiftTapDragSelectionForward
        ? nextExtent.offset < _dragStartSelection!.baseOffset
        : nextExtent.offset > _dragStartSelection!.baseOffset;
    if (isInverted && selection.baseOffset == _dragStartSelection!.baseOffset) {
      editor.userUpdateTextEditingValue(
        editor.textEditingValue.copyWith(
          selection: TextSelection(
            baseOffset: _dragStartSelection!.extentOffset,
            extentOffset: nextExtent.offset,
          ),
        ),
        SelectionChangedCause.drag,
      );
    } else if (!isInverted &&
        nextExtent.offset != _dragStartSelection!.baseOffset &&
        selection.baseOffset != _dragStartSelection!.baseOffset) {
      editor.userUpdateTextEditingValue(
        editor.textEditingValue.copyWith(
          selection: TextSelection(
            baseOffset: _dragStartSelection!.baseOffset,
            extentOffset: nextExtent.offset,
          ),
        ),
        SelectionChangedCause.drag,
      );
    } else {
      _extendSelection(details.globalPosition, SelectionChangedCause.drag);
    }
  }

  /// Handler for [TextSelectionGestureDetector.onDragSelectionEnd].
  ///
  /// By default, it cleans up the state used for handling certain
  /// built-in behaviors.
  ///
  /// See also:
  ///
  ///  * [TextSelectionGestureDetector.onDragSelectionEnd], which triggers this
  ///    callback.
  @protected
  void onDragSelectionEnd(TapDragEndDetails details) {
    _dragBeganOnPreviousSelection = null;

    if (_shouldShowSelectionToolbar &&
        _getEffectiveConsecutiveTapCount(details.consecutiveTapCount) == 2) {
      editor.showToolbar();
    }

    if (_isShiftPressed) {
      _dragStartSelection = null;
    }

    _hideMagnifierIfSupportedByPlatform();
  }

  /// Returns a [TextSelectionGestureDetector] configured with the handlers
  /// provided by this builder.
  ///
  /// The [child] or its subtree should contain an [editor] whose key is
  /// the [GlobalKey] provided by the [delegate]'s
  /// [TextSelectionGestureDetectorBuilderDelegate.editorKey].
  Widget buildGestureDetector({
    Key? key,
    HitTestBehavior? behavior,
    required Widget child,
  }) {
    return TextSelectionGestureDetector(
      key: key,
      onTapTrackStart: onTapTrackStart,
      onTapTrackReset: onTapTrackReset,
      onTapDown: onTapDown,
      onForcePressStart: delegate.forcePressEnabled ? onForcePressStart : null,
      onForcePressEnd: delegate.forcePressEnabled ? onForcePressEnd : null,
      onSecondaryTap: onSecondaryTap,
      onSecondaryTapDown: onSecondaryTapDown,
      onSingleTapUp: onSingleTapUp,
      onSingleTapCancel: onSingleTapCancel,
      onSingleLongTapStart: onSingleLongTapStart,
      onSingleLongTapMoveUpdate: onSingleLongTapMoveUpdate,
      onSingleLongTapEnd: onSingleLongTapEnd,
      onDoubleTapDown: onDoubleTapDown,
      onTripleTapDown: onTripleTapDown,
      onDragSelectionStart: onDragSelectionStart,
      onDragSelectionUpdate: onDragSelectionUpdate,
      onDragSelectionEnd: onDragSelectionEnd,
      behavior: behavior,
      child: child,
    );
  }
}
