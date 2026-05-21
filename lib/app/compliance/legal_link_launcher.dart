import 'package:url_launcher/url_launcher.dart';

/// Opens a public legal document in the platform browser.
class LegalLinkLauncher {
  const LegalLinkLauncher._();

  static Future<bool> openUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
