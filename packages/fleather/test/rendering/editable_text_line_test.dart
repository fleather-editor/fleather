// ignore_for_file: use_full_hex_values_for_flutter_colors

import 'dart:ui';

import 'package:fleather/fleather.dart';
import 'package:fleather/src/rendering/editable_text_line.dart';
import 'package:fleather/src/rendering/paragraph_proxy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rendering_tools.dart';

void main() {
  TestRenderingFlutterBinding.ensureInitialized();
  group('$RenderEditableTextLine', () {
    test('Background color', () {
      final cursorController = CursorController(
          showCursor: ValueNotifier(false),
          style: const CursorStyle(
              color: Colors.blue, backgroundColor: Colors.blue),
          tickerProvider: FakeTickerProvider());
      final lineNode = LineNode()
        ..insert(0, 'some text', ParchmentStyle.fromJson({'bg': 0xffff0000}));
      final rootNode = RootNode();
      rootNode.addFirst(lineNode);
      final paintingContext = MockPaintingContext();
      final renderParagraph = RenderParagraph(const TextSpan(text: 'some text'),
          textDirection: TextDirection.ltr);
      final renderBox = RenderEditableTextLine(
          node: lineNode,
          padding: EdgeInsets.zero,
          textDirection: TextDirection.ltr,
          cursorController: cursorController,
          selection: const TextSelection.collapsed(offset: 0),
          selectionColor: Colors.blue,
          enableInteractiveSelection: false,
          hasFocus: false,
          inlineCodeTheme: InlineCodeThemeData(style: const TextStyle()));
      renderBox.body = RenderParagraphProxy(
          child: renderParagraph,
          textStyle: const TextStyle(),
          textScaleFactor: 1,
          textDirection: TextDirection.ltr,
          textWidthBasis: TextWidthBasis.parent);
      layout(renderBox);
      renderBox.paint(paintingContext, Offset.zero);
      expect(paintingContext.canvas.drawnRect, isNotNull);
      expect(paintingContext.canvas.drawnRect!.width, greaterThan(100));
      expect(paintingContext.canvas.drawnRect!.height, greaterThan(10));
      expect(paintingContext.canvas.drawnRectPaint!.style, PaintingStyle.fill);
      expect(paintingContext.canvas.drawnRectPaint!.color,
          const Color(0xffff0000));
    });

    test('inline code', () {
      final cursorController = CursorController(
          showCursor: ValueNotifier(false),
          style: const CursorStyle(
              color: Colors.blue, backgroundColor: Colors.blue),
          tickerProvider: FakeTickerProvider());
      final lineNode = LineNode()
        ..insert(0, 'some text', ParchmentStyle.fromJson({'c': true}));
      final rootNode = RootNode();
      rootNode.addFirst(lineNode);
      final paintingContext = MockPaintingContext();
      final renderParagraph = RenderParagraph(const TextSpan(text: 'some text'),
          textDirection: TextDirection.ltr);
      final renderBox = RenderEditableTextLine(
          node: lineNode,
          padding: EdgeInsets.zero,
          textDirection: TextDirection.ltr,
          cursorController: cursorController,
          selection: const TextSelection.collapsed(offset: 0),
          selectionColor: Colors.blue,
          enableInteractiveSelection: false,
          hasFocus: false,
          inlineCodeTheme: InlineCodeThemeData(
              style: const TextStyle(),
              backgroundColor: const Color(0xffff00000)));
      renderBox.body = RenderParagraphProxy(
          child: renderParagraph,
          textStyle: const TextStyle(),
          textScaleFactor: 1,
          textDirection: TextDirection.ltr,
          textWidthBasis: TextWidthBasis.parent);
      layout(renderBox);
      renderBox.paint(paintingContext, Offset.zero);
      expect(paintingContext.canvas.drawnRect, isNotNull);
      expect(paintingContext.canvas.drawnRect!.width, greaterThan(100));
      expect(paintingContext.canvas.drawnRect!.height, greaterThan(10));
      expect(paintingContext.canvas.drawnRectPaint!.style, PaintingStyle.fill);
      expect(paintingContext.canvas.drawnRectPaint!.color,
          const Color(0xffff00000));
    });
  });
}

class FakeTickerProvider extends Fake implements TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => FakeTicker();
}

class FakeTicker extends Fake implements Ticker {
  @override
  String toString({bool debugIncludeStack = false}) {
    return super.toString();
  }
}

class MockCanvas extends Fake implements Canvas {
  Rect? drawnRect;
  Paint? drawnRectPaint;

  @override
  void drawRect(Rect rect, Paint paint) {
    drawnRect = rect;
    drawnRectPaint = paint;
  }

  @override
  void drawParagraph(Paragraph paragraph, Offset offset) {}
}

class MockPaintingContext extends Fake implements PaintingContext {
  @override
  final MockCanvas canvas = MockCanvas();

  @override
  void paintChild(RenderObject child, Offset offset) {
    child.paint(this, offset);
  }
}
