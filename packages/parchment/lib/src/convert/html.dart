import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart';
import 'package:parchment/parchment.dart';
import 'package:quill_delta/quill_delta.dart';

final _inlineAttributesParchmentToHtml = {
  ParchmentAttribute.bold.key: 'strong',
  ParchmentAttribute.italic.key: 'em',
  ParchmentAttribute.underline.key: 'u',
  ParchmentAttribute.strikethrough.key: 'del',
  ParchmentAttribute.inlineCode.key: 'code',
  ParchmentAttribute.link.key: 'a',
};

const _indentWidthInPx = 32;

/// HTML conversion of Parchment
///
/// ## Inline attributes mapping
/// - b -> <strong>
/// - i -> <em>
/// - u -> <u>
/// - s -> <del>
/// - c -> <code>
/// - a -> <a>
///
/// ## Line attributes mapping
/// - default -> <p>
/// - heading X -> <hX>
/// - bq -> <blockquote>
/// - code -> <pre><code>
/// - ol -> <ol><li>
/// - ul -> <ul><li>
/// - cl -> <div class="checklist">
///           <div class"checklist-item><input type="checklist" checked><label>
/// - alignment -> <xxx align="left | right | center | justify">
/// - direction -> <xxx dir="rtl">
///
/// ## Embed mapping
/// - [BlockEmbed.image] -> <img src="...">
/// - [BlockEmbed.horizontalRule] -> <hr>
///
/// *note: `<br>` are not recognized as new lines and will be ignored*
/// *note2: a single line of text with only inline attributes will not be surrounded with `<p>`
class ParchmentHtmlCodec extends Codec<Delta, String> {
  const ParchmentHtmlCodec();

  @override
  Converter<String, Delta> get decoder => const _ParchmentHtmlDecoder();

  @override
  Converter<Delta, String> get encoder => const _ParchmentHtmlEncoder();
}

// Mutable record for the state of the encoder
class _EncoderState {
  StringBuffer buffer = StringBuffer();
  // Stack on inline tags
  final List<_HtmlInlineTag> openInlineTags = [];

  // Stack of blocks currently being processed
  // The first element of the stack is the last block that occurred in the
  // operations. When an operation with a different block comes up, the html
  // of the first element are written to the buffer and the first element is
  // replaced by the new block.
  //
  // Multiple items in the stack means nested blocks are being handled.
  final List<_HtmlBlockTag> openBlockTags = [];
  int nextLineStartPosition = 0;
  bool isSingleLine = true;
}

// Inline tags relate directly to ParchmentAttributeScope.inline.
// While iterating through operations, when within a line, one can only know if
// the corresponding HTML tag is open. Only when the operation doesn't have the
// attribute can we know that the tag should have been closed at the previous iteration.
//
// Line tags are related to attributes with line scope but that cannot
// contains more than one line (such as heading, blockquote, paragraphs).
// While iterating through operations, one can only know if the corresponding
// HTML tag is open. Only when the operation corresponds to a new line can we
// know that the tag should have be closed at the start of the current operation.
//
// Block tags are line Parchment attributes that can contain several lines.
// These can be code or lists.
// These behave almost as line tags except there can be nested blocks
class _ParchmentHtmlEncoder extends Converter<Delta, String> {
  const _ParchmentHtmlEncoder();

  static const _htmlElementEscape = HtmlEscape(HtmlEscapeMode.element);
  static final _brPrEolRegex = RegExp(r'<br></p>$');
  static final _brEolRegex = RegExp(r'<br>$');

  // Style has only positioning attributes
  static bool isPlain(ParchmentStyle style) {
    if (style.isEmpty) return true;
    for (final key in style.keys) {
      if (key == ParchmentAttribute.alignment.key) continue;
      if (key == ParchmentAttribute.direction.key) continue;
      if (key == ParchmentAttribute.indent.key) continue;
      return false;
    }
    return true;
  }

