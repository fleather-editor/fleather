import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter_portal/enhanced_composited_transform.dart';

import 'editable_box.dart';

/// Proxy to built-in [RenderParagraph] so that it can be used inside Fleather
/// editor.
class RenderParagraphProxy extends RenderProxyBox
    implements RenderContentProxyBox {
  RenderParagraphProxy({
    required TextStyle textStyle,
    required double textScaleFactor,
    required TextWidthBasis textWidthBasis,
    required this.layerLink,
    RenderBox Function()? portalTheater,
    RenderParagraph? child,
    TextDirection? textDirection,
    StrutStyle? strutStyle,
    Locale? locale,
    TextHeightBehavior? textHeightBehavior,
  })  : _prototypePainter = TextPainter(
            text: TextSpan(text: ' ', style: textStyle),
            textAlign: TextAlign.left,
            textDirection: textDirection,
            textScaleFactor: textScaleFactor,
            strutStyle: strutStyle,
            locale: locale,
            textWidthBasis: textWidthBasis,
            textHeightBehavior: textHeightBehavior),
        _portalTheater = portalTheater,
        super(child);

  final TextPainter _prototypePainter;
  final EnhancedLayerLink layerLink;
  RenderBox Function()? _portalTheater;

  set textStyle(TextStyle value) {
    if (_prototypePainter.text!.style == value) return;
    _prototypePainter.text = TextSpan(text: ' ', style: value);
    markNeedsLayout();
  }

  set textDirection(TextDirection value) {
    if (_prototypePainter.textDirection == value) return;
    _prototypePainter.textDirection = value;
    markNeedsLayout();
  }

  set textAlign(TextAlign value) {
    if (_prototypePainter.textAlign == value) return;
    _prototypePainter.textAlign = value;
    markNeedsLayout();
  }

  set textScaleFactor(double value) {
    if (_prototypePainter.textScaleFactor == value) return;
    _prototypePainter.textScaleFactor = value;
    markNeedsLayout();
  }

  set strutStyle(StrutStyle value) {
    if (_prototypePainter.strutStyle == value) return;
    _prototypePainter.strutStyle = value;
    markNeedsLayout();
  }

  set locale(Locale? value) {
    if (_prototypePainter.locale == value) return;
    _prototypePainter.locale = value;
    markNeedsLayout();
  }

  set textWidthBasis(TextWidthBasis value) {
    if (_prototypePainter.textWidthBasis == value) return;
    _prototypePainter.textWidthBasis = value;
    markNeedsLayout();
  }

  set textHeightBehavior(TextHeightBehavior? value) {
    if (_prototypePainter.textHeightBehavior == value) return;
    _prototypePainter.textHeightBehavior = value;
    markNeedsLayout();
  }

  set portalTheater(RenderBox Function()? value) {
    if (_portalTheater == value) return;
    _portalTheater = value;
    markNeedsPaint();
  }

  @override
  RenderParagraph? get child => super.child as RenderParagraph?;

  @override
  double get preferredLineHeight => _prototypePainter.preferredLineHeight;

  @override
  Offset getOffsetForCaret(TextPosition position, Rect caretPrototype) {
    return child!.getOffsetForCaret(position, caretPrototype);
  }

  @override
  TextPosition getPositionForOffset(Offset offset) {
    return child!.getPositionForOffset(offset);
  }

  @override
  double? getFullHeightForCaret(TextPosition position) {
    return child!.getFullHeightForCaret(position);
  }

  @override
  TextRange getWordBoundary(TextPosition position) {
    return child!.getWordBoundary(position);
  }

  @override
  List<TextBox> getBoxesForSelection(TextSelection selection) {
    return child!
        .getBoxesForSelection(selection, boxHeightStyle: BoxHeightStyle.max);
  }

  @override
  void performLayout() {
    super.performLayout();
    _prototypePainter.layout(
        minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    Rect getTheatherRect() {
      assert(_portalTheater != null);
      final theater = _portalTheater!();
      final shift = globalToLocal(Offset.zero, ancestor: theater) /*- offset*/;
      final r = shift & theater.size;
      return r;
    }

    context.pushLayer(
        EnhancedLeaderLayer(
          debugName: '42',
          link: layerLink,
          offset: offset,
          theaterRectRelativeToLeader: getTheatherRect,
        ),
        super.paint,
        Offset.zero);
  }
}
