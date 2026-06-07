import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/pro_device_switch_policy.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

void main() {
  const deviceA = TvDevice(
    id: 'a',
    displayName: 'TV A',
    brand: TvBrand.samsung,
    capabilities: {DeviceCapability.keyCommands},
  );
  const deviceB = TvDevice(
    id: 'b',
    displayName: 'TV B',
    brand: TvBrand.lg,
    capabilities: {DeviceCapability.keyCommands},
  );

  group('ProDeviceSwitchPolicy.canSwitchTo', () {
    test('allows any device when Pro', () {
      expect(
        ProDeviceSwitchPolicy.canSwitchTo(
          device: deviceB,
          activeDeviceId: 'a',
          isPro: true,
        ),
        isTrue,
      );
    });

    test('allows any device when no active device on free tier', () {
      expect(
        ProDeviceSwitchPolicy.canSwitchTo(
          device: deviceB,
          activeDeviceId: null,
          isPro: false,
        ),
        isTrue,
      );
    });

    test('allows re-selecting the active device on free tier', () {
      expect(
        ProDeviceSwitchPolicy.canSwitchTo(
          device: deviceA,
          activeDeviceId: 'a',
          isPro: false,
        ),
        isTrue,
      );
    });

    test('blocks switching to another device on free tier', () {
      expect(
        ProDeviceSwitchPolicy.canSwitchTo(
          device: deviceB,
          activeDeviceId: 'a',
          isPro: false,
        ),
        isFalse,
      );
    });
  });

  group('ProDeviceSwitchPolicy.isSwitchLocked', () {
    test('is false when no active device', () {
      expect(
        ProDeviceSwitchPolicy.isSwitchLocked(
          device: deviceB,
          activeDeviceId: null,
          isPro: false,
        ),
        isFalse,
      );
    });

    test('is true for non-active device when another is active', () {
      expect(
        ProDeviceSwitchPolicy.isSwitchLocked(
          device: deviceB,
          activeDeviceId: 'a',
          isPro: false,
        ),
        isTrue,
      );
    });
  });

  group('ProDeviceSwitchPolicy.canSwitchBetweenSavedDevices', () {
    test('is true for Pro users', () {
      expect(
        ProDeviceSwitchPolicy.canSwitchBetweenSavedDevices(
          isPro: true,
          activeDeviceId: 'a',
        ),
        isTrue,
      );
    });

    test('is true on free tier when no active device', () {
      expect(
        ProDeviceSwitchPolicy.canSwitchBetweenSavedDevices(
          isPro: false,
          activeDeviceId: null,
        ),
        isTrue,
      );
    });

    test('is false on free tier when an active device exists', () {
      expect(
        ProDeviceSwitchPolicy.canSwitchBetweenSavedDevices(
          isPro: false,
          activeDeviceId: 'a',
        ),
        isFalse,
      );
    });
  });
}