  // For lists and block code, new lines do not necessarily mean a new block
  static bool isSameBlock(_HtmlBlockTag previous, _HtmlBlockTag current) {
    final p = previous.style.values;
    final c = current.style.values;

    // List items can have different positions (alignment, indent, direction)
    final areOrderedUnorderedLists = (p.contains(ParchmentAttribute.ol) ||
            p.contains(ParchmentAttribute.ul)) &&
        (c.contains(ParchmentAttribute.ol) ||
            c.contains(ParchmentAttribute.ul));
    final areChecklists =
        p.contains(ParchmentAttribute.cl) && c.contains(ParchmentAttribute.cl);
    if (areOrderedUnorderedLists || areChecklists) {
      final positionAttributes = [
        ParchmentAttribute.alignment.unset,
        ParchmentAttribute.alignment.center,
        ParchmentAttribute.alignment.right,
        ParchmentAttribute.alignment.justify,
        ParchmentAttribute.direction.rtl,
        ParchmentAttribute.direction.unset,
      ];
      final modifiedPrevious = previous.style.removeAll(positionAttributes);
      final modifiedCurrent = current.style.removeAll(positionAttributes);
      return modifiedCurrent == modifiedPrevious;
    }
    // block code
    if (p.contains(ParchmentAttribute.code) &&
        c.contains(ParchmentAttribute.code)) return true;
    return false;
  }

  // current and candidate are both blocks
  static bool isNestedList(ParchmentStyle parent, ParchmentStyle child) {
    final currentListAttribute = parent.values.firstWhereOrNull(
        (e) => e == ParchmentAttribute.ol || e == ParchmentAttribute.ul);
    final candidateListAttribute = child.values.firstWhereOrNull(
        (e) => e == ParchmentAttribute.ol || e == ParchmentAttribute.ul);

    if (currentListAttribute == null || candidateListAttribute == null) {
      return false;
    }

    int currentLevel = parent.values
            .firstWhere((e) => e.key == ParchmentAttribute.indent.key,
                orElse: () => ParchmentAttribute.indent.withLevel(0))
            .value ??
        0;
    int candidateLevel = child.values
            .firstWhere((e) => e.key == ParchmentAttribute.indent.key,
                orElse: () => ParchmentAttribute.indent.withLevel(0))
            .value ??
        0;
    return currentLevel < candidateLevel;
  }

  @override
  String convert(Delta input) {
    final state = _EncoderState();
    for (final op in input.toList()) {
      final buffer = state.buffer;
      final openInlineTags = state.openInlineTags;

      if (_hasPlainParagraph(op)) {
        _processInlineTags(op, buffer, openInlineTags);
        _handlePlainBlock(op, state);
        continue;
      }

      _processInlineTags(op, buffer, openInlineTags);
      _writeData(op, buffer);

      // when op is several new lines, we need to split op into several ops
      // with a single new line
      if (_isMultipleLines(op)) {
        for (var i = 0; i < (op.data as String).length; i++) {
          final subOp = Operation.insert('\n', op.attributes);
          final currentLineStart = state.nextLineStartPosition;
          state.nextLineStartPosition = _handleNewLineLineStyle(
              subOp, buffer, state.nextLineStartPosition);
          int padding =
              _handleNewLineBlockStyle(subOp, state, currentLineStart);
          state.nextLineStartPosition += padding;
        }
      }

      if (_isNewLine(op)) {
        state.isSingleLine = false;
        final currentLineStart = state.nextLineStartPosition;
        state.nextLineStartPosition =
            _handleNewLineLineStyle(op, buffer, state.nextLineStartPosition);
        int padding = _handleNewLineBlockStyle(op, state, currentLineStart);
        state.nextLineStartPosition += padding;
      }
    }

    // Close any remaining inline tags
    for (final attr in state.openInlineTags) {
      _writeTag(state.buffer, attr);
    }

    // Close any remaining blocks
    _closeOpenBlocks(state);

    // Remove default paragraph block if single line of text
    String result = state.buffer.toString();
    if (state.isSingleLine && result.startsWith('<p>')) {
      result = result.substring('<p>'.length, result.length - '</p>'.length);
    }

    // Remove the final <br> if there is one.
    result = result
        .replaceFirst(_brPrEolRegex, '</p>')
        .replaceFirst(_brEolRegex, '');
    return result;
  }

