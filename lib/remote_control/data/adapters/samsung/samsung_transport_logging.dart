import 'dart:convert';
import 'dart:developer' show log;

import 'package:one_remote/remote_control/data/adapters/samsung/samsung_transport_file_logger.dart';

/// Debug logcat + optional on-device file logging for Samsung WebSocket frames.
///
/// Controlled by `--dart-define=SAMSUNG_TRANSPORT_DEBUG=true` (defaults on in
/// this codebase for APK diagnostics; see [SamsungWebSocketTransportClient]).
class SamsungTransportLogging {
  SamsungTransportLogging({
    this.enabled = const bool.fromEnvironment(
      'SAMSUNG_TRANSPORT_DEBUG',
      defaultValue: true,
    ),
    SamsungTransportFileLogger? fileLogger,
  }) : _fileLogger = fileLogger ?? SamsungTransportFileLogger();

  final bool enabled;
  final SamsungTransportFileLogger _fileLogger;

  void logDebug(String message) {
    log(message, name: 'samsung_transport');
    _fileLogger.write(message);
  }

  void logOutbound(String deviceId, String payload) {
    if (!enabled) {
      return;
    }
    logDebug('[$deviceId] TX: ${summarizeOutboundPayload(payload)}');
  }

  static String summarizeOutboundPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return _truncate(payload, 500);
      }
      final method = decoded['method'];
      final params = decoded['params'];
      if (params is Map<String, dynamic>) {
        final type = params['TypeOfRemote'];
        if (type == 'SendInputString' && params['Cmd'] is String) {
          final cmd = params['Cmd'] as String;
          final preview = cmd.length > 56 ? '${cmd.substring(0, 56)}...' : cmd;
          return 'method=$method SendInputString cmdLen=${cmd.length} cmdPreview=$preview';
        }
        if (type == 'SendInputEnd') {
          return 'method=$method SendInputEnd';
        }
      }
      if (method == 'ms.channel.emit') {
        return 'method=$method params=${_truncate(jsonEncode(params), 280)}';
      }
      return _truncate(payload, 500);
    } catch (_) {
      return _truncate(payload, 500);
    }
  }

  static String _truncate(String value, int max) {
    if (value.length <= max) {
      return value;
    }
    return '${value.substring(0, max)}...';
  }
}
