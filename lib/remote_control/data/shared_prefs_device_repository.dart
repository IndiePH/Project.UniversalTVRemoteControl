import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_remote/remote_control/application/device_identity_migration_repository.dart';
import 'package:one_remote/remote_control/application/device_last_seen_repository.dart';
import 'package:one_remote/remote_control/application/device_repository.dart';
import 'package:one_remote/remote_control/data/persistence/device_identity_registry.dart';
import 'package:one_remote/remote_control/domain/models/tv_device.dart';

class SharedPrefsDeviceRepository
    implements
        DeviceRepository,
        DeviceIdentityMigrationRepository,
        DeviceLastSeenRepository {
  SharedPrefsDeviceRepository({this._identityRegistry});

  static const String _deviceIdsKey = 'device_ids_v1';
  static const String _deviceKeyPrefix = 'device_v1_';
  static const String _lastUsedKey = 'last_used_device_id_v1';
  static const String _recentIpsKey = 'recent_manual_ips_v1';
  static const String _pairingAtPrefix = 'last_pairing_at_v1_';
  static const String _lastSeenAtPrefix = 'last_seen_at_v1_';
  static const String _systemInfoPrefix = 'device_system_info_v1_';

  final DeviceIdentityRegistry? _identityRegistry;

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
    _indexIdentity(devices);
    return devices;
  }

  @override
  Future<TvDevice?> getLastUsedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_lastUsedKey);
    if (id == null || id.isEmpty) return null;
    final raw = prefs.getString('$_deviceKeyPrefix$id');
    if (raw == null) return null;
    final device = _decodeDevice(raw);
    if (device != null) _indexIdentity([device]);
    return device;
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
  Future<DateTime?> getLastSeenAt(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt('$_lastSeenAtPrefix$deviceId');
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
    _indexIdentity([device]);
  }

  /// Re-keys a legacy IP-derived saved device to [device.id].
  ///
  /// The new device and copied metadata are written before the active id list
  /// is changed. The old keys are removed only after the new record is
  /// reachable, so an interrupted migration leaves either the old active
  /// record or a complete new record to retry from. Legacy host-keyed pairing
  /// secrets are intentionally not removed; the secret gateway still needs
  /// them as a backwards-compatible fallback.
  @override
  Future<bool> migrateDeviceIdentity({
    required String legacyId,
    required TvDevice device,
  }) async {
    final oldId = legacyId.trim();
    final newId = device.id.trim();
    if (oldId.isEmpty ||
        newId.isEmpty ||
        oldId == newId ||
        !device.hasStableId) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final ids = _decodeStringList(prefs.getString(_deviceIdsKey));
    if (!ids.contains(legacyId)) return false;

    final oldKey = '$_deviceKeyPrefix$legacyId';
    final oldRaw = prefs.getString(oldKey);
    if (oldRaw == null) return false;
    final oldDevice = _decodeDevice(oldRaw);
    if (oldDevice == null ||
        oldDevice.id != legacyId ||
        oldDevice.brand != device.brand) {
      return false;
    }

    final newKey = '$_deviceKeyPrefix$newId';
    final existingNewRaw = prefs.getString(newKey);
    if (existingNewRaw != null) {
      final existingNew = _decodeDevice(existingNewRaw);
      if (existingNew == null ||
          existingNew.id != newId ||
          existingNew.brand != device.brand) {
        return false;
      }
    }

    // Always refresh the new record with the saved display metadata and the
    // newly discovered host. This is safe after the stable-id/brand check.
    await prefs.setString(newKey, jsonEncode(device.toJson()));
    await _copyIntIfMissing(
      prefs,
      '$_pairingAtPrefix$legacyId',
      '$_pairingAtPrefix$newId',
    );
    await _copyIntIfMissing(
      prefs,
      '$_lastSeenAtPrefix$legacyId',
      '$_lastSeenAtPrefix$newId',
    );
    await _copyStringIfMissing(
      prefs,
      '$_systemInfoPrefix$legacyId',
      '$_systemInfoPrefix$newId',
    );

    final migratedIds = <String>[];
    for (final id in ids) {
      final replacement = id == legacyId ? newId : id;
      if (!migratedIds.contains(replacement)) {
        migratedIds.add(replacement);
      }
    }
    await prefs.setString(_deviceIdsKey, jsonEncode(migratedIds));

    if (prefs.getString(_lastUsedKey) == legacyId) {
      await prefs.setString(_lastUsedKey, newId);
    }

    // Retire the old active record only after the replacement is listed.
    await prefs.remove(oldKey);
    await prefs.remove('$_pairingAtPrefix$legacyId');
    await prefs.remove('$_lastSeenAtPrefix$legacyId');
    await prefs.remove('$_systemInfoPrefix$legacyId');
    _indexIdentity([device]);
    return true;
  }

  @override
  Future<void> removeSavedDevice(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = _decodeStringList(prefs.getString(_deviceIdsKey));
    ids.remove(deviceId);
    await prefs.setString(_deviceIdsKey, jsonEncode(ids));
    await prefs.remove('$_deviceKeyPrefix$deviceId');
    await prefs.remove('$_pairingAtPrefix$deviceId');
    await prefs.remove('$_lastSeenAtPrefix$deviceId');

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
  Future<void> setLastSeenAt({
    required String deviceId,
    required DateTime timestamp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '$_lastSeenAtPrefix$deviceId',
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

  Future<void> _copyIntIfMissing(
    SharedPreferences prefs,
    String oldKey,
    String newKey,
  ) async {
    if (prefs.getInt(newKey) != null) return;
    final value = prefs.getInt(oldKey);
    if (value != null) {
      await prefs.setInt(newKey, value);
    }
  }

  Future<void> _copyStringIfMissing(
    SharedPreferences prefs,
    String oldKey,
    String newKey,
  ) async {
    if (prefs.getString(newKey) != null) return;
    final value = prefs.getString(oldKey);
    if (value != null) {
      await prefs.setString(newKey, value);
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

  /// Feeds each loaded device's `resolvedHost -> stableId` into the
  /// [DeviceIdentityRegistry] so brand secret stores can translate the host
  /// they receive from a transport into the stable id under which the secret
  /// is persisted. No-op for legacy devices without a stable id.
  /// (they keep using host-keyed storage) and when no registry is wired.
  void _indexIdentity(List<TvDevice> devices) {
    final registry = _identityRegistry;
    if (registry == null) return;
    for (final device in devices) {
      if (!device.hasStableId) continue;
      final host = device.resolvedHost;
      if (host.isEmpty) continue;
      registry.register(host, device.id);
    }
  }
}
