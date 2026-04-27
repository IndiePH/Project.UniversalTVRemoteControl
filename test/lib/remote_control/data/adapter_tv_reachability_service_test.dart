import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/remote_control/application/tv_brand_adapter.dart';
import 'package:one_remote/remote_control/data/adapter_tv_reachability_service.dart';
import 'package:one_remote/remote_control/domain/models/connection_state.dart';
import 'package:one_remote/remote_control/domain/models/device_capability.dart';
import 'package:one_remote/remote_control/domain/models/remote_command.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

void main() {
  const lgDevice = TvDevice(
    id: 'lg-192.168.1.10',
    displayName: 'LG TV',
    brand: TvBrand.lg,
    capabilities: {DeviceCapability.keyCommands},
  );

  const samsungDevice = TvDevice(
    id: 'samsung-192.168.1.20',
    displayName: 'Samsung TV',
    brand: TvBrand.samsung,
    capabilities: {DeviceCapability.keyCommands},
  );

  group('AdapterTvReachabilityService', () {
    test('returns true when adapter probeConnection completes', () async {
      final service = AdapterTvReachabilityService(
        adapters: [_ReachableAdapter(TvBrand.lg)],
      );
      expect(await service.isReachable(lgDevice), isTrue);
    });

    test('returns false when adapter probeConnection throws', () async {
      final service = AdapterTvReachabilityService(
        adapters: [_UnreachableAdapter(TvBrand.lg)],
      );
      expect(await service.isReachable(lgDevice), isFalse);
    });

    test('returns false when no adapter matches brand', () async {
      final service = AdapterTvReachabilityService(
        adapters: [_ReachableAdapter(TvBrand.lg)],
      );
      expect(await service.isReachable(samsungDevice), isFalse);
    });

    test(
      'prefers exact (brand + variant) match over brand-only fallback',
      () async {
        final defaultAdapter = _ReachableAdapter(TvBrand.samsung);
        final variantAdapter = _UnreachableAdapter(
          TvBrand.samsung,
          variant: 'alt',
        );
        final service = AdapterTvReachabilityService(
          adapters: [defaultAdapter, variantAdapter],
        );
        const altDevice = TvDevice(
          id: 'samsung-192.168.1.20',
          displayName: 'Samsung TV',
          brand: TvBrand.samsung,
          capabilities: {DeviceCapability.keyCommands},
          protocolVariant: 'alt',
        );
        expect(await service.isReachable(altDevice), isFalse);
      },
    );

    test('falls back to brand-only adapter when no variant match', () async {
      final service = AdapterTvReachabilityService(
        adapters: [_ReachableAdapter(TvBrand.samsung)],
      );
      expect(await service.isReachable(samsungDevice), isTrue);
    });
  });
}

class _ReachableAdapter implements TvBrandAdapter {
  _ReachableAdapter(this.brand, {String? variant})
    : protocolVariant = variant ?? TvDevice.defaultProtocolVariant;

  @override
  final TvBrand brand;

  @override
  final String protocolVariant;

  @override
  Future<void> probeConnection({required TvDevice device}) async {}

  @override
  bool get supportsTextInput => false;

  @override
  Set<RemoteCommand> get supportedCommands => const {};

  @override
  Future<void> sendCommand({
    required TvDevice device,
    required RemoteCommand command,
  }) async {}

  @override
  Future<void> sendText({
    required TvDevice device,
    required String text,
  }) async {}

  @override
  Stream<bool> watchRemoteTextInputReady(TvDevice device) =>
      const Stream.empty();

  @override
  Stream<ConnectionState> watchConnectionState(TvDevice device) =>
      const Stream.empty();

  @override
  Future<TvDeviceInfo?> queryDeviceInfo({required TvDevice device}) async =>
      null;

  @override
  Future<void> preparePairing({required TvDevice device}) async {}

  @override
  Future<void> unpairDevice({required TvDevice device}) async {}

  @override
  Future<void> submitPairingCode({
    required TvDevice device,
    required String fourDigitPin,
  }) async {}
}

class _UnreachableAdapter extends _ReachableAdapter {
  _UnreachableAdapter(super.brand, {super.variant});

  @override
  Future<void> probeConnection({required TvDevice device}) async =>
      throw Exception('unreachable');
}
