/// Result of server-side Google Play purchase validation.
final class ProReceiptValidationResult {
  const ProReceiptValidationResult({
    required this.entitled,
    this.expiresAtEpochMs,
    this.resolvedProductId,
  });

  const ProReceiptValidationResult.notEntitled()
      : entitled = false,
        expiresAtEpochMs = null,
        resolvedProductId = null;

  final bool entitled;
  final int? expiresAtEpochMs;
  final String? resolvedProductId;
}
