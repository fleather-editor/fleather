import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:quiver/core.dart';

/// Scope of a style attribute, defines context in which an attribute can be
/// applied.
enum ParchmentAttributeScope {
  /// Inline-scoped attributes are applicable to all characters within a line.
  ///
  /// Inline attributes cannot be applied to the line itself.
  inline,

  /// Line-scoped attributes are only applicable to a line of text as a whole.
  ///
  /// Line attributes do not have any effect on any character within the line.
  line,
}

/// Interface for objects which provide access to an attribute key.
///
/// Implemented by [ParchmentAttribute] and [ParchmentAttributeBuilder].
abstract class ParchmentAttributeKey<T> {
  /// Unique key of this attribute.
  String get key;
}

/// Builder for style attributes.
///
/// Useful in scenarios when an attribute value is not known upfront, for
/// instance, link attribute.
///
/// See also:
///   * [LinkAttributeBuilder]
///   * [BlockAttributeBuilder]
///   * [HeadingAttributeBuilder]
///   * [IndentAttributeBuilder
///   * [BackgroundColorAttributeBuilder]
///   * [DirectionAttributeBuilder]
abstract class ParchmentAttributeBuilder<T>
    implements ParchmentAttributeKey<T> {
  const ParchmentAttributeBuilder._(this.key, this.scope);

  @override
  final String key;
  final ParchmentAttributeScope scope;

  ParchmentAttribute<T> get unset => ParchmentAttribute<T>._(key, scope, null);

  ParchmentAttribute<T> withValue(T? value) =>
      ParchmentAttribute<T>._(key, scope, value);
}

/// Style attribute applicable to a segment of a Parchment document.
///
/// All supported attributes are available via static fields on this class.
/// Here is an example of applying styles to a document:
///
///     void makeItPretty(Parchment document) {
///       // Format 5 characters at position 0 as bold
///       document.format(0, 5, ParchmentAttribute.bold);
///       // Similarly for italic
///       document.format(0, 5, ParchmentAttribute.italic);
///       // Format first line as a heading (h1)
///       // Note that there is no need to specify character range of the whole
///       // line. Simply set index position to anywhere within the line and
///       // length to 0.
///       document.format(0, 0, ParchmentAttribute.h1);
///     }
///
/// List of supported attributes:
///
///   * [ParchmentAttribute.bold]
///   * [ParchmentAttribute.italic]
///   * [ParchmentAttribute.underline]
///   * [ParchmentAttribute.strikethrough]
///   * [ParchmentAttribute.inlineCode]
///   * [ParchmentAttribute.link]
///   * [ParchmentAttribute.heading]
///   * [ParchmentAttribute.backgroundColor]
///   * [ParchmentAttribute.checked]
///   * [ParchmentAttribute.block]
///   * [ParchmentAttribute.direction]
///   * [ParchmentAttribute.alignment]
///   * [ParchmentAttribute.indent]
class ParchmentAttribute<T> implements ParchmentAttributeBuilder<T> {
  static final Map<String, ParchmentAttributeBuilder> _registry = {
    ParchmentAttribute.bold.key: ParchmentAttribute.bold,
    ParchmentAttribute.italic.key: ParchmentAttribute.italic,
    ParchmentAttribute.underline.key: ParchmentAttribute.underline,
    ParchmentAttribute.strikethrough.key: ParchmentAttribute.strikethrough,
    ParchmentAttribute.inlineCode.key: ParchmentAttribute.inlineCode,
    ParchmentAttribute.link.key: ParchmentAttribute.link,
    ParchmentAttribute.heading.key: ParchmentAttribute.heading,
    ParchmentAttribute.foregroundColor.key: ParchmentAttribute.foregroundColor,
    ParchmentAttribute.backgroundColor.key: ParchmentAttribute.backgroundColor,
    ParchmentAttribute.checked.key: ParchmentAttribute.checked,
    ParchmentAttribute.block.key: ParchmentAttribute.block,
    ParchmentAttribute.direction.key: ParchmentAttribute.direction,
    ParchmentAttribute.alignment.key: ParchmentAttribute.alignment,
    ParchmentAttribute.indent.key: ParchmentAttribute.indent,
  };

  // Inline attributes

  /// Bold style attribute.
  static const bold = _BoldAttribute();

  /// Italic style attribute.
  static const italic = _ItalicAttribute();

  /// Underline style attribute.
  static const underline = _UnderlineAttribute();

  /// Strikethrough style attribute.
  static const strikethrough = _StrikethroughAttribute();

