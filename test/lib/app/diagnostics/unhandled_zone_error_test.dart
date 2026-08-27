import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/diagnostics/unhandled_zone_error.dart';

void main() {
  group('UnhandledZoneError.isFatal', () {
    test('LAN connection reset by peer is not a fatal Crashlytics crash', () {
      final error = SocketException(
        'Connection reset by peer (OS Error: Connection reset by peer, errno = 104)',
        osError: const OSError('Connection reset by peer', 104),
        address: InternetAddress('192.168.254.102'),
        port: 48688,
      );

      expect(UnhandledZoneError.isFatal(error), isFalse);
    });

    test('unexpected application errors remain fatal', () {
      expect(UnhandledZoneError.isFatal(StateError('bug')), isTrue);
    });
  });
}
