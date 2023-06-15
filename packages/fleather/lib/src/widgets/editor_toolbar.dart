import 'dart:io';

import 'package:fleather/fleather.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const double kToolbarHeight = 56.0;

class InsertEmbedButton extends StatelessWidget {
  final FleatherController controller;
  final IconData icon;

  const InsertEmbedButton({
    Key? key,
    required this.controller,
    required this.icon,
  }) : super(key: key);

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
      },
    );
  }
}

class UndoRedoButton extends StatelessWidget {
  final FleatherController controller;
  final _UndoRedoButtonVariant _variant;

  const UndoRedoButton._(this.controller, this._variant, {Key? key})
      : super(key: key);

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
    Key? key,
    required this.controller,
    this.icon,
  }) : super(key: key);

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
  }
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({Key? key}) : super(key: key);

  @override
  _LinkDialogState createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  String _link = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: TextField(
        decoration: const InputDecoration(labelText: 'Paste a link'),
        autofocus: true,
        onChanged: _linkChanged,
      ),
      actions: [
        TextButton(
          onPressed: _link.isNotEmpty ? _applyLink : null,
          child: const Text('Apply'),
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
    Key? key,
    required this.attribute,
    required this.icon,
    required this.controller,
    this.childBuilder = defaultToggleStyleButtonBuilder,
  }) : super(key: key);

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

/// Signature of callbacks that return a [Color] picked from a [BuildContext].
typedef PickColor = Future<Color?> Function(BuildContext);

/// Signature of callbacks the return a [Widget] from a [BuildContext]
/// and a [Color].
typedef ColorButtonBuilder = Widget Function(BuildContext, Color);

/// Toolbar button which allows to apply background color style to a portion of text.
///
/// Works as a dropdown menu button.
class ColorButton extends StatefulWidget {
  const ColorButton(
      {Key? key,
      required this.controller,
      required this.attributeKey,
      required this.defaultColor,
      required this.builder,
      this.pickColor})
      : super(key: key);

  final FleatherController controller;
  final ColorParchmentAttributeBuilder attributeKey;
  final Color defaultColor;
  final ColorButtonBuilder builder;
  final PickColor? pickColor;

  @override
  State<ColorButton> createState() => _ColorButtonState();
}

class _ColorButtonState extends State<ColorButton> {
  static double buttonSize = 32;

  late Color _value;

  ParchmentStyle get _selectionStyle => widget.controller.getSelectionStyle();

  void _didChangeEditingValue() {
    setState(() {
      _value = Color(_selectionStyle.get(widget.attributeKey)?.value ??
          widget.defaultColor.value);
    });
  }

  Future<Color?> _defaultPickColor(BuildContext context) async {
    // kIsWeb important here as Platform.xxx will cause a crash en web
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final maxWidth = isMobile ? 200.0 : 100.0;

    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero) + Offset(0, buttonSize);

    final selector = Material(
      elevation: 4.0,
      color: Theme.of(context).canvasColor,
      child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.all(8.0),
          child: _ColorPalette(defaultColor: widget.defaultColor)),
    );

    return Navigator.of(context).push<Color>(
      RawDialogRoute(
        barrierColor: Colors.transparent,
        pageBuilder: (context, _, __) {
          return Stack(
            children: [
              Positioned(
                key: const Key('color_palette'),
                top: offset.dy,
                left: offset.dx,
                child: selector,
              )
            ],
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _value = Color(_selectionStyle.get(widget.attributeKey)?.value ??
        widget.defaultColor.value);
    widget.controller.addListener(_didChangeEditingValue);
  }

  @override
  void didUpdateWidget(covariant ColorButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_didChangeEditingValue);
      widget.controller.addListener(_didChangeEditingValue);
      _value = Color(_selectionStyle.get(widget.attributeKey)?.value ??
          widget.defaultColor.value);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_didChangeEditingValue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(
        width: buttonSize,
        height: buttonSize,
      ),
      child: RawMaterialButton(
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        padding: EdgeInsets.zero,
        elevation: 0,
        hoverElevation: 1,
        highlightElevation: 1,
        onPressed: () async {
          final selectedColor =
              await (widget.pickColor ?? _defaultPickColor)(context);
          widget.controller.formatSelection(widget.attributeKey
              .withColor(selectedColor?.value ?? widget.defaultColor.value));
        },
        child: Builder(builder: (context) => widget.builder(context, _value)),
      ),
    );
  }
}

class _ColorPalette extends StatelessWidget {
  static const colors = [
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
    Colors.white
  ];

  const _ColorPalette({required this.defaultColor});

