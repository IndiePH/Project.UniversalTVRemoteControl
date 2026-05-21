import 'package:flutter_test/flutter_test.dart';
import 'package:one_remote/app/ads/interstitial_ad_policy.dart';

void main() {
  test('blocks until both action and interval thresholds are met', () {
    final policy = InterstitialAdPolicy(
      minSuccessfulActionsBetweenAds: 3,
      minIntervalBetweenAds: const Duration(minutes: 10),
      sessionImpressionCap: 2,
      now: () => DateTime(2026, 1, 1, 12, 0),
    );

    policy.recordSuccessfulAction();
    policy.recordSuccessfulAction();
    policy.recordSuccessfulAction();

    expect(
      policy.canShow(
        showAds: true,
        canRequestAds: true,
        isLayoutEditMode: false,
        isModalOpen: false,
      ),
      isTrue,
    );

    policy.recordShown();

    expect(
      policy.canShow(
        showAds: true,
        canRequestAds: true,
        isLayoutEditMode: false,
        isModalOpen: false,
      ),
      isFalse,
    );
  });

  test('blocks when ads are not allowed by subscription or consent', () {
    final policy = InterstitialAdPolicy(
      minSuccessfulActionsBetweenAds: 1,
      minIntervalBetweenAds: Duration.zero,
      sessionImpressionCap: 2,
      now: DateTime.now,
    )..recordSuccessfulAction();

    expect(
      policy.canShow(
        showAds: false,
        canRequestAds: true,
        isLayoutEditMode: false,
        isModalOpen: false,
      ),
      isFalse,
    );
    expect(
      policy.canShow(
        showAds: true,
        canRequestAds: false,
        isLayoutEditMode: false,
        isModalOpen: false,
      ),
      isFalse,
    );
  });

  test('blocks while layout edit mode or modal state is active', () {
    final policy = InterstitialAdPolicy(
      minSuccessfulActionsBetweenAds: 1,
      minIntervalBetweenAds: Duration.zero,
      sessionImpressionCap: 2,
      now: DateTime.now,
    )..recordSuccessfulAction();

    expect(
      policy.canShow(
        showAds: true,
        canRequestAds: true,
        isLayoutEditMode: true,
        isModalOpen: false,
      ),
      isFalse,
    );
    expect(
      policy.canShow(
        showAds: true,
        canRequestAds: true,
        isLayoutEditMode: false,
        isModalOpen: true,
      ),
      isFalse,
    );
  });

  test('enforces per-session cap', () {
    final now = DateTime(2026, 1, 1, 12, 0);
    final policy = InterstitialAdPolicy(
      minSuccessfulActionsBetweenAds: 1,
      minIntervalBetweenAds: Duration.zero,
      sessionImpressionCap: 1,
      now: () => now,
    )..recordSuccessfulAction();

    expect(
      policy.canShow(
        showAds: true,
        canRequestAds: true,
        isLayoutEditMode: false,
        isModalOpen: false,
      ),
      isTrue,
    );

    policy.recordShown();
    policy.recordSuccessfulAction();

    expect(
      policy.canShow(
        showAds: true,
        canRequestAds: true,
        isLayoutEditMode: false,
        isModalOpen: false,
      ),
      isFalse,
    );
  });
}
