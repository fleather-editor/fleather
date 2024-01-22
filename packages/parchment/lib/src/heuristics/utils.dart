import '../document/embeds.dart';

bool isBlockEmbed(Object data) {
  if (data is EmbeddableObject) {
    return !data.inline;
  }
  if (data is Map) {
    return !data[EmbeddableObject.kInlineKey];
  }
  return false;
}
