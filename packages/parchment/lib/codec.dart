// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Provides codecs to convert Parchment documents to other formats.
library parchment.codec;

import 'src/codecs/markdown.dart';
import 'src/codecs/html.dart';

export 'src/codecs/markdown.dart';
export 'src/codecs/html.dart';

/// Markdown codec for Parchment documents.
const parchmentMarkdown = ParchmentMarkdownCodec();

/// HTML codec for Parchment documents.
const parchmentHtml = ParchmentHtmlCodec();
