import 'dart:convert';

import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const FleatherApp());
}

class FleatherApp extends StatelessWidget {
  const FleatherApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
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
    _initController();
  }

  Future<void> _initController() async {
    try {
      final result = await rootBundle.loadString('assets/welcome.json');
      final doc = ParchmentDocument.fromJson(jsonDecode(result));
      _controller = FleatherController(doc);
    } catch (_) {
      _controller = FleatherController();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, title: Text('Fleather Demo')),
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
                  ),
                ),
              ],
            ),
    );
  }

  Widget _embedBuilder(BuildContext context, EmbedNode node) {
    if (node.value.type == 'hr') {
      final theme = FleatherTheme.of(context)!;
      return Divider(
        height: theme.paragraph.style.fontSize! * theme.paragraph.style.height!,
        thickness: 2,
        color: Colors.grey.shade200,
      );
    }
    if (node.value.type == 'icon') {
      final data = node.value.data;
      // Icons.rocket_launch_outlined
      return Icon(
        IconData(int.parse(data['codePoint']), fontFamily: data['fontFamily']),
        color: Color(int.parse(data['color'])),
        size: 18,
      );
    }
    if (node.value.type == 'image' &&
        node.value.data['source_type'] == 'assets') {
      return Image.asset(node.value.data['source']);
    }
    throw UnimplementedError();
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
