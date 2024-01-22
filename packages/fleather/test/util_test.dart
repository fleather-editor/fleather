import 'package:flutter_test/flutter_test.dart';
import 'package:fleather/util.dart';
import 'package:parchment_delta/parchment_delta.dart';

void main() {
  group('getPositionDelta', () {
    test('actual has more characters inserted than user', () {
      final user = Delta()
        ..retain(7)
        ..insert('a');
      final actual = Delta()
        ..retain(7)
        ..insert('\na');
      final result = getPositionDelta(user, actual);
      expect(result, 1);
    });

    test('actual has less characters inserted than user', () {
      final user = Delta()
        ..retain(7)
        ..insert('abc');
      final actual = Delta()
        ..retain(7)
        ..insert('ab');
      final result = getPositionDelta(user, actual);
      expect(result, -1);
    });

    test('actual has less characters deleted than user', () {
      final user = Delta()
        ..retain(7)
        ..delete(3);
      final actual = Delta()
        ..retain(7)
        ..delete(2);
      final result = getPositionDelta(user, actual);
      expect(result, 1);
    });
  });

  test('isDataOnlyNewLines', () {
    expect(isDataOnlyNewLines(123), false);
    expect(isDataOnlyNewLines(Object()), false);
    expect(isDataOnlyNewLines(''), false);
    expect(isDataOnlyNewLines('\nTest\nTest\n'), false);
    expect(isDataOnlyNewLines('\n \n\n'), false);
    expect(isDataOnlyNewLines('\n\t\n\n'), false);
    expect(isDataOnlyNewLines('\n\n\n'), true);
  });
}
