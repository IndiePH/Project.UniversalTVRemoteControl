import 'package:one_remote/remote_control/domain/models/tv_device.dart';

abstract final class SonyProtocolVariants {
  static const String defaultVariant = TvDevice.defaultProtocolVariant;

  /// Sony's own BRAVIA IP Control protocol (REST/JSON-RPC over HTTP) — a
  /// second, independent protocol from the Android TV Remote Protocol v2
  /// path `defaultVariant` covers. See `SonyBraviaAdapter`.
  static const String braviaIpControl = 'sony_bravia_ip_control';
}
