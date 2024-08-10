import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:parchment/parchment.dart';

import 'controller.dart';
import 'editor.dart';
import 'theme.dart';
import '../../l10n/l10n.dart';

const double kToolbarHeight = 56.0;

class InsertEmbedButton extends StatelessWidget {
  final FleatherController controller;
  final IconData icon;

  const InsertEmbedButton({
    super.key,
    required this.controller,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return FLIconButton(
      highlightElevation: 0,
      hoverElevation: 0,
      size: 32,
      icon: Icon(
        icon,
        size: 18,
        color: Theme.of(context).iconTheme.color,
      ),
      fillColor: Theme.of(context).canvasColor,
      onPressed: () {
        final index = controller.selection.baseOffset;
        final length = controller.selection.extentOffset - index;
        // Move the cursor to the beginning of the line right after the embed.
        // 2 = 1 for the embed itself and 1 for the newline after it
        final newSelection = controller.selection.copyWith(
          baseOffset: index + 2,
          extentOffset: index + 2,
        );
        controller.replaceText(index, length, BlockEmbed.horizontalRule,
            selection: newSelection);
        FleatherToolbar._of(context).requestKeyboard();
      },
    );
  }
}

class UndoRedoButton extends StatelessWidget {
  final FleatherController controller;
  final _UndoRedoButtonVariant _variant;

  const UndoRedoButton._(this.controller, this._variant, {super.key});

  const UndoRedoButton.undo({
    Key? key,
    required FleatherController controller,
  }) : this._(controller, _UndoRedoButtonVariant.undo, key: key);

  const UndoRedoButton.redo({
    Key? key,
    required FleatherController controller,
  }) : this._(controller, _UndoRedoButtonVariant.redo, key: key);

  bool _isEnabled() {
    if (_variant == _UndoRedoButtonVariant.undo) {
      return controller.canUndo;
    } else {
      return controller.canRedo;
    }
  }

  void _onPressed() {
    if (_variant == _UndoRedoButtonVariant.undo) {
      controller.undo();
    } else {
      controller.redo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final icon =
              _variant == _UndoRedoButtonVariant.undo ? Icons.undo : Icons.redo;
          final isEnabled = _isEnabled();
          final theme = Theme.of(context);

          return FLIconButton(
            highlightElevation: 0,
            hoverElevation: 0,
            size: 32,
            icon: Icon(
              icon,
              size: 18,
              color: isEnabled ? theme.iconTheme.color : theme.disabledColor,
            ),
            fillColor: Theme.of(context).canvasColor,
            onPressed: isEnabled ? _onPressed : null,
          );
        });
  }
}

enum _UndoRedoButtonVariant {
  undo,
  redo,
}

/// Toolbar button for formatting text as a link.
class LinkStyleButton extends StatefulWidget {
  final FleatherController controller;
  final IconData? icon;

  const LinkStyleButton({
    super.key,
    required this.controller,
    this.icon,
  });

  @override
  State<LinkStyleButton> createState() => _LinkStyleButtonState();
}

class _LinkStyleButtonState extends State<LinkStyleButton> {
  void _didChangeSelection() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_didChangeSelection);
  }

  @override
  void didUpdateWidget(covariant LinkStyleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_didChangeSelection);
      widget.controller.addListener(_didChangeSelection);
    }
  }

  @override
  void dispose() {
    super.dispose();
    widget.controller.removeListener(_didChangeSelection);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = !widget.controller.selection.isCollapsed;
    final pressedHandler = isEnabled ? () => _openLinkDialog(context) : null;
    return FLIconButton(
      highlightElevation: 0,
      hoverElevation: 0,
      size: 32,
      icon: Icon(
        widget.icon ?? Icons.link,
        size: 18,
        color: isEnabled ? theme.iconTheme.color : theme.disabledColor,
      ),
      fillColor: Theme.of(context).canvasColor,
      onPressed: pressedHandler,
    );
  }

  void _openLinkDialog(BuildContext context) {
    showDialog<String>(
      context: context,
      builder: (ctx) {
        return const _LinkDialog();
      },
    ).then(_linkSubmitted);
  }

  void _linkSubmitted(String? value) {
    if (value == null || value.isEmpty) return;
    widget.controller
        .formatSelection(ParchmentAttribute.link.fromString(value));
    FleatherToolbar._of(context).requestKeyboard();
  }
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog();

  @override
  _LinkDialogState createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  String _link = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: TextField(
        decoration: InputDecoration(
          labelText: context.l.addLinkDialogPasteLink,
        ),
        autofocus: true,
        onChanged: _linkChanged,
      ),
      actions: [
        TextButton(
          onPressed: _link.isNotEmpty ? _applyLink : null,
          child: Text(context.l.addLinkDialogApply),
        ),
      ],
    );
  }

  void _linkChanged(String value) {
    setState(() {
      _link = value;
    });
  }

  void _applyLink() {
    Navigator.pop(context, _link);
  }
}

