import 'package:fleather/src/widgets/history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_delta/quill_delta.dart';

void main() {
  group('History stack', () {
    late HistoryStack stack;

    setUp(() {
      stack = HistoryStack(Delta()..insert('Hello\n'));
    });

    group('empty stack', () {
      test('undo returns null', () {
        expect(stack.undo(), isNull);
      });

      test('redo returns null', () {
        expect(stack.redo(), isNull);
      });
    });

    test('undoes twice', () {
      final change = Delta()..insert('Hello world\n');
      final otherChange = Delta()..insert('Hello world ok\n');
      final exp = Delta()
        ..retain(5)
        ..delete(6);
      final expOther = Delta()
        ..retain(11)
        ..delete(3);
      stack.push(change);
      stack.push(otherChange);
      var act = stack.undo();
      expect(act, expOther);
      act = stack.undo();
      expect(act, exp);
    });

    test('undoes too many times', () {
      final change = Delta()..insert('Hello world\n');
      stack.push(change);
      var act = stack.undo();
      expect(act, isNotNull);
      act = stack.undo();
      expect(act, isNull);
    });

    test('redoes twice', () {
      final change = Delta()..insert('Hello world\n');
      final otherChange = Delta()..insert('Hello world ok\n');
      final exp = Delta()
        ..retain(5)
        ..insert(' world');
      final expOther = Delta()
        ..retain(11)
        ..insert(' ok');
      stack.push(change);
      stack.push(otherChange);
      stack.undo();
      stack.undo();
      var act = stack.redo();
      expect(act, exp);
      act = stack.redo();
      expect(act, expOther);
    });

    test('redoes too many times', () {
      final change = Delta()..insert('Hello world\n');
      stack.push(change);
      stack.undo();
      var act = stack.redo();
      expect(act, isNotNull);
      act = stack.redo();
      expect(act, isNull);
    });

    test('pushes new items while index is at start', () {
      final change = Delta()..insert('Hello world\n');
      stack.push(change);
      expect(stack.undo(), isNotNull);
      stack.push(change);
      expect(stack.redo(), isNull);
    });

    test('undoing formatting', () {
      final change = Delta()
        ..insert('Hello', {'b': true})
        ..insert('\n');
      stack.push(change);
      var act = stack.undo();
      expect(act, Delta()..retain(5, {'b': null}));
    });

    test('Delta', () {
      final base = Delta()..insert('Hello\n');
      final inc = Delta()..retain(5, {'b': true});
      expect(inc.invert(base), Delta()..retain(5, {'b': null}));
    });
  });
}
