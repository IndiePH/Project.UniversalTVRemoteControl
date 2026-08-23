import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_capabilities.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

void main() {
  group('TvDevice.copyWith', () {
    const base = TvDevice(
      id: 'tv-1',
      displayName: 'Old Name',
      brand: TvBrand.lg,
      capabilities: {DeviceCapability.keyCommands},
      protocolVariant: 'webos_v2',
    );

    test('updates displayName and preserves all other fields', () {
      final updated = base.copyWith(displayName: 'New Name');

      expect(updated.displayName, 'New Name');
      expect(updated.id, base.id);
      expect(updated.brand, base.brand);
      expect(updated.capabilities, base.capabilities);
      expect(updated.protocolVariant, base.protocolVariant);
    });

    test('preserves displayName when not provided', () {
      final updated = base.copyWith(
        capabilities: {DeviceCapability.powerControl},
      );

      expect(updated.displayName, base.displayName);
    });

    test('preserves displayName when other fields are updated', () {
      final updated = base.copyWith(protocolVariant: 'webos_v3');

      expect(updated.displayName, base.displayName);
      expect(updated.protocolVariant, 'webos_v3');
    });
  });

  group('TvDevice.toJson / fromJson', () {
    test('round-trips all fields', () {
      const original = TvDevice(
        id: 'tv-1',
        displayName: 'My TV',
        brand: TvBrand.lg,
        capabilities: {
          DeviceCapability.keyCommands,
          DeviceCapability.textInput,
          DeviceCapability.powerControl,
        },
        protocolVariant: 'webos_v2',
      );

      final restored = TvDevice.fromJson(original.toJson());

      expect(restored, isNotNull);
      expect(restored!.id, original.id);
      expect(restored.displayName, original.displayName);
      expect(restored.brand, original.brand);
      expect(restored.capabilities, equals(original.capabilities));
      expect(restored.protocolVariant, original.protocolVariant);
    });

    test('fromJson restores persisted capabilities, ignoring brand defaults', () {
      // Samsung brand defaults do not include textInput (flag off in test env),
      // but the persisted JSON explicitly includes it — fromJson must honour that.
      final json = <String, dynamic>{
        'id': 'tv-1',
        'displayName': 'Samsung TV',
        'brand': 'samsung',
        'capabilities': ['keyCommands', 'textInput', 'powerControl'],
        'protocolVariant': 'default',
      };

      final device = TvDevice.fromJson(json);

      expect(device, isNotNull);
      expect(device!.capabilities, contains(DeviceCapability.textInput));
    });

    test(
      'fromJson falls back to brand defaults when capabilities list is empty',
      () {
        final json = <String, dynamic>{
          'id': 'tv-1',
          'displayName': 'LG TV',
          'brand': 'lg',
          'capabilities': <String>[],
        };

        final device = TvDevice.fromJson(json);

        expect(device, isNotNull);
        expect(
          device!.capabilities,
          equals(const TvCapabilities().capabilitiesFor(TvBrand.lg)),
        );
      },
    );

    test(
      'fromJson defaults protocolVariant to "default" when key is absent',
      () {
        final json = <String, dynamic>{
          'id': 'tv-1',
          'displayName': 'LG TV',
          'brand': 'lg',
          'capabilities': ['keyCommands'],
        };

        final device = TvDevice.fromJson(json);

        expect(
          device!.protocolVariant,
          equals(TvDevice.defaultProtocolVariant),
        );
      },
    );

    test('fromJson silently drops unrecognised capability names', () {
      final json = <String, dynamic>{
        'id': 'tv-1',
        'displayName': 'LG TV',
        'brand': 'lg',
        'capabilities': ['keyCommands', 'unknownCap'],
      };

      final device = TvDevice.fromJson(json);

      expect(device, isNotNull);
      expect(device!.capabilities, equals({DeviceCapability.keyCommands}));
    });

    test('fromJson returns null for unrecognised brand', () {
      final json = <String, dynamic>{
        'id': 'tv-1',
        'displayName': 'Unknown TV',
        'brand': 'panasonic',
        'capabilities': ['keyCommands'],
      };

      expect(TvDevice.fromJson(json), isNull);
    });

    test('fromJson migrates tcl_roku to brand roku default variant', () {
      final json = <String, dynamic>{
        'id': 'tv-1',
        'displayName': 'TCL Roku TV',
        'brand': 'tcl',
        'protocolVariant': 'tcl_roku',
        'capabilities': <String>[],
      };

      final device = TvDevice.fromJson(json);

      expect(device, isNotNull);
      expect(device!.brand, TvBrand.roku);
      expect(device.protocolVariant, TvDevice.defaultProtocolVariant);
      expect(
        device.capabilities,
        equals(const TvCapabilities().capabilitiesFor(TvBrand.roku)),
      );
    });

    test(
      'fromJson migrates tcl_google_tv to brand androidTv default variant',
      () {
        final json = <String, dynamic>{
          'id': 'tv-1',
          'displayName': 'TCL Google TV',
          'brand': 'tcl',
          'protocolVariant': 'tcl_google_tv',
          'capabilities': <String>[],
        };

        final device = TvDevice.fromJson(json);

        expect(device, isNotNull);
        expect(device!.brand, TvBrand.androidTv);
        expect(device.protocolVariant, TvDevice.defaultProtocolVariant);
        expect(
          device.capabilities,
          equals(const TvCapabilities().capabilitiesFor(TvBrand.androidTv)),
        );
      },
    );

    test('protocolVariant is included in toJson output', () {
      const device = TvDevice(
        id: 'tv-1',
        displayName: 'TV',
        brand: TvBrand.samsung,
        capabilities: {DeviceCapability.keyCommands},
        protocolVariant: 'tizen_v5',
      );

      final json = device.toJson();

      expect(json['protocolVariant'], equals('tizen_v5'));
    });

    test('modelIdentifier round-trips through toJson / fromJson', () {
      const original = TvDevice(
        id: 'tv-1',
        displayName: 'LG TV',
        brand: TvBrand.lg,
        capabilities: {DeviceCapability.keyCommands},
        modelIdentifier: 'OLED65C2PSA',
      );

      final restored = TvDevice.fromJson(original.toJson());

      expect(restored!.modelIdentifier, equals('OLED65C2PSA'));
    });

    test('fromJson sets modelIdentifier to null when key is absent', () {
      final json = <String, dynamic>{
        'id': 'tv-1',
        'displayName': 'LG TV',
        'brand': 'lg',
        'capabilities': ['keyCommands'],
      };

      final device = TvDevice.fromJson(json);

      expect(device!.modelIdentifier, isNull);
    });
  });

  group('TvDevice.copyWith modelIdentifier', () {
    const base = TvDevice(
      id: 'tv-1',
      displayName: 'LG TV',
      brand: TvBrand.lg,
      capabilities: {DeviceCapability.keyCommands},
      modelIdentifier: 'OLED65C2PSA',
    );

    test('updates modelIdentifier and preserves other fields', () {
      final updated = base.copyWith(modelIdentifier: 'OLED77C3PSA');

      expect(updated.modelIdentifier, equals('OLED77C3PSA'));
      expect(updated.id, base.id);
      expect(updated.displayName, base.displayName);
      expect(updated.brand, base.brand);
    });

    test('preserves modelIdentifier when not provided', () {
      final updated = base.copyWith(displayName: 'New Name');

      expect(updated.modelIdentifier, equals('OLED65C2PSA'));
    });
  });

  group('TvDevice.host / resolvedHost', () {
    test('resolvedHost returns the explicit host when set', () {
      const device = TvDevice(
        id: 'roku-YX00AB123456',
        displayName: 'Roku TV',
        brand: TvBrand.roku,
        capabilities: {DeviceCapability.keyCommands},
        host: '192.168.1.73',
      );

      expect(device.resolvedHost, equals('192.168.1.73'));
    });

    test('resolvedHost backfills from the IPv4 in id when host is null', () {
      const device = TvDevice(
        id: 'samsung-192.168.1.50',
        displayName: 'Samsung TV',
        brand: TvBrand.samsung,
        capabilities: {DeviceCapability.keyCommands},
      );

      expect(device.host, isNull);
      expect(device.resolvedHost, equals('192.168.1.50'));
    });

    test(
      'resolvedHost returns empty string when host is null and id has no IPv4',
      () {
        const device = TvDevice(
          id: 'roku-YX00AB123456',
          displayName: 'Roku TV',
          brand: TvBrand.roku,
          capabilities: {DeviceCapability.keyCommands},
        );

        expect(device.host, isNull);
        expect(device.resolvedHost, equals(''));
      },
    );

    test('toJson includes host and fromJson round-trips it', () {
      const original = TvDevice(
        id: 'samsung-uuid:1234',
        displayName: 'Samsung TV',
        brand: TvBrand.samsung,
        capabilities: {DeviceCapability.keyCommands},
        host: '192.168.1.50',
      );

      final restored = TvDevice.fromJson(original.toJson());

      expect(restored, isNotNull);
      expect(restored!.host, equals('192.168.1.50'));
      expect(restored.resolvedHost, equals('192.168.1.50'));
    });

    test(
      'fromJson backfills host from the legacy IP-derived id when key is absent',
      () {
        final json = <String, dynamic>{
          'id': 'samsung-192.168.1.50',
          'displayName': 'Samsung TV',
          'brand': 'samsung',
          'capabilities': ['keyCommands'],
        };

        final device = TvDevice.fromJson(json);

        expect(device, isNotNull);
        expect(device!.host, equals('192.168.1.50'));
        expect(device.resolvedHost, equals('192.168.1.50'));
      },
    );

    test('fromJson treats an empty host string as absent and backfills', () {
      final json = <String, dynamic>{
        'id': 'samsung-192.168.1.50',
        'displayName': 'Samsung TV',
        'brand': 'samsung',
        'capabilities': ['keyCommands'],
        'host': '   ',
      };

      final device = TvDevice.fromJson(json);

      expect(device, isNotNull);
      expect(device!.host, equals('192.168.1.50'));
    });

    test('copyWith updates host and preserves other fields', () {
      const base = TvDevice(
        id: 'samsung-uuid:1234',
        displayName: 'Samsung TV',
        brand: TvBrand.samsung,
        capabilities: {DeviceCapability.keyCommands},
        host: '192.168.1.50',
      );

      final updated = base.copyWith(host: '192.168.1.73');

      expect(updated.host, equals('192.168.1.73'));
      expect(updated.resolvedHost, equals('192.168.1.73'));
      expect(updated.id, base.id);
      expect(updated.displayName, base.displayName);
      expect(updated.brand, base.brand);
    });

    test('copyWith preserves host when not provided', () {
      const base = TvDevice(
        id: 'samsung-uuid:1234',
        displayName: 'Samsung TV',
        brand: TvBrand.samsung,
        capabilities: {DeviceCapability.keyCommands},
        host: '192.168.1.50',
      );

      expect(base.copyWith(displayName: 'New').host, equals('192.168.1.50'));
    });
  });

  group('TvDevice.hasStableId', () {
    test('a stable id (no embedded IPv4) is recognized as stable', () {
      const device = TvDevice(
        id: 'samsung-12345678-1234-1234-1234-123456789abc',
        displayName: 'Samsung TV',
        brand: TvBrand.samsung,
        capabilities: {DeviceCapability.keyCommands},
        host: '192.168.1.50',
      );

      expect(device.hasStableId, isTrue);
    });

    test('an IP-derived id is recognized as not stable (legacy)', () {
      const device = TvDevice(
        id: 'samsung-192.168.1.50',
        displayName: 'Samsung TV',
        brand: TvBrand.samsung,
        capabilities: {DeviceCapability.keyCommands},
        host: '192.168.1.50',
      );

      expect(device.hasStableId, isFalse);
    });

    test('toJson includes id and fromJson round-trips it', () {
      const original = TvDevice(
        id: 'samsung-12345678-1234-1234-1234-123456789abc',
        displayName: 'Samsung TV',
        brand: TvBrand.samsung,
        capabilities: {DeviceCapability.keyCommands},
        host: '192.168.1.50',
      );

      final restored = TvDevice.fromJson(original.toJson());

      expect(restored, isNotNull);
      expect(
        restored!.id,
        equals('samsung-12345678-1234-1234-1234-123456789abc'),
      );
      expect(restored.hasStableId, isTrue);
    });

    test('copyWith updates id and preserves other fields', () {
      const base = TvDevice(
        id: 'samsung-192.168.1.50',
        displayName: 'Samsung TV',
        brand: TvBrand.samsung,
        capabilities: {DeviceCapability.keyCommands},
      );

      final updated = base.copyWith(
        id: 'samsung-new-udn',
        host: '192.168.1.73',
      );

      expect(updated.id, equals('samsung-new-udn'));
      expect(updated.hasStableId, isTrue);
      expect(updated.host, equals('192.168.1.73'));
    });

    test('copyWith preserves id when not provided', () {
      const base = TvDevice(
        id: 'samsung-udn-1',
        displayName: 'Samsung TV',
        brand: TvBrand.samsung,
        capabilities: {DeviceCapability.keyCommands},
      );

      expect(base.copyWith(displayName: 'New').id, equals('samsung-udn-1'));
    });
  });
}
