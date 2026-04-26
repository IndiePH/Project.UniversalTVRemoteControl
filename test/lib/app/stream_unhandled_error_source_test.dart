import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/stream_unhandled_error_source.dart';
import 'package:one_remote/app/unhandled_error_source.dart';

void main() {
  group('StreamUnhandledErrorSource', () {
    test('implements UnhandledErrorSource', () {
      final source = StreamUnhandledErrorSource();
      expect(source, isA<UnhandledErrorSource>());
    });

    test('emits added errors on the stream', () async {
      final source = StreamUnhandledErrorSource();
      final error = Exception('boom');

      final received = <Object>[];
      final sub = source.errors.listen(received.add);
      source.add(error);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, [error]);
    });

    test('emits multiple errors in order', () async {
      final source = StreamUnhandledErrorSource();
      final e1 = Exception('first');
      final e2 = Exception('second');

      final received = <Object>[];
      final sub = source.errors.listen(received.add);
      source.add(e1);
      source.add(e2);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, [e1, e2]);
    });

    test('multiple subscribers each receive emitted errors', () async {
      final source = StreamUnhandledErrorSource();
      final error = Exception('shared');

      final a = <Object>[];
      final b = <Object>[];
      final subA = source.errors.listen(a.add);
      final subB = source.errors.listen(b.add);
      source.add(error);
      await Future<void>.delayed(Duration.zero);
      await subA.cancel();
      await subB.cancel();

      expect(a, [error]);
      expect(b, [error]);
    });

    test('add after controller is closed does not throw', () async {
      final source = StreamUnhandledErrorSource();
      await source.errors.listen((_) {}).cancel();
      // broadcast controllers don't close on cancel — this call should not throw
      expect(() => source.add(Exception('late')), returnsNormally);
    });
  });
}
