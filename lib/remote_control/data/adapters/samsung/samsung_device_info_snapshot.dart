import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

/// Parsed Samsung `ms.channel.connect` payload for validation and debug UI.
class SamsungDeviceInfoSnapshot {
  const SamsungDeviceInfoSnapshot({
    this.model,
    this.os,
    this.firmwareVersion,
    this.frameVersion,
    this.deviceFrameId,
  });

  final String? model;
  final String? os;
  final String? firmwareVersion;
  final String? frameVersion;
  final String? deviceFrameId;

  bool get hasAnyField => <String?>[
    model,
    os,
    firmwareVersion,
    frameVersion,
    deviceFrameId,
  ].any((value) => value != null && value.isNotEmpty);

  static SamsungDeviceInfoSnapshot? fromConnectData(Map<String, dynamic> data) {
    final snapshot = SamsungDeviceInfoSnapshot(
      model: _trimString(data['model']),
      os: _trimString(data['OS']),
      firmwareVersion: _trimString(data['firmwareVersion']),
      frameVersion: _trimString(data['version']),
      deviceFrameId: _trimString(data['id']),
    );
    return snapshot.hasAnyField ? snapshot : null;
  }

  TvDeviceInfo toTvDeviceInfo() {
    final extraLines = <String>[];
    if (os != null && os!.isNotEmpty) {
      extraLines.add('OS: $os');
    }
    if (frameVersion != null && frameVersion!.isNotEmpty) {
      extraLines.add('Frame: $frameVersion');
    }
    if (deviceFrameId != null && deviceFrameId!.isNotEmpty) {
      extraLines.add('Id: $deviceFrameId');
    }
    return TvDeviceInfo(
      modelIdentifier: model,
      firmwareVersion: firmwareVersion,
      debugDetails: extraLines.isEmpty ? null : extraLines.join('\n'),
    );
  }

  static String? _trimString(Object? value) {
    final trimmed = value?.toString().trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
