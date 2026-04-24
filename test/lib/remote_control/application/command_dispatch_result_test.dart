import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/command_dispatch_result.dart';

void main() {
  group('CommandDispatchResult.success', () {
    test('isSuccess is true', () {
      const result = CommandDispatchResult.success('OK');
      expect(result.isSuccess, isTrue);
    });

    test('isCompatibilityIssue is false', () {
      const result = CommandDispatchResult.success('OK');
      expect(result.isCompatibilityIssue, isFalse);
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

    test('isCompatibilityIssue is false', () {
      const result = CommandDispatchResult.unsupported('Not supported');
      expect(result.isCompatibilityIssue, isFalse);
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

    test('isCompatibilityIssue is false', () {
      const result = CommandDispatchResult.failure('Something went wrong');
      expect(result.isCompatibilityIssue, isFalse);
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

    test('isCompatibilityIssue is true', () {
      const result = CommandDispatchResult.compatibility('No focused text field');
      expect(result.isCompatibilityIssue, isTrue);
    });

    test('message is preserved', () {
      const result = CommandDispatchResult.compatibility('IME not ready');
      expect(result.message, 'IME not ready');
    });
  });

  group('CommandDispatchResult: current ambiguity (R-11)', () {
    // Documents the known design gap: unsupported and failure are
    // programmatically indistinguishable by flags. R-11 (task 2.13) will
    // introduce a CommandOutcome discriminator to resolve this.
    test('unsupported and failure share the same flag values', () {
      const unsupported = CommandDispatchResult.unsupported('not available');
      const failure = CommandDispatchResult.failure('transport error');

      expect(unsupported.isSuccess, equals(failure.isSuccess));
      expect(unsupported.isCompatibilityIssue, equals(failure.isCompatibilityIssue));
    });
  });
}
