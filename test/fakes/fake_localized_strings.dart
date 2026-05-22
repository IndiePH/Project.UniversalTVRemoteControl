import 'package:one_remote/app/localized_strings.dart';

class FakeLocalizedStrings implements LocalizedStrings {
  @override
  String pairingNoAdapter(String brandName) =>
      'No adapter configured for $brandName.';
  @override
  String pairingApproved(String deviceName) =>
      'Pairing approved for $deviceName.';
  @override
  String pairingFailed(String deviceName) => 'Pairing failed for $deviceName.';
  @override
  String pairingCodeAccepted(String deviceName) =>
      'Pairing code accepted for $deviceName.';
  @override
  String pairingCodeSubmitFailed(String deviceName) =>
      'Failed to submit pairing code for $deviceName.';
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
      "When the pairing request appears on your TV screen, tap 'Allow'.";
  @override
  String get pairingSamsungPreStep0 =>
      'Your Samsung TV is ON and connected to the same Wi-Fi.';
  @override
  String get pairingSamsungPreStep1 =>
      'Accept any connection permission that appears on your TV.';
  @override
  String get pairingAndroidTvProgressHint =>
      'A PIN will appear on your TV screen — enter it when prompted.';
  @override
  String get pairingAndroidTvPreStep0 =>
      'Your Android TV or Google TV is ON and on the same Wi-Fi.';
  @override
  String get pairingAndroidTvPreStep1 =>
      'A PIN will appear on your TV screen — enter it when prompted.';
  @override
  String get pairingRokuProgressHint =>
      'Make sure mobile control is enabled in Roku settings.';
  @override
  String get pairingRokuPreStep0 =>
      'On TV, open Settings > System > Advanced system settings.';
  @override
  String get pairingRokuPreStep1 => 'Set Control by mobile apps to Enabled.';
  @override
  String get pairingTclLegacyProgressHint =>
      'Connecting using legacy TCL Wi-Fi transport.';
  @override
  String get pairingTclLegacyPreStep0 =>
      'Legacy TCL Wi-Fi requires the TV IP address on port 4123.';
  @override
  String get pairingTclLegacyPreStep1 =>
      'Power-on may still require the original remote, CEC, or WOL.';
  @override
  String remoteCommandUnsupported(String commandName, String brandName) =>
      'Command $commandName is not supported for $brandName.';
  @override
  String remoteCommandSent(String commandName) => 'Sent: $commandName';
  @override
  String remoteCommandFailed(String deviceName) =>
      'Failed to send command to $deviceName.';
  @override
  String remoteTextInputUnsupported(String brandName) =>
      'Text input is not supported for $brandName.';
  @override
  String remoteTextSent(String text) => 'Text sent: "$text"';
  @override
  String remoteTextFailed(String deviceName) =>
      'Failed to send text to $deviceName.';
  @override
  String get remoteTextLgImeFocusRequired =>
      'LG IME text injection rejected — ensure a text field is focused on the TV.';
  @override
  String get remoteTextSamsungCompatibilityError =>
      'Typing from this phone is not available on this TV screen or app. '
      'Use the TV on-screen keyboard and direction buttons to enter text.';
}
