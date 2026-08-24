import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_pa.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
    Locale('es'),
    Locale('gu'),
    Locale('hi'),
    Locale('kn'),
    Locale('ml'),
    Locale('mr'),
    Locale('pa'),
    Locale('ta'),
    Locale('te'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'RV Astro Vastu'**
  String get appName;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to RV Astro Vastu'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your personalized astrology journey starts here.'**
  String get welcomeSubtitle;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @languagePreference.
  ///
  /// In en, this message translates to:
  /// **'Language Preference'**
  String get languagePreference;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @birthProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Your Birth Profile'**
  String get birthProfileTitle;

  /// No description provided for @birthProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Accurate birth details help us create your personalized astrology experience.'**
  String get birthProfileSubtitle;

  /// No description provided for @basicInformation.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get basicInformation;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @enterYourName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterYourName;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirth;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// No description provided for @exactBirthTime.
  ///
  /// In en, this message translates to:
  /// **'Exact Birth Time'**
  String get exactBirthTime;

  /// No description provided for @selectTime.
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get selectTime;

  /// No description provided for @placeOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Place of Birth'**
  String get placeOfBirth;

  /// No description provided for @searchCity.
  ///
  /// In en, this message translates to:
  /// **'Search city'**
  String get searchCity;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @kundali.
  ///
  /// In en, this message translates to:
  /// **'Kundali'**
  String get kundali;

  /// No description provided for @horoscope.
  ///
  /// In en, this message translates to:
  /// **'Horoscope'**
  String get horoscope;

  /// No description provided for @panchang.
  ///
  /// In en, this message translates to:
  /// **'Panchang'**
  String get panchang;

  /// No description provided for @dasha.
  ///
  /// In en, this message translates to:
  /// **'Dasha'**
  String get dasha;

  /// No description provided for @vastu.
  ///
  /// In en, this message translates to:
  /// **'Vastu'**
  String get vastu;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @dailyHoroscope.
  ///
  /// In en, this message translates to:
  /// **'Daily Horoscope'**
  String get dailyHoroscope;

  /// No description provided for @todaysHoroscope.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Horoscope'**
  String get todaysHoroscope;

  /// No description provided for @birthChart.
  ///
  /// In en, this message translates to:
  /// **'Birth Chart'**
  String get birthChart;

  /// No description provided for @planetaryPositions.
  ///
  /// In en, this message translates to:
  /// **'Planetary Positions'**
  String get planetaryPositions;

  /// No description provided for @currentDasha.
  ///
  /// In en, this message translates to:
  /// **'Current Dasha'**
  String get currentDasha;

  /// No description provided for @mahadasha.
  ///
  /// In en, this message translates to:
  /// **'Mahadasha'**
  String get mahadasha;

  /// No description provided for @antardasha.
  ///
  /// In en, this message translates to:
  /// **'Antardasha'**
  String get antardasha;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @pleaseEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get pleaseEnterName;

  /// No description provided for @pleaseSelectGender.
  ///
  /// In en, this message translates to:
  /// **'Please select gender'**
  String get pleaseSelectGender;

  /// No description provided for @pleaseSelectDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Please select date of birth'**
  String get pleaseSelectDateOfBirth;

  /// No description provided for @pleaseSelectBirthTime.
  ///
  /// In en, this message translates to:
  /// **'Please select birth time'**
  String get pleaseSelectBirthTime;

  /// No description provided for @pleaseEnterBirthLocation.
  ///
  /// In en, this message translates to:
  /// **'Please enter your place of birth'**
  String get pleaseEnterBirthLocation;

  /// No description provided for @pleaseSelectBirthLocation.
  ///
  /// In en, this message translates to:
  /// **'Please select a birth location from the suggestions'**
  String get pleaseSelectBirthLocation;

  /// No description provided for @timezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get timezone;

  /// No description provided for @selectedBirthLocation.
  ///
  /// In en, this message translates to:
  /// **'Selected Birth Location'**
  String get selectedBirthLocation;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get searching;

  /// No description provided for @noLocationsFound.
  ///
  /// In en, this message translates to:
  /// **'No locations found'**
  String get noLocationsFound;

  /// No description provided for @rashiChart.
  ///
  /// In en, this message translates to:
  /// **'Rashi Chart'**
  String get rashiChart;

  /// No description provided for @nakshatra.
  ///
  /// In en, this message translates to:
  /// **'Nakshatra'**
  String get nakshatra;

  /// No description provided for @astrology.
  ///
  /// In en, this message translates to:
  /// **'Astrology'**
  String get astrology;

  /// No description provided for @muhurta.
  ///
  /// In en, this message translates to:
  /// **'Muhurat'**
  String get muhurta;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @createBirthProfile.
  ///
  /// In en, this message translates to:
  /// **'Create Birth Profile'**
  String get createBirthProfile;

  /// No description provided for @yourBirthProfile.
  ///
  /// In en, this message translates to:
  /// **'Your Birth Profile'**
  String get yourBirthProfile;

  /// No description provided for @personalizedAstrology.
  ///
  /// In en, this message translates to:
  /// **'Your Personalized Astrology'**
  String get personalizedAstrology;

  /// No description provided for @loadingKundali.
  ///
  /// In en, this message translates to:
  /// **'Preparing your Kundali...'**
  String get loadingKundali;

  /// No description provided for @calculatingChart.
  ///
  /// In en, this message translates to:
  /// **'Calculating your birth chart...'**
  String get calculatingChart;

  /// No description provided for @noBirthProfile.
  ///
  /// In en, this message translates to:
  /// **'No birth profile found'**
  String get noBirthProfile;

  /// No description provided for @pleaseCreateBirthProfile.
  ///
  /// In en, this message translates to:
  /// **'Please create your birth profile first.'**
  String get pleaseCreateBirthProfile;

  /// No description provided for @planet.
  ///
  /// In en, this message translates to:
  /// **'Planet'**
  String get planet;

  /// No description provided for @sign.
  ///
  /// In en, this message translates to:
  /// **'Sign'**
  String get sign;

  /// No description provided for @house.
  ///
  /// In en, this message translates to:
  /// **'House'**
  String get house;

  /// No description provided for @degree.
  ///
  /// In en, this message translates to:
  /// **'Degree'**
  String get degree;

  /// No description provided for @ascendant.
  ///
  /// In en, this message translates to:
  /// **'Ascendant'**
  String get ascendant;

  /// No description provided for @sun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sun;

  /// No description provided for @moon.
  ///
  /// In en, this message translates to:
  /// **'Moon'**
  String get moon;

  /// No description provided for @mars.
  ///
  /// In en, this message translates to:
  /// **'Mars'**
  String get mars;

  /// No description provided for @mercury.
  ///
  /// In en, this message translates to:
  /// **'Mercury'**
  String get mercury;

  /// No description provided for @jupiter.
  ///
  /// In en, this message translates to:
  /// **'Jupiter'**
  String get jupiter;

  /// No description provided for @venus.
  ///
  /// In en, this message translates to:
  /// **'Venus'**
  String get venus;

  /// No description provided for @saturn.
  ///
  /// In en, this message translates to:
  /// **'Saturn'**
  String get saturn;

  /// No description provided for @rahu.
  ///
  /// In en, this message translates to:
  /// **'Rahu'**
  String get rahu;

  /// No description provided for @ketu.
  ///
  /// In en, this message translates to:
  /// **'Ketu'**
  String get ketu;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @calculatingYourKundali.
  ///
  /// In en, this message translates to:
  /// **'Calculating your Kundali...'**
  String get calculatingYourKundali;

  /// No description provided for @unableToCalculateKundali.
  ///
  /// In en, this message translates to:
  /// **'Unable to calculate Kundali'**
  String get unableToCalculateKundali;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @birthProfileRequired.
  ///
  /// In en, this message translates to:
  /// **'Birth Profile Required'**
  String get birthProfileRequired;

  /// No description provided for @createBirthProfileBeforeViewingKundali.
  ///
  /// In en, this message translates to:
  /// **'Create your birth profile before viewing your Kundali.'**
  String get createBirthProfileBeforeViewingKundali;

  /// No description provided for @currentVimshottariDasha.
  ///
  /// In en, this message translates to:
  /// **'Current Vimshottari Dasha'**
  String get currentVimshottariDasha;

  /// No description provided for @currentAntardasha.
  ///
  /// In en, this message translates to:
  /// **'Current Antardasha'**
  String get currentAntardasha;

  /// No description provided for @dashaTimeline.
  ///
  /// In en, this message translates to:
  /// **'Dasha Timeline'**
  String get dashaTimeline;

  /// No description provided for @elapsed.
  ///
  /// In en, this message translates to:
  /// **'Elapsed'**
  String get elapsed;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @antardashaTimeline.
  ///
  /// In en, this message translates to:
  /// **'Antardasha Timeline'**
  String get antardashaTimeline;

  /// No description provided for @pratyantardasha.
  ///
  /// In en, this message translates to:
  /// **'Pratyantardasha'**
  String get pratyantardasha;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get active;

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'NOW'**
  String get now;

  /// No description provided for @birthProfile.
  ///
  /// In en, this message translates to:
  /// **'Birth Profile'**
  String get birthProfile;

  /// No description provided for @kundaliChart.
  ///
  /// In en, this message translates to:
  /// **'Kundali Chart'**
  String get kundaliChart;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @continueText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'bn',
    'en',
    'es',
    'gu',
    'hi',
    'kn',
    'ml',
    'mr',
    'pa',
    'ta',
    'te',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'gu':
      return AppLocalizationsGu();
    case 'hi':
      return AppLocalizationsHi();
    case 'kn':
      return AppLocalizationsKn();
    case 'ml':
      return AppLocalizationsMl();
    case 'mr':
      return AppLocalizationsMr();
    case 'pa':
      return AppLocalizationsPa();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
