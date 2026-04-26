import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand_capabilities.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

void main() {
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

    test('fromJson falls back to brand defaults when capabilities list is empty', () {
      final json = <String, dynamic>{
        'id': 'tv-1',
        'displayName': 'LG TV',
        'brand': 'lg',
        'capabilities': <String>[],
      };

      final device = TvDevice.fromJson(json);

      expect(device, isNotNull);
      expect(device!.capabilities, equals(TvBrand.lg.defaultCapabilities));
    });

    test('fromJson defaults protocolVariant to "default" when key is absent', () {
      final json = <String, dynamic>{
        'id': 'tv-1',
        'displayName': 'LG TV',
        'brand': 'lg',
        'capabilities': ['keyCommands'],
      };

      final device = TvDevice.fromJson(json);

      expect(device!.protocolVariant, equals(TvDevice.defaultProtocolVariant));
    });

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
  });
}
