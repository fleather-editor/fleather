// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:quill_delta/quill_delta.dart';

import '../document/attributes.dart';

class ParchmentMarkdownCodec extends Codec<Delta, String> {
  const ParchmentMarkdownCodec();

  @override
  Converter<String, Delta> get decoder => _ParchmentMarkdownDecoder();

  @override
  Converter<Delta, String> get encoder => _ParchmentMarkdownEncoder();
}

class _ParchmentMarkdownDecoder extends Converter<String, Delta> {
  final List<Map<String, dynamic>?> _attributesByStyleLength = [
    null,
    {'i': true}, // _
    {'b': true}, // **
    {'i': true, 'b': true} // _**
  ];
  final RegExp _headingRegExp = RegExp(r'(#+) *(.+)');
  final _styleRegExp = RegExp(
    r'(([*_])(\*{2}|_{2})(?<italic_bold_text>.*?[^ \3\2])\3\2)|((\*{2}|_{2})([*_])(?<bold_italic_text>.*?[^ \7\6])\7\6)|(((\*{1,2})|(_{1,2}))(?<bold_or_italic_text>.*?[^ \10])\10)',
  );

  // TODO: implement full solution as per:
  // https://www.michaelperrin.fr/blog/2019/02/advanced-regular-expressions
  final RegExp _linkRegExp =
      RegExp(r'\[(?<text>.+)\]\((?<url>[^ ]+)(?: "(?<title>.+)")?\)');
  final RegExp _ulRegExp = RegExp(r'^( *)\* +(.*)');
  final RegExp _olRegExp = RegExp(r'^( *)\d+[.)] +(.*)');
  final RegExp _bqRegExp = RegExp(r'^> *(.*)');
  final RegExp _codeRegExpTag = RegExp(r'^( *)```');
  final RegExp _inlineCodeRegExp = RegExp(r'`(.+?)`');
  bool _inBlockStack = false;

//  final List<String> _blockStack = [];
//  int _olDepth = 0;

  @override
  Delta convert(String input) {
    final lines = input.split('\n');
    final delta = Delta();

    for (var line in lines) {
      _handleLine(line, delta);
    }

    return delta;
  }

  void _handleLine(String line, Delta delta,
      [Map<String, dynamic>? attributes]) {
    if (_handleBlockQuote(line, delta, attributes)) {
      return;
    }
    if (_handleBlock(line, delta, attributes)) {
      return;
    }
    if (_handleHeading(line, delta, attributes)) {
      return;
    }

    if (line.isNotEmpty) {
      _handleSpan(line, delta, true, attributes);
    }
  }

  /// Markdown supports headings and blocks within blocks (except for within code)
  /// but not blocks within headers, or ul within
  bool _handleBlock(String line, Delta delta,
      [Map<String, dynamic>? attributes]) {
    final match = _codeRegExpTag.matchAsPrefix(line);
    if (match != null) {
      _inBlockStack = !_inBlockStack;
      return true;
    }
    if (_inBlockStack) {
      delta.insert(
          '$line\n',
          ParchmentAttribute.code
              .toJson()); // TODO: replace with?: {'quote': true})
      // Don't bother testing for code blocks within block stacks
      return true;
    }

    if (_handleOrderedList(line, delta, attributes) ||
        _handleUnorderedList(line, delta, attributes)) {
      return true;
    }

    return false;
  }

  // all blocks are supported within bq
  bool _handleBlockQuote(String line, Delta delta,
      [Map<String, dynamic>? attributes]) {
    var match = _bqRegExp.matchAsPrefix(line);
    var span = match?.group(1);
    if (span != null) {
      final newAttributes = <String, dynamic>{
        'block': 'quote'
      }; // ParchmentAttribute.bq.toJson();
      if (attributes != null) {
        newAttributes.addAll(attributes);
      }
      // all blocks are supported within bq
      _handleLine(span, delta, newAttributes);
      return true;
    }
    return false;
  }

  /// ol is supported within ol and bq, but not supported within ul
  bool _handleOrderedList(String line, Delta delta,
      [Map<String, dynamic>? attributes]) {
    var match = _olRegExp.matchAsPrefix(line);
    var span = match?.group(2);
    if (span != null) {
// TODO: support nesting
//      var depth =  match.group(1).length / 3;
      Map<String, dynamic> newAttributes = ParchmentAttribute.ol.toJson();
      if (attributes != null) {
        newAttributes.addAll(attributes);
      }
      // There's probably no reason why you would have other block types on the same line
      _handleSpan(span, delta, true, newAttributes);
      return true;
    }
    return false;
  }

