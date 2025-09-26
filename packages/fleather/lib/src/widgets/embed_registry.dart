import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';

class EmbedRegistry {
  const EmbedRegistry() : this._(const {});

  const EmbedRegistry.fallback() : this._(const {'hr': HorizontalRule()});

  const EmbedRegistry._(this._registry);

  factory EmbedRegistry.withConfigurations(List<EmbedConfiguration> configs) {
    EmbedRegistry registry = EmbedRegistry();
    return registry.registerAll(configs);
  }

  factory EmbedRegistry.fallbackWithConfigurations(
      List<EmbedConfiguration> configs) {
    EmbedRegistry registry = EmbedRegistry.fallback();
    return registry.registerAll(configs);
  }

  final Map<String, EmbedConfiguration> _registry;

  EmbedRegistry registerAll(List<EmbedConfiguration> configs) {
    var registry = this;
    for (final c in configs) {
      registry = registry.register(c);
    }
    return registry;
  }

  EmbedRegistry register(EmbedConfiguration config) {
    if (_registry.containsKey(config.type)) {
      throw ArgumentError('${config.type} was already registered');
    }
    return EmbedRegistry._(Map.from(this._registry)..[config.type] = config);
  }

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
  final String type;

  const EmbedConfiguration({required this.type});

  Widget build(BuildContext context, Map<String, dynamic> data);
}

abstract class BlockEmbedConfiguration extends EmbedConfiguration {
  const BlockEmbedConfiguration({required super.type});
}

abstract class SpanEmbedConfiguration extends EmbedConfiguration {
  const SpanEmbedConfiguration(
      {required super.type,
      this.alignment = PlaceholderAlignment.bottom,
      this.baseline,
      this.style});

  final PlaceholderAlignment alignment;
  final TextBaseline? baseline;
  final TextStyle? style;
}

class HorizontalRule extends BlockEmbedConfiguration {
  const HorizontalRule() : super(type: 'hr');

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
