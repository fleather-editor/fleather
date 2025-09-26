import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';

/// A registry fpr embeds.
///
/// Implementers should register [EmbedConfiguration]s in [EmbedRegistry] to
/// specify how to render an embed.
class EmbedRegistry {
  const EmbedRegistry._(this._registry);

  /// An empty registry
  const EmbedRegistry() : this._(const {});

  /// The default Fleather [EmbedRegistry]
  ///
  /// Contains only [HorizontalRule]
  const EmbedRegistry.fallback() : this._(const {'hr': HorizontalRule()});

  /// Creates a registry with a list of [EmbedConfiguration]s.
  factory EmbedRegistry.withConfigurations(List<EmbedConfiguration> configs) {
    EmbedRegistry registry = EmbedRegistry();
    return registry._registerAll(configs);
  }

  /// Creates a registry with a list of [EmbedConfiguration]s merged with the
  /// fallback configurations.
  factory EmbedRegistry.fallbackWithConfigurations(
      List<EmbedConfiguration> configs) {
    EmbedRegistry registry = EmbedRegistry.fallback();
    return registry._registerAll(configs);
  }

  final Map<String, EmbedConfiguration> _registry;

  EmbedRegistry _registerAll(List<EmbedConfiguration> configs) {
    var registry = this;
    for (final c in configs) {
      registry = registry._register(c);
    }
    return registry;
  }

  EmbedRegistry _register(EmbedConfiguration config) {
    if (_registry.containsKey(config.key)) {
      throw ArgumentError('${config.key} was already registered');
    }
    return EmbedRegistry._(Map.from(this._registry)..[config.key] = config);
  }

  /// Retrieve from registry the [SpanEmbedConfiguration] corresponding to a
  /// [EmbeddableObject].
  ///
  /// Used by widget to render the embed in the editor.
  SpanEmbedConfiguration spanEmbed(EmbeddableObject node) {
    assert(node.inline, 'EmbeddableObject must be inline for SpanEmbeds');
    final embed = _registry[node.type];
    if (embed == null) {
      throw StateError(
        '${node.type} was not registered. Make sure to register an embed '
        'in the EmbedRegistry',
      );
    }
    assert(embed is SpanEmbedConfiguration,
        'Registered embed for ${node.type} is a ${embed.runtimeType}. Expecting a SpanEmbed');
    return embed as SpanEmbedConfiguration;
  }

  /// Retrieve from registry the [BlockEmbedConfiguration] corresponding to a
  /// [EmbeddableObject].
  ///
  /// Used by widget to render the embed in the editor.
  BlockEmbedConfiguration blockEmbed(EmbeddableObject node) {
    assert(!node.inline, 'EmbeddableObject may not be inline for BlockEmbeds');
    final embed = _registry[node.type];
    if (embed == null) {
      throw StateError(
        '${node.type} was not registered. Make sure to register an embed '
        'in the EmbedRegistry',
      );
    }
    assert(
        embed is BlockEmbedConfiguration,
        'Registered embed for ${node.type} is a ${embed.runtimeType}. '
        'Expecting a BlocEmbed');
    return _registry[node.type] as BlockEmbedConfiguration;
  }
}

sealed class EmbedConfiguration {
  /// The key of the embed
  ///
  /// Used to identify the the configuration in the [EmbedRegistry]
  final String key;

  const EmbedConfiguration({required this.key});

  /// Builds the [Widget] according to the supplied [data].
  Widget build(BuildContext context, Map<String, dynamic> data);
}

/// [EmbedConfiguration] for block embeds
abstract class BlockEmbedConfiguration extends EmbedConfiguration {
  const BlockEmbedConfiguration({required super.key});
}

/// [EmbedConfiguration] for span embeds
abstract class SpanEmbedConfiguration extends EmbedConfiguration {
  const SpanEmbedConfiguration(
      {required super.key,
      this.alignment = PlaceholderAlignment.bottom,
      this.baseline,
      this.style});

  /// The [PlaceholderAlignment] that should be passed to the [WidgetSpan]
  ///
  /// See [PlaceholderSpan.alignment]
  final PlaceholderAlignment alignment;

  /// The optional [TextBaseline] that should be passed to the [WidgetSpan]
  ///
  /// See [PlaceholderSpan.baseline]
  final TextBaseline? baseline;

  /// The optional [TextStyle] that should be passed to the [WidgetSpan]
  ///
  /// See [PlaceholderSpan.style]
  final TextStyle? style;
}

/// Horizontal rule [BlockEmbedConfiguration]
class HorizontalRule extends BlockEmbedConfiguration {
  const HorizontalRule() : super(key: 'hr');

  @override
  Widget build(BuildContext context, Map<String, dynamic> data) {
    final fleatherThemeData = FleatherTheme.of(context)!;
    return Divider(
      height: fleatherThemeData.horizontalRule.height,
      thickness: fleatherThemeData.horizontalRule.thickness,
      color: fleatherThemeData.horizontalRule.color,
    );
  }
}