/// Builder for toolbar buttons handling toggleable style attributes.
///
/// See [defaultToggleStyleButtonBuilder] as a reference implementation.
typedef ToggleStyleButtonBuilder = Widget Function(
  BuildContext context,
  ParchmentAttribute attribute,
  IconData icon,
  bool isToggled,
  VoidCallback? onPressed,
);

/// Toolbar button which allows to toggle a style attribute on or off.
class ToggleStyleButton extends StatefulWidget {
  /// The style attribute controlled by this button.
  final ParchmentAttribute attribute;

  /// The icon representing the style [attribute].
  final IconData icon;

  /// Controller attached to a Fleather editor.
  final FleatherController controller;

  /// Builder function to customize visual representation of this button.
  final ToggleStyleButtonBuilder childBuilder;

  const ToggleStyleButton({
    super.key,
    required this.attribute,
    required this.icon,
    required this.controller,
    this.childBuilder = defaultToggleStyleButtonBuilder,
  });

  @override
  State<ToggleStyleButton> createState() => _ToggleStyleButtonState();
}

class _ToggleStyleButtonState extends State<ToggleStyleButton> {
  late bool _isToggled;

  ParchmentStyle get _selectionStyle => widget.controller.getSelectionStyle();

  void _didChangeEditingValue() {
    setState(() => _checkIsToggled());
  }

  @override
  void initState() {
    super.initState();
    _checkIsToggled();
    widget.controller.addListener(_didChangeEditingValue);
  }

  @override
  void didUpdateWidget(covariant ToggleStyleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_didChangeEditingValue);
      widget.controller.addListener(_didChangeEditingValue);
      _checkIsToggled();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_didChangeEditingValue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If the cursor is currently inside a code block we disable all
    // toggle style buttons (except the code block button itself) since there
    // is no point in applying styles to a unformatted block of text.
    // TODO: Add code block checks to heading and embed buttons as well.
    final isInCodeBlock =
        _selectionStyle.containsSame(ParchmentAttribute.block.code);
    final isEnabled =
        !isInCodeBlock || widget.attribute == ParchmentAttribute.block.code;
    return widget.childBuilder(context, widget.attribute, widget.icon,
        _isToggled, isEnabled ? _toggleAttribute : null);
  }

  void _toggleAttribute() {
    if (_isToggled) {
      if (!widget.attribute.isUnset) {
        widget.controller.formatSelection(widget.attribute.unset);
      }
    } else {
      widget.controller.formatSelection(widget.attribute);
    }
    FleatherToolbar._of(context).requestKeyboard();
  }

  void _checkIsToggled() {
    if (widget.attribute.isUnset) {
      _isToggled = !_selectionStyle.contains(widget.attribute);
    } else {
      _isToggled = _selectionStyle.containsSame(widget.attribute);
    }
  }
}

/// Default builder for toggle style buttons.
Widget defaultToggleStyleButtonBuilder(
  BuildContext context,
  ParchmentAttribute attribute,
  IconData icon,
  bool isToggled,
  VoidCallback? onPressed,
) {
  final theme = Theme.of(context);
  final isEnabled = onPressed != null;
  final iconColor = isEnabled
      ? isToggled
          ? theme.primaryIconTheme.color
          : theme.iconTheme.color
      : theme.disabledColor;
  final fillColor = isToggled ? theme.colorScheme.secondary : theme.canvasColor;
  return FLIconButton(
    highlightElevation: 0,
    hoverElevation: 0,
    size: 32,
    icon: Icon(icon, size: 18, color: iconColor),
    fillColor: fillColor,
    onPressed: onPressed,
  );
}

/// Signature of callbacks that return a [Color] picked from a palette built in
/// a [BuildContext] with a [String] specifying the label of the `null` selection
/// option
typedef PickColor = Future<Color?> Function(BuildContext, String);

/// Signature of callbacks the returns a [Widget] from a [BuildContext]
/// and a [Color] (`null` color to use the default color of the text - copes with dark mode).
typedef ColorButtonBuilder = Widget Function(BuildContext, Color?);

/// Toolbar button which allows to apply background color style to a portion of text.
///
/// Works as a dropdown menu button.
class ColorButton extends StatefulWidget {
  const ColorButton(
      {super.key,
      required this.controller,
      required this.attributeKey,
      required this.nullColorLabel,
      required this.builder,
      this.pickColor});