  /// Inline code style attribute.
  static const inlineCode = _InlineCodeAttribute();

  /// Foreground color attribute.
  static const foregroundColor = ForegroundColorAttributeBuilder._();

  /// Background color attribute.
  static const backgroundColor = BackgroundColorAttributeBuilder._();

  /// Link style attribute.
  // ignore: const_eval_throws_exception
  static const link = LinkAttributeBuilder._();

  // Line attributes

  /// Heading style attribute.
  // ignore: const_eval_throws_exception
  static const heading = HeadingAttributeBuilder._();

  /// Alias for [ParchmentAttribute.heading.level1].
  static ParchmentAttribute<int> get h1 => heading.level1;

  /// Alias for [ParchmentAttribute.heading.level2].
  static ParchmentAttribute<int> get h2 => heading.level2;

  /// Alias for [ParchmentAttribute.heading.level3].
  static ParchmentAttribute<int> get h3 => heading.level3;

  /// Alias for [ParchmentAttribute.heading.level4].
  static ParchmentAttribute<int> get h4 => heading.level4;

  /// Alias for [ParchmentAttribute.heading.level5].
  static ParchmentAttribute<int> get h5 => heading.level5;

  /// Alias for [ParchmentAttribute.heading.level5].
  static ParchmentAttribute<int> get h6 => heading.level6;

  /// Indent attribute
  static const indent = IndentAttributeBuilder._();

  /// Applies checked style to a line of text in checklist block.
  static const checked = _CheckedAttribute();

  /// Block attribute
  // ignore: const_eval_throws_exception
  static const block = BlockAttributeBuilder._();

  /// Alias for [ParchmentAttribute.block.bulletList].
  static ParchmentAttribute<String> get ul => block.bulletList;

  /// Alias for [ParchmentAttribute.block.numberList].
  static ParchmentAttribute<String> get ol => block.numberList;

  /// Alias for [ParchmentAttribute.block.checkList].
  static ParchmentAttribute<String> get cl => block.checkList;

  /// Alias for [ParchmentAttribute.block.quote].
  static ParchmentAttribute<String> get bq => block.quote;

  /// Alias for [ParchmentAttribute.block.code].
  static ParchmentAttribute<String> get code => block.code;

  /// Direction attribute
  static const direction = DirectionAttributeBuilder._();

  /// Alias for [ParchmentAttribute.direction.rtl].
  static ParchmentAttribute<String> get rtl => direction.rtl;

  /// Alignment attribute
  static const alignment = AlignmentAttributeBuilder._();

  /// Alias for [ParchmentAttribute.alignment.unset]
  static ParchmentAttribute<String> get left => alignment.unset;

  /// Alias for [ParchmentAttribute.alignment.right]
  static ParchmentAttribute<String> get right => alignment.right;

  /// Alias for [ParchmentAttribute.alignment.center]
  static ParchmentAttribute<String> get center => alignment.center;

  /// Alias for [ParchmentAttribute.alignment.justify]
  static ParchmentAttribute<String> get justify => alignment.justify;

  static ParchmentAttribute _fromKeyValue(String key, dynamic value) {
    if (!_registry.containsKey(key)) {
      throw ArgumentError.value(
          key, 'No attribute with key "$key" registered.');
    }
    final builder = _registry[key]!;
    return builder.withValue(value);
  }

  const ParchmentAttribute._(this.key, this.scope, this.value);

  /// Unique key of this attribute.
  @override
  final String key;

  /// Scope of this attribute.
  @override
  final ParchmentAttributeScope scope;

  /// Value of this attribute.
  ///
  /// If value is `null` then this attribute represents a transient action
  /// of removing associated style and is never persisted in a resulting
  /// document.
  ///
  /// See also [unset], [ParchmentStyle.merge] and [ParchmentStyle.put]
  /// for details.
  final T? value;

  /// Returns special "unset" version of this attribute.
  ///
  /// Unset attribute's [value] is always `null`.
  ///
  /// When composed into a rich text document, unset attributes remove
  /// associated style.
  @override
  ParchmentAttribute<T> get unset => ParchmentAttribute<T>._(key, scope, null);

  /// Returns `true` if this attribute is an unset attribute.
  bool get isUnset => value == null;

  /// Returns `true` if this is an inline-scoped attribute.
  bool get isInline => scope == ParchmentAttributeScope.inline;

  @override
  ParchmentAttribute<T> withValue(T? value) =>
      ParchmentAttribute<T>._(key, scope, value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ParchmentAttribute<T>) return false;
    return key == other.key && scope == other.scope && value == other.value;
  }

  @override
  int get hashCode => hash3(key, scope, value);

  @override
  String toString() => '$key: $value';

  Map<String, dynamic> toJson() => <String, dynamic>{key: value};
}

