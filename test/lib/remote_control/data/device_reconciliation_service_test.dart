import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/data/device_reconciliation_service.dart';
import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_capabilities.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

TvDevice _device({
  required String id,
  required String host,
  required TvBrand brand,
}) {
  return TvDevice(
    id: id,
    displayName: '${brand.displayName} TV ($host)',
    brand: brand,
    capabilities: const TvCapabilities().capabilitiesFor(brand),
    host: host,
  );
}

void main() {
  group('DeviceReconciliationService', () {
    test(
      'updates saved host when a discovered TV matches by stableId at a new IP',
      () {
        final saved = [
          _device(
            id: 'samsung-uuid-1',
            host: '192.168.1.10',
            brand: TvBrand.samsung,
          ),
        ];
        final discovered = [
          _device(
            id: 'samsung-uuid-1',
            host: '192.168.1.99',
            brand: TvBrand.samsung,
          ),
        ];

        final result = DeviceReconciliationService().reconcile(
          discovered: discovered,
          saved: saved,
        );

        expect(result.updatedSavedDevices, hasLength(1));
        expect(result.updatedSavedDevices.single.host, '192.168.1.99');
        expect(result.updatedSavedDevices.single.id, 'samsung-uuid-1');
        expect(result.matches, hasLength(1));
      },
    );

    test('does not produce an update when the host is unchanged', () {
      final saved = [
        _device(
          id: 'samsung-uuid-1',
          host: '192.168.1.10',
          brand: TvBrand.samsung,
        ),
      ];
      final discovered = [
        _device(
          id: 'samsung-uuid-1',
          host: '192.168.1.10',
          brand: TvBrand.samsung,
        ),
      ];

      final result = DeviceReconciliationService().reconcile(
        discovered: discovered,
        saved: saved,
      );

      expect(result.updatedSavedDevices, isEmpty);
      expect(result.matches, hasLength(1));
    });

    test('skips saved devices without a stableId (legacy IP-derived id)', () {
      final saved = [
        _device(
          id: 'samsung-192.168.1.10',
          host: '192.168.1.10',
          brand: TvBrand.samsung,
        ),
      ];
      final discovered = [
        _device(
          id: 'samsung-uuid-1',
          host: '192.168.1.99',
          brand: TvBrand.samsung,
        ),
      ];

      final result = DeviceReconciliationService().reconcile(
        discovered: discovered,
        saved: saved,
      );

      expect(result.updatedSavedDevices, isEmpty);
      expect(result.matches, isEmpty);
    });

    test(
      'skips discovered devices without a stableId (legacy IP-derived id)',
      () {
        final saved = [
          _device(
            id: 'samsung-uuid-1',
            host: '192.168.1.10',
            brand: TvBrand.samsung,
          ),
        ];
        final discovered = [
          _device(
            id: 'samsung-192.168.1.99',
            host: '192.168.1.99',
            brand: TvBrand.samsung,
          ),
        ];

        final result = DeviceReconciliationService().reconcile(
          discovered: discovered,
          saved: saved,
        );

        expect(result.updatedSavedDevices, isEmpty);
        expect(result.matches, isEmpty);
      },
    );

    test(
      'registers discovered host -> stableId for matches and unmatched discoveries',
      () {
        final registry = DeviceIdentityRegistry();
        final service = DeviceReconciliationService(identityRegistry: registry);

        final saved = [
          _device(
            id: 'samsung-uuid-1',
            host: '192.168.1.10',
            brand: TvBrand.samsung,
          ),
        ];
        final discovered = [
          _device(
            id: 'samsung-uuid-1',
            host: '192.168.1.99',
            brand: TvBrand.samsung,
          ),
          _device(id: 'lg-uuid-2', host: '192.168.1.50', brand: TvBrand.lg),
        ];

        service.reconcile(discovered: discovered, saved: saved);

        expect(registry.stableIdForHost('192.168.1.99'), 'samsung-uuid-1');
        expect(registry.hostForStableId('samsung-uuid-1'), '192.168.1.99');
        expect(registry.stableIdForHost('192.168.1.50'), 'lg-uuid-2');
      },
    );

    test('creates a legacy rekey only for an exact host and brand match', () {
      final saved = [
        _device(
          id: 'samsung-192.168.1.10',
          host: '192.168.1.10',
          brand: TvBrand.samsung,
        ),
      ];
      final discovered = [
        _device(
          id: 'samsung-uuid-1',
          host: '192.168.1.10',
          brand: TvBrand.samsung,
        ),
      ];

      final result = DeviceReconciliationService().reconcile(
        discovered: discovered,
        saved: saved,
      );

      expect(result.legacyRekeys, hasLength(1));
      expect(result.legacyRekeys.single.legacy.id, 'samsung-192.168.1.10');
      expect(result.legacyRekeys.single.migrated.id, 'samsung-uuid-1');
      expect(result.legacyRekeys.single.migrated.host, '192.168.1.10');
    });

    test('does not rekey when the legacy TV host changed', () {
      final saved = [
        _device(
          id: 'samsung-192.168.1.10',
          host: '192.168.1.10',
          brand: TvBrand.samsung,
        ),
      ];
      final discovered = [
        _device(
          id: 'samsung-uuid-1',
          host: '192.168.1.99',
          brand: TvBrand.samsung,
        ),
      ];

      final result = DeviceReconciliationService().reconcile(
        discovered: discovered,
        saved: saved,
      );

      expect(result.legacyRekeys, isEmpty);
    });

    test('does not rekey when the brand differs at the same host', () {
      final saved = [
        _device(
          id: 'samsung-192.168.1.10',
          host: '192.168.1.10',
          brand: TvBrand.samsung,
        ),
      ];
      final discovered = [
        _device(id: 'lg-uuid-1', host: '192.168.1.10', brand: TvBrand.lg),
      ];

      final result = DeviceReconciliationService().reconcile(
        discovered: discovered,
        saved: saved,
      );

      expect(result.legacyRekeys, isEmpty);
    });

    test('does not rekey an ambiguous host with multiple legacy records', () {
      final saved = [
        _device(
          id: 'samsung-192.168.1.10',
          host: '192.168.1.10',
          brand: TvBrand.samsung,
        ),
        _device(
          id: 'samsung-192.168.1.10-copy',
          host: '192.168.1.10',
          brand: TvBrand.samsung,
        ),
      ];
      final discovered = [
        _device(
          id: 'samsung-uuid-1',
          host: '192.168.1.10',
          brand: TvBrand.samsung,
        ),
      ];

      final result = DeviceReconciliationService().reconcile(
        discovered: discovered,
        saved: saved,
      );

      expect(result.legacyRekeys, isEmpty);
    });

    test(
      'does not rekey when a stable saved record already occupies the host',
      () {
        final saved = [
          _device(
            id: 'samsung-192.168.1.10',
            host: '192.168.1.10',
            brand: TvBrand.samsung,
          ),
          _device(
            id: 'samsung-existing-uuid',
            host: '192.168.1.10',
            brand: TvBrand.samsung,
          ),
        ];
        final discovered = [
          _device(
            id: 'samsung-uuid-1',
            host: '192.168.1.10',
            brand: TvBrand.samsung,
          ),
        ];

        final result = DeviceReconciliationService().reconcile(
          discovered: discovered,
          saved: saved,
        );

        expect(result.legacyRekeys, isEmpty);
      },
    );

    test('host comparison is case- and whitespace-insensitive', () {
      final saved = [
        _device(
          id: 'samsung-uuid-1',
          host: ' 192.168.1.10 ',
          brand: TvBrand.samsung,
        ),
      ];
      final discovered = [
        _device(
          id: 'samsung-uuid-1',
          host: '192.168.1.10',
          brand: TvBrand.samsung,
        ),
      ];

      final result = DeviceReconciliationService().reconcile(
        discovered: discovered,
        saved: saved,
      );

      expect(result.updatedSavedDevices, isEmpty);
    });

    test('preserves saved device identity and non-host fields on update', () {
      final saved = TvDevice(
        id: 'samsung-uuid-1',
        displayName: 'Living Room TV',
        brand: TvBrand.samsung,
        capabilities: const TvCapabilities().capabilitiesFor(TvBrand.samsung),
        protocolVariant: 'default',
        modelIdentifier: 'QN90A',
        host: '192.168.1.10',
      );
      final discovered = _device(
        id: 'samsung-uuid-1',
        host: '192.168.1.99',
        brand: TvBrand.samsung,
      );

      final result = DeviceReconciliationService().reconcile(
        discovered: [discovered],
        saved: [saved],
      );

      final updated = result.updatedSavedDevices.single;
      expect(updated.id, 'samsung-uuid-1');
      expect(updated.displayName, 'Living Room TV');
      expect(updated.modelIdentifier, 'QN90A');
      expect(updated.hasStableId, isTrue);
      expect(updated.host, '192.168.1.99');
    });
  });
}
