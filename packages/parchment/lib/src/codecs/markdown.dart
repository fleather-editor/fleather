import 'dart:convert';

import 'package:parchment_delta/parchment_delta.dart';

import '../document/attributes.dart';
import '../document.dart';
import '../document/block.dart';
import '../document/leaf.dart';
import '../document/line.dart';

class ParchmentMarkdownCodec extends Codec<ParchmentDocument, String> {
  const ParchmentMarkdownCodec();

  @override
  Converter<String, ParchmentDocument> get decoder =>
      _ParchmentMarkdownDecoder();

  @override
  Converter<ParchmentDocument, String> get encoder =>
      _ParchmentMarkdownEncoder();
}

class _ParchmentMarkdownDecoder extends Converter<String, ParchmentDocument> {
  static final _headingRegExp = RegExp(r'(#+) *(.+)');
  static final _styleRegExp = RegExp(
    // italic then bold
    r'(([*_])(\*{2}|_{2})(?<italic_bold_text>.*?[^ \3\2])\3\2)|'
    // bold then italic
    r'((\*{2}|_{2})([*_])(?<bold_italic_text>.*?[^ \7\6])\7\6)|'
    // italic or bold
    r'(((\*{1,2})|(_{1,2}))(?<bold_or_italic_text>.*?[^ \10])\10)|'
    // strike through
    r'(~~(?<strike_through_text>.+?)~~)|'
    // inline code
    r'(`(?<inline_code_text>.+?)`)',
  );

  // as per https://www.michaelperrin.fr/blog/2019/02/advanced-regular-expressions
  static final _linkRegExp =
      RegExp(r'\[(?<text>.+)\]\((?<url>[^ ]+)(?: "(?<title>.+)")?\)');
  static final _ulRegExp = RegExp(r'^( *)\* +(.*)');
  static final _olRegExp = RegExp(r'^( *)\d+[.)] +(.*)');
  static final _bqRegExp = RegExp(r'^> *(.*)');
  static final _codeRegExpTag = RegExp(r'^( *)```');

  bool _inBlockStack = false;

  @override
  ParchmentDocument convert(String input) {
    final lines = input.split('\n');
    final delta = Delta();

    for (final line in lines) {
      _handleLine(line, delta);
    }

    return ParchmentDocument.fromDelta(delta..trim());
  }

  void _handleLine(String line, Delta delta, [ParchmentStyle? style]) {
    if (line.isEmpty && delta.isEmpty) {
      delta.insert('\n');
      return;
    }

    if (_handleBlockQuote(line, delta, style)) {
      return;
    }
    if (_handleBlock(line, delta, style)) {
      return;
    }
    if (_handleHeading(line, delta, style)) {
      return;
    }

    if (line.isNotEmpty) {
      if (style?.isInline ?? true) {
        _handleSpan(line, delta, true, style);
      } else {
        _handleSpan(line, delta, false,
            ParchmentStyle().putAll(style?.inlineAttributes ?? []));
        _handleSpan('\n', delta, false,
            ParchmentStyle().putAll(style?.lineAttributes ?? []));
      }
    }
  }

  // Markdown supports headings and blocks within blocks (except for within code)
  // but not blocks within headers, or ul within
  bool _handleBlock(String line, Delta delta, [ParchmentStyle? style]) {
    final match = _codeRegExpTag.matchAsPrefix(line);
    if (match != null) {
      _inBlockStack = !_inBlockStack;
      return true;
    }
    if (_inBlockStack) {
      delta.insert(line);
      delta.insert('\n', ParchmentAttribute.code.toJson());
      // Don't bother testing for code blocks within block stacks
      return true;
    }

    if (_handleOrderedList(line, delta, style) ||
        _handleUnorderedList(line, delta, style)) {
      return true;
    }

    return false;
  }

  // all blocks are supported within bq
  bool _handleBlockQuote(String line, Delta delta, [ParchmentStyle? style]) {
    // we do not support nested blocks
    if (style?.contains(ParchmentAttribute.block) ?? false) {
      return false;
    }
    final match = _bqRegExp.matchAsPrefix(line);
    final span = match?.group(1);
    if (span != null) {
      final newStyle = (style ?? ParchmentStyle()).put(ParchmentAttribute.bq);

      // all blocks are supported within bq
      _handleLine(span, delta, newStyle);
      return true;
    }
    return false;
  }

