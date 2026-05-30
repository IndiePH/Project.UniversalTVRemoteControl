import 'package:one_remote/app/diagnostics/app_diagnostics_recorder.dart';
import 'package:one_remote/remote_control/application/device_discovery_service.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Records discovery success/empty/error counts for the diagnostics dashboard.
final class DiagnosticsRecordingDeviceDiscoveryService
    implements DeviceDiscoveryService {
  const DiagnosticsRecordingDeviceDiscoveryService({
    required this._delegate,
    required this._recorder,
  });

  final DeviceDiscoveryService _delegate;
  final AppDiagnosticsRecorder _recorder;

  @override
  Future<List<TvDevice>> discoverDevices() async {
    try {
      final devices = await _delegate.discoverDevices();
      _recorder.recordDiscoveryAttempt(deviceCount: devices.length);
      return devices;
    } catch (error) {
      _recorder.recordDiscoveryAttempt(deviceCount: 0, error: error);
      rethrow;
    }
  }
}