/// Collection of style attributes.
class ParchmentStyle {
  ParchmentStyle._(this._data);

  final Map<String, ParchmentAttribute> _data;

  static ParchmentStyle fromJson(Map<String, dynamic>? data) {
    if (data == null) return ParchmentStyle();

    final result = data.map((String key, dynamic value) {
      var attr = ParchmentAttribute._fromKeyValue(key, value);
      return MapEntry<String, ParchmentAttribute>(key, attr);
    });
    return ParchmentStyle._(result);
  }

  ParchmentStyle() : _data = <String, ParchmentAttribute>{};

  /// Returns `true` if this attribute set is empty.
  bool get isEmpty => _data.isEmpty;

  /// Returns `true` if this attribute set is note empty.
  bool get isNotEmpty => _data.isNotEmpty;

  /// Returns `true` if this style is not empty and contains only inline-scoped
  /// attributes and is not empty.
  bool get isInline => isNotEmpty && values.every((item) => item.isInline);

  /// Checks that this style has only one attribute, and returns that attribute.
  ParchmentAttribute get single => _data.values.single;

  /// Returns line-scoped attributes
  Iterable<ParchmentAttribute> get lineAttributes =>
      values.where((e) => e.scope == ParchmentAttributeScope.line);

  /// Returns inline-scoped attributes
  Iterable<ParchmentAttribute> get inlineAttributes =>
      values.where((e) => e.scope == ParchmentAttributeScope.inline);

  /// Returns `true` if attribute with [key] is present in this set.
  ///
  /// Only checks for presence of specified [key] regardless of the associated
  /// value.
  ///
  /// To test if this set contains an attribute with specific value consider
  /// using [containsSame].
  bool contains(ParchmentAttributeKey key) => _data.containsKey(key.key);

  /// Returns `true` if this set contains attribute with the same value as
  /// [attribute].
  bool containsSame(ParchmentAttribute attribute) {
    return get<dynamic>(attribute) == attribute;
  }

  /// Returns value of specified attribute [key] in this set.
  T? value<T>(ParchmentAttributeKey<T> key) => get(key)?.value;

  /// Returns [ParchmentAttribute] from this set by specified [key].
  ParchmentAttribute<T>? get<T>(ParchmentAttributeKey<T> key) =>
      _data[key.key] as ParchmentAttribute<T>?;

  /// Returns collection of all attribute keys in this set.
  Iterable<String> get keys => _data.keys;

  /// Returns collection of all attributes in this set.
  Iterable<ParchmentAttribute> get values => _data.values;

  /// Puts [attribute] into this attribute set and returns result as a new set.
  ParchmentStyle put(ParchmentAttribute attribute) {
    final result = Map<String, ParchmentAttribute>.from(_data);
    result[attribute.key] = attribute;
    return ParchmentStyle._(result);
  }

  /// Puts [attributes] into this attribute set and returns result as a new set.
  ParchmentStyle putAll(Iterable<ParchmentAttribute> attributes) {
    final result = Map<String, ParchmentAttribute>.from(_data);
    for (final attr in attributes) {
      result[attr.key] = attr;
    }
    return ParchmentStyle._(result);
  }

  /// Merges this attribute set with [attribute] and returns result as a new
  /// attribute set.
  ///
  /// Performs compaction if [attribute] is an "unset" value, e.g. removes
  /// corresponding attribute from this set completely.
  ///
  /// See also [put] method which does not perform compaction and allows
  /// constructing styles with "unset" values.
  ParchmentStyle merge(ParchmentAttribute attribute) {
    final merged = Map<String, ParchmentAttribute>.from(_data);
    if (attribute.isUnset) {
      merged.remove(attribute.key);
    } else {
      merged[attribute.key] = attribute;
    }
    return ParchmentStyle._(merged);
  }

  /// Merges all attributes from [other] into this style and returns result
  /// as a new instance of [ParchmentStyle].
  ParchmentStyle mergeAll(ParchmentStyle other) {
    var result = ParchmentStyle._(_data);
    for (var value in other.values) {
      result = result.merge(value);
    }
    return result;
  }

  /// Removes [attributes] from this style and returns new instance of
  /// [ParchmentStyle] containing result.
  ParchmentStyle removeAll(Iterable<ParchmentAttribute> attributes) {
    final merged = Map<String, ParchmentAttribute>.from(_data);
    attributes.map((item) => item.key).forEach(merged.remove);
    return ParchmentStyle._(merged);
  }

