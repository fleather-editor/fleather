// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:flutter/material.dart';

import 'src/home.dart';

void main() {
  runApp(const FleatherApp());
}

class FleatherApp extends StatelessWidget {
  const FleatherApp({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fleather - rich-text editor for Flutter',
      home: HomePage(),
    );
  }
}
