abstract interface class LocalizedStrings {
  String pairingNoAdapter(String brandName);
  String pairingApproved(String deviceName);
  String pairingFailed(String deviceName);
  String pairingCodeAccepted(String deviceName);
  String pairingCodeSubmitFailed(String deviceName);
  String get pairingLgProgressHint;
  String get pairingSamsungProgressHint;
  String get pairingHisenseProgressHint;
  String get pairingLgPreStep0;
  String get pairingLgPreStep1;
  String get pairingSamsungPreStep0;
  String get pairingSamsungPreStep1;
  String remoteCommandUnsupported(String commandName, String brandName);
  String remoteCommandSent(String commandName);
  String remoteCommandFailed(String deviceName);
  String remoteTextInputUnsupported(String brandName);
  String remoteTextSent(String text);
  String remoteTextFailed(String deviceName);
  String get remoteTextLgImeFocusRequired;
  String get remoteTextSamsungCompatibilityError;
}