  /// Returns JSON-serializable representation of this style.
  Map<String, dynamic>? toJson() => _data.isEmpty
      ? null
      : _data.map<String, dynamic>((String _, ParchmentAttribute value) =>
          MapEntry<String, dynamic>(value.key, value.value));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ParchmentStyle) return false;
    final eq = const MapEquality<String, ParchmentAttribute>();
    return eq.equals(_data, other._data);
  }

  @override
  int get hashCode {
    final hashes = _data.entries.map((entry) => hash2(entry.key, entry.value));
    return hashObjects(hashes);
  }

  @override
  String toString() => "{${_data.values.join(', ')}}";
}

/// Applies bold style to a text segment.
class _BoldAttribute extends ParchmentAttribute<bool> {
  const _BoldAttribute() : super._('b', ParchmentAttributeScope.inline, true);
}

/// Applies italic style to a text segment.
class _ItalicAttribute extends ParchmentAttribute<bool> {
  const _ItalicAttribute() : super._('i', ParchmentAttributeScope.inline, true);
}

/// Applies underline style to a text segment.
class _UnderlineAttribute extends ParchmentAttribute<bool> {
  const _UnderlineAttribute()
      : super._('u', ParchmentAttributeScope.inline, true);
}

/// Applies strikethrough style to a text segment.
class _StrikethroughAttribute extends ParchmentAttribute<bool> {
  const _StrikethroughAttribute()
      : super._('s', ParchmentAttributeScope.inline, true);
}

/// Applies code style to a text segment.
class _InlineCodeAttribute extends ParchmentAttribute<bool> {
  const _InlineCodeAttribute()
      : super._('c', ParchmentAttributeScope.inline, true);
}

/// Builder for color-based style attributes.
///
/// Useful in scenarios when a color attribute value is not known upfront.
///
/// See also:
///   * [BackgroundColorAttributeBuilder]
///   * [ForegroundColorAttributeBuilder]
abstract class ColorParchmentAttributeBuilder
    extends ParchmentAttributeBuilder<int> {
  const ColorParchmentAttributeBuilder._(super.key, super.scope) : super._();

  /// Creates the color attribute with [color] value
  ParchmentAttribute<int> withColor(int color);
}

/// Builder for background color value.
/// Color is interpreted from the lower 32 bits of an [int].
///
/// The bits are interpreted as follows:
///
/// * Bits 24-31 are the alpha value.
/// * Bits 16-23 are the red value.
/// * Bits 8-15 are the green value.
/// * Bits 0-7 are the blue value.
/// (see [Color] documentation for more details
///
/// There is no need to use this class directly, consider using
/// [ParchmentAttribute.backgroundColor] instead.
class BackgroundColorAttributeBuilder extends ColorParchmentAttributeBuilder {
  static const _bgColor = 'bg';
  static const _transparentColor = 0;

  const BackgroundColorAttributeBuilder._()
      : super._(_bgColor, ParchmentAttributeScope.inline);

  /// Creates foreground color attribute with [color] value
  ///
  /// If color is transparent, [unset] is returned
  @override
  ParchmentAttribute<int> withColor(int color) {
    if (color == _transparentColor) {
      return unset;
    }
    return ParchmentAttribute<int>._(key, scope, color);
  }
}

/// Builder for text color value.
/// Color is interpreted from the lower 32 bits of an [int].
///
/// The bits are interpreted as follows:
///
/// * Bits 24-31 are the alpha value.
/// * Bits 16-23 are the red value.
/// * Bits 8-15 are the green value.
/// * Bits 0-7 are the blue value.
/// (see [Color] documentation for more details
///
/// There is no need to use this class directly, consider using
/// [ParchmentAttribute.foregroundColor] instead.
class ForegroundColorAttributeBuilder extends ColorParchmentAttributeBuilder {
  static const _fgColor = 'fg';
  static const _black = 0x00000000;

  const ForegroundColorAttributeBuilder._()
      : super._(_fgColor, ParchmentAttributeScope.inline);

  /// Creates foreground color attribute with [color] value
  ///
  /// If color is black, [unset] is returned
  @override
  ParchmentAttribute<int> withColor(int color) {
    if (color == _black) {
      return unset;
    }
    return ParchmentAttribute._(key, scope, color);
  }
}

/// Builder for link attribute values.
///
/// There is no need to use this class directly, consider using
/// [ParchmentAttribute.link] instead.
class LinkAttributeBuilder extends ParchmentAttributeBuilder<String> {
  static const _kLink = 'a';

