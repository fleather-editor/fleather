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
    if (selection.isCollapsed) {
      return [];
    }

    final childIter = _childrenIterator();
    final accWidth = childIter
        .take(selection.extentOffset)
        .fold(0.0, (acc, child) => acc + child.size.width);

    return <TextBox>[
      TextBox.fromLTRBD(0.0, 0.0, accWidth, size.height, TextDirection.ltr)
    ];
  }

  @override
  double? getFullHeightForCaret(TextPosition position) {
    return preferredLineHeight;
  }

  @override
  Offset getOffsetForCaret(TextPosition position, Rect caretPrototype) {
    final childIter = _childrenIterator();
    final accWidth = childIter
        .take(position.offset)
        .fold(0.0, (acc, child) => acc + child.size.width);
    return Offset(accWidth, 0.0);
  }

  @override
  TextPosition getPositionForOffset(Offset offset) {
    if (childCount == 0) {
      return const TextPosition(offset: 0);
    }

    double accWidth = 0;
    int i = 0;
    final childIter = _childrenIterator();

    for (final child in childIter) {
      final halfWidth = child.size.width / 2;
      accWidth += halfWidth;

      if (offset.dx < accWidth) {
        return TextPosition(offset: i);
      }

      accWidth += halfWidth;
      i += 1;
    }

    return TextPosition(offset: childCount);
  }

  @override
  TextRange getWordBoundary(TextPosition position) {
    return TextRange(start: 0, end: childCount);
  }

  @override
  double get preferredLineHeight => size.height;

  _RenderFlexChildrenIterator _childrenIterator() {
    return _RenderFlexChildrenIterator(this);
  }
}

class _RenderFlexChildrenIterator extends Iterable<RenderBox>
    with Iterator<RenderBox> {
  final RenderFlex _flex;
  @override
  final int length;
  RenderBox? _current;

  _RenderFlexChildrenIterator(this._flex) : length = _flex.childCount;

  @override
  RenderBox get current => _current as RenderBox;

  @override
  Iterator<RenderBox> get iterator => this;

  @override
  bool moveNext() {
    final RenderBox? next;
    if (_current == null) {
      next = _flex.firstChild;
    } else {
      next = _flex.childAfter(_current!);
    }

    if (next == null) {
      return false;
    }

    _current = next;
    return true;
  }
}