  final FleatherController controller;
  final ColorParchmentAttributeBuilder attributeKey;
  final String nullColorLabel;
  final ColorButtonBuilder builder;
  final PickColor? pickColor;

  @override
  State<ColorButton> createState() => _ColorButtonState();
}

class _ColorButtonState extends State<ColorButton> {
  static double buttonSize = 32;

  late Color? _value;

  ParchmentStyle get _selectionStyle => widget.controller.getSelectionStyle();

  void _didChangeEditingValue() {
    setState(() {
      final selectionColor = _selectionStyle.get(widget.attributeKey);
      _value =
          selectionColor?.value != null ? Color(selectionColor!.value!) : null;
    });
  }

  Future<Color?> _defaultPickColor(
      BuildContext context, String nullColorLabel) async {
    final isMobile = switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
    final maxWidth = isMobile ? 200.0 : 100.0;

    final completer = Completer<Color?>();

    final selector = Material(
      key: const Key('color_selector'),
      elevation: 4.0,
      color: Theme.of(context).canvasColor,
      child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.all(8.0),
          child: _ColorPalette(nullColorLabel,
              onSelectedColor: completer.complete)),
    );

    return SelectorScope.showSelector(context, selector, completer);
  }

  @override
  void initState() {
    super.initState();
    final selectionColor = _selectionStyle.get(widget.attributeKey);
    _value =
        selectionColor?.value != null ? Color(selectionColor!.value!) : null;
    widget.controller.addListener(_didChangeEditingValue);
  }

  @override
  void didUpdateWidget(covariant ColorButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_didChangeEditingValue);
      widget.controller.addListener(_didChangeEditingValue);
      final selectionColor = _selectionStyle.get(widget.attributeKey);
      _value =
          selectionColor?.value != null ? Color(selectionColor!.value!) : null;
    }
  }

  @override
  void dispose() {
    super.dispose();
    widget.controller.removeListener(_didChangeEditingValue);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints:
          BoxConstraints.tightFor(width: buttonSize, height: buttonSize),
      child: RawMaterialButton(
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        padding: EdgeInsets.zero,
        elevation: 0,
        fillColor: Theme.of(context).canvasColor,
        highlightElevation: 0,
        hoverElevation: 0,
        onPressed: () async {
          final toolbar = FleatherToolbar._of(context);
          final selectedColor = await (widget.pickColor ?? _defaultPickColor)(
              context, widget.nullColorLabel);
          final attribute = selectedColor != null
              ? widget.attributeKey.withColor(selectedColor.value)
              : widget.attributeKey.unset;
          widget.controller.formatSelection(attribute);
          toolbar.requestKeyboard();
        },
        child: Builder(builder: (context) => widget.builder(context, _value)),
      ),
    );
  }
}

class _ColorPalette extends StatelessWidget {
  static const colors = [
    null,
    Colors.indigo,
    Colors.blue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.brown,
    Colors.grey,
    Colors.white,
    Colors.black,
  ];

  const _ColorPalette(this.nullColorLabel, {required this.onSelectedColor});

  final String nullColorLabel;
  final void Function(Color?) onSelectedColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      runAlignment: WrapAlignment.spaceBetween,
      alignment: WrapAlignment.start,
      runSpacing: 4,
      spacing: 4,
      children: [...colors]
          .map((e) => _ColorPaletteElement(e, nullColorLabel, onSelectedColor))
          .toList(),
    );
  }
}

class _ColorPaletteElement extends StatelessWidget {
  const _ColorPaletteElement(
      this.color, this.nullColorLabel, this.onSelectedColor);

  final Color? color;
  final String nullColorLabel;
  final void Function(Color?) onSelectedColor;

  @override
  Widget build(BuildContext context) {
    final isMobile = switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
    final size = isMobile ? 32.0 : 16.0;
    return Container(
      width: (color == null ? 4 : 1) * size + (color == null ? 3 * 4 : 0),
      height: size,
      decoration: BoxDecoration(color: color),
      child: RawMaterialButton(
        onPressed: () => onSelectedColor(color),
        child: color == null
            ? Text(
                nullColorLabel,
                style: Theme.of(context).textTheme.bodySmall,
              )
            : null,
      ),
    );
  }
}

/// Toolbar button which allows to apply heading style to a line of text in
/// Fleather editor.
///
/// Works as a dropdown menu button.
// TODO: Add "dense" parameter which if set to true changes the button to use an icon instead of text (useful for mobile layouts)
class SelectHeadingButton extends StatefulWidget {
  const SelectHeadingButton({super.key, required this.controller});

