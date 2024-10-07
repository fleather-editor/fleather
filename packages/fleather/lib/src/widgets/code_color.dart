import 'package:flutter/widgets.dart';
import 'package:highlight/highlight.dart' show highlight, Node;

/// use highlight to color the code
/// the default theme is github theme
class CodeColor {
  static const _rootKey = 'root';
  static const _defaultFontColor = Color(0xff000000);

  TextSpan textSpan(String source, bool isDark) {
    var theme = isDark ? vs2015Theme : githubTheme;
    var textStyle = TextStyle(
      color: theme[_rootKey]?.color ?? _defaultFontColor,
    );

    return TextSpan(
      style: textStyle,
      children:
          _convert(highlight.parse(source, language: 'java').nodes!, theme),
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

const vs2015Theme = {
  'root':
      TextStyle(backgroundColor: Color(0xff1E1E1E), color: Color(0xffDCDCDC)),
  'keyword': TextStyle(color: Color(0xff569CD6)),
  'literal': TextStyle(color: Color(0xff569CD6)),
  'symbol': TextStyle(color: Color(0xff569CD6)),
  'name': TextStyle(color: Color(0xff569CD6)),
  'link': TextStyle(color: Color(0xff569CD6)),
  'built_in': TextStyle(color: Color(0xff4EC9B0)),
  'type': TextStyle(color: Color(0xff4EC9B0)),
  'number': TextStyle(color: Color(0xffB8D7A3)),
  'class': TextStyle(color: Color(0xffB8D7A3)),
  'string': TextStyle(color: Color(0xffD69D85)),
  'meta-string': TextStyle(color: Color(0xffD69D85)),
  'regexp': TextStyle(color: Color(0xff9A5334)),
  'template-tag': TextStyle(color: Color(0xff9A5334)),
  'subst': TextStyle(color: Color(0xffDCDCDC)),
  'function': TextStyle(color: Color(0xffDCDCDC)),
  'title': TextStyle(color: Color(0xffDCDCDC)),
  'params': TextStyle(color: Color(0xffDCDCDC)),
  'formula': TextStyle(color: Color(0xffDCDCDC)),
  'comment': TextStyle(color: Color(0xff57A64A), fontStyle: FontStyle.italic),
  'quote': TextStyle(color: Color(0xff57A64A), fontStyle: FontStyle.italic),
  'doctag': TextStyle(color: Color(0xff608B4E)),
  'meta': TextStyle(color: Color(0xff9B9B9B)),
  'meta-keyword': TextStyle(color: Color(0xff9B9B9B)),
  'tag': TextStyle(color: Color(0xff9B9B9B)),
  'variable': TextStyle(color: Color(0xffBD63C5)),
  'template-variable': TextStyle(color: Color(0xffBD63C5)),
  'attr': TextStyle(color: Color(0xff9CDCFE)),
  'attribute': TextStyle(color: Color(0xff9CDCFE)),
  'builtin-name': TextStyle(color: Color(0xff9CDCFE)),
  'section': TextStyle(color: Color(0xffffd700)),
  'emphasis': TextStyle(fontStyle: FontStyle.italic),
  'strong': TextStyle(fontWeight: FontWeight.bold),
  'bullet': TextStyle(color: Color(0xffD7BA7D)),
  'selector-tag': TextStyle(color: Color(0xffD7BA7D)),
  'selector-id': TextStyle(color: Color(0xffD7BA7D)),
  'selector-class': TextStyle(color: Color(0xffD7BA7D)),
  'selector-attr': TextStyle(color: Color(0xffD7BA7D)),
  'selector-pseudo': TextStyle(color: Color(0xffD7BA7D)),
  'addition': TextStyle(backgroundColor: Color(0xff144212)),
  'deletion': TextStyle(backgroundColor: Color(0xff660000)),
};

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
