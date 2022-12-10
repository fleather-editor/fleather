import 'package:flutter/widgets.dart';

import '../rendering/embed_proxy.dart';

class EmbedProxy extends SingleChildRenderObjectWidget {
  const EmbedProxy({
    Key? key,
    required Widget child,
  }) : super(key: key, child: child);

  @override
  RenderEmbedProxy createRenderObject(BuildContext context) {
    return RenderEmbedProxy();
  }
}

/// Render children in a horizontal list. Uses Flutter's [Flex] behind the scenes.
class GroupEmbedProxy extends MultiChildRenderObjectWidget {
  GroupEmbedProxy({
    Key? key,
    required List<Widget> children,
  }) : super(key: key, children: children);

  TextDirection? getEffectiveTextDirection(BuildContext context) {
    return Directionality.maybeOf(context);
  }

  @override
  RenderGroupEmbedProxy createRenderObject(BuildContext context) {
    return RenderGroupEmbedProxy(
      textDirection: getEffectiveTextDirection(context),
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderGroupEmbedProxy renderObject) {
    renderObject.textDirection = getEffectiveTextDirection(context);
  }
}
