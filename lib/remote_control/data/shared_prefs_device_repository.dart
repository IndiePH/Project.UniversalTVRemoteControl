import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

class SharedPrefsDeviceRepository implements DeviceRepository {
  static const String _deviceIdsKey = 'device_ids_v1';
  static const String _deviceKeyPrefix = 'device_v1_';
  static const String _lastUsedKey = 'last_used_device_id_v1';
  static const String _recentIpsKey = 'recent_manual_ips_v1';
  static const String _pairingAtPrefix = 'last_pairing_at_v1_';
  static const String _systemInfoPrefix = 'device_system_info_v1_';

  @override
  Future<List<TvDevice>> getSavedDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = _decodeStringList(prefs.getString(_deviceIdsKey));
    final devices = <TvDevice>[];
    for (final id in ids) {
      final raw = prefs.getString('$_deviceKeyPrefix$id');
      if (raw == null) continue;
      final device = _decodeDevice(raw);
      if (device != null) devices.add(device);
    }
    return devices;
  }

  @override
  Future<TvDevice?> getLastUsedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_lastUsedKey);
    if (id == null || id.isEmpty) return null;
    final raw = prefs.getString('$_deviceKeyPrefix$id');
    if (raw == null) return null;
    return _decodeDevice(raw);
  }

  @override
  Future<List<String>> getRecentManualIps() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeStringList(prefs.getString(_recentIpsKey));
  }

  @override
  Future<DateTime?> getLastSuccessfulPairingAt(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt('$_pairingAtPrefix$deviceId');
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  @override
  Future<void> saveDevice(TvDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = _decodeStringList(prefs.getString(_deviceIdsKey));
    if (!ids.contains(device.id)) {
      ids.add(device.id);
      await prefs.setString(_deviceIdsKey, jsonEncode(ids));
    }
    await prefs.setString(
      '$_deviceKeyPrefix${device.id}',
      jsonEncode(device.toJson()),
    );
  }

  @override
  Future<void> removeSavedDevice(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = _decodeStringList(prefs.getString(_deviceIdsKey));
    ids.remove(deviceId);
    await prefs.setString(_deviceIdsKey, jsonEncode(ids));
    await prefs.remove('$_deviceKeyPrefix$deviceId');
    await prefs.remove('$_pairingAtPrefix$deviceId');

    final lastUsed = prefs.getString(_lastUsedKey);
    if (lastUsed == deviceId) {
      await prefs.setString(_lastUsedKey, ids.isNotEmpty ? ids.first : '');
    }
  }

  @override
  Future<void> saveRecentManualIp(String ipAddress) async {
    final prefs = await SharedPreferences.getInstance();
    final ips = _decodeStringList(prefs.getString(_recentIpsKey));
    ips.remove(ipAddress);
    ips.insert(0, ipAddress);
    if (ips.length > 5) ips.removeLast();
    await prefs.setString(_recentIpsKey, jsonEncode(ips));
  }

  @override
  Future<void> setLastSuccessfulPairingAt({
    required String deviceId,
    required DateTime timestamp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '$_pairingAtPrefix$deviceId',
      timestamp.millisecondsSinceEpoch,
    );
  }

  @override
  Future<void> setLastUsedDevice(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastUsedKey, deviceId);
  }

  @override
  Future<void> saveDeviceSystemInfo(
    String deviceId,
    Map<String, dynamic> info,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_systemInfoPrefix$deviceId', jsonEncode(info));
  }

  @override
  Future<Map<String, dynamic>?> getDeviceSystemInfo(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_systemInfoPrefix$deviceId');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<String>().toList();
    } catch (_) {
      return [];
    }
  }

  TvDevice? _decodeDevice(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return TvDevice.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}
