import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/lg/lg_message_builder.dart';

void main() {
  group('buildLgSsapRequest', () {
    test('produces correct SSAP request shape', () {
      final msg = buildLgSsapRequest(
        requestId: 'req_1',
        uri: 'ssap://audio/volume/up',
        payload: const {},
      );
      expect(msg['type'], 'request');
      expect(msg['id'], 'req_1');
      expect(msg['uri'], 'ssap://audio/volume/up');
      expect(msg['payload'], isEmpty);
    });

    test('includes payload fields when provided', () {
      final msg = buildLgSsapRequest(
        requestId: 'req_2',
        uri: 'ssap://com.webos.appmanager/launch',
        payload: const {'id': 'netflix'},
      );
      expect(msg['payload'], containsPair('id', 'netflix'));
    });

    test('request IDs are preserved verbatim', () {
      final msg = buildLgSsapRequest(
        requestId: 'ptr_42',
        uri: 'ssap://com.webos.service.networkinput/getPointerInputSocket',
        payload: const {},
      );
      expect(msg['id'], 'ptr_42');
    });
  });

  group('buildLgRegisterPayload', () {
    test('combined permission count meets 39-permission requirement', () {
      final msg = buildLgRegisterPayload();
      final manifest = msg['payload']['manifest'] as Map<String, dynamic>;
      final signed = manifest['signed'] as Map<String, dynamic>;
      final outer = (manifest['permissions'] as List<dynamic>).length;
      final inner = (signed['permissions'] as List<dynamic>).length;
      expect(outer + inner, greaterThanOrEqualTo(39));
    });

    test('serial field matches required LG RSA-SHA256 value', () {
      final msg = buildLgRegisterPayload();
      final signed =
          msg['payload']['manifest']['signed'] as Map<String, dynamic>;
      expect(signed['serial'], '2f930e2d2cfe083771f68e4fe7bb07');
    });

    test('includes client-key in payload when provided', () {
      final msg = buildLgRegisterPayload(clientKey: 'abc123');
      expect(msg['payload']['client-key'], 'abc123');
    });

    test('omits client-key when null', () {
      final msg = buildLgRegisterPayload();
      expect(
        (msg['payload'] as Map<String, dynamic>).containsKey('client-key'),
        isFalse,
      );
    });

    test('pairingType is PROMPT', () {
      final msg = buildLgRegisterPayload();
      expect(msg['payload']['pairingType'], 'PROMPT');
    });
  });
}
