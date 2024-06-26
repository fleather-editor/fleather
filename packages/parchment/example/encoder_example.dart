import 'package:parchment/codecs.dart';
import 'package:parchment/parchment.dart';
import 'package:parchment_delta/parchment_delta.dart';

void main() {
  // We're going to start by creating a new blank document
  final doc = ParchmentDocument();

  // Since this is an example of building a custom embed. We're going to define a custom embed object.
  // "Youtube" refers to the name of the embed object
  // "inline" will communicate if this embed is inline with other content, or if it lives by itself on its own line.
  // Embeds take up one character but are encoded as a simple object with Map<String, dynamic> data.
  // You can see the data as the next argument in the constructor.
  // Data can have literally any data you want.
  final url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
  final thumbUrl = 'https://img.youtube.com/vi/dQw4w9WgXcQ/0.jpg';

  // We're going to do both an inline and a block embed. They are essentially the same except the inline property.
  // Inline Block Embed
  final youtubeInlineEmbedDelta = {
    '_type': 'youtube',
    '_inline': true,
    'url': url,
    'title': 'Read the Url Before Clicking',
    'language': 'en',
    'thumbUrl': thumbUrl
  };

  // Block Embed
  final youtubeBlockEmbedDelta = {
    '_type': 'youtube',
    '_inline': false,
    'url': url,
    'title': 'Read the Url Before Clicking',
    'language': 'en',
    'thumbUrl': thumbUrl
  };

  // Lets create new Delta to insert content into our document.
  final newDelta = Delta()
    ..insert(
        'Lets add in some examples of custom embed blocks which we\'ll implement custom encoders to encode the result.')
    ..insert('\n')
    ..insert('Lets Start with a simple inline block: ')
    ..insert(youtubeInlineEmbedDelta)
    ..insert('\n')
    ..insert('Now lets add a block embed: \n')
    ..insert(youtubeBlockEmbedDelta);

  // Since we know our changes are progormatically generated they don't need to be run through Heuristics and Autoformatting.
  // So we are going to use the compose command which bypasses any of Fleather's additional logic to keep content consistent and clean.
  // This is useful for programatically generated content but you should use another command if the content includes any user input so it properly formats.
  // Using ChangeSource.local because these changes originated programmatically on our machine.
  doc.compose(newDelta, ChangeSource.local);

  // This is where some of the magic happens. Lets define a custom encoder so we can format our youtube embed for export from fleather.
  // If you are just saving to the database then using jsonEncode(doc) would be enough and no additional work needed.
  // But if you want to make use of fleather's excellent HTML and Markdown encoders then we need to take an additional step.

  // Lets start with markdown since it is simpler.
  final markdownYouTubeEncoder = EncodeExtension(
      codecType: CodecExtensionType
          .markdown, // We use this so we can pass all encoders to the converter and the converter can smart select the correct encoders it would like to use.
      blockType:
          'youtube', // We're matching against the type of embed. "youtube" was defined above as the first param of our EmbeddableObject.
      encode: (EmbeddableObject embeddable) {
        return "[![${embeddable.data['title']}](${embeddable.data['thumbUrl']})](${embeddable.data['url']})";
      }); // This function takes in an embeddable object and returns a string which you can use with markdown.

  // A few important things to note about the encode function.
  // 1.) The encode function left out the language. We can store information in the embed object which we don't want to display.
  // 2.) You have access to all the fields of the embed by using embeddable.data['field_name']

  // Lets trying making an encoder for HTML now.
  final htmlYouTubeEncoder = EncodeExtension(
      codecType: CodecExtensionType.html, // We change to HTML here
      blockType:
          'youtube', // Still matching against Youtube since we're encoding the same type of block embed.
      encode: (EmbeddableObject embeddable) {
        return """<div style="display: inline-block; text-align: center;">
                  <a href="${embeddable.data['url']}" target="_blank" style="text-decoration: none; color: black;">
                    <img src="${embeddable.data['thumbrUrl']}" alt="${embeddable.data['title']}" style="width: 200px; height: auto; display: block; margin-bottom: 8px;">
                    <span style="display: block; font-size: 16px; font-weight: bold;">${embeddable.data['title']}</span>
                  </a>
                </div>

                """;
      });

  // For the HTML output we set the content to display as inline-block. This is because the encoder runs both as a block and inline elemnt.
  // Fleather will still wrap block embeds in <p></p> tags, so displaying as inline-block should work for both.

  // Now that we have two encoders for our HTML block, Markdown and HTML, lets try to export out document has HTML and Markdown.
  final encoderList = [markdownYouTubeEncoder, htmlYouTubeEncoder];

  // Lets encode our document to HTML and Markdown
  // Notice how we can just pass our list to the codec without any additional work. So define all your encoders and just pass them along when encoding.
  final htmlOutput = ParchmentHtmlCodec(extensions: encoderList).encode(doc);
  final markdownOutput =
      ParchmentMarkdownCodec(extensions: encoderList).encode(doc);

  // Lets print out our results.
  print('HTML Output:');
  print(htmlOutput);
  print('\n\n');
  print('Markdown Output:');
  print(markdownOutput);

  // Congrats! You can now make all manner of awesome custom embeds and work with them like any other text.
  // Using fleather's fabulous embed rendering engine in the editor you can call functions, update widgets
  // and do all sorts of logic within your embed functions. Then when you're done, call these export functions
  // with your custom encoders and you're good to go!

  // Dispose resources allocated by this document, e.g. closes "changes" stream.
  // After document is closed it cannot be modified.
  doc.close();
}
