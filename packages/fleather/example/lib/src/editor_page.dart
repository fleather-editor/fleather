import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:quill_delta/quill_delta.dart';
import 'package:fleather/fleather.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({Key key}) : super(key: key);

  @override
  EditorPageState createState() => EditorPageState();
}

class EditorPageState extends State<EditorPage> {
  /// Allows to control the editor and the document.
  FleatherController _controller;

  /// Fleather editor like any other input field requires a focus node.
  FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _loadDocument().then((document) {
      setState(() {
        _controller = FleatherController(document);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = (_controller == null)
        ? const Center(child: CircularProgressIndicator())
        : FleatherField(
            padding: const EdgeInsets.all(16),
            controller: _controller,
            focusNode: _focusNode,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor page'),
        actions: <Widget>[
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.save),
              onPressed: () => _saveDocument(context),
            ),
          )
        ],
      ),
      body: body,
    );
  }

  /// Loads the document asynchronously from a file if it exists, otherwise
  /// returns default document.
  Future<ParchmentDocument> _loadDocument() async {
    final file = File(Directory.systemTemp.path + '/quick_start.json');
    if (await file.exists()) {
      final contents = await file.readAsString().then(
          (data) => Future.delayed(const Duration(seconds: 1), () => data));
      return ParchmentDocument.fromJson(jsonDecode(contents));
    }
    final delta = Delta()..insert('Fleather Quick Start\n');
    return ParchmentDocument()..compose(delta, ChangeSource.local);
  }

  void _saveDocument(BuildContext context) {
    // Fleather documents can be easily serialized to JSON by passing to
    // `jsonEncode` directly:
    final contents = jsonEncode(_controller.document);
    // For this example we save our document to a temporary file.
    final file = File(Directory.systemTemp.path + '/quick_start.json');
    // And show a snack bar on success.
    file.writeAsString(contents).then((_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved.')));
    });
  }
}
