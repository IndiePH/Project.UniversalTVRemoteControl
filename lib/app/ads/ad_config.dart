import 'package:flutter/foundation.dart';

/// Unity LevelPlay identifiers for OneRemote.
class AdConfig {
  const AdConfig._();

  static const String appKey = '27c78d0ad';
  static const String bannerAdUnitId = '20azo5e9eecpv182';

  static bool get supportsMobileAds {
    if (kIsWeb) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }
}