  /// Closes all open blocks and returns the ending position.
  int _closeOpenBlocks(_EncoderState state,
      {bool beforePlainParagraphHandling = false}) {
    final openBlockTags = state.openBlockTags;
    final buffer = state.buffer;
    final numToClose = openBlockTags.length;
    int position = 0;
    for (var i = 0; i < numToClose; i++) {
      final blockTag = openBlockTags[i];
      if (position > 0) {
        blockTag.closingPosition = position;
      } else {
        position = blockTag.closingPosition;
      }
      if (!isPlain(blockTag.style)) {
        position += blockTag.inducedPadding;
      }
      if (i == numToClose - 1 && !beforePlainParagraphHandling) {
        blockTag.closingPosition = buffer.length;
      }
      _writeBlockTag(buffer, blockTag);
    }

    state.openBlockTags.clear();
    return numToClose == 1 ? position : buffer.length;
  }

  bool _hasPlainParagraph(Operation op) {
    return op.isPlain &&
        op.data is String &&
        (op.data as String).contains('\n');
  }

  void _processInlineTags(
      Operation op, StringBuffer buffer, List<_HtmlInlineTag> openInlineTags) {
    final parchmentStyle = ParchmentStyle.fromJson(op.attributes);
    final Set<ParchmentAttribute> inlineAttributes =
        Set.from(parchmentStyle.inlineAttributes);

    // Close any tag absent from inline attributes
    // Closing tags effectively adds the opening tag at the appropriate position
    // AND adds the closing tag
    final attributesToRemove = <_HtmlInlineTag>{};
    for (final attr in openInlineTags) {
      if (!inlineAttributes.contains(attr.attribute)) {
        _writeTag(buffer, attr);
        attributesToRemove.add(attr);
      }
    }
    for (final attr in attributesToRemove) {
      openInlineTags.remove(attr);
    }

    // Open any necessary inline attributes
    for (final attr in inlineAttributes) {
      if (!openInlineTags.map((e) => e.attribute).contains(attr)) {
        openInlineTags.insert(0, _HtmlInlineTag(attr, buffer.length));
      }
    }
  }

  bool _isNewLine(Operation op) =>
      op.data is String && (op.data as String) == '\n';

  bool _isMultipleLines(Operation op) {
    if (op.data is! String) return false;
    final text = op.data as String;
    final regex = RegExp('\n{2,}', multiLine: true);
    final matches = regex.allMatches(text);
    return matches.length == 1 && matches.first.group(0) == text;
  }

  // update position in state indicating where following line will start
  //
  // Plain block deserve a special treatment as they are the only operations in
  // which the data string will contain several paragraph.
  void _handlePlainBlock(Operation op, _EncoderState state) {
    assert(_hasPlainParagraph(op));
    var position = 0;
    var initialPosition = position;
    final openBlockTags = state.openBlockTags;
    final buffer = state.buffer;

    if (openBlockTags.isNotEmpty) {
      position = _closeOpenBlocks(state, beforePlainParagraphHandling: true);
      state.isSingleLine = false;
    }

    final text = op.data as String;
    final lines = text.split('\n');
    // several new lines de facto
    if (lines.length > 2) {
      state.isSingleLine = false;
    }
    for (var i = 0; i < lines.length; i++) {
      final subOp = Operation.insert(lines[i]);

      // Last line opens a new paragraph for later treatments and writes to buffer if
      // there's anything to write (in which case, it is no more a single line input)
      if (i == lines.length - 1) {
        // Done with set of paragraphs, add last paragraph to block stack.
        openBlockTags.insert(
            0, _HtmlBlockTag(ParchmentStyle(), initialPosition, buffer.length));
        if (lines[i].isNotEmpty) {
          // Elements that do not belong to a paragraph but to block of next op
          _writeData(subOp, buffer);
          state.isSingleLine = false;
        }
        continue;
      }

      _writeData(subOp, buffer);
      _writeTag(buffer, _HtmlLineTag(ParchmentStyle(), position));
      initialPosition = position;
      position = buffer.length;
    }

    assert(openBlockTags.length <= 1,
        'At most one paragraph should be pushed in stack');
    state.nextLineStartPosition = position;
  }

