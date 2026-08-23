/// Optional layout deletion capability used when a saved device is explicitly
/// removed.
///
/// Kept separate from [LayoutRepository] so existing in-memory and test
/// repositories do not need destructive operations.
abstract interface class LayoutDeletionRepository {
  Future<void> deleteLayout({required String deviceId});
}
