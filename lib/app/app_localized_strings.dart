import 'package:one_remote/app/localized_strings.dart';
import 'package:one_remote/l10n/app_localizations.dart';

final class AppLocalizedStrings implements LocalizedStrings {
  // ignore: unused_field
  static late AppLocalizations _l10n;

  static void update(AppLocalizations l10n) => _l10n = l10n;
}
