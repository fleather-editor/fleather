import 'package:flutter/rendering.dart';

import 'editable_box.dart';

/// Proxy to an arbitrary embeddable [RenderBox].
///
/// Computes necessary editing metrics based on the dimensions of the child
/// render box.
class RenderEmbedProxy extends RenderProxyBox implements RenderContentProxyBox {
  RenderEmbedProxy({RenderBox? child}) : super(child);

  @override
  List<TextBox> getBoxesForSelection(TextSelection selection) {
    if (selection.isCollapsed) {
      final left = selection.extentOffset == 0 ? 0.0 : size.width;
      final right = selection.extentOffset == 0 ? 0.0 : size.width;
      return <TextBox>[
        TextBox.fromLTRBD(left, 0.0, right, size.height, TextDirection.ltr)
      ];
    }
    return <TextBox>[
      TextBox.fromLTRBD(0.0, 0.0, size.width, size.height, TextDirection.ltr)
    ];
  }

  @override
  double getFullHeightForCaret(TextPosition position) {
    return preferredLineHeight;
  }

  @override
  Offset getOffsetForCaret(TextPosition position, Rect caretPrototype) {
    assert(position.offset == 0 || position.offset == 1);
    return (position.offset == 0)
        ? Offset.zero
        : Offset(size.width - caretPrototype.width, 0.0);
  }

  @override
  TextPosition getPositionForOffset(Offset offset) {
    final position = (offset.dx > size.width / 2) ? 1 : 0;
    return TextPosition(offset: position);
  }

  @override
  TextRange getWordBoundary(TextPosition position) {
    return const TextRange(start: 0, end: 1);
  }

  @override
  double get preferredLineHeight => size.height;
}

/// Proxy to an arbitrary embeddable [RenderBox].
///
/// Computes necessary editing metrics based on the dimensions of the childlren
/// render boxes.
class RenderGroupEmbedProxy extends RenderFlex
    implements RenderContentProxyBox {
  RenderGroupEmbedProxy({
    TextDirection? textDirection,
  }) : super(textDirection: textDirection);

  @override
  List<TextBox> getBoxesForSelection(TextSelection selection) {
    return [];
  }

  @override
  double? getFullHeightForCaret(TextPosition position) {
    return preferredLineHeight;
  }

  @override
  Offset getOffsetForCaret(TextPosition position, Rect caretPrototype) {
    if (childCount == 0 || position.offset == 0) {
      return Offset.zero;
    }

    RenderBox? child;
    double accWidth = 0;

    for (var i = 0; i < childCount; i += 1) {
      if (position.offset <= i) {
        return Offset(accWidth, 0.0);
      }

      if (i == 0) {
        child = firstChild!;
      } else {
        child = childAfter(child!)!;
      }

      // TODO: Can we use `semanticBounds` here?
      // As an alternative I can also calculate the size myself:
      //   final width = (child as RenderBox).getMinIntrinsicWidth(size.height);
      final width = child.semanticBounds.width;
      accWidth += width;
    }

    return Offset(accWidth, 0.0);
  }

  @override
  TextPosition getPositionForOffset(Offset offset) {
    if (childCount == 0) {
      return const TextPosition(offset: 0);
    }

    RenderBox? child;
    double accWidth = 0;

    for (var i = 0; i < childCount; i += 1) {
      if (i == 0) {
        child = firstChild!;
      } else {
        child = childAfter(child!)!;
      }

      // I don't know what to use. As an alternative I can also calculate the size myself:
      //   final width = (child as RenderBox).getMinIntrinsicWidth(size.height);
      final halfWidth = child.semanticBounds.width / 2;
      accWidth += halfWidth;

      if (offset.dx < accWidth) {
        return TextPosition(offset: i);
      }

      accWidth += halfWidth;
    }

    return TextPosition(offset: childCount);
  }

  @override
  TextRange getWordBoundary(TextPosition position) {
    return TextRange(start: 0, end: childCount);
  }

  @override
  double get preferredLineHeight => size.height;
}
