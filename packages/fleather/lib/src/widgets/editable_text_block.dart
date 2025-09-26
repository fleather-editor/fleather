import 'package:collection/collection.dart';
import 'package:fleather/src/widgets/embed_registry.dart';
import 'package:flutter/material.dart';
import 'package:parchment/parchment.dart';

import '../../util.dart';
import '../rendering/editable_text_block.dart';
import 'checkbox.dart';
import 'controller.dart';
import 'cursor.dart';
import 'editable_text_line.dart';
import 'link.dart';
import 'text_line.dart';
import 'theme.dart';

class EditableTextBlock extends StatelessWidget {
  final BlockNode node;
  final FleatherController controller;
  final bool readOnly;
  final VerticalSpacing spacing;
  final CursorController cursorController;
  final TextWidthBasis textWidthBasis;
  final TextSelection selection;
  final Color selectionColor;
  final bool enableInteractiveSelection;
  final bool hasFocus;
  final EmbedRegistry embedRegistry;
  final LinkActionPicker linkActionPicker;
  final ValueChanged<String?>? onLaunchUrl;
  final EdgeInsets? contentPadding;

  const EditableTextBlock({
    super.key,
    required this.node,
    required this.controller,
    required this.readOnly,
    required this.spacing,
    required this.cursorController,
    required this.textWidthBasis,
    required this.selection,
    required this.selectionColor,
    required this.enableInteractiveSelection,
    required this.hasFocus,
    required this.embedRegistry,
    required this.linkActionPicker,
    this.onLaunchUrl,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));

