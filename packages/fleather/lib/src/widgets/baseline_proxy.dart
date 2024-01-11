import 'package:flutter/material.dart';

import '../rendering/baseline_proxy.dart';

/// Provides baseline metrics for the editor.
///
/// This widget exists to address the issue of [SingleChildScrollView] not
/// computing distance to actual baseline which causes issues when Fleather
/// editor is wrapped with [InputDecorator]. Specifically the decorator's
/// hintText is rendered in a wrong place.
///
/// BaselineProxy attempts simulates the editor's baseline based on the
/// [textStyle] of the first line in the document as well as additional
/// [padding] around it.
class BaselineProxy extends SingleChildRenderObjectWidget {
  final TextStyle textStyle;
  final EdgeInsets padding;

  const BaselineProxy({
    super.key,
    super.child,
    required this.textStyle,
    required this.padding,
  });

  @override
  RenderBaselineProxy createRenderObject(BuildContext context) {
    return RenderBaselineProxy(
      textStyle: textStyle,
      padding: padding,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderBaselineProxy renderObject) {
    renderObject
      ..textStyle = textStyle
      ..padding = padding;
  }
}
