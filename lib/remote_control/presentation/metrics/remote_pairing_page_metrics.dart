/// Layout constants for the pairing screen Paired device list.
abstract final class RemotePairingPageMetrics {
  /// Maximum paired rows visible before the list scrolls internally.
  static const int maxVisiblePairedDevices = 3;

  /// Vertical padding on each paired row (`EdgeInsets.symmetric(vertical: 2)`).
  static const double pairedListItemVerticalPadding = 4;

  /// One paired row: [ListTile] + outer vertical padding.
  static const double pairedListRowExtent = 64 + pairedListItemVerticalPadding;
}
