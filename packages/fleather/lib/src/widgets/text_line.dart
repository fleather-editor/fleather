import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parchment/parchment.dart';

import 'controller.dart';
import 'editable_text_line.dart';
import 'editor.dart';
import 'embed_proxy.dart';
import 'keyboard_listener.dart';
import 'link.dart';
import 'rich_text_proxy.dart';
import 'theme.dart';

/// Line of text in Fleather editor.
///
/// This widget allows to render non-editable line of rich text, but can be
/// wrapped with [EditableTextLine] which adds editing features.
class TextLine extends StatefulWidget {
  /// Line of text represented by this widget.
  final LineNode node;
  final bool readOnly;
  final FleatherController controller;
  final FleatherEmbedBuilder embedBuilder;
  final ValueChanged<String?>? onLaunchUrl;
  final LinkActionPicker linkActionPicker;

  const TextLine({
    super.key,
    required this.node,
    required this.readOnly,
    required this.controller,
    required this.embedBuilder,
    required this.onLaunchUrl,
    required this.linkActionPicker,
  });

  @override
  State<TextLine> createState() => _TextLineState();
}

class _TextLineState extends State<TextLine> {
  bool _metaOrControlPressed = false;

  UniqueKey _richTextKey = UniqueKey();

  final _linkRecognizers = <Node, GestureRecognizer>{};

  FleatherPressedKeys? _pressedKeys;

  void _pressedKeysChanged() {
    final newValue = _pressedKeys!.metaPressed || _pressedKeys!.controlPressed;
    if (_metaOrControlPressed != newValue) {
      setState(() {
        _metaOrControlPressed = newValue;
        _richTextKey = UniqueKey();
      });
    }
  }

  bool get isDesktop => {
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.windows
      }.contains(defaultTargetPlatform);

