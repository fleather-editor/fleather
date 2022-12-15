// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Provides codecs to convert Parchment documents to other formats.
library parchment.convert;

import 'src/convert/markdown.dart';
import 'src/convert/html.dart';

export 'src/convert/markdown.dart';
export 'src/convert/html.dart';

/// Markdown codec for Parchment documents.
const ParchmentMarkdownCodec parchmentMarkdown = ParchmentMarkdownCodec();

/// HTML codec for Parchment documents.
const ParchmentHtmlCodec parchmentHtml = ParchmentHtmlCodec();
