import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';

void main() {
  group('CommandDispatchResult.success', () {
    test('isSuccess is true', () {
      const result = CommandDispatchResult.success('OK');
      expect(result.isSuccess, isTrue);
    });

    test('outcome is success', () {
      const result = CommandDispatchResult.success('OK');
      expect(result.outcome, CommandOutcome.success);
    });

    test('message is preserved', () {
      const result = CommandDispatchResult.success('Sent: volumeUp');
      expect(result.message, 'Sent: volumeUp');
    });
  });

  group('CommandDispatchResult.unsupported', () {
    test('isSuccess is false', () {
      const result = CommandDispatchResult.unsupported('Not supported');
      expect(result.isSuccess, isFalse);
    });

    test('outcome is unsupported', () {
      const result = CommandDispatchResult.unsupported('Not supported');
      expect(result.outcome, CommandOutcome.unsupported);
    });

    test('message is preserved', () {
      const result = CommandDispatchResult.unsupported('Command not available');
      expect(result.message, 'Command not available');
    });
  });

  group('CommandDispatchResult.failure', () {
    test('isSuccess is false', () {
      const result = CommandDispatchResult.failure('Something went wrong');
      expect(result.isSuccess, isFalse);
    });

    test('outcome is failure', () {
      const result = CommandDispatchResult.failure('Something went wrong');
      expect(result.outcome, CommandOutcome.failure);
    });

    test('message is preserved', () {
      const result = CommandDispatchResult.failure('Transport error');
      expect(result.message, 'Transport error');
    });
  });

  group('CommandDispatchResult.compatibility', () {
    test('isSuccess is false', () {
      const result = CommandDispatchResult.compatibility('No focused text field');
      expect(result.isSuccess, isFalse);
    });

    test('outcome is compatibility', () {
      const result = CommandDispatchResult.compatibility('No focused text field');
      expect(result.outcome, CommandOutcome.compatibility);
    });

    test('message is preserved', () {
      const result = CommandDispatchResult.compatibility('IME not ready');
      expect(result.message, 'IME not ready');
    });
  });

  group('CommandDispatchResult: outcome discriminates all four cases (R-11)', () {
    test('unsupported and failure have distinct outcomes', () {
      const unsupported = CommandDispatchResult.unsupported('not available');
      const failure = CommandDispatchResult.failure('transport error');

      expect(unsupported.outcome, CommandOutcome.unsupported);
      expect(failure.outcome, CommandOutcome.failure);
      expect(unsupported.outcome, isNot(failure.outcome));
    });
  });
}
