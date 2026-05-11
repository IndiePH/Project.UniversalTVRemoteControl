import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';
import 'package:one_remote/remote_control/domain/models/pin_format.dart';

void main() {
  group('CommandDispatchResult.success', () {
    test('isSuccess is true', () {
      final result = CommandDispatchResult.success('OK');
      expect(result.isSuccess, isTrue);
    });

    test('outcome is success', () {
      final result = CommandDispatchResult.success('OK');
      expect(result.getOutcome(), CommandOutcome.success);
    });

    test('message is preserved', () {
      final result = CommandDispatchResult.success('Sent: volumeUp');
      expect(result.message, 'Sent: volumeUp');
    });
  });

  group('CommandDispatchResult.unsupported', () {
    test('isSuccess is false', () {
      final result = CommandDispatchResult.unsupported('Not supported');
      expect(result.isSuccess, isFalse);
    });

    test('outcome is unsupported', () {
      final result = CommandDispatchResult.unsupported('Not supported');
      expect(result.getOutcome(), CommandOutcome.unsupported);
    });

    test('message is preserved', () {
      final result = CommandDispatchResult.unsupported('Command not available');
      expect(result.message, 'Command not available');
    });
  });

  group('CommandDispatchResult.failure', () {
    test('isSuccess is false', () {
      final result = CommandDispatchResult.failure('Something went wrong');
      expect(result.isSuccess, isFalse);
    });

    test('outcome is failure', () {
      final result = CommandDispatchResult.failure('Something went wrong');
      expect(result.getOutcome(), CommandOutcome.failure);
    });

    test('message is preserved', () {
      final result = CommandDispatchResult.failure('Transport error');
      expect(result.message, 'Transport error');
    });
  });

  group('CommandDispatchResult.compatibility', () {
    test('isSuccess is false', () {
      final result = CommandDispatchResult.compatibility('No focused text field');
      expect(result.isSuccess, isFalse);
    });

    test('outcome is compatibility', () {
      final result = CommandDispatchResult.compatibility('No focused text field');
      expect(result.getOutcome(), CommandOutcome.compatibility);
    });

    test('message is preserved', () {
      final result = CommandDispatchResult.compatibility('IME not ready');
      expect(result.message, 'IME not ready');
    });
  });

  group('CommandDispatchResult: outcome discriminates all four cases (R-11)', () {
    test('unsupported and failure have distinct outcomes', () {
      final unsupported = CommandDispatchResult.unsupported('not available');
      final failure = CommandDispatchResult.failure('transport error');

      expect(unsupported.getOutcome(), CommandOutcome.unsupported);
      expect(failure.getOutcome(), CommandOutcome.failure);
      expect(unsupported.getOutcome(), isNot(failure.getOutcome()));
    });
  });

  group('CommandDispatchResult.pinRequired', () {
    test('isPinRequired is true', () {
      final result = CommandDispatchResult.pinRequired('Enter PIN');
      expect(result.isPinRequired, isTrue);
    });

    test('isSuccess is false', () {
      final result = CommandDispatchResult.pinRequired('Enter PIN');
      expect(result.isSuccess, isFalse);
    });

    test('pinFormat defaults to fourDigitNumeric when not specified', () {
      final result = CommandDispatchResult.pinRequired('Enter PIN');
      expect(result.pinFormat, PinFormat.fourDigitNumeric);
    });

    test('pinFormat is sixCharHex when explicitly passed', () {
      final result = CommandDispatchResult.pinRequired(
        'Enter code',
        pinFormat: PinFormat.sixCharHex,
      );
      expect(result.pinFormat, PinFormat.sixCharHex);
    });

    test('message is preserved', () {
      final result = CommandDispatchResult.pinRequired('TV is showing a PIN');
      expect(result.message, 'TV is showing a PIN');
    });
  });
}
