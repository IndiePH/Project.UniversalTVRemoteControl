import 'package:one_remote/remote_control/domain/models/layout_position.dart';

abstract class LayoutRepository {
  Future<Map<String, LayoutPosition>> loadLayout({
    required String deviceId,
  });

  Future<void> saveLayout({
    required String deviceId,
    required Map<String, LayoutPosition> positionsByItemId,
  });
}