  // ol is supported within ol and bq, but not supported within ul
  bool _handleOrderedList(String line, Delta delta, [ParchmentStyle? style]) {
    // we do not support nested blocks
    if (style?.contains(ParchmentAttribute.block) ?? false) {
      return false;
    }
    final match = _olRegExp.matchAsPrefix(line);
    final span = match?.group(2);
    if (span != null) {
      _handleSpan(span, delta, false, style);
      _handleSpan(
          '\n', delta, false, ParchmentStyle().put(ParchmentAttribute.ol));
      return true;
    }
    return false;
  }

  bool _handleUnorderedList(String line, Delta delta, [ParchmentStyle? style]) {
    // we do not support nested blocks
    if (style?.contains(ParchmentAttribute.block) ?? false) {
      return false;
    }

    final newStyle = (style ?? ParchmentStyle()).put(ParchmentAttribute.ul);

    final match = _ulRegExp.matchAsPrefix(line);
    final span = match?.group(2);
    if (span != null) {
      _handleSpan(span, delta, false,
          ParchmentStyle().putAll(newStyle.inlineAttributes));
      _handleSpan(
          '\n', delta, false, ParchmentStyle().putAll(newStyle.lineAttributes));
      return true;
    }
    return false;
  }

  bool _handleHeading(String line, Delta delta, [ParchmentStyle? style]) {
    final match = _headingRegExp.matchAsPrefix(line);
    final levelTag = match?.group(1);
    if (levelTag != null) {
      final level = levelTag.length;
      final newStyle = (style ?? ParchmentStyle())
          .put(ParchmentAttribute.heading.withValue(level));

      final span = match?.group(2);
      if (span == null) {
        return false;
      }
      _handleSpan(span, delta, false,
          ParchmentStyle().putAll(newStyle.inlineAttributes));
      _handleSpan(
          '\n', delta, false, ParchmentStyle().putAll(newStyle.lineAttributes));
      return true;
    }

    return false;
  }

  void _handleSpan(
      String span, Delta delta, bool addNewLine, ParchmentStyle? outerStyle) {
    var start = _handleStyles(span, delta, outerStyle);
    span = span.substring(start);

    if (span.isNotEmpty) {
      start = _handleLinks(span, delta, outerStyle);
      span = span.substring(start);
    }

    if (span.isNotEmpty) {
      if (addNewLine) {
        delta.insert('$span\n', outerStyle?.toJson());
      } else {
        delta.insert(span, outerStyle?.toJson());
      }
    } else if (addNewLine) {
      delta.insert('\n', outerStyle?.toJson());
    }
  }

  int _handleStyles(String span, Delta delta, ParchmentStyle? outerStyle) {
    var start = 0;

    // `**some code**`
    //  does not translate to
    // <code><strong>some code</code></strong>
    //  but to
    // <code>**code**</code>
    if (outerStyle?.contains(ParchmentAttribute.inlineCode) ?? false) {
      return start;
    }

    final matches = _styleRegExp.allMatches(span);
    for (final match in matches) {
      if (match.start > start) {
        if (span.substring(match.start - 1, match.start) == '[') {
          delta.insert(
              span.substring(start, match.start - 1), outerStyle?.toJson());
          start = match.start -
              1 +
              _handleLinks(span.substring(match.start - 1), delta, outerStyle);
          continue;
        } else {
          delta.insert(
              span.substring(start, match.start), outerStyle?.toJson());
        }
      }

      final String text;
      final String styleTag;
      if (match.namedGroup('italic_bold_text') != null) {
        text = match.namedGroup('italic_bold_text')!;
        styleTag = '${match.group(2)}${match.group(3)}';
      } else if (match.namedGroup('bold_italic_text') != null) {
        text = match.namedGroup('bold_italic_text')!;
        styleTag = '${match.group(6)}${match.group(7)}';
      } else if (match.namedGroup('bold_or_italic_text') != null) {
        text = match.namedGroup('bold_or_italic_text')!;
        styleTag = match.group(10)!;
      } else if (match.namedGroup('strike_through_text') != null) {
        text = match.namedGroup('strike_through_text')!;
        styleTag = '~~';
      } else {
        assert(match.namedGroup('inline_code_text') != null);
        text = match.namedGroup('inline_code_text')!;
        styleTag = '`';
      }
      var newStyle = _fromStyleTag(styleTag);

      if (outerStyle != null) {
        newStyle = newStyle.mergeAll(outerStyle);
      }

      _handleSpan(text, delta, false, newStyle);
      start = match.end;
    }

    return start;
  }