  bool _handleUnorderedList(String line, Delta delta,
      [Map<String, dynamic>? attributes]) {
    var match = _ulRegExp.matchAsPrefix(line);
    var span = match?.group(2);
    if (span != null) {
//      var depth = match.group(1).length / 3;
      Map<String, dynamic> newAttributes = ParchmentAttribute.ul.toJson();
      if (attributes != null) {
        newAttributes.addAll(attributes);
      }
      // There's probably no reason why you would have other block types on the same line
      _handleSpan(span, delta, true, newAttributes);
      return true;
    }
    return false;
  }

  bool _handleHeading(String line, Delta delta,
      [Map<String, dynamic>? attributes]) {
    final match = _headingRegExp.matchAsPrefix(line);
    final levelTag = match?.group(1);
    if (levelTag != null) {
      final level = levelTag.length;
      final Map<String, dynamic> newAttributes = {
        'heading': level
      }; // ParchmentAttribute.heading.withValue(level).toJson();
      if (attributes != null) {
        newAttributes.addAll(attributes);
      }

      final span = match?.group(2);
      if (span == null) {
        return false;
      }
      _handleSpan(
          span,
          delta,
          true,
          attributes != null
              ? (attributes..addAll(newAttributes))
              : newAttributes);
      return true;
    }

    return false;
  }

  void _handleSpan(String span, Delta delta, bool addNewLine,
      Map<String, dynamic>? outerStyle) {
    var start = _handleStyles(span, delta, outerStyle);
    span = span.substring(start);

    if (span.isNotEmpty) {
      start = _handleLinks(span, delta, outerStyle);
      span = span.substring(start);
    }

    if (span.isNotEmpty) {
      if (addNewLine) {
        delta.insert('$span\n', outerStyle);
      } else {
        delta.insert(span, outerStyle);
      }
    } else if (addNewLine) {
      delta.insert('\n', outerStyle);
    }
  }

  int _handleStyles(
      String span, Delta delta, Map<String, dynamic>? outerStyle) {
    var start = 0;

    final matches = _styleRegExp.allMatches(span);
    for (final match in matches) {
      if (match.start > start) {
        if (span.substring(match.start - 1, match.start) == '[') {
          delta.insert(span.substring(start, match.start - 1), outerStyle);
          start = match.start -
              1 +
              _handleLinks(span.substring(match.start - 1), delta, outerStyle);
          continue;
        } else {
          delta.insert(span.substring(start, match.start), outerStyle);
        }
      }
      final String? text;
      final int styleLength;
      if (match.namedGroup('italic_bold_text') != null) {
        text = match.namedGroup('italic_bold_text');
        styleLength = 3;
      } else if (match.namedGroup('bold_italic_text') != null) {
        text = match.namedGroup('bold_italic_text');
        styleLength = 3;
      } else {
        text = match.namedGroup('bold_or_italic_text');
        styleLength = match.group(10)?.length ?? 0;
      }

      if (text == null) {
        return start;
      }

      final newStyle =
          Map<String, dynamic>.from(_attributesByStyleLength[styleLength]!);
      if (outerStyle != null) {
        newStyle.addAll(outerStyle);
      }
      _handleSpan(text, delta, false, newStyle);
      start = match.end;
    }

    return start;
  }

  int _handleLinks(String span, Delta delta, Map<String, dynamic>? outerStyle) {
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
      final Map<String, dynamic> newAttributes = {
        'a': href
      }; // ParchmentAttribute.link.fromString(href).toJson();
      if (outerStyle != null) {
        newAttributes.addAll(outerStyle);
      }
      _handleSpan(text, delta, false, newAttributes);
      start = match.end;
    }

    return start;
  }
}

class _ParchmentMarkdownEncoder extends Converter<Delta, String> {
  // TODO: as per https://daringfireball.net/projects/markdown/basics
  //  emphasis = "*" || "_"
  //  strong emphasis = "**" || "__"
  //  combined = "***" || "___"
  static final simpleBlocks = <ParchmentAttribute, String>{
    ParchmentAttribute.bq: '> ',
    ParchmentAttribute.ul: '* ',
    ParchmentAttribute.ol: '1. ',
  };

