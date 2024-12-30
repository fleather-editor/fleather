/// Provides codecs to convert Parchment documents to other formats.
library;

import 'src/codecs/html.dart';
import 'src/codecs/markdown.dart';

export 'src/codecs/html.dart';
export 'src/codecs/markdown.dart';

/// Markdown codec for Parchment documents.
const parchmentMarkdown = ParchmentMarkdownCodec();

/// Not strict markdown codec for Parchment documents.
const parchmentMarkdownNotStrict =
    ParchmentMarkdownCodec(strictEncoding: false);

/// HTML codec for Parchment documents.
const parchmentHtml = ParchmentHtmlCodec();
