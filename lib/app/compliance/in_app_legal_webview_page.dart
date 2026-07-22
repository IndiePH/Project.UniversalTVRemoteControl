import 'package:flutter/material.dart';
import 'package:one_remote/app/theme/app_theme_preference.dart';
import 'package:webview_flutter/webview_flutter.dart';

class InAppLegalWebViewPage extends StatefulWidget {
  const InAppLegalWebViewPage({
    super.key,
    required this.url,
    required this.title,
    required this.themePreference,
  });

  final String url;
  final String title;
  final AppThemePreference themePreference;

  @override
  State<InAppLegalWebViewPage> createState() => _InAppLegalWebViewPageState();
}

class _InAppLegalWebViewPageState extends State<InAppLegalWebViewPage> {
  late final WebViewController _controller;
  var _isLoading = true;
  AppThemePreference? _lastThemePreference;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
            _applyThemeHintToPage();
          },
        ),
      )
      ..setBackgroundColor(Colors.transparent)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pref = widget.themePreference;
    if (_lastThemePreference != pref) {
      _lastThemePreference = pref;
      _applyThemeHintToPage();
    }
  }

  Future<void> _applyThemeHintToPage() async {
    final pref = _lastThemePreference;
    if (pref == null) {
      return;
    }

    final theme = switch (pref) {
      AppThemePreference.light => 'light',
      AppThemePreference.dark => 'dark',
      AppThemePreference.system => 'system',
    };

    // The GitHub Pages site provides a `#themeSelect` control and `theme.js`
    // that stores `theme-preference` in localStorage and applies
    // `documentElement.dataset.theme`. We mirror that behavior so the page's
    // own theme system (Jekyll/CSS) controls the final look.
    final js =
        '''
(() => {
  try {
    const theme = '$theme'; // 'system' | 'light' | 'dark'
    const key = 'theme-preference';
    try { localStorage.setItem(key, theme); } catch (_) {}

    // Apply immediately as a fallback, even if the select isn't on this page.
    if (theme === 'light' || theme === 'dark') {
      document.documentElement.dataset.theme = theme;
      document.documentElement.style.colorScheme = theme;
    } else {
      delete document.documentElement.dataset.theme;
      document.documentElement.style.colorScheme = '';
    }

    const select = document.getElementById('themeSelect');
    if (select && typeof select.value !== 'undefined') {
      select.value = theme;
      select.dispatchEvent(new Event('change', { bubbles: true }));
    }
  } catch (_) {}
})();
''';

    try {
      await _controller.runJavaScript(js);
    } catch (_) {
      // Ignore: some platforms/pages may not allow JS execution.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
