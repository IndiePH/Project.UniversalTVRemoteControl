import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_remote/remote_control/application/layout_repository.dart';
import 'package:one_remote/remote_control/domain/models/layout_position.dart';

class SharedPrefsLayoutRepository implements LayoutRepository {
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
      for (final entry in positionsByItemId.entries) entry.key: entry.value.toJson(),
    };
    await prefs.setString('$_keyPrefix$deviceId', jsonEncode(jsonMap));
  }
}