  final Color defaultColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      runAlignment: WrapAlignment.spaceBetween,
      alignment: WrapAlignment.start,
      runSpacing: 4,
      spacing: 4,
      children: [defaultColor, ...colors]
          .map((e) => _ColorPaletteElement(color: e))
          .toList(),
    );
  }
}

class _ColorPaletteElement extends StatelessWidget {
  const _ColorPaletteElement({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    // kIsWeb important here as Platform.xxx will cause a crash en web
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final size = isMobile ? 32.0 : 16.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        border: color == Colors.transparent
            ? Border.all(
                color: Colors.black,
                strokeAlign: BorderSide.strokeAlignInside,
              )
            : null,
      ),
      child: RawMaterialButton(onPressed: () => Navigator.pop(context, color)),
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

final _headingToText = {
  ParchmentAttribute.heading.unset: 'Normal',
  ParchmentAttribute.heading.level1: 'Heading 1',
  ParchmentAttribute.heading.level2: 'Heading 2',
  ParchmentAttribute.heading.level3: 'Heading 3',
  ParchmentAttribute.heading.level4: 'Heading 4',
  ParchmentAttribute.heading.level5: 'Heading 5',
  ParchmentAttribute.heading.level6: 'Heading 6',
};

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

  void _selectAttribute(ParchmentAttribute<int> value) {
    widget.controller.formatSelection(value);
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
    widget.controller.removeListener(_didChangeEditingValue);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(height: buttonHeight),
      child: RawMaterialButton(
        onPressed: _selectHeading,
        child: Text(_headingToText[current] ?? ''),
      ),
    );
  }

  Future<void> _selectHeading() async {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset =
        renderBox.localToGlobal(Offset.zero) + Offset(0, buttonHeight);
    final themeData = FleatherTheme.of(context)!;

    final selector = Material(
      elevation: 4.0,
      borderRadius: BorderRadius.circular(2),
      color: Theme.of(context).canvasColor,
      child: _HeadingList(theme: themeData),
    );

    final newValue = await Navigator.of(context).push<ParchmentAttribute<int>>(
      RawDialogRoute(
        barrierColor: Colors.transparent,
        pageBuilder: (context, _, __) {
          return Stack(
            children: [
              Positioned(
                top: offset.dy,
                left: offset.dx,
                child: selector,
              )
            ],
          );
        },
      ),
    );

    if (newValue != null) _selectAttribute(newValue);
  }
}

class _HeadingList extends StatelessWidget {
  final FleatherThemeData theme;

  const _HeadingList({required this.theme});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _headingToText.entries
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
        value: value, text: text, style: valueToStyle[value]);
  }
}

class _HeadingListEntry extends StatelessWidget {
  final ParchmentAttribute<int> value;
  final String text;
  final TextStyle? style;

  const _HeadingListEntry(
      {required this.value, required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return RawMaterialButton(
      key: Key('heading_entry${value.value ?? 0}'),
      clipBehavior: Clip.antiAlias,
      onPressed: () => Navigator.pop(context, value),
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
      {Key? key, this.increase = true, required this.controller})
      : super(key: key);

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
            }
          : null,
    );
  }
}

class FleatherToolbar extends StatefulWidget implements PreferredSizeWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  const FleatherToolbar({Key? key, this.padding, required this.children})
      : super(key: key);

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
              decoration: BoxDecoration(
                color: value,
                border: value == Colors.transparent
                    ? Border.all(
                        color:
                            Theme.of(context).iconTheme.color ?? Colors.black)
                    : null,
              ),
            )
          ],
        );
    Widget textColorBuilder(context, value) => Column(
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
              decoration: BoxDecoration(
                color: value,
                border: value == Colors.transparent
                    ? Border.all(
                        color:
                            Theme.of(context).iconTheme.color ?? Colors.black)
                    : null,
              ),
            )
          ],
        );
    return FleatherToolbar(key: key, padding: padding, children: [
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
      Visibility(
        visible: !hideForegroundColor,
        child: ColorButton(
          controller: controller,
          attributeKey: ParchmentAttribute.foregroundColor,
          defaultColor: Colors.black,
          builder: textColorBuilder,
        ),
      ),
      Visibility(
        visible: !hideBackgroundColor,
        child: ColorButton(
          controller: controller,
          attributeKey: ParchmentAttribute.backgroundColor,
          defaultColor: Colors.transparent,
          builder: backgroundColorBuilder,
        ),
      ),
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
    ]);
  }

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

  @override
  Widget build(BuildContext context) {
    return FleatherTheme(
      data: theme,
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
    Key? key,
    required this.onPressed,
    this.icon,
    this.size = 40,
    this.fillColor,
    this.hoverElevation = 1,
    this.highlightElevation = 1,
  }) : super(key: key);

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
