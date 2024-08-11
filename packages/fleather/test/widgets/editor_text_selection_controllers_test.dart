import 'dart:math' as math;

import 'package:fleather/fleather.dart';
import 'package:fleather/src/widgets/editor_input_client_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../testing.dart';

class MyTextSelectionHandle extends StatefulWidget {
  final Size size;
  const MyTextSelectionHandle(
      {super.key, required this.size});

  @override
  State<StatefulWidget> createState() {
    return MyTextSelectionHandleState();
  }
}

class MyTextSelectionHandleState
    extends State<MyTextSelectionHandle> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size.width,
      height: widget.size.height,
      color: Colors.red,
    );
  }
}

class MyTextSelectionControllers
    extends MaterialTextSelectionControls {
  final Size size;
  MyTextSelectionControllers(this.size);

  @override
  Widget buildHandle(BuildContext context,
      TextSelectionHandleType type, double textHeight,
      [VoidCallback? onTap]) {
    final Widget handle = MyTextSelectionHandle(
      size: size,
    );

    return switch (type) {
      TextSelectionHandleType.left => Transform.rotate(
          angle: math.pi / 2.0,
          child: handle), // points up-right
      TextSelectionHandleType.right =>
        handle, // points up-left
      TextSelectionHandleType.collapsed => Transform.rotate(
          angle: math.pi / 4.0, child: handle), // points up
    };
  }
}

void main() {
  group('CustomTextSelectionControllers', () { 
 
    testWidgets('set customTextSelectionControllers',
        (tester) async { 
      final document = ParchmentDocument.fromJson([
        {'insert': 'some text\n'}
      ]);
      FleatherController controller =
          FleatherController(document: document);
      FocusNode focusNode = FocusNode();
      final Size testSize = Size(230, 5);
      final editor = MaterialApp(
        home: FleatherEditor(
            controller: controller,
            focusNode: focusNode,
            textSelectionControls:
                MyTextSelectionControllers(testSize)),
      ); 
      await tester.pumpWidget(editor);
      await tester.tap(find.byType(RawEditor).first);
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isTrue);
      tester.binding.scheduleWarmUpFrame();
      final handleState =
          tester.state(find.byType(MyTextSelectionHandle))
              as MyTextSelectionHandleState;
      expect(handleState.context.size, testSize);
    });
  });
}
