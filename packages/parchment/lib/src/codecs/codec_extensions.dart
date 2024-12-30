// This document contains functions for extending the default Encoders and Decoders which come with Fleather
// This allows you to write custom extensions which are called when running the encode and decode functions.
// By including a type you allow the extension to be scoped to availble options (Markdown, HTML).
// So you can just build a big pile of extensions if you want and just add them in to every instance of the encoder/decoder.

// Custom Encoder and Decoder functions run BEFORE the default encoder and decoder functions.
// This means you can override normal behavior of the default embed encoder if desired (really just for HR and image tags at this point).

import 'package:parchment/src/document/embeds.dart';

// Simple enum to allow us to write one encode class to encapsulate both Markdown and HTML encode extensions
enum CodecExtensionType {
  markdown,
  html,
}

// This class is exported for the end-user developer to define custom encoders
// This allows Parchment encoder function to take in a list of EncodeExtensions
// Which will run before the default encoders so developers can override default behavior
// or define their own custom encoders.
// This is built specifically for block embeds.
class EncodeExtension {
  // Specify Markdown or HTML
  // More verbose to write extensions for each type
  // But probably more clear.
  final CodecExtensionType codecType;

  // Which embeddable Block Type are we matching against?
  final String blockType;

  // This function will run if we find an embeddable block of matching blockType.
  // Should output a string with the encoded block in the format the encoder perfers.
  // For example, a block which outputs an image might parse and output the following string (taken from the default encode function):
  // '<img src="${embeddable.data['source']}" style="max-width: 100%; object-fit: contain;">');
  // Markdown might look like this:
  // '![${embeddable.data['alt']}](${embeddable.data['source']})'
  // Function takes in an EmbeddableObject and returns a string.
  final String Function(EmbeddableObject embeddable) encode;

  // Constructor
  EncodeExtension({
    required this.codecType,
    required this.blockType,
    required this.encode,
  });

  // Simple bool to see if this node can be encoded. String match on node type
  bool canEncode(CodecExtensionType type, String node) {
    return codecType == type && node == blockType;
  }
}

// TODO: Implement DecodeExtension class
// Might need to make more specalized decode classes for markdown and HTML.
