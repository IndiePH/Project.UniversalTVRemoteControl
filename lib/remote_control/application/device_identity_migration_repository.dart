import 'package:one_remote/remote_control/domain/models/tv_device.dart';

/// Optional persistence capability for migrating a legacy IP-derived device id
/// to a stable device id.
///
/// Kept separate from [DeviceRepository] so non-persistent repositories and
/// test doubles are not forced to implement a storage-specific operation.
abstract interface class DeviceIdentityMigrationRepository {
  /// Re-keys [legacyId] to [device.id] and returns whether the migration was
  /// applied. Implementations must be write-new-before-retire and safe to
  /// retry.
  Future<bool> migrateDeviceIdentity({
    required String legacyId,
    required TvDevice device,
  });
}
