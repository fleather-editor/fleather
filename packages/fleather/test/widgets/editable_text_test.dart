// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../testing.dart';

void main() {
  group('FleatherEditableText', () {
    testWidgets('user input', (tester) async {
      final editor = EditorSandBox(tester: tester);
      await editor.pumpAndTap();
      final currentValue = editor.document.toPlainText();
      await enterText(tester, 'Added ', oldText: currentValue);
      expect(editor.document.toPlainText(), 'Added This House Is A Circus\n');
    });

    testWidgets('autofocus', (tester) async {
      final editor = EditorSandBox(tester: tester, autofocus: true);
      await editor.pump();
      expect(editor.focusNode.hasFocus, isTrue);
    });

    testWidgets('no autofocus', (tester) async {
      final editor = EditorSandBox(tester: tester);
      await editor.pump();
      expect(editor.focusNode.hasFocus, isFalse);
    });
  });
}

Future<void> enterText(WidgetTester tester, String textInserted,
    {String oldText = '', int atOffset = 0}) async {
  return TestAsyncUtils.guard(() async {
    updateDeltaEditingValue(TextEditingDeltaInsertion(
        oldText: oldText,
        textInserted: textInserted,
        insertionOffset: atOffset,
        selection: const TextSelection.collapsed(offset: 0),
        composing: TextRange.empty));
    await tester.idle();
  });
}

void updateDeltaEditingValue(TextEditingDelta delta, {int? client}) {
  TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
      .handlePlatformMessage(
    SystemChannels.textInput.name,
    SystemChannels.textInput.codec.encodeMethodCall(
      MethodCall(
        'TextInputClient.updateEditingStateWithDeltas',
        <dynamic>[
          client ?? -1,
          {
            'deltas': [delta.toJSON()]
          }
        ],
      ),
    ),
    (ByteData? data) {
      /* ignored */
    },
  );
}

extension DeltaJson on TextEditingDelta {
  Map<String, dynamic> toJSON() {
    final json = <String, dynamic>{};
    json['composingBase'] = composing.start;
    json['composingExtent'] = composing.end;

    json['selectionBase'] = selection.baseOffset;
    json['selectionExtent'] = selection.extentOffset;
    json['selectionAffinity'] = selection.affinity.name;
    json['selectionIsDirectional'] = selection.isDirectional;

    json['oldText'] = oldText;
    if (this is TextEditingDeltaInsertion) {
      final insertion = this as TextEditingDeltaInsertion;
      json['deltaStart'] = insertion.insertionOffset;
      // Assumes no replacement, simply insertion here
      json['deltaEnd'] = insertion.insertionOffset;
      json['deltaText'] = insertion.textInserted;
    }
    return json;
  }
}