  const LinkAttributeBuilder._()
      : super._(_kLink, ParchmentAttributeScope.inline);

  /// Creates a link attribute with specified link [value].
  ParchmentAttribute<String> fromString(String value) =>
      ParchmentAttribute<String>._(key, scope, value);
}

/// Builder for heading attribute styles.
///
/// There is no need to use this class directly, consider using
/// [ParchmentAttribute.heading] instead.
class HeadingAttributeBuilder extends ParchmentAttributeBuilder<int> {
  static const _kHeading = 'heading';

  const HeadingAttributeBuilder._()
      : super._(_kHeading, ParchmentAttributeScope.line);

  /// Level 1 heading, equivalent of `H1` in HTML.
  ParchmentAttribute<int> get level1 =>
      ParchmentAttribute<int>._(key, scope, 1);

  /// Level 2 heading, equivalent of `H2` in HTML.
  ParchmentAttribute<int> get level2 =>
      ParchmentAttribute<int>._(key, scope, 2);

  /// Level 3 heading, equivalent of `H3` in HTML.
  ParchmentAttribute<int> get level3 =>
      ParchmentAttribute<int>._(key, scope, 3);

  /// Level 4 heading, equivalent of `H4` in HTML.
  ParchmentAttribute<int> get level4 =>
      ParchmentAttribute<int>._(key, scope, 4);

  /// Level 5 heading, equivalent of `H5` in HTML.
  ParchmentAttribute<int> get level5 =>
      ParchmentAttribute<int>._(key, scope, 5);

  /// Level 6 heading, equivalent of `H6` in HTML.
  ParchmentAttribute<int> get level6 =>
      ParchmentAttribute<int>._(key, scope, 6);
}

/// Applies checked style to a line in a checklist block.
class _CheckedAttribute extends ParchmentAttribute<bool> {
  const _CheckedAttribute()
      : super._('checked', ParchmentAttributeScope.line, true);
}

/// Builder for block attribute styles (number/bullet lists, code and quote).
///
/// There is no need to use this class directly, consider using
/// [ParchmentAttribute.block] instead.
class BlockAttributeBuilder extends ParchmentAttributeBuilder<String> {
  static const _kBlock = 'block';

  const BlockAttributeBuilder._()
      : super._(_kBlock, ParchmentAttributeScope.line);

  /// Formats a block of lines as a bullet list.
  ParchmentAttribute<String> get bulletList =>
      ParchmentAttribute<String>._(key, scope, 'ul');

  /// Formats a block of lines as a number list.
  ParchmentAttribute<String> get numberList =>
      ParchmentAttribute<String>._(key, scope, 'ol');

  /// Formats a block of lines as a check list.
  ParchmentAttribute<String> get checkList =>
      ParchmentAttribute<String>._(key, scope, 'cl');

  /// Formats a block of lines as a code snippet, using monospace font.
  ParchmentAttribute<String> get code =>
      ParchmentAttribute<String>._(key, scope, 'code');

  /// Formats a block of lines as a quote.
  ParchmentAttribute<String> get quote =>
      ParchmentAttribute<String>._(key, scope, 'quote');
}

class DirectionAttributeBuilder extends ParchmentAttributeBuilder<String> {
  static const _kDirection = 'direction';

  const DirectionAttributeBuilder._()
      : super._(_kDirection, ParchmentAttributeScope.line);

  ParchmentAttribute<String> get rtl =>
      ParchmentAttribute<String>._(key, scope, 'rtl');
}

class AlignmentAttributeBuilder extends ParchmentAttributeBuilder<String> {
  static const _kAlignment = 'alignment';

  const AlignmentAttributeBuilder._()
      : super._(_kAlignment, ParchmentAttributeScope.line);

  ParchmentAttribute<String> get right =>
      ParchmentAttribute<String>._(key, scope, 'right');

  ParchmentAttribute<String> get center =>
      ParchmentAttribute<String>._(key, scope, 'center');

  ParchmentAttribute<String> get justify =>
      ParchmentAttribute<String>._(key, scope, 'justify');
}

const _maxIndentationLevel = 8;

class IndentAttributeBuilder extends ParchmentAttributeBuilder<int> {
  static const _kIndent = 'indent';

  const IndentAttributeBuilder._()
      : super._(_kIndent, ParchmentAttributeScope.line);

  ParchmentAttribute<int> withLevel(int level) {
    if (level == 0) {
      return unset;
    }
    return ParchmentAttribute._(
        key, scope, math.min(_maxIndentationLevel, level));
  }
}
