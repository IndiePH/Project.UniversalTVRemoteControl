import 'package:one_remote/remote_control/domain/models/tv_device_info.dart';

/// Protocol variant tags for [TvBrand.tcl] (legacy Wi-Fi only in active DI).
///
/// [googleTv] and [roku] remain for [TvDevice.fromJson] migration to
/// [TvBrand.androidTv] / [TvBrand.roku]; they are not registered in DI.
abstract final class TclProtocolVariants {
  static const String googleTv = 'tcl_google_tv';
  static const String roku = 'tcl_roku';
  static const String legacyWifi = 'tcl_legacy_wifi';

  /// [queryDeviceInfo] marker stamped by legacy TCL transports at pairing time.
  static const String legacyWifiModelMarker = legacyWifi;

  static bool isLegacyWifi(TvDeviceInfo info) {
    final model = (info.modelIdentifier ?? '').toLowerCase();
    return model == legacyWifiModelMarker;
  }
}
