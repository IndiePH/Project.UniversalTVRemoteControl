import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/utils/two_digit_format.dart';

void main() {
  group('formatTwoDigits', () {
    test('single-digit value is padded to 2 characters', () {
      expect(formatTwoDigits(3), '03');
    });

    test('zero is padded to 2 characters', () {
      expect(formatTwoDigits(0), '00');
    });

    test('double-digit value is unchanged', () {
      expect(formatTwoDigits(12), '12');
    });

    test('value >= 10 is not padded', () {
      expect(formatTwoDigits(10), '10');
    });

    test('value 9 is padded', () {
      expect(formatTwoDigits(9), '09');
    });

    test('value 1 is padded', () {
      expect(formatTwoDigits(1), '01');
    });

    test('larger values are returned as-is', () {
      expect(formatTwoDigits(59), '59');
      expect(formatTwoDigits(100), '100');
    });
  });
}
