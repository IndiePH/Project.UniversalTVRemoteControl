import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_remote/remote_control/application/layout_identity_migration_repository.dart';
import 'package:one_remote/remote_control/application/layout_deletion_repository.dart';
import 'package:one_remote/remote_control/application/layout_repository.dart';
import 'package:one_remote/remote_control/domain/models/layout_position.dart';

class SharedPrefsLayoutRepository
    implements
        LayoutRepository,
        LayoutIdentityMigrationRepository,
        LayoutDeletionRepository {
  static const String _keyPrefix = 'remote_layout_v1_';

  @override
  Future<Map<String, LayoutPosition>> loadLayout({
    required String deviceId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_keyPrefix$deviceId');
    if (jsonString == null || jsonString.isEmpty) {
      return const {};
    }

    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      return const {};
    }

    final result = <String, LayoutPosition>{};
    for (final entry in decoded.entries) {
      final position = LayoutPosition.fromJson(entry.value);
      if (position != null) {
        result[entry.key] = position;
      }
    }
    return result;
  }

  @override
  Future<void> saveLayout({
    required String deviceId,
    required Map<String, LayoutPosition> positionsByItemId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonMap = <String, dynamic>{
      for (final entry in positionsByItemId.entries)
        entry.key: entry.value.toJson(),
    };
    await prefs.setString('$_keyPrefix$deviceId', jsonEncode(jsonMap));
  }

  @override
  Future<void> deleteLayout({required String deviceId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$deviceId');
  }

  /// Copies a legacy layout to a stable device id without overwriting an
  /// existing stable-id layout. The old key remains until the device identity
  /// migration is complete, making an interrupted migration retryable without
  /// losing the legacy layout.
  @override
  Future<bool> migrateLayoutIdentity({
    required String legacyDeviceId,
    required String newDeviceId,
  }) async {
    if (legacyDeviceId.isEmpty ||
        newDeviceId.isEmpty ||
        legacyDeviceId == newDeviceId) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final oldKey = '$_keyPrefix$legacyDeviceId';
    final newKey = '$_keyPrefix$newDeviceId';
    final oldValue = prefs.getString(oldKey);
    if (oldValue == null || oldValue.isEmpty) return false;

    if (prefs.getString(newKey) == null) {
      await prefs.setString(newKey, oldValue);
    }
    return true;
  }

  @override
  Future<void> completeLayoutIdentityMigration({
    required String legacyDeviceId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$legacyDeviceId');
  }
}
