import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Opt-in interface for adapters that run their own background connectivity
/// polling loop (e.g. Hisense's MQTT poll timer) and can pause/resume it
/// without touching the underlying connection, which is left to time out on
/// its own schedule if genuinely idle. Mirrors the [TransportLogProvider]
/// capability-check pattern: checked via `is BackgroundPollAware` in
/// `BrandRoutedRemoteCommandService`, implemented only by adapters that
/// actually have a poll loop to pause.
abstract interface class BackgroundPollAware {
  Future<void> pauseMonitoring({required TvDevice device});
  Future<void> resumeMonitoring({required TvDevice device});
}