  ParchmentStyle _fromStyleTag(String styleTag) {
    assert(
        (styleTag == '`') |
            (styleTag == '~~') |
            (styleTag == '_') |
            (styleTag == '*') |
            (styleTag == '__') |
            (styleTag == '**') |
            (styleTag == '__*') |
            (styleTag == '**_') |
            (styleTag == '_**') |
            (styleTag == '*__') |
            (styleTag == '***') |
            (styleTag == '___'),
        'Invalid style tag \'$styleTag\'');
    assert(styleTag.isNotEmpty, 'Style tag must not be empty');
    if (styleTag == '`') {
      return ParchmentStyle().put(ParchmentAttribute.inlineCode);
    }
    if (styleTag == '~~') {
      return ParchmentStyle().put(ParchmentAttribute.strikethrough);
    }
    if (styleTag.length == 3) {
      return ParchmentStyle()
          .putAll([ParchmentAttribute.bold, ParchmentAttribute.italic]);
    }
    if (styleTag.length == 2) {
      return ParchmentStyle().put(ParchmentAttribute.bold);
    }
    return ParchmentStyle().put(ParchmentAttribute.italic);
  }

  int _handleLinks(String span, Delta delta, ParchmentStyle? outerStyle) {
    var start = 0;

    final matches = _linkRegExp.allMatches(span);
    for (final match in matches) {
      if (match.start > start) {
        delta.insert(span.substring(start, match.start)); //, outerStyle);
      }

      final text = match.group(1);
      final href = match.group(2);
      if (text == null || href == null) {
        return start;
      }
      final newStyle = (outerStyle ?? ParchmentStyle())
          .put(ParchmentAttribute.link.fromString(href));

      _handleSpan(text, delta, false, newStyle);
      start = match.end;
    }

    return start;
  }
}

class _ParchmentMarkdownEncoder extends Converter<ParchmentDocument, String> {
  static final simpleBlocks = <ParchmentAttribute, String>{
    ParchmentAttribute.bq: '> ',
    ParchmentAttribute.ul: '* ',
    ParchmentAttribute.ol: '. ',
  };

  String _trimRight(StringBuffer buffer) {
    var text = buffer.toString();
    if (!text.endsWith(' ')) return '';
    final result = text.trimRight();
    buffer.clear();
    buffer.write(result);
    return ' ' * (text.length - result.length);
  }

  void handleText(
      StringBuffer buffer, TextNode node, ParchmentStyle currentInlineStyle) {
    final style = node.style;
    final rightPadding = _trimRight(buffer);

    for (final attr in currentInlineStyle.inlineAttributes.toList().reversed) {
      if (!style.contains(attr)) {
        _writeAttribute(buffer, attr, close: true);
      }
    }

    buffer.write(rightPadding);

    final leftTrimmedText = node.value.trimLeft();

    buffer.write(' ' * (node.length - leftTrimmedText.length));

    for (final attr in style.inlineAttributes) {
      if (!currentInlineStyle.contains(attr)) {
        _writeAttribute(buffer, attr);
      }
    }

    buffer.write(leftTrimmedText);
  }