  final FleatherController controller;

  @override
  State<SelectHeadingButton> createState() => _SelectHeadingButtonState();
}

Map<ParchmentAttribute<int>, String> _headingToText(BuildContext context) {
  final localizations = context.l;

  return {
    ParchmentAttribute.heading.unset: localizations.headingNormal,
    ParchmentAttribute.heading.level1: localizations.headingLevel1,
    ParchmentAttribute.heading.level2: localizations.headingLevel2,
    ParchmentAttribute.heading.level3: localizations.headingLevel3,
    ParchmentAttribute.heading.level4: localizations.headingLevel4,
    ParchmentAttribute.heading.level5: localizations.headingLevel5,
    ParchmentAttribute.heading.level6: localizations.headingLevel6,
  };
}

class _SelectHeadingButtonState extends State<SelectHeadingButton> {
  static double buttonHeight = 32;

  ParchmentAttribute<int>? current;

  ParchmentStyle get selectionStyle => widget.controller.getSelectionStyle();

  void _didChangeEditingValue() {
    setState(() {
      current = selectionStyle.get(ParchmentAttribute.heading) ??
          ParchmentAttribute.heading.unset;
    });
  }

  @override
  void initState() {
    super.initState();
    current = selectionStyle.get(ParchmentAttribute.heading) ??
        ParchmentAttribute.heading.unset;
    widget.controller.addListener(_didChangeEditingValue);
  }

  @override
  void didUpdateWidget(covariant SelectHeadingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_didChangeEditingValue);
      widget.controller.addListener(_didChangeEditingValue);
      current = selectionStyle.get(ParchmentAttribute.heading) ??
          ParchmentAttribute.heading.unset;
    }
  }

  @override
  void dispose() {
    super.dispose();
    widget.controller.removeListener(_didChangeEditingValue);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(height: buttonHeight),
      child: RawMaterialButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        padding: EdgeInsets.zero,
        fillColor: Theme.of(context).canvasColor,
        elevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        onPressed: () async {
          final toolbar = FleatherToolbar._of(context);
          final attribute = await _selectHeading();
          if (attribute != null) {
            widget.controller.formatSelection(attribute);
            toolbar.requestKeyboard();
          }
        },
        child: Text(_headingToText(context)[current] ?? ''),
      ),
    );
  }

  Future<ParchmentAttribute<int>?> _selectHeading() async {
    final themeData = FleatherTheme.of(context)!;

    final completer = Completer<ParchmentAttribute<int>?>();

    final selector = Material(
      key: const Key('heading_selector'),
      elevation: 4.0,
      borderRadius: BorderRadius.circular(2),
      color: Theme.of(context).canvasColor,
      child: _HeadingList(theme: themeData, onSelected: completer.complete),
    );

    return SelectorScope.showSelector(context, selector, completer);
  }
}

class _HeadingList extends StatelessWidget {
  const _HeadingList({required this.theme, required this.onSelected});

  final FleatherThemeData theme;
  final void Function(ParchmentAttribute<int>) onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _headingToText(context)
              .entries
              .map((entry) => _listItem(theme, entry.key, entry.value))
              .toList(),
        ),
      ),
    );
  }

  Widget _listItem(
      FleatherThemeData? theme, ParchmentAttribute<int> value, String text) {
    final valueToStyle = {
      ParchmentAttribute.heading.unset: theme?.paragraph.style,
      ParchmentAttribute.heading.level1: theme?.heading1.style,
      ParchmentAttribute.heading.level2: theme?.heading2.style,
      ParchmentAttribute.heading.level3: theme?.heading3.style,
      ParchmentAttribute.heading.level4: theme?.heading4.style,
      ParchmentAttribute.heading.level5: theme?.heading5.style,
      ParchmentAttribute.heading.level6: theme?.heading6.style,
    };
    return _HeadingListEntry(
        value: value,
        text: text,
        style: valueToStyle[value],
        onSelected: onSelected);
  }
}

class _HeadingListEntry extends StatelessWidget {
  const _HeadingListEntry(
      {required this.value,
      required this.text,
      required this.style,
      required this.onSelected});

  final ParchmentAttribute<int> value;
  final String text;
  final TextStyle? style;
  final void Function(ParchmentAttribute<int>) onSelected;

