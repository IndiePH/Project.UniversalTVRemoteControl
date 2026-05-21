/// Decides when a full-screen interstitial ad is eligible to be shown.
///
/// This policy tracks engagement and timing gates so full-screen ads are only
/// attempted after enough successful actions and with a cooldown interval.
class InterstitialAdPolicy {
  InterstitialAdPolicy({
    required this.minSuccessfulActionsBetweenAds,
    required this.minIntervalBetweenAds,
    required this.sessionImpressionCap,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int minSuccessfulActionsBetweenAds;
  final Duration minIntervalBetweenAds;
  final int sessionImpressionCap;
  final DateTime Function() _now;

  DateTime? _lastShownAt;
  int _successfulActionsSinceLastAd = 0;
  int _sessionImpressions = 0;

  void recordSuccessfulAction() {
    _successfulActionsSinceLastAd += 1;
  }

  void recordShown() {
    _lastShownAt = _now();
    _sessionImpressions += 1;
    _successfulActionsSinceLastAd = 0;
  }

  bool canShow({
    required bool showAds,
    required bool canRequestAds,
    required bool isLayoutEditMode,
    required bool isModalOpen,
  }) {
    if (!showAds || !canRequestAds) {
      return false;
    }
    if (isLayoutEditMode || isModalOpen) {
      return false;
    }
    if (_sessionImpressions >= sessionImpressionCap) {
      return false;
    }
    if (_successfulActionsSinceLastAd < minSuccessfulActionsBetweenAds) {
      return false;
    }
    final lastShownAt = _lastShownAt;
    if (lastShownAt == null) {
      return true;
    }
    return _now().difference(lastShownAt) >= minIntervalBetweenAds;
  }
}
