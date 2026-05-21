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
  String get uiCancel => 'Cancel';

  @override
  String get uiDone => 'Done';

  @override
  String get uiDismiss => 'Dismiss';

  @override
  String get uiConfirm => 'Confirm';

  @override
  String get uiContinue => 'Continue';

  @override
  String get uiRename => 'Rename';

  @override
  String get uiRemove => 'Remove';

  @override
  String get connectionStateConnected => 'Connected';

  @override
  String get connectionStateConnecting => 'Connecting…';

  @override
  String get connectionStateError => 'Connection error';

  @override
  String get connectionStateDisconnected => 'Disconnected';

  @override
  String get connectTvTooltip => 'Connect TV';

  @override
  String get remoteSwitchDeviceTooltip => 'Switch TV';

  @override
  String get remoteDeviceSwitcherTitle => 'Your TVs';

  @override
  String get remoteDeviceSwitcherManageButton => 'Add or manage TVs';

  @override
  String get layoutEditTooltip => 'Edit layout';

  @override
  String get layoutEditDoneTooltip => 'Done editing layout';

  @override
  String get proLayoutLockedTooltip => 'Pro required to edit layout';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get layoutEditorTitle => 'Layout Editor';

  @override
  String get layoutEditorResetButton => 'Reset Layout';

  @override
  String get layoutEditorInstruction =>
      'Drag buttons to new positions. Grid lines show cells; a green outline means the drop is allowed.';

  @override
  String get remoteTextEntrySheetTitle => 'Send text to TV';

  @override
  String get remoteTextEntryHint => 'Search or enter text';

  @override
  String get remoteTextEntrySendButton => 'Send';

  @override
  String get dpadUp => 'Up';

  @override
  String get dpadDown => 'Down';

  @override
  String get dpadLeft => 'Left';

  @override
  String get dpadRight => 'Right';

  @override
  String get dpadOk => 'OK';

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
  String get pairingWaitingForApproval => 'Waiting for TV approval...';

  @override
  String get pairingDiscoveryLimitedSupport =>
      'Limited support — some remote features may not work on this TV.';

  @override
  String pairingDiscoveryExperimentalSupport(String brandName) {
    return '$brandName — experimental support; pairing and commands may be unstable.';
  }

  @override
  String get pairingDiscoveryHisenseLimitedSupport =>
      'Limited support — remote keys work; app keyboard may not be available.';

  @override
  String get pairingDiscoveryRokuLimitedSupport =>
      'Limited support — keys and power work; no app keyboard or PIN pairing.';

  @override
  String get pairingNotePreviouslyPaired => 'Previously paired';

  @override
  String pairingNotePreviouslyPairedAt(String pairedAt) {
    return 'Previously paired ($pairedAt)';
  }

  @override
  String pairingDevicePairedOn(String pairedAt) {
    return '(paired on $pairedAt)';
  }

  @override
  String pairingDeviceRemoved(String deviceName) {
    return 'Removed $deviceName';
  }

  @override
  String get pairingExceptionFailed => 'Pairing failed. Please try again.';

  @override
  String get pairingDiscoveryFailed => 'Discovery failed. Please try again.';

  @override
  String get pairingNoTvConnected => 'No TV connected';

  @override
  String get pairingNoDevicesFound =>
      'No TVs found yet. Run a scan to discover devices.';

  @override
  String get pairingAddManuallyTooltip => 'Add manually';

  @override
  String get pairingScanTooltip => 'Scan for TVs';

  @override
  String get pairingSelectRemoteTitle => 'Select Remote';

  @override
  String get pairingHelpTooltip => 'Pairing help';

  @override
  String get pairingRenameTooltip => 'Rename';

  @override
  String get pairingDeviceInfoTooltip => 'Device info';

  @override
  String get pairingNeedHelpTitle => 'Need help finding your TV?';

  @override
  String get pairingPermissionChecklistTitle =>
      'Permission and network checklist';

  @override
  String get pairingPermissionChecklistBody =>
      '- Keep phone and TV on the same Wi-Fi network.\n- Allow local network/Wi-Fi permissions when prompted.\n- Disable client/AP isolation on your router if enabled.';

  @override
  String get pairingCannotFindTvTitle => 'Cannot find TV? Try this';

  @override
  String get pairingCannotFindTvBody =>
      '- Run Scan for TVs again and wait a few seconds.\n- Use Add Manually with the TV IP address.\n- Restart TV network, then re-open the pairing screen.';

  @override
  String get pairingManualTitle => 'Manual Pairing';

  @override
  String get pairingManualBrandLabel => 'TV brand';

  @override
  String get pairingManualIpLabel => 'TV IP address';

  @override
  String get pairingManualIpHint => 'e.g. 192.168.1.20';

  @override
  String get pairingManualAddButton => 'Add Manually';

  @override
  String get pairingManualErrorEmptyIp => 'Enter a TV IP address.';

  @override
  String get pairingManualErrorInvalidIp =>
      'Enter a valid IPv4 address (e.g. 192.168.1.20).';

  @override
  String pairingPreCheckTitle(String brandName) {
    return 'Before pairing with $brandName';
  }

  @override
  String get pairingPreCheckMakeSure => 'Make sure:';

  @override
  String get pairingPinTitle => 'Enter TV pairing code';

  @override
  String get pairingPinBody =>
      'A code will appear on your TV screen — enter it below to finish pairing.';

  @override
  String get pairingPinCodeLabel => '4-digit TV code';

  @override
  String get pairingPinCodeLabelHex => '6-character code (e.g. A4B2C1)';

  @override
  String get pairingPinSubmitButton => 'Submit code';

  @override
  String get pairingPinErrorInvalid => 'Enter exactly 4 digits.';

  @override
  String get pairingPinErrorInvalidHex =>
      'Enter exactly 6 characters (0–9, A–F).';

  @override
  String get pairingOutcomeSuccessTitle => 'Paired successfully';

  @override
  String get pairingOutcomeFailureTitle => 'Pairing failed';

  @override
  String pairingOutcomeSuccessBody(String deviceName) {
    return '$deviceName is ready to use.';
  }

  @override
  String get pairingRenameDialogTitle => 'Rename TV';

  @override
  String get pairingRenameNameLabel => 'TV name';

  @override
  String get pairingRenameErrorEmpty => 'Enter a name.';

  @override
  String get pairingRemoveTitle => 'Remove saved device?';

  @override
  String get pairingRemoveActiveBody =>
      'This is the currently connected device. Removing it may disconnect your current control session.';

  @override
  String pairingRemoveSavedBody(String deviceName) {
    return 'This will remove \"$deviceName\" from saved devices.';
  }

  @override
  String get pairingDeviceInfoTitle => 'Device Info';

  @override
  String get pairingDeviceInfoLabelName => 'Name';

  @override
  String get pairingDeviceInfoLabelBrand => 'Brand';

  @override
  String get pairingDeviceInfoLabelModel => 'Model';

  @override
  String get pairingDeviceInfoLabelVariant => 'Variant';

  @override
  String get pairingDeviceInfoLabelPairedOn => 'Paired on';

  @override
  String get pairingDeviceInfoLabelLastIp => 'Last known IP';

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

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearanceSectionTitle => 'Appearance';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeSystemSubtitle =>
      'Match your device light or dark mode';

  @override
  String get settingsDebugSectionTitle => 'Debug';

  @override
  String get settingsUseFakeTransportsTitle => 'Use fake transports';

  @override
  String get settingsUseFakeTransportsEnabled =>
      'Using fake discovery and fake transport clients.';

  @override
  String get settingsUseFakeTransportsDisabled =>
      'Using real discovery and real transport clients.';

  @override
  String get settingsCopyTransportLogs => 'Copy transport logs';

  @override
  String get settingsDiagnosticsSummaryTitle => 'Session diagnostics';

  @override
  String settingsDiagnosticsDiscoveryLine(int attempts, String rate) {
    return 'Discovery: $attempts attempts, $rate found a TV';
  }

  @override
  String settingsDiagnosticsPairingLine(int succeeded, int failed) {
    return 'Pairing sessions: $succeeded ok, $failed failed';
  }

  @override
  String settingsDiagnosticsUnhandledLine(int count) {
    return 'Unhandled errors: $count';
  }

  @override
  String get settingsCopyDiagnosticsReport => 'Copy diagnostics report';

  @override
  String get settingsCopyRuntimeFlagsTemplate => 'Copy runtime flags template';

  @override
  String get settingsCopyRuntimeFlagsTemplateSubtitle =>
      'Paste and fill dart-define values.';

  @override
  String get proSectionTitle => 'Pro';

  @override
  String get proStatusActive => 'Active';

  @override
  String get proStatusNotActive => 'Pro is not active.';

  @override
  String get proStatusChecking => 'Checking purchase status...';

  @override
  String get proStoreAccountHintGooglePlay =>
      'Your purchase is tied to your current Google Play account. Use Restore on a new phone with the same account.';

  @override
  String get proStoreAccountHintAppStore =>
      'Your purchase is tied to your current App Store account. Use Restore on a new phone with the same account.';

  @override
  String get proUpgradeButton => 'Upgrade to Pro';

  @override
  String get proRestoreButton => 'Restore purchases';

  @override
  String get proStoreUnavailable =>
      'Store purchases are unavailable on this device.';

  @override
  String get proPurchaseStarted => 'Purchase flow started.';

  @override
  String get proRestoreStarted => 'Restoring purchases...';

  @override
  String get settingsLegalSectionTitle => 'Legal';

  @override
  String get settingsPrivacyPolicy => 'Privacy policy';

  @override
  String get settingsAdPrivacyOptions => 'Ad privacy settings';

  @override
  String get settingsLegalLinkFailed => 'Could not open the link.';
}