  @override
  Widget build(BuildContext context) {
    return RawMaterialButton(
      key: Key('heading_entry${value.value ?? 0}'),
      clipBehavior: Clip.antiAlias,
      onPressed: () => onSelected(value),
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Text(
          text,
          maxLines: 1,
          style: style,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class IndentationButton extends StatefulWidget {
  final bool increase;
  final FleatherController controller;

  const IndentationButton(
      {super.key, this.increase = true, required this.controller});

  @override
  State<IndentationButton> createState() => _IndentationButtonState();
}

class _IndentationButtonState extends State<IndentationButton> {
  ParchmentStyle get _selectionStyle => widget.controller.getSelectionStyle();

  void _didChangeEditingValue() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_didChangeEditingValue);
  }

  @override
  void didUpdateWidget(covariant IndentationButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_didChangeEditingValue);
      widget.controller.addListener(_didChangeEditingValue);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_didChangeEditingValue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled =
        !_selectionStyle.containsSame(ParchmentAttribute.block.code);
    final theme = Theme.of(context);
    final iconColor = isEnabled ? theme.iconTheme.color : theme.disabledColor;
    return FLIconButton(
      highlightElevation: 0,
      hoverElevation: 0,
      size: 32,
      icon: Icon(
          widget.increase
              ? Icons.format_indent_increase
              : Icons.format_indent_decrease,
          size: 18,
          color: iconColor),
      fillColor: theme.canvasColor,
      onPressed: isEnabled
          ? () {
              final indentLevel =
                  _selectionStyle.get(ParchmentAttribute.indent)?.value ?? 0;
              if (indentLevel == 0 && !widget.increase) {
                return;
              }
              if (indentLevel == 1 && !widget.increase) {
                widget.controller
                    .formatSelection(ParchmentAttribute.indent.unset);
              } else {
                widget.controller.formatSelection(ParchmentAttribute.indent
                    .withLevel(indentLevel + (widget.increase ? 1 : -1)));
              }
              FleatherToolbar._of(context).requestKeyboard();
            }
          : null,
    );
  }
}

class FleatherToolbar extends StatefulWidget implements PreferredSizeWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  /// If provided, toolbar requests focus and keyboard on toolbar buttons press.
  final GlobalKey<EditorState>? editorKey;

  const FleatherToolbar({
    super.key,
    this.editorKey,
    this.padding,
    required this.children,
  });

