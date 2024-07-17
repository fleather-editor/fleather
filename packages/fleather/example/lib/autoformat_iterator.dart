import 'dart:convert';
import 'dart:io';

import 'package:fleather/fleather.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parchment_delta/parchment_delta.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const FleatherApp());
}

class FleatherApp extends StatelessWidget {
  const FleatherApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        title: 'Fleather - rich-text editor for Flutter',
        home: HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FocusNode _focusNode = FocusNode();
  FleatherController? _controller;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) BrowserContextMenu.disableContextMenu();
    _initController();
  }

  @override
  void dispose() {
    super.dispose();
    if (kIsWeb) BrowserContextMenu.enableContextMenu();
  }

  Future<void> _initController() async {
    try {
      final result = await rootBundle.loadString('assets/welcome.json');

      /// Build Autoformats with backups
      /// Autoformats allow for ergonomic automatic text transformations.
      /// This example takes ![youtube link] and transforms it into a youtube blockembed.
      /// Fallback text transformations apply styles by using markdown such as _italics_ or **bold**.
      final customAutoFormat = AutoFormatYoutubeEmbed();
      final autoFormats = AutoFormats.buildWithFallback([customAutoFormat]);

      /// Heuristics work very similar to autoformats but are focused on improving the editing experience.
      final heuristics = ParchmentHeuristics(
        formatRules: [],
        insertRules: [
          ForceNewlineForInsertsAroundInlineImageRule(),
        ],
        deleteRules: [],
      ).merge(ParchmentHeuristics.fallback);
      final doc = ParchmentDocument.fromJson(
        jsonDecode(result),
        heuristics: heuristics,
      );
      _controller = FleatherController(document: doc, autoFormats: autoFormats);
    } catch (err, st) {
      print('Cannot read welcome.json: $err\n$st');
      _controller = FleatherController();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, title: Text('Fleather Demo')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final picker = ImagePicker();
          final image = await picker.pickImage(source: ImageSource.gallery);
          if (image != null) {
            final selection = _controller!.selection;
            _controller!.replaceText(
              selection.baseOffset,
              selection.extentOffset - selection.baseOffset,
              EmbeddableObject('image', inline: false, data: {
                'source_type': kIsWeb ? 'url' : 'file',
                'source': image.path,
              }),
            );
            _controller!.replaceText(
              selection.baseOffset + 1,
              0,
              '\n',
              selection:
                  TextSelection.collapsed(offset: selection.baseOffset + 2),
            );
          }
        },
        child: Icon(Icons.add_a_photo),
      ),
      body: _controller == null
          ? Center(child: const CircularProgressIndicator())
          : Column(
              children: [
                FleatherToolbar.basic(controller: _controller!),
                Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
                Expanded(
                  child: FleatherEditor(
                    controller: _controller!,
                    focusNode: _focusNode,
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: MediaQuery.of(context).padding.bottom,
                    ),
                    onLaunchUrl: _launchUrl,
                    maxContentWidth: 800,
                    embedBuilder: _embedBuilder,
                    spellCheckConfiguration: SpellCheckConfiguration(
                        spellCheckService: DefaultSpellCheckService(),
                        misspelledSelectionColor: Colors.red,
                        misspelledTextStyle:
                            DefaultTextStyle.of(context).style),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _embedBuilder(BuildContext context, EmbedNode node) {
    if (node.value.type == 'icon') {
      final data = node.value.data;
      // Icons.rocket_launch_outlined
      return Icon(
        IconData(int.parse(data['codePoint']), fontFamily: data['fontFamily']),
        color: Color(int.parse(data['color'])),
        size: 18,
      );
    }

    if (node.value.type == 'youtube') {
      final data = node.value.data;
      final url = data['url'];
      final thumbUrl = data['thumbUrl'];
      final subtitles = data['subtitles'];
      final language = data['language'];

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          children: [
            if (thumbUrl != null)
              Image.network(thumbUrl,
                  width: 300, height: 169, fit: BoxFit.cover),
            Text(
              'Language: $language',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              'Subtitles: $subtitles',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            TextButton(
              onPressed: () => {}, // _launchUrl(url),
              child: Text('Watch on YouTube'),
            ),
          ],
        ),
      );
    }

    if (node.value.type == 'image') {
      final sourceType = node.value.data['source_type'];
      ImageProvider? image;
      if (sourceType == 'assets') {
        image = AssetImage(node.value.data['source']);
      } else if (sourceType == 'file') {
        image = FileImage(File(node.value.data['source']));
      } else if (sourceType == 'url') {
        image = NetworkImage(node.value.data['source']);
      }
      if (image != null) {
        return Padding(
          // Caret takes 2 pixels, hence not symmetric padding values.
          padding: const EdgeInsets.only(left: 4, right: 2, top: 2, bottom: 2),
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              image: DecorationImage(image: image, fit: BoxFit.cover),
            ),
          ),
        );
      }
    }

    return defaultFleatherEmbedBuilder(context, node);
  }

  void _launchUrl(String? url) async {
    if (url == null) return;
    final uri = Uri.parse(url);
    final _canLaunch = await canLaunchUrl(uri);
    if (_canLaunch) {
      await launchUrl(uri);
    }
  }
}

