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