  factory FleatherToolbar.basic({
    Key? key,
    required FleatherController controller,
    EdgeInsetsGeometry? padding,
    bool hideBoldButton = false,
    bool hideItalicButton = false,
    bool hideUnderLineButton = false,
    bool hideStrikeThrough = false,
    bool hideBackgroundColor = false,
    bool hideForegroundColor = false,
    bool hideInlineCode = false,
    bool hideHeadingStyle = false,
    bool hideIndentation = false,
    bool hideListNumbers = false,
    bool hideListBullets = false,
    bool hideListChecks = false,
    bool hideCodeBlock = false,
    bool hideQuote = false,
    bool hideLink = false,
    bool hideHorizontalRule = false,
    bool hideDirection = false,
    bool hideUndoRedo = false,
    List<Widget> leading = const <Widget>[],
    List<Widget> trailing = const <Widget>[],
    bool hideAlignment = false,
    GlobalKey<EditorState>? editorKey,
  }) {
    Widget backgroundColorBuilder(context, value) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mode_edit_outline_outlined,
              size: 16,
            ),
            Container(
              width: 18,
              height: 4,
              decoration: BoxDecoration(color: value),
            )
          ],
        );
    Widget textColorBuilder(context, value) {
      Color effectiveColor =
          value ?? DefaultTextStyle.of(context).style.color ?? Colors.black;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.text_fields_sharp,
            size: 16,
          ),
          Container(
            width: 18,
            height: 4,
            decoration: BoxDecoration(color: effectiveColor),
          )
        ],
      );
    }

    return FleatherToolbar(
      key: key,
      editorKey: editorKey,
      padding: padding,
      children: [
        ...leading,

        Visibility(
          visible: !hideBoldButton,
          child: ToggleStyleButton(
            attribute: ParchmentAttribute.bold,
            icon: Icons.format_bold,
            controller: controller,
          ),
        ),
        const SizedBox(width: 1),
        Visibility(
          visible: !hideItalicButton,
          child: ToggleStyleButton(
            attribute: ParchmentAttribute.italic,
            icon: Icons.format_italic,
            controller: controller,
          ),
        ),
        const SizedBox(width: 1),
        Visibility(
          visible: !hideUnderLineButton,
          child: ToggleStyleButton(
            attribute: ParchmentAttribute.underline,
            icon: Icons.format_underline,
            controller: controller,
          ),
        ),
        const SizedBox(width: 1),
        Visibility(
          visible: !hideStrikeThrough,
          child: ToggleStyleButton(
            attribute: ParchmentAttribute.strikethrough,
            icon: Icons.format_strikethrough,
            controller: controller,
          ),
        ),
        const SizedBox(width: 1),
        Builder(builder: (context) {
          return Visibility(
            visible: !hideForegroundColor,
            child: ColorButton(
              controller: controller,
              attributeKey: ParchmentAttribute.foregroundColor,
              nullColorLabel: context.l.foregroundColorAutomatic,
              builder: textColorBuilder,
            ),
          );
        }),
        Builder(builder: (context) {
          return Visibility(
            visible: !hideBackgroundColor,
            child: ColorButton(
              controller: controller,
              attributeKey: ParchmentAttribute.backgroundColor,
              nullColorLabel: context.l.backgroundColorNoColor,
              builder: backgroundColorBuilder,
            ),
          );
        }),
        const SizedBox(width: 1),
        Visibility(
          visible: !hideInlineCode,
          child: ToggleStyleButton(
            attribute: ParchmentAttribute.inlineCode,
            icon: Icons.code,
            controller: controller,
          ),
        ),
        Visibility(
            visible: !hideBoldButton &&
                !hideItalicButton &&
                !hideUnderLineButton &&
                !hideStrikeThrough &&
                !hideInlineCode,
            child: VerticalDivider(
                indent: 16, endIndent: 16, color: Colors.grey.shade400)),

        /// ################################################################

        Visibility(
            visible: !hideDirection,
            child: ToggleStyleButton(
              attribute: ParchmentAttribute.rtl,
              icon: Icons.format_textdirection_r_to_l,
              controller: controller,
            )),
        Visibility(
            visible: !hideDirection,
            child: VerticalDivider(
                indent: 16, endIndent: 16, color: Colors.grey.shade400)),

        /// ################################################################

        Visibility(
          visible: !hideAlignment,
          child: ToggleStyleButton(
            attribute: ParchmentAttribute.left,
            icon: Icons.format_align_left,
            controller: controller,
          ),
        ),
        const SizedBox(width: 1),
        Visibility(
          visible: !hideAlignment,
          child: ToggleStyleButton(
            attribute: ParchmentAttribute.center,
            icon: Icons.format_align_center,
            controller: controller,
          ),
        ),
        const SizedBox(width: 1),
        Visibility(
          visible: !hideAlignment,
          child: ToggleStyleButton(
            attribute: ParchmentAttribute.right,
            icon: Icons.format_align_right,
            controller: controller,
          ),
        ),
        const SizedBox(width: 1),
        Visibility(
          visible: !hideAlignment,
          child: ToggleStyleButton(
            attribute: ParchmentAttribute.justify,
            icon: Icons.format_align_justify,
            controller: controller,
          ),
        ),
        Visibility(
            visible: !hideAlignment,
            child: VerticalDivider(
                indent: 16, endIndent: 16, color: Colors.grey.shade400)),

        /// ################################################################

        Visibility(
          visible: !hideIndentation,
          child: IndentationButton(
            increase: false,
            controller: controller,
          ),
        ),
        Visibility(
          visible: !hideIndentation,
          child: IndentationButton(
            controller: controller,
          ),
        ),
        Visibility(
            visible: !hideIndentation,
            child: VerticalDivider(
                indent: 16, endIndent: 16, color: Colors.grey.shade400)),

        /// ################################################################

        Visibility(
            visible: !hideHeadingStyle,
            child: SelectHeadingButton(controller: controller)),
        Visibility(
            visible: !hideHeadingStyle,
            child: VerticalDivider(
                indent: 16, endIndent: 16, color: Colors.grey.shade400)),

        /// ################################################################
        Visibility(
          visible: !hideListNumbers,
          child: ToggleStyleButton(
            attribute: ParchmentAttribute.block.numberList,
            controller: controller,
            icon: Icons.format_list_numbered,
          ),
        ),

        Visibility(
          visible: !hideListBullets,
          child: ToggleStyleButton(
            attribute: ParchmentAttribute.block.bulletList,
            controller: controller,
            icon: Icons.format_list_bulleted,
          ),
        ),
        Visibility(
          visible: !hideListChecks,
          child: ToggleStyleButton(
            attribute: ParchmentAttribute.block.checkList,
            controller: controller,
            icon: Icons.checklist,
          ),
        ),
        Visibility(
          visible: !hideCodeBlock,
          child: ToggleStyleButton(
            attribute: ParchmentAttribute.block.code,
            controller: controller,
            icon: Icons.code,
          ),
        ),
        Visibility(
            visible: !hideListNumbers &&
                !hideListBullets &&
                !hideListChecks &&
                !hideCodeBlock,
            child: VerticalDivider(
                indent: 16, endIndent: 16, color: Colors.grey.shade400)),

        /// ################################################################

        Visibility(
          visible: !hideQuote,
          child: ToggleStyleButton(
            attribute: ParchmentAttribute.block.quote,
            controller: controller,
            icon: Icons.format_quote,
          ),
        ),
        Visibility(
            visible: !hideQuote,
            child: VerticalDivider(
                indent: 16, endIndent: 16, color: Colors.grey.shade400)),

        /// ################################################################

        Visibility(
            visible: !hideLink, child: LinkStyleButton(controller: controller)),
        Visibility(
          visible: !hideHorizontalRule,
          child: InsertEmbedButton(
            controller: controller,
            icon: Icons.horizontal_rule,
          ),
        ),
        Visibility(
            visible: !hideHorizontalRule || !hideLink,
            child: VerticalDivider(
                indent: 16, endIndent: 16, color: Colors.grey.shade400)),

        /// ################################################################

        Visibility(
          visible: !hideUndoRedo,
          child: UndoRedoButton.undo(
            controller: controller,
          ),
        ),
        Visibility(
          visible: !hideUndoRedo,
          child: UndoRedoButton.redo(
            controller: controller,
          ),
        ),

        ...trailing,
      ],
    );
  }

  static _FleatherToolbarState _of(BuildContext context) =>
      context.findAncestorStateOfType<_FleatherToolbarState>()!;

  @override
  State<FleatherToolbar> createState() => _FleatherToolbarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _FleatherToolbarState extends State<FleatherToolbar> {
  late FleatherThemeData theme;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parentTheme = FleatherTheme.of(context, nullOk: true);
    final fallbackTheme = FleatherThemeData.fallback(context);
    theme = (parentTheme != null)
        ? fallbackTheme.merge(parentTheme)
        : fallbackTheme;
  }

  void requestKeyboard() => widget.editorKey?.currentState?.requestKeyboard();

  @override
  Widget build(BuildContext context) {
    return FleatherTheme(
      data: theme,
      child: SelectorScope(
        child: Container(
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 8),
          constraints:
              BoxConstraints.tightFor(height: widget.preferredSize.height),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.children,
            ),
          ),
        ),
      ),
    );
  }
}