    final theme = FleatherTheme.of(context)!;
    return _EditableBlock(
      node: node,
      padding: spacing,
      contentPadding: contentPadding,
      textWidthBasis: textWidthBasis,
      decoration: _getDecorationForBlock(node, theme) ?? const BoxDecoration(),
      children: _buildChildren(context),
    );
  }

  List<Widget> _buildChildren(BuildContext context) {
    final theme = FleatherTheme.of(context)!;
    final count = node.children.length;
    final lineNodes = node.children.toList().cast<LineNode>();
    final leadingWidgets = _buildLeading(theme, lineNodes);
    final children = <Widget>[];
    var index = 0;
    for (final line in lineNodes) {
      final nodeTextDirection = getDirectionOfNode(line);
      children.add(Directionality(
        textDirection: nodeTextDirection,
        child: EditableTextLine(
          node: line,
          spacing: _getSpacingForLine(line, index, count, theme),
          leading: leadingWidgets?[index],
          indentWidth: _getIndentWidth(line),
          devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
          body: TextLine(
            node: line,
            readOnly: readOnly,
            controller: controller,
            embedRegistry: embedRegistry,
            linkActionPicker: linkActionPicker,
            onLaunchUrl: onLaunchUrl,
            textWidthBasis: textWidthBasis,
          ),
          cursorController: cursorController,
          selection: selection,
          selectionColor: selectionColor,
          enableInteractiveSelection: enableInteractiveSelection,
          hasFocus: hasFocus,
        ),
      ));
      index++;
    }
    return children.toList(growable: false);
  }

  List<Widget>? _buildLeading(
      FleatherThemeData theme, List<LineNode> children) {
    final block = node.style.get(ParchmentAttribute.block);
    if (block == ParchmentAttribute.block.numberList) {
      return _buildNumberPointsForNumberList(theme, children);
    } else if (block == ParchmentAttribute.block.bulletList) {
      return _buildBulletPointForBulletList(theme, children);
    } else if (block == ParchmentAttribute.block.code) {
      return _buildNumberPointsForCodeBlock(theme, children);
    } else if (block == ParchmentAttribute.block.checkList) {
      return _buildCheckboxForCheckList(theme, children);
    } else {
      return null;
    }
  }

  List<Widget> _buildCheckboxForCheckList(
          FleatherThemeData theme, List<LineNode> children) =>
      children.map((node) {
        return _CheckboxPoint(
          value: node.style.containsSame(ParchmentAttribute.checked),
          enabled: !readOnly,
          onChanged: (checked) => _toggle(node, checked),
        );
      }).toList();

  List<Widget> _buildBulletPointForBulletList(
          FleatherThemeData theme, List<Node> children) =>
      children
          .map((_) => _BulletPoint(
                style:
                    theme.paragraph.style.copyWith(fontWeight: FontWeight.bold),
                strutStyle: theme.strutStyle,
              ))
          .toList();

  List<Widget> _buildNumberPointsForCodeBlock(
          FleatherThemeData theme, List<LineNode> children) =>
      children
          .mapIndexed((i, _) => _NumberPoint(
                number: i + 1,
                style: theme.code.style.copyWith(
                    color: theme.code.style.color?.withValues(alpha: 0.4)),
                width: 32.0,
                padding: 8,
                withDot: false,
                strutStyle: theme.strutStyle,
              ))
          .toList();

  List<Widget> _buildNumberPointsForNumberList(
      FleatherThemeData theme, List<LineNode> children) {
    final leadingWidgets = <Widget>[];
    final levelsIndexes = <int, int>{};
    int? lastLevel;
    for (final element in children) {
      final currentLevel =
          element.style.get(ParchmentAttribute.indent)?.value ?? 0;
      var currentIndex = 0;

      if (lastLevel != null) {
        if (lastLevel == currentLevel) {
          currentIndex = levelsIndexes[lastLevel]! + 1;
        } else if (lastLevel > currentLevel) {
          final currentLevelIndex = levelsIndexes[currentLevel];
          currentIndex = currentLevelIndex == null ? 0 : currentLevelIndex + 1;
        }
      }

      leadingWidgets.add(_NumberPoint(
        number: currentIndex + 1,
        style: theme.lists.style,
        width: 32.0,
        padding: 8.0,
        strutStyle: theme.strutStyle,
      ));
      levelsIndexes[currentLevel] = currentIndex;
      lastLevel = currentLevel;
    }
    return leadingWidgets;
  }

  double _getIndentWidth(LineNode line) {
    final block = node.style.get(ParchmentAttribute.block);

    final indentationLevel =
        line.style.get(ParchmentAttribute.indent)?.value ?? 0;
    var extraIndent = indentationLevel * 16;

    if (block == ParchmentAttribute.block.quote) {
      return extraIndent + 16.0;
    } else {
      return extraIndent + 32.0;
    }
  }

  VerticalSpacing _getSpacingForLine(
      LineNode node, int index, int count, FleatherThemeData theme) {
    final heading = node.style.get(ParchmentAttribute.heading);

    double? top;
    double? bottom;

    if (heading == ParchmentAttribute.heading.level1) {
      top = theme.heading1.spacing.top;
      bottom = theme.heading1.spacing.bottom;
    } else if (heading == ParchmentAttribute.heading.level2) {
      top = theme.heading2.spacing.top;
      bottom = theme.heading2.spacing.bottom;
    } else if (heading == ParchmentAttribute.heading.level3) {
      top = theme.heading3.spacing.top;
      bottom = theme.heading3.spacing.bottom;
    } else if (heading == ParchmentAttribute.heading.level4) {
      top = theme.heading4.spacing.top;
      bottom = theme.heading4.spacing.bottom;
    } else if (heading == ParchmentAttribute.heading.level5) {
      top = theme.heading5.spacing.top;
      bottom = theme.heading5.spacing.bottom;
    } else if (heading == ParchmentAttribute.heading.level6) {
      top = theme.heading6.spacing.top;
      bottom = theme.heading6.spacing.bottom;
    } else {
      final block = this.node.style.get(ParchmentAttribute.block);
      VerticalSpacing? lineSpacing;
      if (block == ParchmentAttribute.block.quote) {
        lineSpacing = theme.quote.lineSpacing;
      } else if (block == ParchmentAttribute.block.numberList ||
          block == ParchmentAttribute.block.bulletList ||
          block == ParchmentAttribute.block.checkList) {
        lineSpacing = theme.lists.lineSpacing;
      } else if (block == ParchmentAttribute.block.code) {
        lineSpacing = theme.lists.lineSpacing;
      }
      top = lineSpacing?.top;
      bottom = lineSpacing?.bottom;
    }

    // If this line is the top one in this block we ignore its top spacing
    // because the block itself already has it. Similarly with the last line
    // and its bottom spacing.
    if (index == 0) {
      top = 0.0;
    }

    if (index == count - 1) {
      bottom = 0.0;
    }

    return VerticalSpacing(top: top ?? 0, bottom: bottom ?? 0);
  }

  BoxDecoration? _getDecorationForBlock(
      BlockNode node, FleatherThemeData theme) {
    final style = node.style.get(ParchmentAttribute.block);
    if (style == ParchmentAttribute.block.quote) {
      return theme.quote.decoration;
    } else if (style == ParchmentAttribute.block.code) {
      return theme.code.decoration;
    }
    return null;
  }

  void _toggle(LineNode node, bool checked) {
    final attr =
        checked ? ParchmentAttribute.checked : ParchmentAttribute.checked.unset;
    controller.formatText(node.documentOffset, 0, attr, notify: false);
  }
}

