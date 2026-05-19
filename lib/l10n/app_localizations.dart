import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'OneRemote'**
  String get appTitle;

  /// No description provided for @uiCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get uiCancel;

  /// No description provided for @uiDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get uiDone;

  /// No description provided for @uiDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get uiDismiss;

  /// No description provided for @uiConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get uiConfirm;

  /// No description provided for @uiContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get uiContinue;

  /// No description provided for @uiRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get uiRename;

  /// No description provided for @uiRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get uiRemove;

  /// No description provided for @connectionStateConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectionStateConnected;

  /// No description provided for @connectionStateConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connectionStateConnecting;

  /// No description provided for @connectionStateError.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get connectionStateError;

  /// No description provided for @connectionStateDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get connectionStateDisconnected;

  /// No description provided for @connectTvTooltip.
  ///
  /// In en, this message translates to:
  /// **'Connect TV'**
  String get connectTvTooltip;

  /// No description provided for @layoutEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit layout'**
  String get layoutEditTooltip;

  /// No description provided for @layoutEditDoneTooltip.
  ///
  /// In en, this message translates to:
  /// **'Done editing layout'**
  String get layoutEditDoneTooltip;

  /// No description provided for @proLayoutLockedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pro required to edit layout'**
  String get proLayoutLockedTooltip;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @layoutEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Layout Editor'**
  String get layoutEditorTitle;

  /// No description provided for @layoutEditorResetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset Layout'**
  String get layoutEditorResetButton;

  /// No description provided for @layoutEditorInstruction.
  ///
  /// In en, this message translates to:
  /// **'Drag buttons to new positions. Grid lines show cells; a green outline means the drop is allowed.'**
  String get layoutEditorInstruction;

  /// No description provided for @remoteTextEntrySheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Send text to TV'**
  String get remoteTextEntrySheetTitle;

  /// No description provided for @remoteTextEntryHint.
  ///
  /// In en, this message translates to:
  /// **'Search or enter text'**
  String get remoteTextEntryHint;

  /// No description provided for @remoteTextEntrySendButton.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get remoteTextEntrySendButton;

  /// No description provided for @dpadUp.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get dpadUp;

  /// No description provided for @dpadDown.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get dpadDown;

  /// No description provided for @dpadLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get dpadLeft;

  /// No description provided for @dpadRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get dpadRight;

  /// No description provided for @dpadOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get dpadOk;

  /// No description provided for @pairingNoAdapter.
  ///
  /// In en, this message translates to:
  /// **'No adapter configured for {brandName}.'**
  String pairingNoAdapter(String brandName);

  /// No description provided for @pairingApproved.
  ///
  /// In en, this message translates to:
  /// **'Pairing approved for {deviceName}.'**
  String pairingApproved(String deviceName);

  /// No description provided for @pairingFailed.
  ///
  /// In en, this message translates to:
  /// **'Pairing failed for {deviceName}.'**
  String pairingFailed(String deviceName);

  /// No description provided for @pairingCodeAccepted.
  ///
  /// In en, this message translates to:
  /// **'Pairing code accepted for {deviceName}.'**
  String pairingCodeAccepted(String deviceName);

  /// No description provided for @pairingCodeSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit pairing code for {deviceName}.'**
  String pairingCodeSubmitFailed(String deviceName);

  /// No description provided for @pairingLgProgressHint.
  ///
  /// In en, this message translates to:
  /// **'Look at your TV screen and accept the pairing prompt.'**
  String get pairingLgProgressHint;

  /// No description provided for @pairingSamsungProgressHint.
  ///
  /// In en, this message translates to:
  /// **'Accept any connection permission that appears on your TV.'**
  String get pairingSamsungProgressHint;

  /// No description provided for @pairingHisenseProgressHint.
  ///
  /// In en, this message translates to:
  /// **'Connecting to TV…'**
  String get pairingHisenseProgressHint;

  /// No description provided for @pairingLgPreStep0.
  ///
  /// In en, this message translates to:
  /// **'Your LG TV is ON and connected to the same Wi-Fi.'**
  String get pairingLgPreStep0;

  /// No description provided for @pairingLgPreStep1.
  ///
  /// In en, this message translates to:
  /// **'When the pairing request appears on your TV screen, tap \'Allow\'.'**
  String get pairingLgPreStep1;

  /// No description provided for @pairingSamsungPreStep0.
  ///
  /// In en, this message translates to:
  /// **'Your Samsung TV is ON and connected to the same Wi-Fi.'**
  String get pairingSamsungPreStep0;

  /// No description provided for @pairingSamsungPreStep1.
  ///
  /// In en, this message translates to:
  /// **'Accept any connection permission that appears on your TV.'**
  String get pairingSamsungPreStep1;

  /// No description provided for @pairingAndroidTvProgressHint.
  ///
  /// In en, this message translates to:
  /// **'A PIN will appear on your TV screen — enter it when prompted.'**
  String get pairingAndroidTvProgressHint;

  /// No description provided for @pairingAndroidTvPreStep0.
  ///
  /// In en, this message translates to:
  /// **'Your Android TV or Google TV is ON and on the same Wi-Fi.'**
  String get pairingAndroidTvPreStep0;

  /// No description provided for @pairingAndroidTvPreStep1.
  ///
  /// In en, this message translates to:
  /// **'A PIN will appear on your TV screen — enter it when prompted.'**
  String get pairingAndroidTvPreStep1;

  /// No description provided for @pairingRokuProgressHint.
  ///
  /// In en, this message translates to:
  /// **'Make sure mobile control is enabled in Roku settings.'**
  String get pairingRokuProgressHint;

  /// No description provided for @pairingRokuPreStep0.
  ///
  /// In en, this message translates to:
  /// **'On TV, open Settings > System > Advanced system settings.'**
  String get pairingRokuPreStep0;

  /// No description provided for @pairingRokuPreStep1.
  ///
  /// In en, this message translates to:
  /// **'Set Control by mobile apps to Enabled.'**
  String get pairingRokuPreStep1;

  /// No description provided for @pairingTclLegacyProgressHint.
  ///
  /// In en, this message translates to:
  /// **'Connecting using legacy TCL Wi-Fi transport.'**
  String get pairingTclLegacyProgressHint;

  /// No description provided for @pairingTclLegacyPreStep0.
  ///
  /// In en, this message translates to:
  /// **'Legacy TCL Wi-Fi requires the TV IP address on port 4123.'**
  String get pairingTclLegacyPreStep0;

  /// No description provided for @pairingTclLegacyPreStep1.
  ///
  /// In en, this message translates to:
  /// **'Power-on may still require the original remote, CEC, or WOL.'**
  String get pairingTclLegacyPreStep1;

  /// No description provided for @pairingWaitingForApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for TV approval...'**
  String get pairingWaitingForApproval;

  /// No description provided for @pairingNotePreviouslyPaired.
  ///
  /// In en, this message translates to:
  /// **'Previously paired'**
  String get pairingNotePreviouslyPaired;

  /// No description provided for @pairingNotePreviouslyPairedAt.
  ///
  /// In en, this message translates to:
  /// **'Previously paired ({pairedAt})'**
  String pairingNotePreviouslyPairedAt(String pairedAt);

  /// No description provided for @pairingDevicePairedOn.
  ///
  /// In en, this message translates to:
  /// **'(paired on {pairedAt})'**
  String pairingDevicePairedOn(String pairedAt);

  /// No description provided for @pairingDeviceRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed {deviceName}'**
  String pairingDeviceRemoved(String deviceName);

  /// No description provided for @pairingExceptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Pairing failed. Please try again.'**
  String get pairingExceptionFailed;

  /// No description provided for @pairingDiscoveryFailed.
  ///
  /// In en, this message translates to:
  /// **'Discovery failed. Please try again.'**
  String get pairingDiscoveryFailed;

  /// No description provided for @pairingNoTvConnected.
  ///
  /// In en, this message translates to:
  /// **'No TV connected'**
  String get pairingNoTvConnected;

  /// No description provided for @pairingNoDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No TVs found yet. Run a scan to discover devices.'**
  String get pairingNoDevicesFound;

  /// No description provided for @pairingAddManuallyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add manually'**
  String get pairingAddManuallyTooltip;

  /// No description provided for @pairingScanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Scan for TVs'**
  String get pairingScanTooltip;

  /// No description provided for @pairingSelectRemoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Remote'**
  String get pairingSelectRemoteTitle;

  /// No description provided for @pairingHelpTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pairing help'**
  String get pairingHelpTooltip;

  /// No description provided for @pairingRenameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get pairingRenameTooltip;

  /// No description provided for @pairingDeviceInfoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Device info'**
  String get pairingDeviceInfoTooltip;

  /// No description provided for @pairingNeedHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Need help finding your TV?'**
  String get pairingNeedHelpTitle;

  /// No description provided for @pairingPermissionChecklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission and network checklist'**
  String get pairingPermissionChecklistTitle;

  /// No description provided for @pairingPermissionChecklistBody.
  ///
  /// In en, this message translates to:
  /// **'- Keep phone and TV on the same Wi-Fi network.\n- Allow local network/Wi-Fi permissions when prompted.\n- Disable client/AP isolation on your router if enabled.'**
  String get pairingPermissionChecklistBody;

  /// No description provided for @pairingCannotFindTvTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot find TV? Try this'**
  String get pairingCannotFindTvTitle;

  /// No description provided for @pairingCannotFindTvBody.
  ///
  /// In en, this message translates to:
  /// **'- Run Scan for TVs again and wait a few seconds.\n- Use Add Manually with the TV IP address.\n- Restart TV network, then re-open the pairing screen.'**
  String get pairingCannotFindTvBody;

  /// No description provided for @pairingManualTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual Pairing'**
  String get pairingManualTitle;

  /// No description provided for @pairingManualBrandLabel.
  ///
  /// In en, this message translates to:
  /// **'TV brand'**
  String get pairingManualBrandLabel;

  /// No description provided for @pairingManualIpLabel.
  ///
  /// In en, this message translates to:
  /// **'TV IP address'**
  String get pairingManualIpLabel;

  /// No description provided for @pairingManualIpHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 192.168.1.20'**
  String get pairingManualIpHint;

  /// No description provided for @pairingManualAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add Manually'**
  String get pairingManualAddButton;

  /// No description provided for @pairingManualErrorEmptyIp.
  ///
  /// In en, this message translates to:
  /// **'Enter a TV IP address.'**
  String get pairingManualErrorEmptyIp;

  /// No description provided for @pairingManualErrorInvalidIp.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid IPv4 address (e.g. 192.168.1.20).'**
  String get pairingManualErrorInvalidIp;

  /// No description provided for @pairingPreCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Before pairing with {brandName}'**
  String pairingPreCheckTitle(String brandName);

  /// No description provided for @pairingPreCheckMakeSure.
  ///
  /// In en, this message translates to:
  /// **'Make sure:'**
  String get pairingPreCheckMakeSure;

  /// No description provided for @pairingPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter TV pairing code'**
  String get pairingPinTitle;

  /// No description provided for @pairingPinBody.
  ///
  /// In en, this message translates to:
  /// **'A code will appear on your TV screen — enter it below to finish pairing.'**
  String get pairingPinBody;

  /// No description provided for @pairingPinCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'4-digit TV code'**
  String get pairingPinCodeLabel;

  /// No description provided for @pairingPinCodeLabelHex.
  ///
  /// In en, this message translates to:
  /// **'6-character code (e.g. A4B2C1)'**
  String get pairingPinCodeLabelHex;

  /// No description provided for @pairingPinSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Submit code'**
  String get pairingPinSubmitButton;

  /// No description provided for @pairingPinErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter exactly 4 digits.'**
  String get pairingPinErrorInvalid;

  /// No description provided for @pairingPinErrorInvalidHex.
  ///
  /// In en, this message translates to:
  /// **'Enter exactly 6 characters (0–9, A–F).'**
  String get pairingPinErrorInvalidHex;

  /// No description provided for @pairingOutcomeSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Paired successfully'**
  String get pairingOutcomeSuccessTitle;

  /// No description provided for @pairingOutcomeFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Pairing failed'**
  String get pairingOutcomeFailureTitle;

  /// No description provided for @pairingOutcomeSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'{deviceName} is ready to use.'**
  String pairingOutcomeSuccessBody(String deviceName);

  /// No description provided for @pairingRenameDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename TV'**
  String get pairingRenameDialogTitle;

  /// No description provided for @pairingRenameNameLabel.
  ///
  /// In en, this message translates to:
  /// **'TV name'**
  String get pairingRenameNameLabel;

  /// No description provided for @pairingRenameErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get pairingRenameErrorEmpty;

  /// No description provided for @pairingRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove saved device?'**
  String get pairingRemoveTitle;

  /// No description provided for @pairingRemoveActiveBody.
  ///
  /// In en, this message translates to:
  /// **'This is the currently connected device. Removing it may disconnect your current control session.'**
  String get pairingRemoveActiveBody;

  /// No description provided for @pairingRemoveSavedBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove \"{deviceName}\" from saved devices.'**
  String pairingRemoveSavedBody(String deviceName);

  /// No description provided for @pairingDeviceInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Info'**
  String get pairingDeviceInfoTitle;

  /// No description provided for @pairingDeviceInfoLabelName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get pairingDeviceInfoLabelName;

  /// No description provided for @pairingDeviceInfoLabelBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get pairingDeviceInfoLabelBrand;

  /// No description provided for @pairingDeviceInfoLabelModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get pairingDeviceInfoLabelModel;

  /// No description provided for @pairingDeviceInfoLabelVariant.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get pairingDeviceInfoLabelVariant;

  /// No description provided for @pairingDeviceInfoLabelPairedOn.
  ///
  /// In en, this message translates to:
  /// **'Paired on'**
  String get pairingDeviceInfoLabelPairedOn;

  /// No description provided for @pairingDeviceInfoLabelLastIp.
  ///
  /// In en, this message translates to:
  /// **'Last known IP'**
  String get pairingDeviceInfoLabelLastIp;

  /// No description provided for @remoteCommandUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Command {commandName} is not supported for {brandName}.'**
  String remoteCommandUnsupported(String commandName, String brandName);

  /// No description provided for @remoteCommandSent.
  ///
  /// In en, this message translates to:
  /// **'Sent: {commandName}'**
  String remoteCommandSent(String commandName);

  /// No description provided for @remoteCommandFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send command to {deviceName}.'**
  String remoteCommandFailed(String deviceName);

  /// No description provided for @remoteTextInputUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Text input is not supported for {brandName}.'**
  String remoteTextInputUnsupported(String brandName);

  /// No description provided for @remoteTextSent.
  ///
  /// In en, this message translates to:
  /// **'Text sent: \"{text}\"'**
  String remoteTextSent(String text);

  /// No description provided for @remoteTextFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send text to {deviceName}.'**
  String remoteTextFailed(String deviceName);

  /// No description provided for @remoteTextLgImeFocusRequired.
  ///
  /// In en, this message translates to:
  /// **'LG IME text injection rejected — ensure a text field is focused on the TV.'**
  String get remoteTextLgImeFocusRequired;

  /// No description provided for @remoteTextSamsungCompatibilityError.
  ///
  /// In en, this message translates to:
  /// **'Typing from this phone is not available on this TV screen or app. Use the TV on-screen keyboard and direction buttons to enter text.'**
  String get remoteTextSamsungCompatibilityError;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsDebugSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get settingsDebugSectionTitle;

  /// No description provided for @settingsUseFakeTransportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Use fake transports'**
  String get settingsUseFakeTransportsTitle;

  /// No description provided for @settingsUseFakeTransportsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Using fake discovery and fake transport clients.'**
  String get settingsUseFakeTransportsEnabled;

  /// No description provided for @settingsUseFakeTransportsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Using real discovery and real transport clients.'**
  String get settingsUseFakeTransportsDisabled;

  /// No description provided for @settingsCopyTransportLogs.
  ///
  /// In en, this message translates to:
  /// **'Copy transport logs'**
  String get settingsCopyTransportLogs;

  /// No description provided for @settingsCopyRuntimeFlagsTemplate.
  ///
  /// In en, this message translates to:
  /// **'Copy runtime flags template'**
  String get settingsCopyRuntimeFlagsTemplate;

  /// No description provided for @settingsCopyRuntimeFlagsTemplateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste and fill dart-define values.'**
  String get settingsCopyRuntimeFlagsTemplateSubtitle;

  /// No description provided for @proSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get proSectionTitle;

  /// No description provided for @proStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Pro is active.'**
  String get proStatusActive;

  /// No description provided for @proStatusNotActive.
  ///
  /// In en, this message translates to:
  /// **'Pro is not active.'**
  String get proStatusNotActive;

  /// No description provided for @proStatusChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking purchase status...'**
  String get proStatusChecking;

  /// No description provided for @proStoreAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Your purchase is tied to your current Google Play or App Store account. Use Restore on a new phone with the same account.'**
  String get proStoreAccountHint;

  /// No description provided for @proUpgradeButton.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get proUpgradeButton;

  /// No description provided for @proRestoreButton.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get proRestoreButton;

  /// No description provided for @proStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Store purchases are unavailable on this device.'**
  String get proStoreUnavailable;

  /// No description provided for @proPurchaseStarted.
  ///
  /// In en, this message translates to:
  /// **'Purchase flow started.'**
  String get proPurchaseStarted;

  /// No description provided for @proRestoreStarted.
  ///
  /// In en, this message translates to:
  /// **'Restoring purchases...'**
  String get proRestoreStarted;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