  bool get canLaunchLinks {
    if (widget.onLaunchUrl == null) return false;
    // In readOnly mode users can launch links by simply tapping (clicking) on them
    if (widget.readOnly) return true;

    // In editing mode it depends on the platform:

    // Desktop platforms (macos, linux, windows): only allow Meta(Control)+Click combinations
    if (isDesktop) {
      return _metaOrControlPressed;
    }
    // Mobile platforms (ios, android): always allow but we install a
    // long-press handler instead of a tap one. LongPress is followed by a
    // context menu with actions.
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pressedKeys == null) {
      _pressedKeys = FleatherPressedKeys.of(context);
      _pressedKeys!.addListener(_pressedKeysChanged);
    } else {
      _pressedKeys!.removeListener(_pressedKeysChanged);
      _pressedKeys = FleatherPressedKeys.of(context);
      _pressedKeys!.addListener(_pressedKeysChanged);
    }
  }

  @override
  void didUpdateWidget(covariant TextLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.readOnly != widget.readOnly) {
      _richTextKey = UniqueKey();
      _linkRecognizers.forEach((key, value) {
        value.dispose();
      });
      _linkRecognizers.clear();
    }
  }

  @override
  void dispose() {
    _pressedKeys?.removeListener(_pressedKeysChanged);
    _linkRecognizers.forEach((key, value) => value.dispose());
    _linkRecognizers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    if (widget.node.hasBlockEmbed) {
      final embed = widget.node.children.single as EmbedNode;
      return EmbedProxy(child: widget.embedBuilder(context, embed));
    }
    final text = buildText(context, widget.node);
    final textAlign = getTextAlign(widget.node);
    final strutStyle = StrutStyle.fromTextStyle(text.style!);
    return RichTextProxy(
      textStyle: text.style!,
      textAlign: textAlign,
      strutStyle: strutStyle,
      locale: Localizations.maybeLocaleOf(context),
      child: RichText(
        key: _richTextKey,
        text: text,
        textAlign: textAlign,
        strutStyle: strutStyle,
        textScaler: MediaQuery.textScalerOf(context),
      ),
    );
  }

  TextAlign getTextAlign(LineNode node) {
    final alignment = node.style.get(ParchmentAttribute.alignment);
    if (alignment == ParchmentAttribute.center) {
      return TextAlign.center;
    } else if (alignment == ParchmentAttribute.right) {
      return TextAlign.right;
    } else if (alignment == ParchmentAttribute.justify) {
      return TextAlign.justify;
    }
    return TextAlign.left;
  }

  TextSpan buildText(BuildContext context, LineNode node) {
    final theme = FleatherTheme.of(context)!;
    final children = node.children
        .map((node) => _segmentToTextSpan(node, theme))
        .toList(growable: false);
    return TextSpan(
      style: _getParagraphTextStyle(node.style, theme),
      children: children,
    );
  }

  InlineSpan _segmentToTextSpan(Node segment, FleatherThemeData theme) {
    if (segment is EmbedNode) {
      return WidgetSpan(
          child: EmbedProxy(child: widget.embedBuilder(context, segment)));
    }
    final text = segment as TextNode;
    final attrs = text.style;
    final isLink = attrs.contains(ParchmentAttribute.link);
    return TextSpan(
      text: text.value,
      style: _getInlineTextStyle(attrs, widget.node.style, theme),
      recognizer: isLink && canLaunchLinks ? _getRecognizer(segment) : null,
      mouseCursor: isLink && canLaunchLinks ? SystemMouseCursors.click : null,
    );
  }

  GestureRecognizer _getRecognizer(Node segment) {
    if (_linkRecognizers.containsKey(segment)) {
      return _linkRecognizers[segment]!;
    }

    if (isDesktop || widget.readOnly) {
      _linkRecognizers[segment] = TapGestureRecognizer()
        ..onTap = () => _tapLink(segment);
    } else {
      _linkRecognizers[segment] = LongPressGestureRecognizer()
        ..onLongPress = () => _longPressLink(segment);
    }
    return _linkRecognizers[segment]!;
  }

  void _tapLink(Node segment) {
    final link =
        (segment as StyledNode).style.get(ParchmentAttribute.link)!.value;
    widget.onLaunchUrl!(link);
  }

  void _longPressLink(Node segment) async {
    final link =
        (segment as StyledNode).style.get(ParchmentAttribute.link)!.value!;
    final action = await widget.linkActionPicker(segment);
    switch (action) {
      case LinkMenuAction.launch:
        widget.onLaunchUrl!(link);
        break;
      case LinkMenuAction.copy:
        // ignore: unawaited_futures
        Clipboard.setData(ClipboardData(text: link));
        break;
      case LinkMenuAction.remove:
        final range = _getLinkRange(segment);
        widget.controller.formatText(range.start, range.end - range.start,
            ParchmentAttribute.link.unset);
        break;
      case LinkMenuAction.none:
        break;
    }
  }

  TextRange _getLinkRange(Node segment) {
    int start = segment.documentOffset;
    int length = segment.length;
    var prev = segment.previous as StyledNode?;
    final linkAttr =
        (segment as StyledNode).style.get(ParchmentAttribute.link)!;
    while (prev != null) {
      if (prev.style.containsSame(linkAttr)) {
        start = prev.documentOffset;
        length += prev.length;
        prev = prev.previous as StyledNode?;
      } else {
        break;
      }
    }

    var next = segment.next as StyledNode?;
    while (next != null) {
      if (next.style.containsSame(linkAttr)) {
        length += next.length;
        next = next.next as StyledNode?;
      } else {
        break;
      }
    }
    return TextRange(start: start, end: start + length);
  }

  TextStyle _getParagraphTextStyle(
      ParchmentStyle style, FleatherThemeData theme) {
    var textStyle = const TextStyle();
    final heading = widget.node.style.get(ParchmentAttribute.heading);
    if (heading == ParchmentAttribute.heading.level1) {
      textStyle = textStyle.merge(theme.heading1.style);
    } else if (heading == ParchmentAttribute.heading.level2) {
      textStyle = textStyle.merge(theme.heading2.style);
    } else if (heading == ParchmentAttribute.heading.level3) {
      textStyle = textStyle.merge(theme.heading3.style);
    } else if (heading == ParchmentAttribute.heading.level4) {
      textStyle = textStyle.merge(theme.heading4.style);
    } else if (heading == ParchmentAttribute.heading.level5) {
      textStyle = textStyle.merge(theme.heading5.style);
    } else if (heading == ParchmentAttribute.heading.level6) {
      textStyle = textStyle.merge(theme.heading6.style);
    } else {
      textStyle = textStyle.merge(theme.paragraph.style);
    }

    final block = style.get(ParchmentAttribute.block);
    if (block == ParchmentAttribute.block.quote) {
      textStyle = textStyle.merge(theme.quote.style);
    } else if (block == ParchmentAttribute.block.code) {
      textStyle = textStyle.merge(theme.code.style);
    } else if (block != null) {
      // lists
      textStyle = textStyle.merge(theme.lists.style);
    }

    return textStyle;
  }

  TextStyle _getInlineTextStyle(ParchmentStyle nodeStyle,
      ParchmentStyle lineStyle, FleatherThemeData theme) {
    var result = const TextStyle();
    if (nodeStyle.containsSame(ParchmentAttribute.bold)) {
      result = _mergeTextStyleWithDecoration(result, theme.bold);
    }
    if (nodeStyle.containsSame(ParchmentAttribute.italic)) {
      result = _mergeTextStyleWithDecoration(result, theme.italic);
    }
    if (nodeStyle.contains(ParchmentAttribute.link)) {
      result = _mergeTextStyleWithDecoration(result, theme.link);
    }
    if (nodeStyle.contains(ParchmentAttribute.underline)) {
      result = _mergeTextStyleWithDecoration(result, theme.underline);
    }
    if (nodeStyle.contains(ParchmentAttribute.strikethrough)) {
      result = _mergeTextStyleWithDecoration(result, theme.strikethrough);
    }
    if (nodeStyle.contains(ParchmentAttribute.inlineCode)) {
      result = _mergeTextStyleWithDecoration(
          result, theme.inlineCode.styleFor(lineStyle));
    }
    if (nodeStyle.contains(ParchmentAttribute.foregroundColor)) {
      final foregroundColor =
          nodeStyle.get(ParchmentAttribute.foregroundColor)!;
      if (foregroundColor != ParchmentAttribute.foregroundColor.unset) {
        result = result.copyWith(color: Color(foregroundColor.value!));
      }
    }
    return result;
  }

  TextStyle _mergeTextStyleWithDecoration(TextStyle a, TextStyle? b) {
    var decorations = <TextDecoration>[];
    if (a.decoration != null) {
      decorations.add(a.decoration!);
    }
    if (b?.decoration != null) {
      decorations.add(b!.decoration!);
    }
    return a.merge(b).apply(decoration: TextDecoration.combine(decorations));
  }
}
