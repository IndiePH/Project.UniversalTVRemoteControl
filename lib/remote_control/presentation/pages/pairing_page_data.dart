import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/domain/models/tv_brand.dart';
import 'package:one_remote/remote_control/domain/models/tv_capabilities.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';
import 'package:one_remote/utils/two_digit_format.dart';

/// Read/derive data used by `PairingPage` presentation state.
final class PairingPageData {
  const PairingPageData._();

  static Future<List<String>> loadRecentManualIps(
    DeviceRepository deviceRepository,
  ) {
    return deviceRepository.getRecentManualIps();
  }

  static Future<PairingMetadataSnapshot> loadPairingMetadata(
    DeviceRepository deviceRepository,
  ) async {
    final savedDevices = await deviceRepository.getSavedDevices();
    final savedIds = <String>{};
    final pairingHistory = <String, DateTime>{};

    for (final device in savedDevices) {
      savedIds.add(device.id);
      final pairedAt = await deviceRepository.getLastSuccessfulPairingAt(device.id);
      if (pairedAt != null) {
        pairingHistory[device.id] = pairedAt;
      }
    }

    return PairingMetadataSnapshot(
      savedDevices: savedDevices,
      savedDeviceIds: savedIds,
      pairingHistoryByDeviceId: pairingHistory,
    );
  }

  static Future<List<TvDevice>> discoverDevices(
    DeviceDiscoveryService discoveryService,
  ) {
    return discoveryService.discoverDevices();
  }

  static TvDevice buildManualDevice({
    required TvBrand brand,
    required String ip,
  }) {
    return TvDevice(
      id: '${brand.name}-$ip',
      displayName: '${brand.displayName} TV ($ip)',
      brand: brand,
      capabilities: const TvCapabilities().capabilitiesFor(brand),
    );
  }

  static bool isValidIpv4(String input) {
    final regExp = RegExp(
      r'^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$',
    );
    return regExp.hasMatch(input);
  }

  static String? pairingNoteForDevice({
    required String deviceId,
    required Set<String> savedDeviceIds,
    required Map<String, DateTime> pairingHistoryByDeviceId,
  }) {
    if (!savedDeviceIds.contains(deviceId)) {
      return null;
    }
    final pairedAt = pairingHistoryByDeviceId[deviceId];
    if (pairedAt == null) {
      return 'Previously paired';
    }
    final local = pairedAt.toLocal();
    final date =
        '${local.year}-${formatTwoDigits(local.month)}-${formatTwoDigits(local.day)}';
    final time = '${formatTwoDigits(local.hour)}:${formatTwoDigits(local.minute)}';
    return 'Previously paired ($date $time)';
  }
}

final class PairingMetadataSnapshot {
  const PairingMetadataSnapshot({
    required this.savedDevices,
    required this.savedDeviceIds,
    required this.pairingHistoryByDeviceId,
  });

  final List<TvDevice> savedDevices;
  final Set<String> savedDeviceIds;
  final Map<String, DateTime> pairingHistoryByDeviceId;
}