  @override
  String convert(Delta input) {
    final iterator = DeltaIterator(input);
    final buffer = StringBuffer();
    final lineBuffer = StringBuffer();
    ParchmentAttribute<String>? currentBlockStyle;
    var currentInlineStyle = ParchmentStyle();
    var currentBlockLines = [];

    void handleBlock(ParchmentAttribute<String>? blockStyle) {
      if (currentBlockLines.isEmpty) {
        return; // Empty block
      }

      if (blockStyle == null) {
        buffer.write(currentBlockLines.join('\n\n'));
        buffer.writeln();
      } else if (blockStyle == ParchmentAttribute.code) {
        _writeAttribute(buffer, blockStyle);
        buffer.write(currentBlockLines.join('\n'));
        _writeAttribute(buffer, blockStyle, close: true);
        buffer.writeln();
      } else {
        for (var line in currentBlockLines) {
          _writeBlockTag(buffer, blockStyle);
          buffer.write(line);
          buffer.writeln();
        }
      }
      buffer.writeln();
    }

    void handleSpan(String text, Map<String, dynamic>? attributes) {
      final style = ParchmentStyle.fromJson(attributes);
      currentInlineStyle =
          _writeInline(lineBuffer, text, style, currentInlineStyle);
    }

    void handleLine(Map<String, dynamic>? attributes) {
      final style = ParchmentStyle.fromJson(attributes);
      final lineBlock = style.get(ParchmentAttribute.block);
      if (lineBlock == currentBlockStyle) {
        currentBlockLines.add(_writeLine(lineBuffer.toString(), style));
      } else {
        handleBlock(currentBlockStyle);
        currentBlockLines.clear();
        currentBlockLines.add(_writeLine(lineBuffer.toString(), style));

        currentBlockStyle = lineBlock;
      }
      lineBuffer.clear();
    }

    while (iterator.hasNext) {
      final op = iterator.next();
      final opText = op.data is String ? op.data as String : '';
      final lf = opText.indexOf('\n');
      if (lf == -1) {
        handleSpan(op.data as String, op.attributes);
      } else {
        var span = StringBuffer();
        for (var i = 0; i < opText.length; i++) {
          if (opText.codeUnitAt(i) == 0x0A) {
            if (span.isNotEmpty) {
              // Write the span if it's not empty.
              handleSpan(span.toString(), op.attributes);
            }
            // Close any open inline styles.
            handleSpan('', null);
            handleLine(op.attributes);
            span.clear();
          } else {
            span.writeCharCode(opText.codeUnitAt(i));
          }
        }
        // Remaining span
        if (span.isNotEmpty) {
          handleSpan(span.toString(), op.attributes);
        }
      }
    }
    handleBlock(currentBlockStyle); // Close the last block
    return buffer.toString();
  }

  String _writeLine(String text, ParchmentStyle style) {
    var buffer = StringBuffer();
    if (style.contains(ParchmentAttribute.heading)) {
      _writeAttribute(buffer, style.get<int>(ParchmentAttribute.heading));
    }

    // Write the text itself
    buffer.write(text);
    return buffer.toString();
  }

  String _trimRight(StringBuffer buffer) {
    var text = buffer.toString();
    if (!text.endsWith(' ')) return '';
    final result = text.trimRight();
    buffer.clear();
    buffer.write(result);
    return ' ' * (text.length - result.length);
  }

  //
  ParchmentStyle _writeInline(StringBuffer buffer, String text,
      ParchmentStyle style, ParchmentStyle currentStyle) {
    // First close any current styles if needed
    for (var value in currentStyle.values.reverse()) {
      if (value.scope == ParchmentAttributeScope.line) continue;
      if (style.containsSame(value)) continue;
      final padding = _trimRight(buffer);
      _writeAttribute(buffer, value, close: true);
      if (padding.isNotEmpty) buffer.write(padding);
    }
    // Now open any new styles.
    for (var value in style.values) {
      if (value.scope == ParchmentAttributeScope.line) continue;
      if (currentStyle.containsSame(value)) continue;
      final originalText = text;
      text = text.trimLeft();
      final padding = ' ' * (originalText.length - text.length);
      if (padding.isNotEmpty) buffer.write(padding);
      _writeAttribute(buffer, value);
    }
    // Write the text itself
    buffer.write(text);
    return style;
  }

  void _writeAttribute(StringBuffer buffer, ParchmentAttribute? attribute,
      {bool close = false}) {
    if (attribute == ParchmentAttribute.bold) {
      _writeBoldTag(buffer);
    } else if (attribute == ParchmentAttribute.italic) {
      _writeItalicTag(buffer);
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

extension<E> on Iterable<E> {
  Iterable<E> reverse() {
    final reverse = <E>[];
    for (final e in this) {
      reverse.insert(0, e);
    }
    return reverse;
  }
}
