import 'package:flutter/widgets.dart';

import '../rendering/embed_proxy.dart';

class EmbedProxy extends SingleChildRenderObjectWidget {
  const EmbedProxy({
    super.key,
    required Widget super.child,
  });

  @override
  RenderEmbedProxy createRenderObject(BuildContext context) {
    return RenderEmbedProxy();
  }
}
