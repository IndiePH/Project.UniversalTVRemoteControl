/// Optional persistence capability for moving a saved remote layout from a
/// legacy IP-derived device id to a stable device id.
///
/// Kept separate from [LayoutRepository] so in-memory and test repositories
/// remain focused on normal layout reads/writes.
abstract interface class LayoutIdentityMigrationRepository {
  /// Copies the legacy layout to [newDeviceId] without overwriting an existing
  /// stable-id layout. The legacy key is retained until
  /// [completeLayoutIdentityMigration] is called. Returns whether a layout was
  /// found and copied.
  Future<bool> migrateLayoutIdentity({
    required String legacyDeviceId,
    required String newDeviceId,
  });

  /// Retires the legacy layout after the device identity migration succeeds.
  Future<void> completeLayoutIdentityMigration({
    required String legacyDeviceId,
  });
}
