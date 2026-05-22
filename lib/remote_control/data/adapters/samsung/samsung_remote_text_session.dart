import 'dart:async';

import 'package:one_remote/remote_control/application/text_compatibility_error.dart';
import 'package:one_remote/remote_control/application/text_input_compatibility_exception.dart';

/// Per-device IME / on-screen keyboard state derived from Samsung WS events.
///
/// Owns the `watchRemoteTextInputReady` broadcast stream and lightweight app
/// context strings used when text input is unavailable.
class SamsungRemoteTextSession {
  final Map<String, bool> _isImeActiveByDeviceId = <String, bool>{};
  final Map<String, bool> _isImeSessionPrimedByDeviceId = <String, bool>{};
  final Map<String, String> _appContextByDeviceId = <String, String>{};
  final Map<String, StreamController<bool>> _imeReadyBroadcasters =
      <String, StreamController<bool>>{};

  void _notifyImeReadyListeners(String deviceId) {
    final value = _isImeActiveByDeviceId[deviceId] ?? false;
    final controller = _imeReadyBroadcasters[deviceId];
    if (controller != null && !controller.isClosed) {
      controller.add(value);
    }
  }

  Stream<bool> watchRemoteTextInputReady(String deviceId) {
    return Stream<bool>.multi((controller) {
      controller.add(_isImeActiveByDeviceId[deviceId] ?? false);
      final broadcaster = _imeReadyBroadcasters.putIfAbsent(
        deviceId,
        () => StreamController<bool>.broadcast(),
      );
      late final StreamSubscription<bool> sub;
      sub = broadcaster.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = () {
        sub.cancel();
      };
    });
  }

  /// Clears session-derived flags when a new socket is bound for [deviceId].
  void onSocketBound(String deviceId) {
    _isImeActiveByDeviceId[deviceId] = false;
    _isImeSessionPrimedByDeviceId[deviceId] = false;
    _notifyImeReadyListeners(deviceId);
  }

  /// Clears all per-device text-session state after the socket ends.
  void onSocketLost(String deviceId) {
    _isImeActiveByDeviceId[deviceId] = false;
    _notifyImeReadyListeners(deviceId);
    _isImeActiveByDeviceId.remove(deviceId);
    _isImeSessionPrimedByDeviceId.remove(deviceId);
    _appContextByDeviceId.remove(deviceId);
  }

  bool isImeActive(String deviceId) =>
      _isImeActiveByDeviceId[deviceId] ?? false;

  bool isImeSessionPrimed(String deviceId) =>
      _isImeSessionPrimedByDeviceId[deviceId] ?? false;

  void markImeSessionPrimed(String deviceId) {
    _isImeSessionPrimedByDeviceId[deviceId] = true;
  }

  String? appContext(String deviceId) => _appContextByDeviceId[deviceId];

  void ingestDecoded(
    String deviceId,
    Map<String, dynamic>? decoded, {
    void Function(String message)? onImeDebugLog,
  }) {
    _captureAppContext(deviceId: deviceId, decoded: decoded);
    _captureImeSessionState(
      deviceId: deviceId,
      decoded: decoded,
      onImeDebugLog: onImeDebugLog,
    );
  }

  void _captureAppContext({
    required String deviceId,
    required Map<String, dynamic>? decoded,
  }) {
    if (decoded == null) {
      return;
    }
    final method = decoded['method'];
    if (method is String && method.isNotEmpty) {
      _appContextByDeviceId[deviceId] = 'method=$method';
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      return;
    }
    final appId = data['appId'] ?? data['id'];
    if (appId is String && appId.trim().isNotEmpty) {
      final trimmed = appId.trim();
      final event = decoded['event'];
      if (event is String && event.isNotEmpty) {
        _appContextByDeviceId[deviceId] = 'event=$event appId=$trimmed';
      } else {
        _appContextByDeviceId[deviceId] = 'appId=$trimmed';
      }
    }
  }

  void _captureImeSessionState({
    required String deviceId,
    required Map<String, dynamic>? decoded,
    required void Function(String message)? onImeDebugLog,
  }) {
    if (decoded == null) {
      return;
    }
    final event = decoded['event'];
    if (event is! String) {
      return;
    }
    final eventLower = event.toLowerCase();
    if (!eventLower.contains('ime')) {
      return;
    }
    if (eventLower.contains('start')) {
      _isImeActiveByDeviceId[deviceId] = true;
      _isImeSessionPrimedByDeviceId[deviceId] = false;
      _notifyImeReadyListeners(deviceId);
      onImeDebugLog?.call('[$deviceId] RX: IME start');
      return;
    }
    if (eventLower.contains('end')) {
      _isImeActiveByDeviceId[deviceId] = false;
      _isImeSessionPrimedByDeviceId[deviceId] = false;
      _notifyImeReadyListeners(deviceId);
      onImeDebugLog?.call('[$deviceId] RX: IME end');
    }
  }

  /// Throws [TextInputCompatibilityException] when the TV has not opened IME.
  void ensureImeActiveForSendText(String deviceId) {
    if (_isImeActiveByDeviceId[deviceId] ?? false) {
      return;
    }
    throw TextInputCompatibilityException(
      TextCompatibilityError.samsungScreenNotAcceptingInput,
    );
  }
}
