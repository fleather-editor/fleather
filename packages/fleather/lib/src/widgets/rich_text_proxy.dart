import 'package:flutter/widgets.dart';

import '../rendering/paragraph_proxy.dart';

class RichTextProxy extends SingleChildRenderObjectWidget {
  /// Child argument should be an instance of RichText widget.
  const RichTextProxy({
    super.key,
    required RichText super.child,
    required this.textStyle,
    required this.locale,
    required this.strutStyle,
    required this.textAlign,
    this.textScaler = TextScaler.noScaling,
    this.textWidthBasis = TextWidthBasis.parent,
    this.textHeightBehavior,
  });

  final TextStyle textStyle;
  final TextAlign textAlign;
  final TextScaler textScaler;
  final Locale? locale;
  final StrutStyle strutStyle;
  final TextWidthBasis textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;

  @override
  RenderParagraphProxy createRenderObject(BuildContext context) {
    return RenderParagraphProxy(
      textStyle: textStyle,
      textDirection: Directionality.of(context),
      textScaler: textScaler,
      locale: locale,
      strutStyle: strutStyle,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderParagraphProxy renderObject) {
    renderObject.textStyle = textStyle;
    renderObject.textDirection = Directionality.of(context);
    renderObject.textAlign = textAlign;
    renderObject.textScaler = textScaler;
    renderObject.locale = locale;
    renderObject.strutStyle = strutStyle;
    renderObject.textWidthBasis = textWidthBasis;
    renderObject.textHeightBehavior = textHeightBehavior;
  }
}