/// Default icon button used in Fleather editor toolbar.
///
/// Named with a "Z" prefix to distinguish from the Flutter's built-in version.
class FLIconButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? icon;
  final double size;
  final Color? fillColor;
  final double hoverElevation;
  final double highlightElevation;

  const FLIconButton({
    super.key,
    required this.onPressed,
    this.icon,
    this.size = 40,
    this.fillColor,
    this.hoverElevation = 1,
    this.highlightElevation = 1,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(width: size, height: size),
      child: RawMaterialButton(
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        padding: EdgeInsets.zero,
        fillColor: fillColor,
        elevation: 0,
        hoverElevation: hoverElevation,
        highlightElevation: hoverElevation,
        onPressed: onPressed,
        child: icon,
      ),
    );
  }
}

class SelectorScope extends StatefulWidget {
  final Widget child;

  const SelectorScope({super.key, required this.child});

  static SelectorScopeState of(BuildContext context) =>
      context.findAncestorStateOfType<SelectorScopeState>()!;

  /// The [context] should belong to the presenter widget.
  static Future<T?> showSelector<T>(
          BuildContext context, Widget selector, Completer<T?> completer,
          {bool rootOverlay = false}) =>
      SelectorScope.of(context)
          .showSelector(context, selector, completer, rootOverlay: rootOverlay);

  @override
  State<SelectorScope> createState() => SelectorScopeState();
}

class SelectorScopeState extends State<SelectorScope> {
  OverlayEntry? _overlayEntry;

