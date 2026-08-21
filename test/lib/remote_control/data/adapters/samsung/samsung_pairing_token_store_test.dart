import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_pairing_token_store.dart';
import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_authorization.dart';
import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';
import 'package:one_remote/remote_control/data/persistence/device_scoped_secret_persistence.dart';
import 'package:one_remote/remote_control/data/persistence/legacy/legacy_host_scoped_secret_persistence.dart';

SamsungPairingTokenStore _store() => SamsungPairingTokenStore(
  persistence: LegacyInMemoryHostScopedSecretPersistence(),
);

void main() {
  group('SamsungPairingTokenStore', () {
    test(
      'unauthorized frame fails pending approval with rejection message',
      () async {
        const host = '192.168.1.10';
        final store = _store();
        final completer = Completer<void>();
        store.registerPendingApproval(host, completer);

        final outcome = store.handleDecoded(host, <String, dynamic>{
          'event': 'ms.channel.unauthorized',
        });

        expect(outcome, SamsungPairingFrameOutcome.unauthorized);
        await expectLater(
          completer.future,
          throwsA(
            isA<SamsungTransportAuthorizationException>().having(
              (e) => e.message,
              'message',
              'Samsung TV rejected remote-control authorization.',
            ),
          ),
        );
      },
    );

    test(
      'stored token completes pending approval for recovery after TV accepts',
      () async {
        const host = '192.168.1.11';
        final store = _store();
        final completer = Completer<void>();
        store.registerPendingApproval(host, completer);

        final outcome = store.handleDecoded(host, <String, dynamic>{
          'data': <String, dynamic>{'token': 'abc123'},
        });

        expect(outcome, SamsungPairingFrameOutcome.tokenStored);
        await expectLater(completer.future, completes);
        expect(store.trimmedTokenForHost(host), 'abc123');
      },
    );

    test(
      'cancelPendingApprovals fails waiters so pairing can be retried cleanly',
      () async {
        const host = '192.168.1.12';
        final store = _store();
        final completer = Completer<void>();
        store.registerPendingApproval(host, completer);

        store.cancelPendingApprovals(host);

        await expectLater(
          completer.future,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'Pairing cancelled',
            ),
          ),
        );
      },
    );

    test(
      'persisted token is available after a new store instance (cold start)',
      () async {
        const host = '192.168.1.20';
        final persistence = LegacyInMemoryHostScopedSecretPersistence();
        final writer = SamsungPairingTokenStore(persistence: persistence);
        await writer.setTokenForHost(host, 'persisted-token');

        final reader = SamsungPairingTokenStore(persistence: persistence);
        await reader.ensureHostLoaded(host);

        expect(reader.hasNonEmptyToken(host), isTrue);
        expect(reader.trimmedTokenForHost(host), 'persisted-token');
      },
    );

    test('clearTokenForHost removes persisted token', () async {
      const host = '192.168.1.21';
      final persistence = LegacyInMemoryHostScopedSecretPersistence();
      final store = SamsungPairingTokenStore(persistence: persistence);
      await store.setTokenForHost(host, 'to-clear');
      await store.clearTokenForHost(host);

      final reopened = SamsungPairingTokenStore(persistence: persistence);
      await reopened.ensureHostLoaded(host);

      expect(reopened.hasNonEmptyToken(host), isFalse);
    });
  });

  group('SamsungPairingTokenStore stable-id re-keying', () {
    SamsungPairingTokenStore storeWithRegistry(
      LegacyInMemoryHostScopedSecretPersistence host,
      InMemoryDeviceScopedSecretPersistence device,
      DeviceIdentityRegistry registry,
    ) =>
        SamsungPairingTokenStore(
          persistence: host,
          devicePersistence: device,
          identityRegistry: registry,
        );

    test('setTokenForHost persists under stableId when registered', () async {
      final host = LegacyInMemoryHostScopedSecretPersistence();
      final device = InMemoryDeviceScopedSecretPersistence();
      final registry = DeviceIdentityRegistry()
        ..register('192.168.1.40', 'samsung-udn-1');
      final writer = storeWithRegistry(host, device, registry);

      await writer.setTokenForHost('192.168.1.40', 'token-abc');

      expect(await device.read('samsung-udn-1'), 'token-abc');
      expect(await host.read('192.168.1.40'), isNull);
    });

    test('ensureHostLoaded reads stableId entry after IP change', () async {
      final host = LegacyInMemoryHostScopedSecretPersistence();
      final device = InMemoryDeviceScopedSecretPersistence();
      final registry = DeviceIdentityRegistry()
        ..register('192.168.1.40', 'samsung-udn-1');
      final writer = storeWithRegistry(host, device, registry);
      await writer.setTokenForHost('192.168.1.40', 'token-abc');

      registry.register('192.168.1.77', 'samsung-udn-1');
      final reader = storeWithRegistry(host, device, registry);
      await reader.ensureHostLoaded('192.168.1.77');

      expect(reader.hasNonEmptyToken('192.168.1.77'), isTrue);
      expect(reader.trimmedTokenForHost('192.168.1.77'), 'token-abc');
    });

    test('clearTokenForHost removes the stableId entry', () async {
      final host = LegacyInMemoryHostScopedSecretPersistence();
      final device = InMemoryDeviceScopedSecretPersistence();
      final registry = DeviceIdentityRegistry()
        ..register('192.168.1.40', 'samsung-udn-1');
      final store = storeWithRegistry(host, device, registry);
      await store.setTokenForHost('192.168.1.40', 'token-abc');

      await store.clearTokenForHost('192.168.1.40');

      expect(await device.read('samsung-udn-1'), isNull);
    });
  });
}