  // used to write html tags of block lines such as <li> or <code>
  // returns the start position in the buffer of the next line that will be
  // processed
  int _handleNewLineLineStyle(
      Operation op, StringBuffer buffer, int currentLineStart) {
    final opStyle = ParchmentStyle.fromJson(op.attributes);
    final newLineTag = _HtmlLineTag(opStyle, currentLineStart);
    if (newLineTag.style.isNotEmpty) {
      _writeTag(buffer, newLineTag);
    }
    return buffer.length;
  }

  // used to write html tags of blocks themselves.
  // returns padding induced by ex-post addition of block tags
  int _handleNewLineBlockStyle(
      Operation op, _EncoderState state, int currentLineStart) {
    final buffer = state.buffer;
    final openBlockTags = state.openBlockTags;
    final opStyle = ParchmentStyle.fromJson(op.attributes);
    final startPosition = openBlockTags.firstOrNull?.closingPosition ?? 0;

    var newBlockTag = _HtmlBlockTag(opStyle, startPosition);

    // If no previous style, let caller write surrounding tags
    if (openBlockTags.isEmpty) {
      openBlockTags.insert(0, newBlockTag..closingPosition = buffer.length);
      return 0;
    }

    if (isSameBlock(openBlockTags[0], newBlockTag)) {
      openBlockTags[0].closingPosition = buffer.length;
      return 0;
    }

    if (isNestedList(openBlockTags[0].style, opStyle)) {
      openBlockTags.insert(0, _HtmlBlockTag(opStyle, currentLineStart));
      return 0;
    }

    // de-nesting
    if (isNestedList(opStyle, openBlockTags[0].style)) {
      final currentBlockTag = openBlockTags[0];
      _writeBlockTag(
          buffer, currentBlockTag..closingPosition = currentLineStart);
      openBlockTags.removeAt(0);
      return currentBlockTag.inducedPadding;
    }

    if (isPlain(openBlockTags[0].style)) {
      openBlockTags.removeAt(0);
      openBlockTags.insert(0, newBlockTag..closingPosition = buffer.length);
      return 0;
    }

    // change of block
    final currentBlockTag = openBlockTags.removeAt(0);
    _writeBlockTag(buffer, currentBlockTag);
    // adjust block tag opening with padding induced by previous block tags
    newBlockTag = newBlockTag.withPadding(currentBlockTag.inducedPadding);
    newBlockTag.closingPosition = buffer.length;
    openBlockTags.insert(0, newBlockTag);
    return newBlockTag.inducedPadding;
  }

  void _writeTag(StringBuffer buffer, _HtmlTag tag) {
    final html = buffer.toString();
    final preHtml = html.substring(0, tag.openingPosition);
    var innerHtml = html.substring(tag.openingPosition);
    var openTag = tag.openTag;
    var closeTag = tag.closeTag;
    if (closeTag == '</p>' && innerHtml.trim().isEmpty) {
      // Add <br> if it is a blank paragraph. This should render as an empty line.
      innerHtml = '$innerHtml<br>';
    }

    buffer.clear();
    buffer.writeAll([
      preHtml,
      openTag,
      innerHtml,
      closeTag,
    ]);
  }

  void _writeBlockTag(StringBuffer buffer, _HtmlBlockTag tag) {
    if (tag.closingPosition == tag.openingPosition) {
      _writeTag(buffer, tag);
      return;
    }

    final openTag = tag.openTag;
    final closeTag = tag.closeTag;
    final html = buffer.toString();
    buffer.clear();
    buffer.writeAll([
      html.substring(0, tag.openingPosition),
      openTag,
      html.substring(tag.openingPosition, tag.closingPosition),
      closeTag,
      html.substring(tag.closingPosition),
    ]);
  }

