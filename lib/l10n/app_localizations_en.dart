// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OneRemote';

  @override
  String pairingNoAdapter(String brandName) {
    return 'No adapter configured for $brandName.';
  }

  @override
  String pairingApproved(String deviceName) {
    return 'Pairing approved for $deviceName.';
  }

  @override
  String pairingFailed(String deviceName) {
    return 'Pairing failed for $deviceName.';
  }

  @override
  String pairingCodeAccepted(String deviceName) {
    return 'Pairing code accepted for $deviceName.';
  }

  @override
  String pairingCodeSubmitFailed(String deviceName) {
    return 'Failed to submit pairing code for $deviceName.';
  }

  @override
  String get pairingLgProgressHint =>
      'Look at your TV screen and accept the pairing prompt.';

  @override
  String get pairingSamsungProgressHint =>
      'Accept any connection permission that appears on your TV.';

  @override
  String get pairingHisenseProgressHint => 'Connecting to TV…';

  @override
  String get pairingLgPreStep0 =>
      'Your LG TV is ON and connected to the same Wi-Fi.';

  @override
  String get pairingLgPreStep1 =>
      'When the pairing request appears on your TV screen, tap \'Allow\'.';

  @override
  String get pairingSamsungPreStep0 =>
      'Your Samsung TV is ON and connected to the same Wi-Fi.';

  @override
  String get pairingSamsungPreStep1 =>
      'Accept any connection permission that appears on your TV.';

  @override
  String remoteCommandUnsupported(String commandName, String brandName) {
    return 'Command $commandName is not supported for $brandName.';
  }

  @override
  String remoteCommandSent(String commandName) {
    return 'Sent: $commandName';
  }

  @override
  String remoteCommandFailed(String deviceName) {
    return 'Failed to send command to $deviceName.';
  }

  @override
  String remoteTextInputUnsupported(String brandName) {
    return 'Text input is not supported for $brandName.';
  }

  @override
  String remoteTextSent(String text) {
    return 'Text sent: \"$text\"';
  }

  @override
  String remoteTextFailed(String deviceName) {
    return 'Failed to send text to $deviceName.';
  }

  @override
  String get remoteTextLgImeFocusRequired =>
      'LG IME text injection rejected — ensure a text field is focused on the TV.';

  @override
  String get remoteTextSamsungCompatibilityError =>
      'Typing from this phone is not available on this TV screen or app. Use the TV on-screen keyboard and direction buttons to enter text.';
}
