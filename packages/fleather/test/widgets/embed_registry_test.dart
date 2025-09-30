import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('$EmbedRegistry', () {
    test('create fallback', () {
      final registry = EmbedRegistry.fallback();
      final hr = registry.blockEmbed(EmbeddableObject('hr', inline: false));
      expect(hr, isA<HorizontalRule>());
    });

    test('create with configurations', () {
      final registry = EmbedRegistry.withConfigurations([FakeBlockEmbed()]);
      final fakeBlock =
          registry.blockEmbed(EmbeddableObject('fake_block', inline: false));
      expect(fakeBlock, isA<FakeBlockEmbed>());
    });

    test('create fallback with configurations', () {
      final registry =
          EmbedRegistry.fallbackWithConfigurations([FakeBlockEmbed()]);
      final fakeBlock =
          registry.blockEmbed(EmbeddableObject('fake_block', inline: false));
      expect(fakeBlock, isA<FakeBlockEmbed>());
      final hr = registry.blockEmbed(EmbeddableObject('hr', inline: false));
      expect(hr, isA<HorizontalRule>());
    });

    test('cannot register twice the same key', () {
      try {
        EmbedRegistry.withConfigurations([FakeBlockEmbed(), FakeBlockEmbed()]);
      } on ArgumentError catch (_) {
        return;
      }
      fail('Should throw an argument error');
    });

    test('spanEmbed - find nothing', () {
      final registry = EmbedRegistry();
      try {
        registry.spanEmbed(EmbeddableObject('fake_span', inline: true));
      } on StateError catch (_) {
        return;
      }
      fail('Should throw an assertion error');
    });

    test('spanEmbed - finds a block embed', () {
      final registry =
          EmbedRegistry.fallbackWithConfigurations([FakeBlockEmbed()]);
      try {
        registry
            .spanEmbed(EmbeddableObject(FakeBlockEmbed().key, inline: true));
      } on AssertionError catch (_) {
        return;
      }
      fail('Should throw an assertion error');
    });

    test('blockEmbed - find nothing', () {
      final registry = EmbedRegistry();
      try {
        registry.blockEmbed(EmbeddableObject('fake_block', inline: false));
      } on StateError catch (_) {
        return;
      }
      fail('Should throw an assertion error');
    });

    test('blockEmbed - finds a span embed', () {
      final registry = EmbedRegistry.withConfigurations([FakeSpanEmbed()]);
      try {
        registry
            .blockEmbed(EmbeddableObject(FakeSpanEmbed().key, inline: false));
      } on AssertionError catch (_) {
        return;
      }
      fail('Should throw an assertion error');
    });
  });
}

class FakeBlockEmbed extends BlockEmbedConfiguration {
  FakeBlockEmbed() : super(key: 'fake_block');

  @override
  Widget build(BuildContext context, Map<String, dynamic> data) {
    return Text('Span');
  }
}

class FakeSpanEmbed extends SpanEmbedConfiguration {
  FakeSpanEmbed() : super(key: 'fake_span');

  @override
  Widget build(BuildContext context, Map<String, dynamic> data) {
    return Text('Block');
  }
}