  void _writeData(Operation op, StringBuffer buffer) {
    if (op.data is String) {
      var elementContent = op.data as String;
      elementContent = elementContent.replaceAll('\n', '');
      // All content must be HTML-escaped
      elementContent = _htmlElementEscape.convert(elementContent);
      buffer.write(elementContent);
      return;
    }
    if (op.data is Map<String, dynamic>) {
      final data = op.data as Map<String, dynamic>;
      final embeddable = EmbeddableObject.fromJson(data);
      if (embeddable is BlockEmbed) {
        if (embeddable.type == 'hr') {
          buffer.write('<hr>');
          return;
        }
        if (embeddable.type == 'image') {
          // Force the image to fit within any max. width that might be set. If
          // no width or max-width is set on an outer block, then this does nothing.
          buffer.write(
              '<img src="${embeddable.data['source']}" style="max-width: 100%; object-fit: contain;">');
          return;
        }
      }
    }
  }
}

const _styleAttributePrefix = 'style="';
const _styleAttributeSuffix = '"';

abstract class _HtmlTag {
  _HtmlTag(this.openingPosition);

  final int openingPosition;

  String get openTag;

  String get closeTag;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HtmlTag &&
          runtimeType == other.runtimeType &&
          openingPosition == other.openingPosition;

  @override
  int get hashCode => openingPosition.hashCode;
}

class _HtmlInlineTag extends _HtmlTag {
  _HtmlInlineTag(this.attribute, super.openingPosition);

  final ParchmentAttribute attribute;

  @override
  String get openTag {
    final key = attribute.key;
    final value = attribute.value;
    if (key == ParchmentAttribute.link.key) {
      return '<${_inlineAttributesParchmentToHtml[key]} href="$value">';
    }
    return '<${_inlineAttributesParchmentToHtml[key]}>';
  }

  @override
  String get closeTag {
    return '</${_inlineAttributesParchmentToHtml[attribute.key]}>';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is _HtmlInlineTag &&
          runtimeType == other.runtimeType &&
          attribute == other.attribute;

  @override
  int get hashCode => super.hashCode ^ attribute.hashCode;
}

// HTML tags that correspond to line attributes in Parchment
class _HtmlLineTag extends _HtmlTag {
  static bool isLineAttribute(ParchmentAttribute attribute) {
    return attribute.key == ParchmentAttribute.heading.key ||
        (attribute.key == ParchmentAttribute.block.key &&
            (attribute.value == ParchmentAttribute.code.value ||
                attribute.value == ParchmentAttribute.ol.value ||
                attribute.value == ParchmentAttribute.ul.value ||
                attribute.value == ParchmentAttribute.cl.value ||
                attribute.value == ParchmentAttribute.bq.value)) ||
        attribute.key == ParchmentAttribute.alignment.key ||
        attribute.key == ParchmentAttribute.direction.key ||
        attribute.key == ParchmentAttribute.checked.key ||
        attribute.key == ParchmentAttribute.indent.key;
  }

  _HtmlLineTag(ParchmentStyle style, super.openingPosition)
      : style = ParchmentStyle()
            .putAll(style.lineAttributes.where((e) => isLineAttribute(e)));

  final ParchmentStyle style;

  bool get isPlain => _ParchmentHtmlEncoder.isPlain(style);

  String? _tagCss;

  String get tagCss {
    if (_tagCss == null) {
      final content = [
        alignmentCss,
        blockquoteCss,
        indentationCss,
      ].where((css) => css != null).join();
      _tagCss = content.isEmpty
          ? ''
          : '$_styleAttributePrefix$content$_styleAttributeSuffix';
    }
    return _tagCss!;
  }

  String? get alignmentCss {
    var alignment = style.values
        .firstWhereOrNull((e) => e.key == ParchmentAttribute.alignment.key);

    if (alignment == null) return null;

    const alignmentPrefix = 'text-align:';
    const alignmentSuffix = ';';
    if (alignment.value == ParchmentAttribute.alignment.right.value) {
      return '${alignmentPrefix}right$alignmentSuffix';
    }
    if (alignment.value == ParchmentAttribute.alignment.center.value) {
      return '${alignmentPrefix}center$alignmentSuffix';
    }
    if (alignment.value == ParchmentAttribute.alignment.justify.value) {
      return '${alignmentPrefix}justify$alignmentSuffix';
    }
    return null;
  }

