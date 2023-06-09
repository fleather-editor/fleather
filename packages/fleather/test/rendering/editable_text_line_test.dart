// ignore_for_file: use_full_hex_values_for_flutter_colors

import 'dart:async';
import 'dart:ui';

import 'package:fleather/fleather.dart';
import 'package:fleather/src/rendering/editable_text_line.dart';
import 'package:fleather/src/rendering/paragraph_proxy.dart';
import 'package:fleather/src/widgets/editable_text_line.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestRenderingFlutterBinding.ensureInitialized();
  group('$EditableTextLine', () {
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

class TestRenderingFlutterBinding extends BindingBase
    with
        SchedulerBinding,
        ServicesBinding,
        GestureBinding,
        PaintingBinding,
        SemanticsBinding,
        RendererBinding,
        TestDefaultBinaryMessengerBinding {
  /// Creates a binding for testing rendering library functionality.
  ///
  /// If [onErrors] is not null, it is called if [FlutterError] caught any errors
  /// while drawing the frame. If [onErrors] is null and [FlutterError] caught at least
  /// one error, this function fails the test. A test may override [onErrors] and
  /// inspect errors using [takeFlutterErrorDetails].
  ///
  /// Errors caught between frames will cause the test to fail unless
  /// [FlutterError.onError] has been overridden.
  TestRenderingFlutterBinding({this.onErrors}) {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
      Zone.current.parent!
          .handleUncaughtError(details.exception, details.stack!);
    };
  }

  /// The current [TestRenderingFlutterBinding], if one has been created.
  ///
  /// Provides access to the features exposed by this binding. The binding must
  /// be initialized before using this getter; this is typically done by calling
  /// [TestRenderingFlutterBinding.ensureInitialized].
  static TestRenderingFlutterBinding get instance =>
      BindingBase.checkInstance(_instance);
  static TestRenderingFlutterBinding? _instance;

  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
  }

  /// Creates and initializes the binding. This function is
  /// idempotent; calling it a second time will just return the
  /// previously-created instance.
  static TestRenderingFlutterBinding ensureInitialized(
      {VoidCallback? onErrors}) {
    if (_instance != null) {
      return _instance!;
    }
    return TestRenderingFlutterBinding(onErrors: onErrors);
  }

  final List<FlutterErrorDetails> _errors = <FlutterErrorDetails>[];

  /// A function called after drawing a frame if [FlutterError] caught any errors.
  ///
  /// This function is expected to inspect these errors and decide whether they
  /// are expected or not. Use [takeFlutterErrorDetails] to take one error at a
  /// time, or [takeAllFlutterErrorDetails] to iterate over all errors.
  VoidCallback? onErrors;

  /// Returns the error least recently caught by [FlutterError] and removes it
  /// from the list of captured errors.
  ///
  /// Returns null if no errors were captures, or if the list was exhausted by
  /// calling this method repeatedly.
  FlutterErrorDetails? takeFlutterErrorDetails() {
    if (_errors.isEmpty) {
      return null;
    }
    return _errors.removeAt(0);
  }

  /// Returns all error details caught by [FlutterError] from least recently caught to
  /// most recently caught, and removes them from the list of captured errors.
  ///
  /// The returned iterable takes errors lazily. If, for example, you iterate over 2
  /// errors, but there are 5 errors total, this binding will still fail the test.
  /// Tests are expected to take and inspect all errors.
  Iterable<FlutterErrorDetails> takeAllFlutterErrorDetails() sync* {
    // sync* and yield are used for lazy evaluation. Otherwise, the list would be
    // drained eagerly and allow a test pass with unexpected errors.
    while (_errors.isNotEmpty) {
      yield _errors.removeAt(0);
    }
  }

  /// Returns all exceptions caught by [FlutterError] from least recently caught to
  /// most recently caught, and removes them from the list of captured errors.
  ///
  /// The returned iterable takes errors lazily. If, for example, you iterate over 2
  /// errors, but there are 5 errors total, this binding will still fail the test.
  /// Tests are expected to take and inspect all errors.
  Iterable<dynamic> takeAllFlutterExceptions() sync* {
    // sync* and yield are used for lazy evaluation. Otherwise, the list would be
    // drained eagerly and allow a test pass with unexpected errors.
    while (_errors.isNotEmpty) {
      yield _errors.removeAt(0).exception;
    }
  }

  EnginePhase phase = EnginePhase.composite;

  /// Pumps a frame and runs its entire life cycle.
  ///
  /// This method runs all of the [SchedulerPhase]s in a frame, this is useful
  /// to test [SchedulerPhase.postFrameCallbacks].
  void pumpCompleteFrame() {
    final FlutterExceptionHandler? oldErrorHandler = FlutterError.onError;
    FlutterError.onError = _errors.add;
    try {
      TestRenderingFlutterBinding.instance.handleBeginFrame(null);
      TestRenderingFlutterBinding.instance.handleDrawFrame();
    } finally {
      FlutterError.onError = oldErrorHandler;
      if (_errors.isNotEmpty) {
        if (onErrors != null) {
          onErrors!();
          if (_errors.isNotEmpty) {
            _errors.forEach(FlutterError.dumpErrorToConsole);
            fail(
                'There are more errors than the test inspected using TestRenderingFlutterBinding.takeFlutterErrorDetails.');
          }
        } else {
          _errors.forEach(FlutterError.dumpErrorToConsole);
          fail(
              'Caught error while rendering frame. See preceding logs for details.');
        }
      }
    }
  }

  @override
  void drawFrame() {
    assert(phase != EnginePhase.build,
        'rendering_tester does not support testing the build phase; use flutter_test instead');
    final FlutterExceptionHandler? oldErrorHandler = FlutterError.onError;
    FlutterError.onError = _errors.add;
    try {
      pipelineOwner.flushLayout();
      if (phase == EnginePhase.layout) {
        return;
      }
      pipelineOwner.flushCompositingBits();
      if (phase == EnginePhase.compositingBits) {
        return;
      }
      pipelineOwner.flushPaint();
      if (phase == EnginePhase.paint) {
        return;
      }
      renderView.compositeFrame();
      if (phase == EnginePhase.composite) {
        return;
      }
      pipelineOwner.flushSemantics();
      if (phase == EnginePhase.flushSemantics) {
        return;
      }
      assert(phase == EnginePhase.flushSemantics ||
          phase == EnginePhase.sendSemanticsUpdate);
    } finally {
      FlutterError.onError = oldErrorHandler;
      if (_errors.isNotEmpty) {
        if (onErrors != null) {
          onErrors!();
          if (_errors.isNotEmpty) {
            _errors.forEach(FlutterError.dumpErrorToConsole);
            fail(
                'There are more errors than the test inspected using TestRenderingFlutterBinding.takeFlutterErrorDetails.');
          }
        } else {
          _errors.forEach(FlutterError.dumpErrorToConsole);
          fail(
              'Caught error while rendering frame. See preceding logs for details.');
        }
      }
    }
  }
}