class _EditableBlock extends MultiChildRenderObjectWidget {
  final BlockNode node;
  final VerticalSpacing padding;
  final Decoration decoration;
  final EdgeInsets? contentPadding;
  final TextWidthBasis textWidthBasis;

  const _EditableBlock({
    required this.node,
    required this.decoration,
    required this.textWidthBasis,
    required super.children,
    this.contentPadding,
    this.padding = const VerticalSpacing(),
  });

  EdgeInsets get _padding =>
      EdgeInsets.only(top: padding.top, bottom: padding.bottom);

  EdgeInsets get _contentPadding => contentPadding ?? EdgeInsets.zero;

  @override
  RenderEditableTextBlock createRenderObject(BuildContext context) {
    return RenderEditableTextBlock(
      node: node,
      textDirection: Directionality.of(context),
      padding: _padding,
      decoration: decoration,
      contentPadding: _contentPadding,
      textWidthBasis: textWidthBasis,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderEditableTextBlock renderObject) {
    renderObject.node = node;
    renderObject.textDirection = Directionality.of(context);
    renderObject.padding = _padding;
    renderObject.decoration = decoration;
    renderObject.contentPadding = _contentPadding;
    renderObject.textWidthBasis = textWidthBasis;
  }
}

class _NumberPoint extends StatelessWidget {
  final int number;
  final double width;
  final bool withDot;
  final double padding;
  final TextStyle style;
  final StrutStyle? strutStyle;

  const _NumberPoint({
    required this.number,
    required this.width,
    required this.style,
    this.strutStyle,
    this.withDot = true,
    this.padding = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Empirically, depending on height of the style, we need to
      // align at top or at bottom
      alignment: AlignmentDirectional.topEnd,
      width: width,
      padding: EdgeInsetsDirectional.only(end: padding),
      child: Text(
        withDot ? '$number.' : '$number',
        style: style,
        strutStyle: strutStyle,
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final TextStyle style;
  final StrutStyle? strutStyle;

  const _BulletPoint({
    required this.style,
    this.strutStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: AlignmentDirectional.topEnd,
      width: 32,
      padding: const EdgeInsetsDirectional.only(end: 13.0),
      child: Text(
        '•',
        style: style,
        strutStyle: strutStyle,
      ),
    );
  }
}

class _CheckboxPoint extends StatefulWidget {
  const _CheckboxPoint({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  State<_CheckboxPoint> createState() => _CheckboxPointState();
}

class _CheckboxPointState extends State<_CheckboxPoint> {
  late bool value = widget.value;

  @override
  void didUpdateWidget(covariant _CheckboxPoint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (value != widget.value) {
      setState(() => value = widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: AlignmentDirectional.topEnd,
      padding: const EdgeInsetsDirectional.only(top: 2.0, end: 12.0),
      child: FleatherCheckbox(
        value: value,
        onChanged: widget.enabled
            ? (_) {
                widget.onChanged(!value);
                setState(() => value = !value);
              }
            : null,
      ),
    );
  }
}