  String? get blockquoteCss {
    // inline style required for HTML-based email.
    return style.values.contains(ParchmentAttribute.bq)
        ? 'margin: 0 0 0 0.8ex; border-left: 1px solid rgb(204, 204, 204); padding-left: 1ex;'
        : null;
  }

  String? get indentationCss {
    // For list, indentation is handle with nested lists
    if (style.values.contains(ParchmentAttribute.ul) ||
        style.values.contains(ParchmentAttribute.ol)) {
      return null;
    }
    var indentation = style.values
        .firstWhereOrNull((e) => e.key == ParchmentAttribute.indent.key);

    if (indentation == null) return null;
    int value = indentation.value;
    return 'padding-left:${value * _indentWidthInPx}px;';
  }

  String? _directionAttribute;

  String? get directionAttribute {
    if (_directionAttribute == null) {
      var direction = style.values
          .firstWhereOrNull((e) => e.key == ParchmentAttribute.direction.key);

      if (direction == null) {
        return _directionAttribute;
      }

      const directionPrefix = 'dir="';
      const directionSuffix = '"';
      if (direction.value == ParchmentAttribute.direction.rtl.value) {
        _directionAttribute = '${directionPrefix}rtl$directionSuffix';
      }
    }
    return _directionAttribute;
  }

  @override
  String get openTag {
    final css = tagCss.isEmpty ? '' : ' $tagCss';
    final attribute = directionAttribute != null ? ' $directionAttribute' : '';
    // If line is plain text
    if (isPlain) {
      return '<p$attribute$css>';
    }
    String openTag = '';
    for (final attr in style.values) {
      if (attr.key == ParchmentAttribute.heading.key) {
        openTag += '<h${attr.value}$attribute$css>';
      }
      if (attr.key == ParchmentAttribute.block.key) {
        if (attr.value == ParchmentAttribute.bq.value) {
          openTag += '<blockquote$attribute$css>';
        }
        if (attr.value == ParchmentAttribute.code.value) {
          // We are in a <pre><code> block at this point, so no need for an additional <code>.
        }
        if (attr.value == ParchmentAttribute.ol.value) {
          openTag += '<li$attribute$css>';
        }
        if (attr.value == ParchmentAttribute.ul.value) {
          openTag += '<li$attribute$css>';
        }
        if (attr.value == ParchmentAttribute.cl.value) {
          final checked = style.values
              .firstWhereOrNull((e) => e.key == ParchmentAttribute.checked.key);
          final checkedAttribute =
              checked != null && checked.value ? ' checked' : '';
          // Checkboxes disabled so user cannot toggle them.
          // &nbsp to give a little space between the checkbox and the label.
          openTag +=
              '<div class="checklist-item"$attribute$css><input type="checkbox"$checkedAttribute disabled><label>&nbsp;';
        }
      }
    }
    return openTag;
  }

  @override
  String get closeTag {
    if (isPlain) return '</p>';
    String closeTag = '';
    for (final attr in style.values) {
      if (attr.key == ParchmentAttribute.heading.key) {
        closeTag += '</h${attr.value}>';
      }
      if (attr.key == ParchmentAttribute.block.key) {
        if (attr.value == ParchmentAttribute.bq.value) {
          closeTag += '</blockquote>';
        }
        if (attr.value == ParchmentAttribute.code.value) {
          // We are in a <pre><code> block. We need to add a newline to display as a line break.
          closeTag += '\n';
        }
        if (attr.value == ParchmentAttribute.ol.value) {
          closeTag += '</li>';
        }
        if (attr.value == ParchmentAttribute.ul.value) {
          closeTag += '</li>';
        }
        if (attr.value == ParchmentAttribute.cl.value) {
          closeTag += '</label></div>';
        }
      }
    }
    return closeTag;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is _HtmlLineTag &&
          runtimeType == other.runtimeType &&
          style == other.style;

  @override
  int get hashCode => super.hashCode ^ style.hashCode;
}

// HTMLTags that correspond to block attribute in Parchment
class _HtmlBlockTag extends _HtmlTag {
  static final supportedBlocks = <String>{
    ParchmentAttribute.code.value!,
    ParchmentAttribute.ol.value!,
    ParchmentAttribute.ul.value!,
    ParchmentAttribute.cl.value!,
  };