/// This is an example insert rule that will insert a new line before and
/// after inline image embed.
class ForceNewlineForInsertsAroundInlineImageRule extends InsertRule {
  @override
  Delta? apply(Delta document, int index, Object data) {
    if (data is! String) return null;

    final iter = DeltaIterator(document);
    final previous = iter.skip(index);
    final target = iter.next();
    final cursorBeforeInlineEmbed = _isInlineImage(target.data);
    final cursorAfterInlineEmbed =
        previous != null && _isInlineImage(previous.data);

    if (cursorBeforeInlineEmbed || cursorAfterInlineEmbed) {
      final delta = Delta()..retain(index);
      if (cursorAfterInlineEmbed && !data.startsWith('\n')) {
        delta.insert('\n');
      }
      delta.insert(data);
      if (cursorBeforeInlineEmbed && !data.endsWith('\n')) {
        delta.insert('\n');
      }
      return delta;
    }
    return null;
  }

  bool _isInlineImage(Object data) {
    if (data is EmbeddableObject) {
      return data.type == 'image' && data.inline;
    }
    if (data is Map) {
      return data[EmbeddableObject.kTypeKey] == 'image' &&
          data[EmbeddableObject.kInlineKey];
    }
    return false;
  }
}

/// Define a custom autoformat for styling a custom embed object.
/// Use it by typing `!https://www.youtube.com/watch?v=dQw4w9WgXcQ` and then a space.
class AutoFormatYoutubeEmbed extends AutoFormat {
  static final _youtubePattern =
      RegExp(r'!https:\/\/www\.youtube\.com\/watch\?v=([a-zA-Z0-9_-]+)$');

  const AutoFormatYoutubeEmbed();

  @override
  AutoFormatResult? apply(
      ParchmentDocument document, int position, String data) {
    // This rule applies to a space inserted after a YouTube URL, so we can ignore everything else.
    if (data != ' ') return null;

    final documentDelta = document.toDelta();
    final iter = DeltaIterator(documentDelta);
    final previous = iter.skip(position);
    // No previous operation means nothing to analyze.
    if (previous == null || previous.data is! String) return null;
    final previousText = previous.data as String;

    // Split text of previous operation in lines and words and take the last word to test.
    final candidate = previousText.split('\n').last.split(' ').last;
    final match = _youtubePattern.firstMatch(candidate);
    if (match == null) return null;

    final videoId = match.group(1);
    final url = 'https://www.youtube.com/watch?v=$videoId';
    final thumbUrl = 'https://img.youtube.com/vi/$videoId/0.jpg';

    final youtubeEmbedDelta = {
      '_type': 'youtube',
      '_inline': false,
      'url': url,
      'subtitles': 'English',
      'language': 'en',
      'thumbUrl': thumbUrl
    };

    final change = Delta()
      ..retain(position - candidate.length)
      ..delete(candidate.length + 1)
      ..insert('\n')
      ..insert(youtubeEmbedDelta)
      ..insert('\n');

    final undo = change.invert(documentDelta);
    document.compose(change, ChangeSource.local);

    return AutoFormatResult(
      change: change,
      undo: undo,
      undoPositionCandidate: position - candidate.length + 1,
      selection:
          TextSelection.collapsed(offset: position - candidate.length + 2),
      undoSelection: TextSelection.collapsed(offset: position),
    );
  }
}

/// This class formats our custom youtube embed. This is a very simply implementation.
/// But you should see how we can take this amazing places.

abstract class Embed {
  Widget build(BuildContext context, Map<String, dynamic> data);
  String get type;
}

class YoutubeEmbed implements Embed {
  @override
  Widget build(BuildContext context, Map<String, dynamic> data) {
    final url = data['url'];
    final thumbUrl = data['thumbUrl'];
    final subtitles = data['subtitles'];
    final language = data['language'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        children: [
          if (thumbUrl != null)
            Image.network(thumbUrl, width: 300, height: 169, fit: BoxFit.cover),
          Text(
            'Language: $language',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            'Subtitles: $subtitles',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          TextButton(
            onPressed: () => {}, // _launchUrl(url),
            child: Text('Watch on YouTube'),
          ),
        ],
      ),
    );
  }

  @override
  String get type => 'youtube';
}
