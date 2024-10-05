import 'package:flutter/widgets.dart';
import 'package:highlight/highlight.dart' show highlight, Node;

/// use highlight to color the code
/// the default theme is github theme
class CodeColor {
  static const _rootKey = 'root';
  static const _defaultFontColor = Color(0xff000000);

  TextSpan textSpan(String source) {
    var theme = githubTheme;
    var textStyle = TextStyle(
      color: theme[_rootKey]?.color ?? _defaultFontColor,
    );

    return TextSpan(
      style: textStyle,
      children:
          _convert(highlight.parse(source, language: 'dart').nodes!, theme),
    );
  }

  List<TextSpan> _convert(List<Node> nodes, Map<String, TextStyle> theme) {
    List<TextSpan> spans = [];
    var currentSpans = spans;
    List<List<TextSpan>> stack = [];

    void traverse(Node node) {
      if (node.value != null) {
        currentSpans.add(node.className == null
            ? TextSpan(text: node.value)
            : TextSpan(text: node.value, style: theme[node.className!]));
      } else if (node.children != null) {
        List<TextSpan> tmp = [];
        currentSpans
            .add(TextSpan(children: tmp, style: theme[node.className!]));
        stack.add(currentSpans);
        currentSpans = tmp;

        for (var n in node.children!) {
          traverse(n);
          if (n == node.children!.last) {
            currentSpans = stack.isEmpty ? spans : stack.removeLast();
          }
        }
      }
    }

    for (var node in nodes) {
      traverse(node);
    }

    return spans;
  }
}

const githubTheme = {
  'root':
      TextStyle(color: Color(0xff333333), backgroundColor: Color(0xfff8f8f8)),
  'comment': TextStyle(color: Color(0xff999988), fontStyle: FontStyle.italic),
  'quote': TextStyle(color: Color(0xff999988), fontStyle: FontStyle.italic),
  'keyword': TextStyle(color: Color(0xff333333), fontWeight: FontWeight.bold),
  'selector-tag':
      TextStyle(color: Color(0xff333333), fontWeight: FontWeight.bold),
  'subst': TextStyle(color: Color(0xff333333), fontWeight: FontWeight.normal),
  'number': TextStyle(color: Color(0xff008080)),
  'literal': TextStyle(color: Color(0xff008080)),
  'variable': TextStyle(color: Color(0xff008080)),
  'template-variable': TextStyle(color: Color(0xff008080)),
  'string': TextStyle(color: Color(0xffdd1144)),
  'doctag': TextStyle(color: Color(0xffdd1144)),
  'title': TextStyle(color: Color(0xff990000), fontWeight: FontWeight.bold),
  'section': TextStyle(color: Color(0xff990000), fontWeight: FontWeight.bold),
  'selector-id':
      TextStyle(color: Color(0xff990000), fontWeight: FontWeight.bold),
  'type': TextStyle(color: Color(0xff445588), fontWeight: FontWeight.bold),
  'tag': TextStyle(color: Color(0xff000080), fontWeight: FontWeight.normal),
  'name': TextStyle(color: Color(0xff000080), fontWeight: FontWeight.normal),
  'attribute':
      TextStyle(color: Color(0xff000080), fontWeight: FontWeight.normal),
  'regexp': TextStyle(color: Color(0xff009926)),
  'link': TextStyle(color: Color(0xff009926)),
  'symbol': TextStyle(color: Color(0xff990073)),
  'bullet': TextStyle(color: Color(0xff990073)),
  'built_in': TextStyle(color: Color(0xff0086b3)),
  'builtin-name': TextStyle(color: Color(0xff0086b3)),
  'meta': TextStyle(color: Color(0xff999999), fontWeight: FontWeight.bold),
  'deletion': TextStyle(backgroundColor: Color(0xffffdddd)),
  'addition': TextStyle(backgroundColor: Color(0xffddffdd)),
  'emphasis': TextStyle(fontStyle: FontStyle.italic),
  'strong': TextStyle(fontWeight: FontWeight.bold),
};