  static bool isBlockAttribute(ParchmentAttribute attribute) {
    return attribute.key == ParchmentAttribute.block.key &&
            supportedBlocks.contains(attribute.value) ||
        // Needed for nested lists
        attribute.key == ParchmentAttribute.indent.key;
  }

  _HtmlBlockTag(ParchmentStyle style, super.openingPosition,
      [int? closingPosition])
      : style = ParchmentStyle()
            .putAll(style.lineAttributes.where((e) => isBlockAttribute(e))),
        closingPosition = closingPosition ?? openingPosition;

  final ParchmentStyle style;
  int closingPosition;

  int get inducedPadding => openTag.length + closeTag.length;

  _HtmlBlockTag withPadding(int padding) {
    return _HtmlBlockTag(
        style, openingPosition + padding, closingPosition + padding);
  }

  @override
  String get openTag {
    String openTag = '';
    for (final attr in style.values) {
      if (attr.key == ParchmentAttribute.block.key) {
        if (attr.value == ParchmentAttribute.code.value) {
          openTag += '<pre><code>';
        }
        if (attr.value == ParchmentAttribute.ol.value) {
          openTag += '<ol>';
        }
        if (attr.value == ParchmentAttribute.ul.value) {
          openTag += '<ul>';
        }
        if (attr.value == ParchmentAttribute.cl.value) {
          openTag += '<div class="checklist">';
        }
      }
    }
    return openTag;
  }

  @override
  String get closeTag {
    String openTag = '';
    for (final attr in style.values) {
      if (attr.key == ParchmentAttribute.block.key) {
        if (attr.value == ParchmentAttribute.code.value) {
          openTag += '</code></pre>';
        }
        if (attr.value == ParchmentAttribute.ol.value) {
          openTag += '</ol>';
        }
        if (attr.value == ParchmentAttribute.ul.value) {
          openTag += '</ul>';
        }
        if (attr.value == ParchmentAttribute.cl.value) {
          openTag += '</div>';
        }
      }
    }
    return openTag;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is _HtmlBlockTag &&
          runtimeType == other.runtimeType &&
          style == other.style &&
          closingPosition == other.closingPosition;

  @override
  int get hashCode =>
      super.hashCode ^ style.hashCode ^ closingPosition.hashCode;
}

class _ParchmentHtmlDecoder extends Converter<String, Delta> {
  const _ParchmentHtmlDecoder();

  @override
  Delta convert(String input) {
    Delta delta = Delta();
    final htmlDocument = parse(input);

    for (var node in htmlDocument.body!.nodes) {
      delta = delta.concat(_parseNode(node));
    }
    _appendNewLineForTopLevelText(delta);
    return delta;
  }

  void _appendNewLineForTopLevelText(Delta delta) {
    if (delta.isEmpty) return delta.insert('\n');
    if (delta.last.data is! String) return delta.insert('\n');
    final text = delta.last.data as String;
    if (!text.endsWith('\n')) return delta.insert('\n');
    return;
  }

  bool _isLineNode(html.Node node) {
    return node is html.Element &&
        (node.localName == 'p' ||
            node.localName == 'blockquote' ||
            node.localName == 'code' ||
            node.localName == 'li' ||
            node.localName == 'h1' ||
            node.localName == 'h2' ||
            node.localName == 'h3');
  }

