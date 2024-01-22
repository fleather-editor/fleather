/// Provides codecs to convert Parchment documents to other formats.
library parchment.codecs;

import 'src/codecs/markdown.dart';
import 'src/codecs/html.dart';

export 'src/codecs/markdown.dart';
export 'src/codecs/html.dart';

/// Markdown codec for Parchment documents.
const parchmentMarkdown = ParchmentMarkdownCodec();

/// HTML codec for Parchment documents.
const parchmentHtml = ParchmentHtmlCodec();
