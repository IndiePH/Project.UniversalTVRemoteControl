import 'package:one_remote/app/localized_strings.dart';
import 'package:one_remote/l10n/app_localizations.dart';

final class AppLocalizedStrings implements LocalizedStrings {
  static late AppLocalizations _l10n;

  static void update(AppLocalizations l10n) => _l10n = l10n;

  @override
  String pairingNoAdapter(String brandName) => _l10n.pairingNoAdapter(brandName);
  @override
  String pairingApproved(String deviceName) => _l10n.pairingApproved(deviceName);
  @override
  String pairingFailed(String deviceName) => _l10n.pairingFailed(deviceName);
  @override
  String pairingCodeAccepted(String deviceName) => _l10n.pairingCodeAccepted(deviceName);
  @override
  String pairingCodeSubmitFailed(String deviceName) => _l10n.pairingCodeSubmitFailed(deviceName);
  @override
  String get pairingLgProgressHint => _l10n.pairingLgProgressHint;
  @override
  String get pairingSamsungProgressHint => _l10n.pairingSamsungProgressHint;
  @override
  String get pairingHisenseProgressHint => _l10n.pairingHisenseProgressHint;
  @override
  String get pairingLgPreStep0 => _l10n.pairingLgPreStep0;
  @override
  String get pairingLgPreStep1 => _l10n.pairingLgPreStep1;
  @override
  String get pairingSamsungPreStep0 => _l10n.pairingSamsungPreStep0;
  @override
  String get pairingSamsungPreStep1 => _l10n.pairingSamsungPreStep1;
  @override
  String remoteCommandUnsupported(String commandName, String brandName) =>
      _l10n.remoteCommandUnsupported(commandName, brandName);
  @override
  String remoteCommandSent(String commandName) => _l10n.remoteCommandSent(commandName);
  @override
  String remoteCommandFailed(String deviceName) => _l10n.remoteCommandFailed(deviceName);
  @override
  String remoteTextInputUnsupported(String brandName) => _l10n.remoteTextInputUnsupported(brandName);
  @override
  String remoteTextSent(String text) => _l10n.remoteTextSent(text);
  @override
  String remoteTextFailed(String deviceName) => _l10n.remoteTextFailed(deviceName);
  @override
  String get remoteTextLgImeFocusRequired => _l10n.remoteTextLgImeFocusRequired;
  @override
  String get remoteTextSamsungCompatibilityError => _l10n.remoteTextSamsungCompatibilityError;
}