  Delta _parseNode(html.Node node,
      [ParchmentStyle? inlineStyle, ParchmentStyle? blockStyle]) {
    inlineStyle ??= ParchmentStyle();
    blockStyle ??= ParchmentStyle();
    Delta delta = Delta();
    if (node is html.Text) {
      delta.insert(node.text, inlineStyle.toJson());
      return delta;
    }
    if (node is html.Element) {
      if (node.localName == 'hr') {
        delta.insert(BlockEmbed.horizontalRule.toJson());
        return delta;
      }
      if (node.localName == 'img') {
        final src = node.attributes['src'] ?? '';
        delta.insert(BlockEmbed.image(src).toJson());
        return delta;
      }
      inlineStyle = _updateInlineStyle(node, inlineStyle);
      blockStyle = _updateBlockStyle(node, blockStyle);
      if (node.nodes.isNotEmpty) {
        for (var node in node.nodes) {
          delta = delta.concat(_parseNode(node, inlineStyle, blockStyle));
        }
        if (_isLineNode(node)) {
          delta.insert('\n', blockStyle.toJson());
        }
      }
    }
    return delta;
  }

  ParchmentStyle _updateInlineStyle(
      html.Element element, ParchmentStyle inlineStyle) {
    ParchmentStyle updated = inlineStyle;
    if (element.localName == 'strong') {
      updated = inlineStyle.put(ParchmentAttribute.bold);
    } else if (element.localName == 'u') {
      updated = inlineStyle.put(ParchmentAttribute.underline);
    } else if (element.localName == 'del') {
      updated = inlineStyle.put(ParchmentAttribute.strikethrough);
    } else if (element.localName == 'em') {
      updated = inlineStyle.put(ParchmentAttribute.italic);
    } else if (element.localName == 'a') {
      final link =
          ParchmentAttribute.link.withValue(element.attributes['href']);
      updated = inlineStyle.put(link);
    }
    return updated;
  }

  ParchmentStyle _updateBlockStyle(
      html.Element element, ParchmentStyle blockStyle) {
    ParchmentStyle updated = blockStyle;
    if (element.localName == 'h1') {
      updated = updated.put(ParchmentAttribute.h1);
    } else if (element.localName == 'h2') {
      updated = updated.put(ParchmentAttribute.h2);
    } else if (element.localName == 'h3') {
      updated = updated.put(ParchmentAttribute.h3);
    } else if (element.localName == 'blockquote') {
      updated = updated.put(ParchmentAttribute.bq);
    } else if (element.localName == 'pre') {
      updated = updated.put(ParchmentAttribute.code);
    } else if (element.localName == 'code') {
      if (!updated.values.contains(ParchmentAttribute.code)) {
        updated = updated.put(ParchmentAttribute.inlineCode);
      }
    } else if (element.localName == 'ol') {
      if (_hasList(updated)) {
        final indentLevel = updated.value(ParchmentAttribute.indent) ?? 0;
        updated =
            updated.put(ParchmentAttribute.indent.withLevel(indentLevel + 1));
      }
      updated = updated.put(ParchmentAttribute.ol);
    } else if (element.localName == 'ul') {
      if (_hasList(updated)) {
        final indentLevel = updated.value(ParchmentAttribute.indent) ?? 0;
        updated =
            updated.put(ParchmentAttribute.indent.withLevel(indentLevel + 1));
      }
      updated = updated.put(ParchmentAttribute.ul);
    } else if (element.localName == 'input' &&
        element.attributes['type'] == 'checkbox') {
      updated = updated.put(ParchmentAttribute.cl);
      if (element.attributes.containsKey('checked')) {
        updated = updated.put(ParchmentAttribute.checked);
      }
    }

    // Directionality
    final dirAttribute = element.attributes['dir'];
    if (dirAttribute != null && dirAttribute == 'rtl') {
      updated = updated.put(ParchmentAttribute.rtl);
    }

    // Styles (currently only alignment)
    final css = element.attributes['style'];
    final styles = css?.split(';') ?? [];
    for (final style in styles) {
      if (style.startsWith('text-align')) {
        final sValue = style.split(':')[1];
        switch (sValue) {
          case 'right':
            updated = updated.put(ParchmentAttribute.right);
            break;
          case 'center':
            updated = updated.put(ParchmentAttribute.center);
            break;
          case 'justify':
            updated = updated.put(ParchmentAttribute.justify);
        }
        break;
      }
    }
    return updated;
  }

  bool _hasList(ParchmentStyle blockStyle) {
    return blockStyle.values.contains(ParchmentAttribute.ol) ||
        blockStyle.values.contains(ParchmentAttribute.ul);
  }
}
