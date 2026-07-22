import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a public legal document in the platform browser.
class LegalLinkLauncher {
  const LegalLinkLauncher._();

  static Future<bool> openUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      return false;
    }

    final LaunchMode mode;
    if (kIsWeb) {
      mode = LaunchMode.platformDefault;
    } else {
      mode = switch (defaultTargetPlatform) {
        TargetPlatform.android || TargetPlatform.iOS => LaunchMode.inAppWebView,
        _ => LaunchMode.externalApplication,
      };
    }

    return launchUrl(uri, mode: mode);
  }
}
