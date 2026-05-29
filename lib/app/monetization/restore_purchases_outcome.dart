/// Thrown when restore finds purchase records but entitlement verification fails.
final class ProRestoreValidationFailedException implements Exception {
  const ProRestoreValidationFailedException();
}

/// Result of a restore-purchases attempt for user-facing feedback.
enum RestorePurchasesOutcome {
  /// The billing client is not available on this device.
  storeUnavailable,

  /// Pro was already active before restore ran.
  alreadyActive,

  /// A prior purchase was found and Pro is now active.
  restored,

  /// Restore finished but no active Pro purchase was found.
  noPurchasesFound,

  /// Restore could not be completed (timeout or unexpected error).
  failed,
}
