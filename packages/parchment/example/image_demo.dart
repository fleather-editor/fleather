import 'package:parchment/codecs.dart';
import 'package:parchment/parchment.dart';

void main() {
  print('=== Image Support in Parchment Markdown Codec ===\n');

  // Test 1: Markdown to Parchment (Decoding)
  print('1. Decoding Markdown with image to Parchment:');
  final markdown = '![Alt text](https://example.com/image.jpg)';
  print('Input: $markdown');

  final document = parchmentMarkdown.decode(markdown);
  final delta = document.toDelta();

  final embed = delta.elementAt(0).data as BlockEmbed;
  print('Output: Image embed with source: ${embed.data['source']}');
  print('');

  // Test 2: Parchment to Markdown (Encoding)
  print('2. Encoding Parchment with image to Markdown:');
  final imageEmbed = BlockEmbed.image('https://example.com/my-image.png');
  final deltaWithImage = Delta()
    ..insert(imageEmbed)
    ..insert('\n');
  final documentWithImage = ParchmentDocument.fromDelta(deltaWithImage);

  final encodedMarkdown = parchmentMarkdown.encode(documentWithImage);
  print('Output: $encodedMarkdown');

  // Test 3: Round-trip conversion
  print('3. Round-trip conversion:');
  final originalMarkdown = '![Test image](https://example.com/test.jpg)';
  final roundTripDocument = parchmentMarkdown.decode(originalMarkdown);
  final backToMarkdown = parchmentMarkdown.encode(roundTripDocument);

  print('Original: $originalMarkdown');
  print('Round-trip: ${backToMarkdown.trim()}');
  print(
      'Success: ${backToMarkdown.contains('![](https://example.com/test.jpg)')}');
}
