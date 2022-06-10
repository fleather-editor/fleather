import 'package:flutter/material.dart';
import 'package:fleather/fleather.dart';

import 'scaffold.dart';

class DecoratedFieldDemo extends StatefulWidget {
  const DecoratedFieldDemo({Key key}) : super(key: key);

  @override
  _DecoratedFieldDemoState createState() => _DecoratedFieldDemoState();
}

class _DecoratedFieldDemoState extends State<DecoratedFieldDemo> {
  final FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      documentFilename: 'decorated_field.note',
      builder: _buildContent,
      showToolbar: false,
    );
  }

  Widget _buildContent(BuildContext context, FleatherController controller) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: <Widget>[
          const TextField(
            decoration: InputDecoration(labelText: 'Title'),
          ),
          FleatherField(
            controller: controller,
            focusNode: _focusNode,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.only(top: 8.0),
              labelText: 'Description',
              hintText: 'Detailed description, but not too detailed',
            ),
            toolbar: FleatherToolbar.basic(controller: controller),
            // minHeight: 80.0,
            // maxHeight: 160.0,
          ),
          const TextField(
            decoration: InputDecoration(labelText: 'Final thoughts'),
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