  /// The [context] should belong to the presenter widget.
  Future<T?> showSelector<T>(
      BuildContext context, Widget selector, Completer<T?> completer,
      {bool rootOverlay = false}) {
    _overlayEntry?.remove();

    final overlay = Overlay.of(context, rootOverlay: rootOverlay);

    final RenderBox presenter = context.findRenderObject() as RenderBox;
    final RenderBox overlayBox =
        overlay.context.findRenderObject() as RenderBox;
    final offset = Offset(0.0, presenter.size.height);
    final position = RelativeRect.fromSize(
      Rect.fromPoints(
        presenter.localToGlobal(offset, ancestor: overlayBox),
        presenter.localToGlobal(
          presenter.size.bottomRight(Offset.zero) + offset,
          ancestor: overlayBox,
        ),
      ),
      overlayBox.size,
    );

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final mediaQueryData = MediaQuery.of(context);
        return CustomSingleChildLayout(
          delegate: _SelectorLayout(
            position,
            Directionality.of(context),
            mediaQueryData.padding + mediaQueryData.viewInsets,
            DisplayFeatureSubScreen.avoidBounds(mediaQueryData).toSet(),
          ),
          child: TapRegion(
            child: selector,
            onTapOutside: (_) => completer.complete(null),
          ),
        );
      },
    );
    _overlayEntry?.addListener(() {
      if (_overlayEntry?.mounted != true && !completer.isCompleted) {
        _overlayEntry?.dispose();
        _overlayEntry = null;
        completer.complete(null);
      }
    });
    completer.future.whenComplete(removeEntry);
    overlay.insert(_overlayEntry!);
    return completer.future;
  }

  void removeEntry() {
    if (_overlayEntry == null) return;
    _overlayEntry!.remove();
    _overlayEntry!.dispose();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    super.dispose();
    removeEntry();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

const _selectorScreenPadding = 8.0;

// This is a clone of _PopupMenuRouteLayout from Flutter with some modifications
class _SelectorLayout extends SingleChildLayoutDelegate {
  _SelectorLayout(
    this.position,
    this.textDirection,
    this.padding,
    this.avoidBounds,
  );

  // Rectangle of underlying button, relative to the overlay's dimensions.
  final RelativeRect position;

  // Whether to prefer going to the left or to the right.
  final TextDirection textDirection;

  // The padding of unsafe area.
  EdgeInsets padding;

  // List of rectangles that we should avoid overlapping. Unusable screen area.
  final Set<Rect> avoidBounds;

  // We put the child wherever position specifies, so long as it will fit within
  // the specified parent size padded (inset) by [_selectorScreenPadding].
  // If necessary, we adjust the child's position so that it fits.

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    // The menu can be at most the size of the overlay minus 8.0 pixels in each
    // direction.
    return BoxConstraints.loose(constraints.biggest).deflate(
      const EdgeInsets.all(_selectorScreenPadding) + padding,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // size: The size of the overlay.
    // childSize: The size of the menu, when fully open, as determined by
    // getConstraintsForChild.

    final double y = position.top;

    // Find the ideal horizontal position.
    double x;
    if (position.right > childSize.width) {
      // Menu button is closer to the left edge, so grow to the right, aligned to the left edge.
      x = position.left;
    } else if (position.left > childSize.width) {
      // Menu button is closer to the right edge, so grow to the left, aligned to the right edge.
      x = size.width - position.right - childSize.width;
    } else {
      switch (textDirection) {
        case TextDirection.rtl:
          x = size.width - position.right - childSize.width;
        case TextDirection.ltr:
          x = position.left;
      }
    }

    final Offset wantedPosition = Offset(x, y);
    final Offset originCenter = position.toRect(Offset.zero & size).center;
    final Iterable<Rect> subScreens =
        DisplayFeatureSubScreen.subScreensInBounds(
            Offset.zero & size, avoidBounds);
    final Rect subScreen = _closestScreen(subScreens, originCenter);
    return _fitInsideScreen(subScreen, childSize, wantedPosition);
  }

  Rect _closestScreen(Iterable<Rect> screens, Offset point) {
    Rect closest = screens.first;
    for (final Rect screen in screens) {
      if ((screen.center - point).distance <
          (closest.center - point).distance) {
        closest = screen;
      }
    }
    return closest;
  }

  Offset _fitInsideScreen(Rect screen, Size childSize, Offset wantedPosition) {
    double x = wantedPosition.dx;
    double y = wantedPosition.dy;
    // Avoid going outside an area defined as the rectangle 8.0 pixels from the
    // edge of the screen in every direction.
    if (x < screen.left + _selectorScreenPadding + padding.left) {
      x = screen.left + _selectorScreenPadding + padding.left;
    } else if (x + childSize.width >
        screen.right - _selectorScreenPadding - padding.right) {
      x = screen.right -
          childSize.width -
          _selectorScreenPadding -
          padding.right;
    }
    if (y < screen.top + _selectorScreenPadding + padding.top) {
      y = _selectorScreenPadding + padding.top;
    } else if (y + childSize.height >
        screen.bottom - _selectorScreenPadding - padding.bottom) {
      y = screen.bottom -
          childSize.height -
          _selectorScreenPadding -
          padding.bottom;
    }

    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_SelectorLayout oldDelegate) {
    return position != oldDelegate.position ||
        textDirection != oldDelegate.textDirection ||
        padding != oldDelegate.padding ||
        !setEquals(avoidBounds, oldDelegate.avoidBounds);
  }
}