void layout(
  RenderBox box, {
  // If you want to just repump the last box, call pumpFrame().
  BoxConstraints? constraints,
  Alignment alignment = Alignment.center,
  EnginePhase phase = EnginePhase.layout,
  VoidCallback? onErrors,
}) {
  assert(box.parent ==
      null); // We stick the box in another, so you can't reuse it easily, sorry.

  TestRenderingFlutterBinding.instance.renderView.child = null;
  if (constraints != null) {
    box = RenderPositionedBox(
      alignment: alignment,
      child: RenderConstrainedBox(
        additionalConstraints: constraints,
        child: box,
      ),
    );
  }
  TestRenderingFlutterBinding.instance.renderView.child = box;

  pumpFrame(phase: phase, onErrors: onErrors);
}

/// Pumps a single frame.
///
/// If `onErrors` is not null, it is set as [TestRenderingFlutterBinding.onError].
void pumpFrame(
    {EnginePhase phase = EnginePhase.layout, VoidCallback? onErrors}) {
  assert(TestRenderingFlutterBinding.instance.renderView.child !=
      null); // call layout() first!

  if (onErrors != null) {
    TestRenderingFlutterBinding.instance.onErrors = onErrors;
  }

  TestRenderingFlutterBinding.instance.phase = phase;
  TestRenderingFlutterBinding.instance.drawFrame();
}