  @override
  String convert(ParchmentDocument input) {
    final buffer = StringBuffer();
    final lineBuffer = StringBuffer();
    var currentInlineStyle = ParchmentStyle();
    ParchmentAttribute? currentBlockAttribute;

    void handleLine(LineNode node) {
      if (node.hasBlockEmbed) return;

      for (final attr in node.style.lineAttributes) {
        if (attr.key == ParchmentAttribute.block.key) {
          if (currentBlockAttribute != attr) {
            _writeAttribute(lineBuffer, attr);
            currentBlockAttribute = attr;
          } else if (attr != ParchmentAttribute.code) {
            _writeAttribute(lineBuffer, attr);
          }
        } else {
          _writeAttribute(lineBuffer, attr);
        }
      }

      for (final textNode in node.children) {
        handleText(lineBuffer, textNode as TextNode, currentInlineStyle);
        currentInlineStyle = textNode.style;
      }

      handleText(lineBuffer, TextNode(), currentInlineStyle);

      currentInlineStyle = ParchmentStyle();

      final blockAttribute = node.style.get(ParchmentAttribute.block);
      if (currentBlockAttribute != blockAttribute) {
        _writeAttribute(lineBuffer, currentBlockAttribute, close: true);
      }

      buffer.write(lineBuffer);
      lineBuffer.clear();
    }

    void handleBlock(BlockNode node) {
      int currentItemOrder = 1;
      for (final lineNode in node.children) {
        if (node.style.containsSame(ParchmentAttribute.ol)) {
          lineBuffer.write(currentItemOrder);
        }
        handleLine(lineNode as LineNode);
        if (!lineNode.isLast) {
          buffer.write('\n');
        }
        currentItemOrder += 1;
      }

      handleLine(LineNode());
      currentBlockAttribute = null;
    }

    for (final child in input.root.children) {
      if (child is LineNode) {
        handleLine(child);
        buffer.write('\n\n');
      } else if (child is BlockNode) {
        handleBlock(child);
        buffer.write('\n\n');
      }
    }

    return buffer.toString();
  }

  void _writeAttribute(StringBuffer buffer, ParchmentAttribute? attribute,
      {bool close = false}) {
    if (attribute == ParchmentAttribute.bold) {
      _writeBoldTag(buffer);
    } else if (attribute == ParchmentAttribute.italic) {
      _writeItalicTag(buffer);
    } else if (attribute == ParchmentAttribute.inlineCode) {
      _writeInlineCodeTag(buffer);
    } else if (attribute == ParchmentAttribute.strikethrough) {
      _writeStrikeThoughTag(buffer);
    } else if (attribute?.key == ParchmentAttribute.link.key) {
      _writeLinkTag(buffer, attribute as ParchmentAttribute<String>,
          close: close);
    } else if (attribute?.key == ParchmentAttribute.heading.key) {
      _writeHeadingTag(buffer, attribute as ParchmentAttribute<int>);
    } else if (attribute?.key == ParchmentAttribute.block.key) {
      _writeBlockTag(buffer, attribute as ParchmentAttribute<String>,
          close: close);
    } else {
      throw ArgumentError('Cannot handle $attribute');
    }
  }

  void _writeBoldTag(StringBuffer buffer) {
    buffer.write('**');
  }

  void _writeItalicTag(StringBuffer buffer) {
    buffer.write('_');
  }

  void _writeInlineCodeTag(StringBuffer buffer) {
    buffer.write('`');
  }

  void _writeStrikeThoughTag(StringBuffer buffer) {
    buffer.write('~~');
  }

  void _writeLinkTag(StringBuffer buffer, ParchmentAttribute<String> link,
      {bool close = false}) {
    if (close) {
      buffer.write('](${link.value})');
    } else {
      buffer.write('[');
    }
  }

  void _writeHeadingTag(StringBuffer buffer, ParchmentAttribute<int> heading) {
    var level = heading.value!;
    buffer.write('${'#' * level} ');
  }

  void _writeBlockTag(StringBuffer buffer, ParchmentAttribute<String> block,
      {bool close = false}) {
    if (block == ParchmentAttribute.code) {
      if (close) {
        buffer.write('\n```');
      } else {
        buffer.write('```\n');
      }
    } else {
      if (close) return; // no close tag needed for simple blocks.

      final tag = simpleBlocks[block];
      buffer.write(tag);
    }
  }
}
