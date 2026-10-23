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

  /// No description provided for @tithi.
  ///
  /// In en, this message translates to:
  /// **'Tithi'**
  String get tithi;

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

  /// No description provided for @transits.
  ///
  /// In en, this message translates to:
  /// **'Transits'**
  String get transits;

  /// No description provided for @planetary.
  ///
  /// In en, this message translates to:
  /// **'Planetary'**
  String get planetary;

  /// No description provided for @marriage.
  ///
  /// In en, this message translates to:
  /// **'Marriage'**
  String get marriage;

  /// No description provided for @analysis.
  ///
  /// In en, this message translates to:
  /// **'Analysis'**
  String get analysis;

  /// No description provided for @lagna.
  ///
  /// In en, this message translates to:
  /// **'Lagna'**
  String get lagna;

  /// No description provided for @rashi.
  ///
  /// In en, this message translates to:
  /// **'Rashi'**
  String get rashi;

  /// No description provided for @viewKundali.
  ///
  /// In en, this message translates to:
  /// **'View Kundali'**
  String get viewKundali;

  /// No description provided for @viewCompleteKundali.
  ///
  /// In en, this message translates to:
  /// **'View Complete Kundali'**
  String get viewCompleteKundali;

  /// No description provided for @dailyHoroscopeComingNext.
  ///
  /// In en, this message translates to:
  /// **'Daily Horoscope coming next'**
  String get dailyHoroscopeComingNext;

  /// No description provided for @panchangComingNext.
  ///
  /// In en, this message translates to:
  /// **'Panchang coming next'**
  String get panchangComingNext;

  /// No description provided for @planetaryTransitsComingNext.
  ///
  /// In en, this message translates to:
  /// **'Planetary Transits coming next'**
  String get planetaryTransitsComingNext;

  /// No description provided for @marriageAnalysisComingNext.
  ///
  /// In en, this message translates to:
  /// **'Marriage analysis coming next'**
  String get marriageAnalysisComingNext;

  /// No description provided for @myKundali.
  ///
  /// In en, this message translates to:
  /// **'My Kundali'**
  String get myKundali;

  /// No description provided for @moonSign.
  ///
  /// In en, this message translates to:
  /// **'Moon Sign'**
  String get moonSign;

  /// No description provided for @sunSign.
  ///
  /// In en, this message translates to:
  /// **'Sun Sign'**
  String get sunSign;

  /// No description provided for @retrograde.
  ///
  /// In en, this message translates to:
  /// **'Retrograde'**
  String get retrograde;

  /// No description provided for @padaMoonIn.
  ///
  /// In en, this message translates to:
  /// **'Pada {pada} • Moon in {moonSign}'**
  String padaMoonIn(String pada, Object moonSign, String rashi);

  /// No description provided for @northIndianWholeSign.
  ///
  /// In en, this message translates to:
  /// **'North Indian • Whole Sign'**
  String get northIndianWholeSign;

  /// No description provided for @houseShort.
  ///
  /// In en, this message translates to:
  /// **'H{house}'**
  String houseShort(Object house);

  /// No description provided for @unableToContinue.
  ///
  /// In en, this message translates to:
  /// **'Unable to continue: {error}'**
  String unableToContinue(Object error);

  /// No description provided for @rvAstroVastu.
  ///
  /// In en, this message translates to:
  /// **'RV Astro Vastu'**
  String get rvAstroVastu;

  /// No description provided for @yourAstrologyDashboard.
  ///
  /// In en, this message translates to:
  /// **'Your Astrology Dashboard'**
  String get yourAstrologyDashboard;

  /// No description provided for @yourPersonalizedCosmicJourney.
  ///
  /// In en, this message translates to:
  /// **'Your personalized cosmic journey'**
  String get yourPersonalizedCosmicJourney;

  /// No description provided for @viewYourBirthChart.
  ///
  /// In en, this message translates to:
  /// **'View your birth chart, planets, houses, Nakshatra and Dasha'**
  String get viewYourBirthChart;

  /// No description provided for @yourKundaliSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Your Kundali Snapshot'**
  String get yourKundaliSnapshot;

  /// No description provided for @vedicKundali.
  ///
  /// In en, this message translates to:
  /// **'Vedic Kundali'**
  String get vedicKundali;

  /// No description provided for @yourPersonalizedBirthChart.
  ///
  /// In en, this message translates to:
  /// **'Your personalized birth chart'**
  String get yourPersonalizedBirthChart;

  /// No description provided for @birthNakshatra.
  ///
  /// In en, this message translates to:
  /// **'Birth Nakshatra'**
  String get birthNakshatra;

  /// No description provided for @moonIn.
  ///
  /// In en, this message translates to:
  /// **'Moon in'**
  String get moonIn;

  /// No description provided for @astrologyHighlights.
  ///
  /// In en, this message translates to:
  /// **'Astrology Highlights'**
  String get astrologyHighlights;

  /// No description provided for @comingNext.
  ///
  /// In en, this message translates to:
  /// **'Coming Next'**
  String get comingNext;

  /// No description provided for @navamsaD9.
  ///
  /// In en, this message translates to:
  /// **'Navamsa D9'**
  String get navamsaD9;

  /// No description provided for @detailedDivisionalChart.
  ///
  /// In en, this message translates to:
  /// **'Detailed divisional chart'**
  String get detailedDivisionalChart;

  /// No description provided for @vimshottariDasha.
  ///
  /// In en, this message translates to:
  /// **'Vimshottari Dasha'**
  String get vimshottariDasha;

  /// No description provided for @mahadashaAndAntardashaTimeline.
  ///
  /// In en, this message translates to:
  /// **'Mahadasha and Antardasha timeline'**
  String get mahadashaAndAntardashaTimeline;

  /// No description provided for @yogasAndDoshas.
  ///
  /// In en, this message translates to:
  /// **'Yogas & Doshas'**
  String get yogasAndDoshas;

  /// No description provided for @importantCombinationsInChart.
  ///
  /// In en, this message translates to:
  /// **'Important combinations in your chart'**
  String get importantCombinationsInChart;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'RV Astro Vastu'**
  String get appTitle;

  /// No description provided for @astrologyDashboard.
  ///
  /// In en, this message translates to:
  /// **'Your Astrology Dashboard'**
  String get astrologyDashboard;

  /// No description provided for @personalizedCosmicJourney.
  ///
  /// In en, this message translates to:
  /// **'Your personalized cosmic journey'**
  String get personalizedCosmicJourney;

  /// No description provided for @viewBirthChartDescription.
  ///
  /// In en, this message translates to:
  /// **'View your birth chart, planets, houses, Nakshatra and Dasha'**
  String get viewBirthChartDescription;

  /// No description provided for @kundaliSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Your Kundali Snapshot'**
  String get kundaliSnapshot;

  /// No description provided for @personalizedBirthChart.
  ///
  /// In en, this message translates to:
  /// **'Your personalized birth chart'**
  String get personalizedBirthChart;

  /// No description provided for @mahadashaAntardashaTimeline.
  ///
  /// In en, this message translates to:
  /// **'Mahadasha and Antardasha timeline'**
  String get mahadashaAntardashaTimeline;

  /// No description provided for @yogasDoshas.
  ///
  /// In en, this message translates to:
  /// **'Yogas & Doshas'**
  String get yogasDoshas;

  /// No description provided for @importantCombinations.
  ///
  /// In en, this message translates to:
  /// **'Important combinations in your chart'**
  String get importantCombinations;

  /// No description provided for @editBirthProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Birth Profile'**
  String get editBirthProfile;

  /// No description provided for @aries.
  ///
  /// In en, this message translates to:
  /// **'Aries'**
  String get aries;

  /// No description provided for @taurus.
  ///
  /// In en, this message translates to:
  /// **'Taurus'**
  String get taurus;

  /// No description provided for @gemini.
  ///
  /// In en, this message translates to:
  /// **'Gemini'**
  String get gemini;

  /// No description provided for @cancer.
  ///
  /// In en, this message translates to:
  /// **'Cancer'**
  String get cancer;

  /// No description provided for @leo.
  ///
  /// In en, this message translates to:
  /// **'Leo'**
  String get leo;

  /// No description provided for @virgo.
  ///
  /// In en, this message translates to:
  /// **'Virgo'**
  String get virgo;

  /// No description provided for @libra.
  ///
  /// In en, this message translates to:
  /// **'Libra'**
  String get libra;

  /// No description provided for @scorpio.
  ///
  /// In en, this message translates to:
  /// **'Scorpio'**
  String get scorpio;

  /// No description provided for @sagittarius.
  ///
  /// In en, this message translates to:
  /// **'Sagittarius'**
  String get sagittarius;

  /// No description provided for @capricorn.
  ///
  /// In en, this message translates to:
  /// **'Capricorn'**
  String get capricorn;

  /// No description provided for @aquarius.
  ///
  /// In en, this message translates to:
  /// **'Aquarius'**
  String get aquarius;

  /// No description provided for @pisces.
  ///
  /// In en, this message translates to:
  /// **'Pisces'**
  String get pisces;

  /// No description provided for @ashwini.
  ///
  /// In en, this message translates to:
  /// **'Ashwini'**
  String get ashwini;

  /// No description provided for @bharani.
  ///
  /// In en, this message translates to:
  /// **'Bharani'**
  String get bharani;

  /// No description provided for @krittika.
  ///
  /// In en, this message translates to:
  /// **'Krittika'**
  String get krittika;

  /// No description provided for @rohini.
  ///
  /// In en, this message translates to:
  /// **'Rohini'**
  String get rohini;

  /// No description provided for @mrigashira.
  ///
  /// In en, this message translates to:
  /// **'Mrigashira'**
  String get mrigashira;

  /// No description provided for @ardra.
  ///
  /// In en, this message translates to:
  /// **'Ardra'**
  String get ardra;

  /// No description provided for @punarvasu.
  ///
  /// In en, this message translates to:
  /// **'Punarvasu'**
  String get punarvasu;

  /// No description provided for @pushya.
  ///
  /// In en, this message translates to:
  /// **'Pushya'**
  String get pushya;

  /// No description provided for @ashlesha.
  ///
  /// In en, this message translates to:
  /// **'Ashlesha'**
  String get ashlesha;

  /// No description provided for @magha.
  ///
  /// In en, this message translates to:
  /// **'Magha'**
  String get magha;

  /// No description provided for @purvaPhalguni.
  ///
  /// In en, this message translates to:
  /// **'Purva Phalguni'**
  String get purvaPhalguni;

  /// No description provided for @uttaraPhalguni.
  ///
  /// In en, this message translates to:
  /// **'Uttara Phalguni'**
  String get uttaraPhalguni;

  /// No description provided for @hasta.
  ///
  /// In en, this message translates to:
  /// **'Hasta'**
  String get hasta;

  /// No description provided for @chitra.
  ///
  /// In en, this message translates to:
  /// **'Chitra'**
  String get chitra;

  /// No description provided for @swati.
  ///
  /// In en, this message translates to:
  /// **'Swati'**
  String get swati;

  /// No description provided for @vishakha.
  ///
  /// In en, this message translates to:
  /// **'Vishakha'**
  String get vishakha;

  /// No description provided for @anuradha.
  ///
  /// In en, this message translates to:
  /// **'Anuradha'**
  String get anuradha;

  /// No description provided for @jyeshtha.
  ///
  /// In en, this message translates to:
  /// **'Jyeshtha'**
  String get jyeshtha;

  /// No description provided for @mula.
  ///
  /// In en, this message translates to:
  /// **'Mula'**
  String get mula;

  /// No description provided for @purvaAshadha.
  ///
  /// In en, this message translates to:
  /// **'Purva Ashadha'**
  String get purvaAshadha;

  /// No description provided for @uttaraAshadha.
  ///
  /// In en, this message translates to:
  /// **'Uttara Ashadha'**
  String get uttaraAshadha;

  /// No description provided for @shravana.
  ///
  /// In en, this message translates to:
  /// **'Shravana'**
  String get shravana;

  /// No description provided for @dhanishta.
  ///
  /// In en, this message translates to:
  /// **'Dhanishta'**
  String get dhanishta;

  /// No description provided for @shatabhisha.
  ///
  /// In en, this message translates to:
  /// **'Shatabhisha'**
  String get shatabhisha;

  /// No description provided for @purvaBhadrapada.
  ///
  /// In en, this message translates to:
  /// **'Purva Bhadrapada'**
  String get purvaBhadrapada;

  /// No description provided for @uttaraBhadrapada.
  ///
  /// In en, this message translates to:
  /// **'Uttara Bhadrapada'**
  String get uttaraBhadrapada;

  /// No description provided for @revati.
  ///
  /// In en, this message translates to:
  /// **'Revati'**
  String get revati;

  /// No description provided for @pada.
  ///
  /// In en, this message translates to:
  /// **'Pada'**
  String get pada;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get homeGreetingEvening;

  /// No description provided for @homeGreetingNight.
  ///
  /// In en, this message translates to:
  /// **'Good Night'**
  String get homeGreetingNight;

  /// No description provided for @homeCosmicSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Cosmic Snapshot'**
  String get homeCosmicSnapshot;

  /// No description provided for @homeCosmicSnapshotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your personal celestial overview'**
  String get homeCosmicSnapshotSubtitle;

  /// No description provided for @homeCurrentDasha.
  ///
  /// In en, this message translates to:
  /// **'CURRENT DASHA'**
  String get homeCurrentDasha;

  /// No description provided for @homeCalculatingPlanetaryPeriod.
  ///
  /// In en, this message translates to:
  /// **'Calculating your planetary period…'**
  String get homeCalculatingPlanetaryPeriod;

  /// No description provided for @homeAntardasha.
  ///
  /// In en, this message translates to:
  /// **'Antardasha: {planet}'**
  String homeAntardasha(Object planet);

  /// No description provided for @homeTodaysPanchang.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Panchang'**
  String get homeTodaysPanchang;

  /// No description provided for @homePanchangTimezone.
  ///
  /// In en, this message translates to:
  /// **'Panchang calculated for your current location.'**
  String get homePanchangTimezone;

  /// No description provided for @homeUnableToDetermineLocation.
  ///
  /// In en, this message translates to:
  /// **'Unable to determine current location.'**
  String get homeUnableToDetermineLocation;

  /// No description provided for @homeEnableLocationAccess.
  ///
  /// In en, this message translates to:
  /// **'Enable location access and try again.'**
  String get homeEnableLocationAccess;

  /// No description provided for @homeUseCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use Current Location'**
  String get homeUseCurrentLocation;

  /// No description provided for @homeCurrentLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Current location is unavailable.'**
  String get homeCurrentLocationUnavailable;

  /// No description provided for @homeUnableToCalculatePanchang.
  ///
  /// In en, this message translates to:
  /// **'Unable to calculate Panchang.'**
  String get homeUnableToCalculatePanchang;

  /// No description provided for @homeMoonrise.
  ///
  /// In en, this message translates to:
  /// **'Moonrise'**
  String get homeMoonrise;

  /// No description provided for @homeViewTimings.
  ///
  /// In en, this message translates to:
  /// **'View timings'**
  String get homeViewTimings;

  /// No description provided for @homeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get homeToday;

  /// No description provided for @homeDailyHoroscope.
  ///
  /// In en, this message translates to:
  /// **'Your Daily Horoscope'**
  String get homeDailyHoroscope;

  /// No description provided for @homeDailyHoroscopeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Personalized guidance from your chart'**
  String get homeDailyHoroscopeSubtitle;

  /// No description provided for @homeCareer.
  ///
  /// In en, this message translates to:
  /// **'Career'**
  String get homeCareer;

  /// No description provided for @homeCareerGuidance.
  ///
  /// In en, this message translates to:
  /// **'Focus on priorities, communication and steady execution today.'**
  String get homeCareerGuidance;

  /// No description provided for @homeFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get homeFinance;

  /// No description provided for @homeFinanceGuidance.
  ///
  /// In en, this message translates to:
  /// **'Review important financial decisions carefully and avoid unnecessary impulsive choices.'**
  String get homeFinanceGuidance;

  /// No description provided for @homeRelationships.
  ///
  /// In en, this message translates to:
  /// **'Relationships'**
  String get homeRelationships;

  /// No description provided for @homeRelationshipsGuidance.
  ///
  /// In en, this message translates to:
  /// **'Patience and clear communication can create better understanding today.'**
  String get homeRelationshipsGuidance;

  /// No description provided for @homeDashaInsight.
  ///
  /// In en, this message translates to:
  /// **'Dasha Insight'**
  String get homeDashaInsight;

  /// No description provided for @homeDashaInsightDescription.
  ///
  /// In en, this message translates to:
  /// **'Your current planetary period will appear here.'**
  String get homeDashaInsightDescription;

  /// No description provided for @homeDashaInsightDescriptionWithPlanet.
  ///
  /// In en, this message translates to:
  /// **'Your current planetary period is {planet}. Tap to explore the complete Dasha timeline.'**
  String homeDashaInsightDescriptionWithPlanet(Object planet);

  /// No description provided for @homeTransitInsight.
  ///
  /// In en, this message translates to:
  /// **'Transit Insight'**
  String get homeTransitInsight;

  /// No description provided for @homeTransitInsightDescription.
  ///
  /// In en, this message translates to:
  /// **'See how current planetary movements interact with your birth chart.'**
  String get homeTransitInsightDescription;

  /// No description provided for @homeVastuTipOfTheDay.
  ///
  /// In en, this message translates to:
  /// **'Vastu Tip of the Day'**
  String get homeVastuTipOfTheDay;

  /// No description provided for @homeVastuTipDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep the entrance area clean, welcoming and free from unnecessary clutter.'**
  String get homeVastuTipDescription;

  /// No description provided for @homeMyKundali.
  ///
  /// In en, this message translates to:
  /// **'My Kundali'**
  String get homeMyKundali;

  /// No description provided for @homeBirthProfile.
  ///
  /// In en, this message translates to:
  /// **'Birth Profile'**
  String get homeBirthProfile;

  /// No description provided for @homeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get homeLanguage;

  /// No description provided for @homeEditBirthProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit birth profile'**
  String get homeEditBirthProfile;

  /// No description provided for @homeUnableToCalculateKundali.
  ///
  /// In en, this message translates to:
  /// **'Unable to calculate your Kundali'**
  String get homeUnableToCalculateKundali;

  /// No description provided for @homePleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please try again.'**
  String get homePleaseTryAgain;

  /// No description provided for @homeRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get homeRetry;

  /// No description provided for @homeCompleteBirthProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete your Birth Profile'**
  String get homeCompleteBirthProfile;

  /// No description provided for @homeBirthProfileDescription.
  ///
  /// In en, this message translates to:
  /// **'Add your birth details to unlock your personalized cosmic dashboard.'**
  String get homeBirthProfileDescription;

  /// No description provided for @homeSetUpProfile.
  ///
  /// In en, this message translates to:
  /// **'Set Up Profile'**
  String get homeSetUpProfile;

  /// No description provided for @homeYourCosmicJourney.
  ///
  /// In en, this message translates to:
  /// **'Your Cosmic Journey'**
  String get homeYourCosmicJourney;

  /// No description provided for @homeRashi.
  ///
  /// In en, this message translates to:
  /// **'Rashi'**
  String get homeRashi;

  /// No description provided for @homeNakshatra.
  ///
  /// In en, this message translates to:
  /// **'Nakshatra'**
  String get homeNakshatra;

  /// No description provided for @homeLagna.
  ///
  /// In en, this message translates to:
  /// **'Lagna'**
  String get homeLagna;

  /// No description provided for @homeMuhurat.
  ///
  /// In en, this message translates to:
  /// **'Muhurat'**
  String get homeMuhurat;

  /// No description provided for @homeAuspicious.
  ///
  /// In en, this message translates to:
  /// **'Auspicious'**
  String get homeAuspicious;

  /// No description provided for @homeRahuKaal.
  ///
  /// In en, this message translates to:
  /// **'Rahu Kaal'**
  String get homeRahuKaal;

  /// No description provided for @homeAvoidImportantWork.
  ///
  /// In en, this message translates to:
  /// **'Avoid important work'**
  String get homeAvoidImportantWork;

  /// No description provided for @homeYourDay.
  ///
  /// In en, this message translates to:
  /// **'Your Day'**
  String get homeYourDay;

  /// No description provided for @homeViewDasha.
  ///
  /// In en, this message translates to:
  /// **'View Dasha'**
  String get homeViewDasha;

  /// No description provided for @homeViewTransits.
  ///
  /// In en, this message translates to:
  /// **'View Transits'**
  String get homeViewTransits;

  /// No description provided for @homeExploreVastu.
  ///
  /// In en, this message translates to:
  /// **'Explore Vastu'**
  String get homeExploreVastu;

  /// No description provided for @homePersonalizedPlanetaryAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Personalized planetary analysis'**
  String get homePersonalizedPlanetaryAnalysis;

  /// No description provided for @homeDailyVastuGuidance.
  ///
  /// In en, this message translates to:
  /// **'Daily Vastu guidance'**
  String get homeDailyVastuGuidance;

  /// No description provided for @homeDashaInsightDescriptionDashboard.
  ///
  /// In en, this message translates to:
  /// **'Your current planetary period and its influence on today.'**
  String get homeDashaInsightDescriptionDashboard;

  /// No description provided for @homeTransitInsightDescriptionDashboard.
  ///
  /// In en, this message translates to:
  /// **'Discover planetary movements influencing your chart.'**
  String get homeTransitInsightDescriptionDashboard;

  /// No description provided for @homeVastuTipDescriptionDashboard.
  ///
  /// In en, this message translates to:
  /// **'One practical Vastu action for your home or workspace.'**
  String get homeVastuTipDescriptionDashboard;

  /// No description provided for @homePersonalizedGuidanceComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Personalized guidance coming soon.'**
  String get homePersonalizedGuidanceComingSoon;

  /// No description provided for @homeTodaysGuidance.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S GUIDANCE'**
  String get homeTodaysGuidance;

  /// No description provided for @homeTithi.
  ///
  /// In en, this message translates to:
  /// **'Tithi'**
  String get homeTithi;

  /// No description provided for @homeYoga.
  ///
  /// In en, this message translates to:
  /// **'Yoga'**
  String get homeYoga;

  /// No description provided for @homeSunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get homeSunrise;

  /// No description provided for @homeSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get homeSunset;

  /// No description provided for @homeWeekdayMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get homeWeekdayMonday;

  /// No description provided for @homeWeekdayTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get homeWeekdayTuesday;

  /// No description provided for @homeWeekdayWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get homeWeekdayWednesday;

  /// No description provided for @homeWeekdayThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get homeWeekdayThursday;

  /// No description provided for @homeWeekdayFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get homeWeekdayFriday;

  /// No description provided for @homeWeekdaySaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get homeWeekdaySaturday;

  /// No description provided for @homeWeekdaySunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get homeWeekdaySunday;

  /// No description provided for @homeMonthJanuary.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get homeMonthJanuary;

  /// No description provided for @homeMonthFebruary.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get homeMonthFebruary;

  /// No description provided for @homeMonthMarch.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get homeMonthMarch;

  /// No description provided for @homeMonthApril.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get homeMonthApril;

  /// No description provided for @homeMonthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get homeMonthMay;

  /// No description provided for @homeMonthJune.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get homeMonthJune;

  /// No description provided for @homeMonthJuly.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get homeMonthJuly;

  /// No description provided for @homeMonthAugust.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get homeMonthAugust;

  /// No description provided for @homeMonthSeptember.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get homeMonthSeptember;

  /// No description provided for @homeMonthOctober.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get homeMonthOctober;

  /// No description provided for @homeMonthNovember.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get homeMonthNovember;

  /// No description provided for @homeMonthDecember.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get homeMonthDecember;

  /// No description provided for @shukla.
  ///
  /// In en, this message translates to:
  /// **'Shukla'**
  String get shukla;

  /// No description provided for @krishna.
  ///
  /// In en, this message translates to:
  /// **'Krishna'**
  String get krishna;

  /// No description provided for @pratipada.
  ///
  /// In en, this message translates to:
  /// **'Pratipada'**
  String get pratipada;

  /// No description provided for @dwitiya.
  ///
  /// In en, this message translates to:
  /// **'Dwitiya'**
  String get dwitiya;

  /// No description provided for @tritiya.
  ///
  /// In en, this message translates to:
  /// **'Tritiya'**
  String get tritiya;

  /// No description provided for @chaturthi.
  ///
  /// In en, this message translates to:
  /// **'Chaturthi'**
  String get chaturthi;

  /// No description provided for @panchami.
  ///
  /// In en, this message translates to:
  /// **'Panchami'**
  String get panchami;

  /// No description provided for @shashthi.
  ///
  /// In en, this message translates to:
  /// **'Shashthi'**
  String get shashthi;

  /// No description provided for @saptami.
  ///
  /// In en, this message translates to:
  /// **'Saptami'**
  String get saptami;

  /// No description provided for @ashtami.
  ///
  /// In en, this message translates to:
  /// **'Ashtami'**
  String get ashtami;

  /// No description provided for @navami.
  ///
  /// In en, this message translates to:
  /// **'Navami'**
  String get navami;

  /// No description provided for @dashami.
  ///
  /// In en, this message translates to:
  /// **'Dashami'**
  String get dashami;

  /// No description provided for @ekadashi.
  ///
  /// In en, this message translates to:
  /// **'Ekadashi'**
  String get ekadashi;

  /// No description provided for @dwadashi.
  ///
  /// In en, this message translates to:
  /// **'Dwadashi'**
  String get dwadashi;

  /// No description provided for @trayodashi.
  ///
  /// In en, this message translates to:
  /// **'Trayodashi'**
  String get trayodashi;

  /// No description provided for @chaturdashi.
  ///
  /// In en, this message translates to:
  /// **'Chaturdashi'**
  String get chaturdashi;

  /// No description provided for @purnima.
  ///
  /// In en, this message translates to:
  /// **'Purnima'**
  String get purnima;

  /// No description provided for @amavasya.
  ///
  /// In en, this message translates to:
  /// **'Amavasya'**
  String get amavasya;

  /// No description provided for @muhurat.
  ///
  /// In en, this message translates to:
  /// **'Muhurat'**
  String get muhurat;

  /// No description provided for @auspicious.
  ///
  /// In en, this message translates to:
  /// **'Auspicious'**
  String get auspicious;

  /// No description provided for @career.
  ///
  /// In en, this message translates to:
  /// **'Career'**
  String get career;

  /// No description provided for @finance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get finance;

  /// No description provided for @relationships.
  ///
  /// In en, this message translates to:
  /// **'Relationships'**
  String get relationships;

  /// No description provided for @yoga.
  ///
  /// In en, this message translates to:
  /// **'Yoga'**
  String get yoga;

  /// No description provided for @sunrise.
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get sunrise;

  /// No description provided for @sunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get sunset;

  /// No description provided for @tithiNameKrishnaDwitiya.
  ///
  /// In en, this message translates to:
  /// **'Krishna Dwitiya'**
  String get tithiNameKrishnaDwitiya;

  /// No description provided for @nakshatraNamePurvaBhadrapada.
  ///
  /// In en, this message translates to:
  /// **'Purva Bhadrapada'**
  String get nakshatraNamePurvaBhadrapada;

  /// Localized Panchang Tithi name selected from the canonical calculation value.
  ///
  /// In en, this message translates to:
  /// **'{value, select, Shukla_Pratipada{Shukla Pratipada} Shukla_Dwitiya{Shukla Dwitiya} Shukla_Tritiya{Shukla Tritiya} Shukla_Chaturthi{Shukla Chaturthi} Shukla_Panchami{Shukla Panchami} Shukla_Shashthi{Shukla Shashthi} Shukla_Saptami{Shukla Saptami} Shukla_Ashtami{Shukla Ashtami} Shukla_Navami{Shukla Navami} Shukla_Dashami{Shukla Dashami} Shukla_Ekadashi{Shukla Ekadashi} Shukla_Dwadashi{Shukla Dwadashi} Shukla_Trayodashi{Shukla Trayodashi} Shukla_Chaturdashi{Shukla Chaturdashi} Purnima{Purnima} Krishna_Pratipada{Krishna Pratipada} Krishna_Dwitiya{Krishna Dwitiya} Krishna_Tritiya{Krishna Tritiya} Krishna_Chaturthi{Krishna Chaturthi} Krishna_Panchami{Krishna Panchami} Krishna_Shashthi{Krishna Shashthi} Krishna_Saptami{Krishna Saptami} Krishna_Ashtami{Krishna Ashtami} Krishna_Navami{Krishna Navami} Krishna_Dashami{Krishna Dashami} Krishna_Ekadashi{Krishna Ekadashi} Krishna_Dwadashi{Krishna Dwadashi} Krishna_Trayodashi{Krishna Trayodashi} Krishna_Chaturdashi{Krishna Chaturdashi} Amavasya{Amavasya} other{{value}}}'**
  String tithiName(String value);

  /// Localized Panchang Nakshatra name selected from the canonical calculation value.
  ///
  /// In en, this message translates to:
  /// **'{value, select, Ashwini{Ashwini} Bharani{Bharani} Krittika{Krittika} Rohini{Rohini} Mrigashira{Mrigashira} Ardra{Ardra} Punarvasu{Punarvasu} Pushya{Pushya} Ashlesha{Ashlesha} Magha{Magha} Purva_Phalguni{Purva Phalguni} Uttara_Phalguni{Uttara Phalguni} Hasta{Hasta} Chitra{Chitra} Swati{Swati} Vishakha{Vishakha} Anuradha{Anuradha} Jyeshtha{Jyeshtha} Mula{Mula} Purva_Ashadha{Purva Ashadha} Uttara_Ashadha{Uttara Ashadha} Shravana{Shravana} Dhanishtha{Dhanishtha} Shatabhisha{Shatabhisha} Purva_Bhadrapada{Purva Bhadrapada} Uttara_Bhadrapada{Uttara Bhadrapada} Revati{Revati} other{{value}}}'**
  String nakshatraName(String value);

  /// Localized Panchang Yoga name selected from the canonical calculation value.
  ///
  /// In en, this message translates to:
  /// **'{value, select, Vishkambha{Vishkambha} Priti{Priti} Ayushman{Ayushman} Saubhagya{Saubhagya} Shobhana{Shobhana} Atiganda{Atiganda} Sukarma{Sukarma} Dhriti{Dhriti} Shula{Shula} Ganda{Ganda} Vriddhi{Vriddhi} Dhruva{Dhruva} Vyaghata{Vyaghata} Harshana{Harshana} Vajra{Vajra} Siddhi{Siddhi} Vyatipata{Vyatipata} Variyana{Variyana} Parigha{Parigha} Shiva{Shiva} Siddha{Siddha} Sadhya{Sadhya} Shubha{Shubha} Shukla{Shukla} Brahma{Brahma} Indra{Indra} Vaidhriti{Vaidhriti} other{{value}}}'**
  String yogaName(String value);

  /// No description provided for @horoscopeCareer.
  ///
  /// In en, this message translates to:
  /// **'{variant, select, mercury{Career favors communication, analysis and focused execution. Use your Mercury influence to organize priorities and turn ideas into measurable progress.} jupiter{Professional growth is supported through learning, guidance and long-term decisions. Stay open to opportunities that expand your responsibilities or expertise.} saturn{Steady effort is more valuable than quick results today. Take responsibility for important tasks and build progress through disciplined execution.} retrograde{Review ongoing work before pushing ahead. A thoughtful second look at communication, commitments and unfinished tasks can prevent avoidable delays.} other{Focus on clear priorities and consistent execution. Your {mahadasha}–{antardasha} period favors deliberate decisions rather than unnecessary distractions.}}'**
  String horoscopeCareer(String variant, Object mahadasha, Object antardasha);

  /// No description provided for @horoscopeFinance.
  ///
  /// In en, this message translates to:
  /// **'{variant, select, jupiter{Financial prospects benefit from practical planning and long-term thinking. Review opportunities carefully before committing funds.} venus{Financial decisions can benefit from balance and moderation. Prioritize useful purchases and avoid spending simply for short-term comfort.} saturn{Financial discipline is especially important. Review budgets, recurring expenses and commitments before making new decisions.} other{Keep financial decisions measured and practical. The {mahadasha}–{antardasha} period favors reviewing priorities and avoiding unnecessary risk.}}'**
  String horoscopeFinance(String variant, Object mahadasha, Object antardasha);

  /// No description provided for @horoscopeRelationships.
  ///
  /// In en, this message translates to:
  /// **'{variant, select, venus{Warmth and openness can strengthen relationships today. Make time for meaningful conversation and allow appreciation to be expressed clearly.} moon{Emotional connection and a supportive home environment are important today. Gentle communication can create greater understanding with loved ones.} other{Patience and clear communication can improve relationships. Your {nakshatra} influence suggests paying attention to emotional signals rather than reacting too quickly.}}'**
  String horoscopeRelationships(String variant, Object nakshatra);

  /// No description provided for @homeVastuFocusArea.
  ///
  /// In en, this message translates to:
  /// **'Focus area'**
  String get homeVastuFocusArea;

  /// No description provided for @homeVastuTodayAction.
  ///
  /// In en, this message translates to:
  /// **'Today\'s action'**
  String get homeVastuTodayAction;

  /// No description provided for @vastuEntranceAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Entrance Analysis'**
  String get vastuEntranceAnalysis;

  /// No description provided for @vastuSelectEntrance.
  ///
  /// In en, this message translates to:
  /// **'Select entrance segment'**
  String get vastuSelectEntrance;

  /// No description provided for @vastuEntrancePada.
  ///
  /// In en, this message translates to:
  /// **'Entrance pada'**
  String get vastuEntrancePada;

  /// No description provided for @vastuAssessment.
  ///
  /// In en, this message translates to:
  /// **'Assessment'**
  String get vastuAssessment;

  /// No description provided for @vastuFavorable.
  ///
  /// In en, this message translates to:
  /// **'Favorable'**
  String get vastuFavorable;

  /// No description provided for @vastuTraditionalAssessment.
  ///
  /// In en, this message translates to:
  /// **'Traditional assessment'**
  String get vastuTraditionalAssessment;

  /// No description provided for @vastuW4.
  ///
  /// In en, this message translates to:
  /// **'W4'**
  String get vastuW4;

  /// No description provided for @vastuW5.
  ///
  /// In en, this message translates to:
  /// **'W5'**
  String get vastuW5;

  /// No description provided for @vastuPushpadanta.
  ///
  /// In en, this message translates to:
  /// **'Pushpadanta'**
  String get vastuPushpadanta;

  /// No description provided for @vastuVaruna.
  ///
  /// In en, this message translates to:
  /// **'Varuna'**
  String get vastuVaruna;

  /// No description provided for @vastuW4Summary.
  ///
  /// In en, this message translates to:
  /// **'A traditionally favorable west entrance associated with prosperity, stability and positive growth.'**
  String get vastuW4Summary;

  /// No description provided for @vastuW5Summary.
  ///
  /// In en, this message translates to:
  /// **'A traditionally favorable west entrance associated with stability, gains and broader opportunities.'**
  String get vastuW5Summary;

  /// No description provided for @vastuNoSupportedEntrySegments.
  ///
  /// In en, this message translates to:
  /// **'No supported entrance segments are available yet.'**
  String get vastuNoSupportedEntrySegments;

  /// No description provided for @vastuNeutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get vastuNeutral;

  /// No description provided for @vastuChallenging.
  ///
  /// In en, this message translates to:
  /// **'Challenging'**
  String get vastuChallenging;

  /// No description provided for @vastuEntranceDirection.
  ///
  /// In en, this message translates to:
  /// **'Entrance direction'**
  String get vastuEntranceDirection;

  /// No description provided for @vastuEntrancePosition.
  ///
  /// In en, this message translates to:
  /// **'Entrance position'**
  String get vastuEntrancePosition;

  /// No description provided for @vastuPositionStart.
  ///
  /// In en, this message translates to:
  /// **'Start of wall'**
  String get vastuPositionStart;

  /// No description provided for @vastuPositionEnd.
  ///
  /// In en, this message translates to:
  /// **'End of wall'**
  String get vastuPositionEnd;

  /// No description provided for @vastuCalculatedPada.
  ///
  /// In en, this message translates to:
  /// **'Calculated entrance pada'**
  String get vastuCalculatedPada;

  /// No description provided for @vastuAssessmentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Assessment not available yet for this entrance pada.'**
  String get vastuAssessmentUnavailable;

  /// No description provided for @vastuSelectDirection.
  ///
  /// In en, this message translates to:
  /// **'Select direction'**
  String get vastuSelectDirection;

  /// No description provided for @vastuNorth.
  ///
  /// In en, this message translates to:
  /// **'North'**
  String get vastuNorth;

  /// No description provided for @vastuEast.
  ///
  /// In en, this message translates to:
  /// **'East'**
  String get vastuEast;

  /// No description provided for @vastuSouth.
  ///
  /// In en, this message translates to:
  /// **'South'**
  String get vastuSouth;

  /// No description provided for @vastuWest.
  ///
  /// In en, this message translates to:
  /// **'West'**
  String get vastuWest;

  /// No description provided for @vastuRoga.
  ///
  /// In en, this message translates to:
  /// **'Roga'**
  String get vastuRoga;

  /// No description provided for @vastuNaga.
  ///
  /// In en, this message translates to:
  /// **'Naga'**
  String get vastuNaga;

  /// No description provided for @vastuMukhya.
  ///
  /// In en, this message translates to:
  /// **'Mukhya'**
  String get vastuMukhya;

  /// No description provided for @vastuBhallata.
  ///
  /// In en, this message translates to:
  /// **'Bhallata'**
  String get vastuBhallata;

  /// No description provided for @vastuSoma.
  ///
  /// In en, this message translates to:
  /// **'Soma'**
  String get vastuSoma;

  /// No description provided for @vastuBhujaga.
  ///
  /// In en, this message translates to:
  /// **'Bhujaga'**
  String get vastuBhujaga;

  /// No description provided for @vastuAditi.
  ///
  /// In en, this message translates to:
  /// **'Aditi'**
  String get vastuAditi;

  /// No description provided for @vastuDiti.
  ///
  /// In en, this message translates to:
  /// **'Diti'**
  String get vastuDiti;

  /// No description provided for @vastuShikhi.
  ///
  /// In en, this message translates to:
  /// **'Shikhi'**
  String get vastuShikhi;

  /// No description provided for @vastuParjanya.
  ///
  /// In en, this message translates to:
  /// **'Parjanya'**
  String get vastuParjanya;

  /// No description provided for @vastuJayanta.
  ///
  /// In en, this message translates to:
  /// **'Jayanta'**
  String get vastuJayanta;

  /// No description provided for @vastuIndra.
  ///
  /// In en, this message translates to:
  /// **'Indra'**
  String get vastuIndra;

  /// No description provided for @vastuSurya.
  ///
  /// In en, this message translates to:
  /// **'Surya'**
  String get vastuSurya;

  /// No description provided for @vastuSatya.
  ///
  /// In en, this message translates to:
  /// **'Satya'**
  String get vastuSatya;

  /// No description provided for @vastuBhrisha.
  ///
  /// In en, this message translates to:
  /// **'Bhrisha'**
  String get vastuBhrisha;

  /// No description provided for @vastuAkasha.
  ///
  /// In en, this message translates to:
  /// **'Akasha'**
  String get vastuAkasha;

  /// No description provided for @vastuAnila.
  ///
  /// In en, this message translates to:
  /// **'Anila'**
  String get vastuAnila;

  /// No description provided for @vastuPusha.
  ///
  /// In en, this message translates to:
  /// **'Pusha'**
  String get vastuPusha;

  /// No description provided for @vastuVitatha.
  ///
  /// In en, this message translates to:
  /// **'Vitatha'**
  String get vastuVitatha;

  /// No description provided for @vastuGrihakshata.
  ///
  /// In en, this message translates to:
  /// **'Grihakshata'**
  String get vastuGrihakshata;

  /// No description provided for @vastuYama.
  ///
  /// In en, this message translates to:
  /// **'Yama'**
  String get vastuYama;

  /// No description provided for @vastuGandharva.
  ///
  /// In en, this message translates to:
  /// **'Gandharva'**
  String get vastuGandharva;

  /// No description provided for @vastuBhringaraja.
  ///
  /// In en, this message translates to:
  /// **'Bhringaraja'**
  String get vastuBhringaraja;

  /// No description provided for @vastuMriga.
  ///
  /// In en, this message translates to:
  /// **'Mriga'**
  String get vastuMriga;

  /// No description provided for @vastuPitra.
  ///
  /// In en, this message translates to:
  /// **'Pitra'**
  String get vastuPitra;

  /// No description provided for @vastuDauvarika.
  ///
  /// In en, this message translates to:
  /// **'Dauvarika'**
  String get vastuDauvarika;

  /// No description provided for @vastuSugriva.
  ///
  /// In en, this message translates to:
  /// **'Sugriva'**
  String get vastuSugriva;

  /// No description provided for @vastuAsura.
  ///
  /// In en, this message translates to:
  /// **'Asura'**
  String get vastuAsura;

  /// No description provided for @vastuShosha.
  ///
  /// In en, this message translates to:
  /// **'Shosha'**
  String get vastuShosha;

  /// No description provided for @vastuPapayakshma.
  ///
  /// In en, this message translates to:
  /// **'Papayakshma'**
  String get vastuPapayakshma;

  /// No description provided for @muhuratPlannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Muhurat Planner'**
  String get muhuratPlannerTitle;

  /// No description provided for @planWithPanchang.
  ///
  /// In en, this message translates to:
  /// **'Plan with Panchang'**
  String get planWithPanchang;

  /// No description provided for @muhuratPlannerDescription.
  ///
  /// In en, this message translates to:
  /// **'Explore traditional daily timing using your location and selected date.'**
  String get muhuratPlannerDescription;

  /// No description provided for @selectedDate.
  ///
  /// In en, this message translates to:
  /// **'Selected date'**
  String get selectedDate;

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get currentLocation;

  /// No description provided for @unableToDetermineLocation.
  ///
  /// In en, this message translates to:
  /// **'Unable to determine your current location.'**
  String get unableToDetermineLocation;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location is unavailable. Enable location permission and try again.'**
  String get locationUnavailable;

  /// No description provided for @unableToCalculatePanchang.
  ///
  /// In en, this message translates to:
  /// **'Unable to calculate Panchang for this date.'**
  String get unableToCalculatePanchang;

  /// No description provided for @traditionalMuhuratDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Traditional guidance only. Abhijit Muhurat is a general daily window, not a personalized muhurat for weddings, travel, property, or other specific activities. Suitability may depend on the activity and additional Panchang factors.'**
  String get traditionalMuhuratDisclaimer;

  /// No description provided for @abhijitMuhurat.
  ///
  /// In en, this message translates to:
  /// **'Abhijit Muhurat'**
  String get abhijitMuhurat;

  /// No description provided for @traditionalGeneralPurposeWindow.
  ///
  /// In en, this message translates to:
  /// **'Traditional general-purpose time window'**
  String get traditionalGeneralPurposeWindow;

  /// No description provided for @rahuKaalDescription.
  ///
  /// In en, this message translates to:
  /// **'Traditional period commonly avoided for starting certain activities.'**
  String get rahuKaalDescription;

  /// No description provided for @moonrise.
  ///
  /// In en, this message translates to:
  /// **'Moonrise'**
  String get moonrise;

  /// No description provided for @panchangForDate.
  ///
  /// In en, this message translates to:
  /// **'Panchang for {date}'**
  String panchangForDate(Object date);

  /// No description provided for @timesLocalTo.
  ///
  /// In en, this message translates to:
  /// **'Times are local to {timezone}.'**
  String timesLocalTo(Object timezone);

  /// No description provided for @chooseMuhuratDate.
  ///
  /// In en, this message translates to:
  /// **'Choose Muhurat date'**
  String get chooseMuhuratDate;

  /// No description provided for @dailyTimingTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Timing'**
  String get dailyTimingTitle;

  /// No description provided for @planYourDayWithPanchang.
  ///
  /// In en, this message translates to:
  /// **'Plan your day with Panchang'**
  String get planYourDayWithPanchang;

  /// No description provided for @selectedLocationTiming.
  ///
  /// In en, this message translates to:
  /// **'Timings are calculated for your selected location.'**
  String get selectedLocationTiming;

  /// Displays the local timezone on the Daily Timing screen.
  ///
  /// In en, this message translates to:
  /// **'Local time · {timezone}'**
  String localTimeLabel(String timezone);

  /// No description provided for @auspiciousAndCautionaryPeriods.
  ///
  /// In en, this message translates to:
  /// **'Auspicious and cautionary periods'**
  String get auspiciousAndCautionaryPeriods;

  /// No description provided for @auspiciousMuhuratTitle.
  ///
  /// In en, this message translates to:
  /// **'Auspicious Muhurat'**
  String get auspiciousMuhuratTitle;

  /// No description provided for @auspiciousMuhuratDescription.
  ///
  /// In en, this message translates to:
  /// **'A traditional favorable period for planned activities.'**
  String get auspiciousMuhuratDescription;

  /// No description provided for @rahuKaalTitle.
  ///
  /// In en, this message translates to:
  /// **'Rahu Kaal'**
  String get rahuKaalTitle;

  /// No description provided for @sunAndMoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Sun and moon'**
  String get sunAndMoonTitle;

  /// No description provided for @traditionalPanchangGuidance.
  ///
  /// In en, this message translates to:
  /// **'Traditional Panchang guidance is a cultural planning aid; use your judgment for important decisions.'**
  String get traditionalPanchangGuidance;

  /// No description provided for @muhuratPurposeLabel.
  ///
  /// In en, this message translates to:
  /// **'What are you planning?'**
  String get muhuratPurposeLabel;

  /// No description provided for @muhuratPurposeGeneral.
  ///
  /// In en, this message translates to:
  /// **'General purpose'**
  String get muhuratPurposeGeneral;

  /// No description provided for @muhuratPurposeMarriage.
  ///
  /// In en, this message translates to:
  /// **'Marriage'**
  String get muhuratPurposeMarriage;

  /// No description provided for @muhuratPurposeGrihaPravesh.
  ///
  /// In en, this message translates to:
  /// **'Griha Pravesh'**
  String get muhuratPurposeGrihaPravesh;

  /// No description provided for @muhuratPurposeBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business opening'**
  String get muhuratPurposeBusiness;

  /// No description provided for @muhuratPurposeVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle purchase'**
  String get muhuratPurposeVehicle;

  /// No description provided for @muhuratPurposeTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get muhuratPurposeTravel;

  /// No description provided for @muhuratPurposeNote.
  ///
  /// In en, this message translates to:
  /// **'This selection helps organize your plans. The displayed times remain general Panchang guidance, not a verified event-specific Muhurat.'**
  String get muhuratPurposeNote;

  /// No description provided for @muhuratPurposeGuidance.
  ///
  /// In en, this message translates to:
  /// **'For {purpose}, review the full Panchang and activity-specific factors with a qualified astrologer. The times shown here are general guidance, not a verified event-specific Muhurat.'**
  String muhuratPurposeGuidance(Object purpose);

  /// No description provided for @muhuratCandidateHeading.
  ///
  /// In en, this message translates to:
  /// **'Preliminary candidate dates (next 30 days)'**
  String get muhuratCandidateHeading;

  /// No description provided for @muhuratCandidateDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'These dates pass initial screening only. They are not confirmed muhurats; exact Panchang boundaries and additional event-specific factors have not been verified.'**
  String get muhuratCandidateDisclaimer;

  /// No description provided for @muhuratCandidateSearching.
  ///
  /// In en, this message translates to:
  /// **'Checking upcoming dates...'**
  String get muhuratCandidateSearching;

  /// No description provided for @muhuratCandidateNoResults.
  ///
  /// In en, this message translates to:
  /// **'No dates passed these preliminary screening rules in the next 30 days.'**
  String get muhuratCandidateNoResults;

  /// No description provided for @muhuratCandidateSearchError.
  ///
  /// In en, this message translates to:
  /// **'Could not calculate candidate dates. Change the activity selection to try again.'**
  String get muhuratCandidateSearchError;

  /// No description provided for @doshaCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Dosha Check'**
  String get doshaCheckTitle;

  /// No description provided for @doshaCheckSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manglik, Kaal Sarp and Sade Sati from your birth chart'**
  String get doshaCheckSubtitle;

  /// No description provided for @doshaCalculating.
  ///
  /// In en, this message translates to:
  /// **'Checking your chart...'**
  String get doshaCalculating;

  /// No description provided for @doshaUnable.
  ///
  /// In en, this message translates to:
  /// **'Unable to check doshas'**
  String get doshaUnable;

  /// No description provided for @doshaIntro.
  ///
  /// In en, this message translates to:
  /// **'Doshas are challenging planetary patterns in traditional Vedic astrology. They are common, are often cancelled by other factors, and are best read as areas for awareness rather than predictions.'**
  String get doshaIntro;

  /// No description provided for @doshaStatus.
  ///
  /// In en, this message translates to:
  /// **'{status, select, none{Not present} present{Present} mild{Mild} cancelled{Cancelled} partial{Partial} active{Running now} other{{status}}}'**
  String doshaStatus(String status);

  /// No description provided for @manglikTitle.
  ///
  /// In en, this message translates to:
  /// **'Manglik Dosha'**
  String get manglikTitle;

  /// No description provided for @manglikMarsPosition.
  ///
  /// In en, this message translates to:
  /// **'Mars in {sign} · house {lagna} from Lagna, {moon} from Moon, {venus} from Venus'**
  String manglikMarsPosition(String sign, int lagna, int moon, int venus);

  /// No description provided for @manglikSummary.
  ///
  /// In en, this message translates to:
  /// **'{status, select, none{Mars is not in a Manglik house (1, 2, 4, 7, 8 or 12) from the Lagna, Moon or Venus.} present{Mars is in a Manglik house from the Lagna.} mild{Mars is in a Manglik house from the Moon or Venus only. Many traditions treat this as a mild (anshik) Manglik placement.} cancelled{Mars is in a Manglik house, but a commonly cited cancellation applies.} other{{status}}}'**
  String manglikSummary(String status);

  /// No description provided for @manglikCancellation.
  ///
  /// In en, this message translates to:
  /// **'{reason, select, marsInOwnOrExaltedSign{Mars is in its own sign or exalted} jupiterConjunctMars{Jupiter is in the same sign as Mars} jupiterAspectsMars{Jupiter aspects Mars} moonConjunctMars{Moon is in the same sign as Mars (Chandra–Mangal yoga)} other{{reason}}}'**
  String manglikCancellation(String reason);

  /// No description provided for @manglikMatchingTip.
  ///
  /// In en, this message translates to:
  /// **'In marriage matching, a Manglik chart is traditionally paired with another Manglik chart. Use Marriage Compatibility to compare two profiles.'**
  String get manglikMatchingTip;

  /// No description provided for @kaalSarpTitle.
  ///
  /// In en, this message translates to:
  /// **'Kaal Sarp Dosha'**
  String get kaalSarpTitle;

  /// No description provided for @kaalSarpSummaryNone.
  ///
  /// In en, this message translates to:
  /// **'Planets fall on both sides of the Rahu–Ketu axis, so Kaal Sarp yoga is not formed.'**
  String get kaalSarpSummaryNone;

  /// No description provided for @kaalSarpSummaryFull.
  ///
  /// In en, this message translates to:
  /// **'All seven planets lie between Rahu (house {rahu}) and Ketu (house {ketu}).'**
  String kaalSarpSummaryFull(int rahu, int ketu);

  /// No description provided for @kaalSarpSummaryPartial.
  ///
  /// In en, this message translates to:
  /// **'All planets except {planets} lie on one side of the Rahu–Ketu axis. Some traditions call this a partial Kaal Sarp.'**
  String kaalSarpSummaryPartial(String planets);

  /// No description provided for @kaalSarpType.
  ///
  /// In en, this message translates to:
  /// **'{type, select, anant{Anant} kulik{Kulik} vasuki{Vasuki} shankhpal{Shankhpal} padma{Padma} mahapadma{Mahapadma} takshak{Takshak} karkotak{Karkotak} shankhachud{Shankhachud} ghatak{Ghatak} vishdhar{Vishdhar} sheshnag{Sheshnag} other{{type}}} Kaal Sarp'**
  String kaalSarpType(String type);

  /// No description provided for @kaalSarpAmritNote.
  ///
  /// In en, this message translates to:
  /// **'Here the planets run from Ketu to Rahu. Some traditions call this Kaal Amrit yoga and consider it milder.'**
  String get kaalSarpAmritNote;

  /// No description provided for @sadeSatiTitle.
  ///
  /// In en, this message translates to:
  /// **'Shani Sade Sati'**
  String get sadeSatiTitle;

  /// No description provided for @sadeSatiBasis.
  ///
  /// In en, this message translates to:
  /// **'Based on your Moon sign, {sign}.'**
  String sadeSatiBasis(String sign);

  /// No description provided for @sadeSatiSaturnNow.
  ///
  /// In en, this message translates to:
  /// **'Saturn is now in {sign}.'**
  String sadeSatiSaturnNow(String sign);

  /// No description provided for @sadeSatiActive.
  ///
  /// In en, this message translates to:
  /// **'Sade Sati is running — {phase} phase.'**
  String sadeSatiActive(String phase);

  /// No description provided for @sadeSatiPaused.
  ///
  /// In en, this message translates to:
  /// **'Sade Sati is running. Saturn has briefly stepped back out of these signs during retrograde and will return.'**
  String get sadeSatiPaused;

  /// No description provided for @sadeSatiNotActive.
  ///
  /// In en, this message translates to:
  /// **'Sade Sati is not running now.'**
  String get sadeSatiNotActive;

  /// No description provided for @sadeSatiPhase.
  ///
  /// In en, this message translates to:
  /// **'{phase, select, rising{Rising} peak{Peak} setting{Setting} other{{phase}}}'**
  String sadeSatiPhase(String phase);

  /// No description provided for @sadeSatiPhaseDetail.
  ///
  /// In en, this message translates to:
  /// **'{phase, select, rising{Rising — Saturn in the 12th from your Moon} peak{Peak — Saturn over your Moon sign} setting{Setting — Saturn in the 2nd from your Moon} other{{phase}}}'**
  String sadeSatiPhaseDetail(String phase);

  /// No description provided for @sadeSatiCurrentCycle.
  ///
  /// In en, this message translates to:
  /// **'Current cycle: {start} – {end}'**
  String sadeSatiCurrentCycle(String start, String end);

  /// No description provided for @sadeSatiNextCycle.
  ///
  /// In en, this message translates to:
  /// **'Next Sade Sati: {start} – {end}'**
  String sadeSatiNextCycle(String start, String end);

  /// No description provided for @sadeSatiPhaseFrom.
  ///
  /// In en, this message translates to:
  /// **'from {date}'**
  String sadeSatiPhaseFrom(String date);

  /// No description provided for @sadeSatiPastCycles.
  ///
  /// In en, this message translates to:
  /// **'Earlier cycles in your life'**
  String get sadeSatiPastCycles;

  /// No description provided for @shaniDhaiya.
  ///
  /// In en, this message translates to:
  /// **'{house, select, fourth{Shani Dhaiya is running: Saturn is in the 4th from your Moon (Kantaka Shani).} eighth{Shani Dhaiya is running: Saturn is in the 8th from your Moon (Ashtama Shani).} other{{house}}}'**
  String shaniDhaiya(String house);

  /// No description provided for @doshaRemediesTitle.
  ///
  /// In en, this message translates to:
  /// **'Traditional practices'**
  String get doshaRemediesTitle;

  /// No description provided for @doshaRemediesBody.
  ///
  /// In en, this message translates to:
  /// **'Commonly suggested practices include Hanuman Chalisa on Tuesdays for Mars, Shani mantra or charity on Saturdays for Saturn, and a Rahu–Ketu shanti puja for Kaal Sarp. Consult a qualified astrologer before wearing gemstones or arranging rituals.'**
  String get doshaRemediesBody;

  /// No description provided for @doshaDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Traditional astrology interpretation only, calculated with Lahiri ayanamsa and whole-sign houses. It is not a prediction of health, marriage or financial outcomes.'**
  String get doshaDisclaimer;

  /// No description provided for @festivalCalendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Festivals & Vrats'**
  String get festivalCalendarTitle;

  /// No description provided for @festivalCalendarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ekadashi, Purnima and festival dates for where you are'**
  String get festivalCalendarSubtitle;

  /// No description provided for @festivalCalculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating festival dates...'**
  String get festivalCalculating;

  /// No description provided for @festivalUnable.
  ///
  /// In en, this message translates to:
  /// **'Unable to calculate festival dates.'**
  String get festivalUnable;

  /// No description provided for @festivalLocationNeeded.
  ///
  /// In en, this message translates to:
  /// **'Allow location access or create a birth profile so festival dates can be calculated for your place.'**
  String get festivalLocationNeeded;

  /// No description provided for @festivalForCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Dates are calculated for your current location.'**
  String get festivalForCurrentLocation;

  /// No description provided for @festivalForCity.
  ///
  /// In en, this message translates to:
  /// **'Dates are calculated for {city}. Allow location access to use where you are now.'**
  String festivalForCity(String city);

  /// No description provided for @festivalFilter.
  ///
  /// In en, this message translates to:
  /// **'{category, select, all{All} festival{Festivals} ekadashi{Ekadashi} fullNewMoon{Purnima & Amavasya} vrat{Vrats} other{{category}}}'**
  String festivalFilter(String category);

  /// No description provided for @festivalNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this category this month.'**
  String get festivalNone;

  /// No description provided for @festivalToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get festivalToday;

  /// No description provided for @festivalTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get festivalTomorrow;

  /// No description provided for @festivalInDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{In 1 day} other{In {count} days}}'**
  String festivalInDays(int count);

  /// No description provided for @festivalNextUp.
  ///
  /// In en, this message translates to:
  /// **'Next festival'**
  String get festivalNextUp;

  /// No description provided for @festivalPaksha.
  ///
  /// In en, this message translates to:
  /// **'{paksha, select, shukla{Shukla paksha} krishna{Krishna paksha} other{{paksha}}}'**
  String festivalPaksha(String paksha);

  /// No description provided for @festivalName.
  ///
  /// In en, this message translates to:
  /// **'{id, select, makarSankranti{Makar Sankranti} vasantPanchami{Vasant Panchami} mahaShivaratri{Maha Shivaratri} holi{Holi} ugadi{Ugadi / Gudi Padwa} ramNavami{Ram Navami} hanumanJayanti{Hanuman Jayanti} akshayaTritiya{Akshaya Tritiya} nirjalaEkadashi{Nirjala Ekadashi} devshayaniEkadashi{Devshayani Ekadashi} guruPurnima{Guru Purnima} rakshaBandhan{Raksha Bandhan} janmashtami{Krishna Janmashtami} ganeshChaturthi{Ganesh Chaturthi} navratri{Sharad Navratri begins} dussehra{Dussehra} karvaChauth{Karva Chauth} dhanteras{Dhanteras} diwali{Diwali (Lakshmi Puja)} devUthaniEkadashi{Dev Uthani Ekadashi} ekadashi{Ekadashi} purnima{Purnima} amavasya{Amavasya} pradosh{Pradosh Vrat} sankashti{Sankashti Chaturthi} masikShivaratri{Masik Shivaratri} other{{id}}}'**
  String festivalName(String id);

  /// No description provided for @festivalDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Dates follow standard observance rules for your location (sunrise tithi, with pradosh, midnight or moonrise timing where tradition requires). Regional and sampradaya calendars can differ by a day.'**
  String get festivalDisclaimer;

  /// No description provided for @navToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @homeExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get homeExplore;

  /// No description provided for @homeMoonPhase.
  ///
  /// In en, this message translates to:
  /// **'{paksha} · Moon {percent}% lit'**
  String homeMoonPhase(String paksha, int percent);

  /// No description provided for @remindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersTitle;

  /// No description provided for @remindersIntro.
  ///
  /// In en, this message translates to:
  /// **'Reminders are calculated on your phone for where you are, and refresh each time you open the app.'**
  String get remindersIntro;

  /// No description provided for @remindersMorningTitle.
  ///
  /// In en, this message translates to:
  /// **'Morning Panchang'**
  String get remindersMorningTitle;

  /// No description provided for @remindersMorningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The day\'s tithi, nakshatra and Rahu Kaal'**
  String get remindersMorningSubtitle;

  /// No description provided for @remindersMorningTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get remindersMorningTime;

  /// No description provided for @remindersFestivalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Festivals'**
  String get remindersFestivalsTitle;

  /// No description provided for @remindersFestivalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The evening before Diwali, Navratri, Janmashtami and other major festivals'**
  String get remindersFestivalsSubtitle;

  /// No description provided for @remindersVratsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ekadashi and vrats'**
  String get remindersVratsTitle;

  /// No description provided for @remindersVratsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The evening before Ekadashi, Purnima, Amavasya, Pradosh and Sankashti'**
  String get remindersVratsSubtitle;

  /// No description provided for @remindersFootnote.
  ///
  /// In en, this message translates to:
  /// **'Reminders stay on this phone; nothing is sent to a server.'**
  String get remindersFootnote;

  /// No description provided for @remindersPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Start each day with the Panchang'**
  String get remindersPromptTitle;

  /// No description provided for @remindersPromptBody.
  ///
  /// In en, this message translates to:
  /// **'Get a short morning note with the day\'s tithi and Rahu Kaal, and a reminder the evening before festivals and Ekadashi.'**
  String get remindersPromptBody;

  /// No description provided for @remindersTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on reminders'**
  String get remindersTurnOn;

  /// No description provided for @remindersNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get remindersNotNow;

  /// No description provided for @remindersPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for this app. Turn them on in your phone\'s Settings to get reminders.'**
  String get remindersPermissionDenied;

  /// No description provided for @reminderMorningTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s tithi: {tithi}'**
  String reminderMorningTitle(String tithi);

  /// No description provided for @reminderMorningFestivalTitle.
  ///
  /// In en, this message translates to:
  /// **'Today is {festival}'**
  String reminderMorningFestivalTitle(String festival);

  /// No description provided for @reminderMorningBody.
  ///
  /// In en, this message translates to:
  /// **'{nakshatra} nakshatra. Rahu Kaal {rahuKaal}.'**
  String reminderMorningBody(String nakshatra, String rahuKaal);

  /// No description provided for @reminderEveTitle.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow: {name}'**
  String reminderEveTitle(String name);

  /// No description provided for @reminderEveBody.
  ///
  /// In en, this message translates to:
  /// **'Open the app for tomorrow\'s Panchang and timings.'**
  String get reminderEveBody;

  /// No description provided for @chartD1.
  ///
  /// In en, this message translates to:
  /// **'Birth chart (D1)'**
  String get chartD1;

  /// No description provided for @chartD9.
  ///
  /// In en, this message translates to:
  /// **'Navamsa (D9)'**
  String get chartD9;

  /// No description provided for @chartD1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Rashi chart with whole-sign houses from your Lagna.'**
  String get chartD1Subtitle;

  /// No description provided for @chartD9Subtitle.
  ///
  /// In en, this message translates to:
  /// **'The ninth-division chart, read for marriage, dharma and the inner strength of each planet.'**
  String get chartD9Subtitle;

  /// No description provided for @chartShowSouth.
  ///
  /// In en, this message translates to:
  /// **'Show South Indian style'**
  String get chartShowSouth;

  /// No description provided for @chartShowNorth.
  ///
  /// In en, this message translates to:
  /// **'Show North Indian style'**
  String get chartShowNorth;

  /// No description provided for @chartLagnaMark.
  ///
  /// In en, this message translates to:
  /// **'Lagna'**
  String get chartLagnaMark;

  /// No description provided for @chartVargottama.
  ///
  /// In en, this message translates to:
  /// **'Vargottama (same sign in D1 and D9): {planets}'**
  String chartVargottama(String planets);

  /// No description provided for @gocharTitle.
  ///
  /// In en, this message translates to:
  /// **'Transits (Gochar)'**
  String get gocharTitle;

  /// No description provided for @gocharSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where Jupiter, Saturn, Rahu and Ketu are now for you'**
  String get gocharSubtitle;

  /// No description provided for @gocharIntro.
  ///
  /// In en, this message translates to:
  /// **'Slow planets are read from your Moon sign, the classical way Gochar is judged. Jupiter supports from the 2nd, 5th, 7th, 9th and 11th; Saturn, Rahu and Ketu from the 3rd, 6th and 11th.'**
  String get gocharIntro;

  /// No description provided for @gocharPlanetIn.
  ///
  /// In en, this message translates to:
  /// **'{planet} in {sign}'**
  String gocharPlanetIn(String planet, String sign);

  /// No description provided for @gocharHouseFromMoon.
  ///
  /// In en, this message translates to:
  /// **'House {house} from your Moon'**
  String gocharHouseFromMoon(int house);

  /// No description provided for @gocharHouseFromLagna.
  ///
  /// In en, this message translates to:
  /// **'House {house} from your Lagna'**
  String gocharHouseFromLagna(int house);

  /// No description provided for @gocharHouseTheme.
  ///
  /// In en, this message translates to:
  /// **'{area, select, h1{self, health and direction} h2{family, speech and savings} h3{courage, effort and siblings} h4{home, mother and peace of mind} h5{children, learning and creativity} h6{health, debts and competition} h7{partnership and marriage} h8{sudden change and hidden matters} h9{fortune, teachers and dharma} h10{career and reputation} h11{gains, friends and wishes} h12{expenses, travel and retreat} other{{area}}}'**
  String gocharHouseTheme(String area);

  /// No description provided for @gocharTone.
  ///
  /// In en, this message translates to:
  /// **'{tone, select, favourable{Supportive} challenging{Testing} other{{tone}}}'**
  String gocharTone(String tone);

  /// No description provided for @gocharSince.
  ///
  /// In en, this message translates to:
  /// **'In this sign since {date}'**
  String gocharSince(String date);

  /// No description provided for @gocharUntil.
  ///
  /// In en, this message translates to:
  /// **'Moves into {sign} on {date}'**
  String gocharUntil(String date, String sign);

  /// No description provided for @gocharUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Coming up'**
  String get gocharUpcoming;

  /// No description provided for @gocharIngress.
  ///
  /// In en, this message translates to:
  /// **'{planet} enters {sign}'**
  String gocharIngress(String planet, String sign);

  /// No description provided for @gocharDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Transit readings are traditional guidance calculated with Lahiri ayanamsa. Dasha periods and the full chart change how a transit is felt.'**
  String get gocharDisclaimer;

  /// No description provided for @kundliReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Kundli report'**
  String get kundliReportTitle;

  /// No description provided for @kundliReportDownload.
  ///
  /// In en, this message translates to:
  /// **'Download Kundli PDF'**
  String get kundliReportDownload;

  /// No description provided for @kundliReportGenerated.
  ///
  /// In en, this message translates to:
  /// **'Generated {date} by RV Astro Vastu'**
  String kundliReportGenerated(String date);

  /// No description provided for @kundliReportUnable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the PDF. Check your birth profile and try again.'**
  String get kundliReportUnable;

  /// No description provided for @kundliReportFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get kundliReportFrom;

  /// No description provided for @kundliReportTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get kundliReportTo;

  /// No description provided for @kundliReportDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Calculated with Swiss Ephemeris, Lahiri ayanamsa and whole-sign houses. This report is traditional astrological guidance, not a prediction of health, marriage or financial outcomes.'**
  String get kundliReportDisclaimer;

  /// No description provided for @vastuCompassTitle.
  ///
  /// In en, this message translates to:
  /// **'Vastu compass'**
  String get vastuCompassTitle;

  /// No description provided for @vastuCompassSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find the 16 Vastu zones of your home'**
  String get vastuCompassSubtitle;

  /// No description provided for @vastuCompassHowTo.
  ///
  /// In en, this message translates to:
  /// **'Stand at the centre of your home and hold your phone flat. Point the top of the phone at the room or object you want to check, away from metal and electronics.'**
  String get vastuCompassHowTo;

  /// No description provided for @vastuCompassNoSensor.
  ///
  /// In en, this message translates to:
  /// **'This device has no compass sensor. You can still read about every zone below.'**
  String get vastuCompassNoSensor;

  /// No description provided for @vastuCompassHold.
  ///
  /// In en, this message translates to:
  /// **'Hold reading'**
  String get vastuCompassHold;

  /// No description provided for @vastuCompassResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get vastuCompassResume;

  /// No description provided for @vastuAllZones.
  ///
  /// In en, this message translates to:
  /// **'All 16 zones'**
  String get vastuAllZones;

  /// No description provided for @vastuBestFor.
  ///
  /// In en, this message translates to:
  /// **'Best for'**
  String get vastuBestFor;

  /// No description provided for @vastuAvoid.
  ///
  /// In en, this message translates to:
  /// **'Avoid'**
  String get vastuAvoid;

  /// No description provided for @vastuCompassDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Readings use magnetic north and the widely used 16-zone Vastu grid. Consult a Vastu expert before making structural changes.'**
  String get vastuCompassDisclaimer;

  /// No description provided for @vastuZoneName.
  ///
  /// In en, this message translates to:
  /// **'{zone, select, n{North} nne{North-northeast} ne{Northeast} ene{East-northeast} e{East} ese{East-southeast} se{Southeast} sse{South-southeast} s{South} ssw{South-southwest} sw{Southwest} wsw{West-southwest} w{West} wnw{West-northwest} nw{Northwest} nnw{North-northwest} other{{zone}}}'**
  String vastuZoneName(String zone);

  /// No description provided for @vastuZoneTheme.
  ///
  /// In en, this message translates to:
  /// **'{zone, select, n{Money and new opportunities} nne{Health and immunity} ne{Clarity of mind and spiritual practice} ene{Recreation and joy} e{Social connections} ese{Churning and anxiety} se{Cash flow} sse{Strength and confidence} s{Fame and rest} ssw{Disposal and letting go} sw{Relationships and stability} wsw{Learning and savings} w{Gains and results} wnw{Release of negativity} nw{Support and help from others} nnw{Attraction and intimacy} other{{zone}}}'**
  String vastuZoneTheme(String zone);

  /// No description provided for @vastuZoneBest.
  ///
  /// In en, this message translates to:
  /// **'{zone, select, n{Entrance, living room, cash locker, home office} nne{Open space, medicine storage, light exercise} ne{Pooja room, meditation, drinking-water source} ene{Family lounge, play area} e{Entrance, windows, drawing room} ese{Laundry, washing machine, mixer and grinder} se{Kitchen, electrical equipment, inverter} sse{Kitchen, gym, focused workspace} s{Bedroom, rest area} ssw{Toilet, dustbin, storage for discarded items} sw{Master bedroom, heavy storage, locker} wsw{Study room, library} w{Dining area, children\'s room} wnw{Toilet, store room} nw{Guest room, garage, storage of finished goods} nnw{Couple\'s bedroom, lounge} other{{zone}}}'**
  String vastuZoneBest(String zone);

  /// No description provided for @vastuZoneAvoid.
  ///
  /// In en, this message translates to:
  /// **'{zone, select, n{Toilet, kitchen, heavy storage} nne{Toilet, kitchen, store room} ne{Toilet, kitchen, staircase, heavy furniture} ene{Toilet, heavy storage} e{Toilet, store room} ese{Bedroom, study} se{Water tank, bedroom, toilet} sse{Water tank, toilet} s{Water tank, toilet} ssw{Bedroom, kitchen, entrance} sw{Toilet, entrance, open space, kitchen} wsw{Toilet, kitchen} w{Kitchen, open water} wnw{Pooja room, bedroom} nw{Master bedroom, pooja room} nnw{Toilet, kitchen} other{{zone}}}'**
  String vastuZoneAvoid(String zone);

  /// No description provided for @yogasTitle.
  ///
  /// In en, this message translates to:
  /// **'Yogas in your chart'**
  String get yogasTitle;

  /// No description provided for @yogasIntro.
  ///
  /// In en, this message translates to:
  /// **'Planetary combinations from classical Parashari rules, read with whole-sign houses. Tap one to see what forms it.'**
  String get yogasIntro;

  /// No description provided for @yogasNone.
  ///
  /// In en, this message translates to:
  /// **'None of the yogas this app checks are formed in this chart.'**
  String get yogasNone;

  /// No description provided for @chartYogaCancelled.
  ///
  /// In en, this message translates to:
  /// **'cancelled'**
  String get chartYogaCancelled;

  /// No description provided for @chartYogaName.
  ///
  /// In en, this message translates to:
  /// **'{id, select, gajakesari{Gajakesari Yoga} budhaditya{Budhaditya Yoga} chandraMangal{Chandra-Mangal Yoga} ruchaka{Ruchaka Yoga} bhadra{Bhadra Yoga} hamsa{Hamsa Yoga} malavya{Malavya Yoga} shasha{Shasha Yoga} rajYoga{Raj Yoga} yogakaraka{Yogakaraka planet} dhanaYoga{Dhana Yoga} viparitaRajYoga{Viparita Raj Yoga} amala{Amala Yoga} kemadruma{Kemadruma Yoga} other{{id}}}'**
  String chartYogaName(String id);

  /// No description provided for @chartYogaMeaning.
  ///
  /// In en, this message translates to:
  /// **'{id, select, gajakesari{Traditionally linked with wisdom, respect and the ability to recover from setbacks.} budhaditya{Traditionally linked with intelligence, communication skills and recognition for one\'s work.} chandraMangal{Traditionally linked with drive, enterprise and earning through one\'s own effort.} ruchaka{One of the five Mahapurusha yogas: courage, energy and leadership.} bhadra{One of the five Mahapurusha yogas: sharp intellect, eloquence and skill with trade or learning.} hamsa{One of the five Mahapurusha yogas: wisdom, ethics and a respected, generous nature.} malavya{One of the five Mahapurusha yogas: refinement, comfort and an eye for beauty and the arts.} shasha{One of the five Mahapurusha yogas: discipline, endurance and authority built over time.} rajYoga{A combination of effort and fortune, traditionally linked with rise in status and responsibility.} yogakaraka{For your Lagna this planet rules both an angle and a trine, so its periods and placement carry extra weight.} dhanaYoga{A combination of the houses of income and fortune, traditionally linked with accumulating wealth.} viparitaRajYoga{Lords of difficult houses placed in difficult houses; traditionally gives success after obstacles.} amala{Traditionally linked with a good reputation and conduct that earns lasting respect.} kemadruma{Traditionally read as a need for emotional self-reliance. It is very often cancelled by other placements.} other{{id}}}'**
  String chartYogaMeaning(String id);

  /// No description provided for @chartYogaRule.
  ///
  /// In en, this message translates to:
  /// **'{id, select, gajakesari{Jupiter in a kendra (1st, 4th, 7th or 10th) from the Moon.} budhaditya{Sun and Mercury in the same sign.} chandraMangal{Moon and Mars in the same sign.} ruchaka{Mars in its own or exaltation sign, in a kendra from Lagna.} bhadra{Mercury in its own or exaltation sign, in a kendra from Lagna.} hamsa{Jupiter in its own or exaltation sign, in a kendra from Lagna.} malavya{Venus in its own or exaltation sign, in a kendra from Lagna.} shasha{Saturn in its own or exaltation sign, in a kendra from Lagna.} rajYoga{A kendra lord and a trikona lord in the same sign.} yogakaraka{Rules one of the 4th, 7th or 10th and one of the 5th or 9th from Lagna.} dhanaYoga{The lord of the 2nd or 11th in the same sign as the lord of the 1st, 5th or 9th (or each other).} viparitaRajYoga{The lord of the 6th, 8th or 12th placed in the 6th, 8th or 12th.} amala{Mercury, Jupiter or Venus in the 10th from Lagna or the Moon.} kemadruma{No planet other than the Sun, Rahu or Ketu in the 2nd or 12th from the Moon.} other{{id}}}'**
  String chartYogaRule(String id);

  /// No description provided for @compatTitle.
  ///
  /// In en, this message translates to:
  /// **'Marriage Compatibility'**
  String get compatTitle;

  /// No description provided for @compatHeading.
  ///
  /// In en, this message translates to:
  /// **'Ashtakoota Guna Milan'**
  String get compatHeading;

  /// No description provided for @compatIntro.
  ///
  /// In en, this message translates to:
  /// **'Compare two saved birth profiles using their Moon signs and Nakshatras.'**
  String get compatIntro;

  /// No description provided for @compatNeedTwoProfiles.
  ///
  /// In en, this message translates to:
  /// **'Please save at least two birth profiles before calculating compatibility.'**
  String get compatNeedTwoProfiles;

  /// No description provided for @compatManageProfiles.
  ///
  /// In en, this message translates to:
  /// **'Manage Birth Profiles'**
  String get compatManageProfiles;

  /// No description provided for @compatBrideProfile.
  ///
  /// In en, this message translates to:
  /// **'Bride profile'**
  String get compatBrideProfile;

  /// No description provided for @compatGroomProfile.
  ///
  /// In en, this message translates to:
  /// **'Groom profile'**
  String get compatGroomProfile;

  /// No description provided for @compatCalculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating charts…'**
  String get compatCalculating;

  /// No description provided for @compatCalculate.
  ///
  /// In en, this message translates to:
  /// **'Calculate Compatibility'**
  String get compatCalculate;

  /// No description provided for @compatSelectDifferent.
  ///
  /// In en, this message translates to:
  /// **'Please select two different profiles.'**
  String get compatSelectDifferent;

  /// No description provided for @compatProfileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'A selected profile is no longer available. Please select both profiles again.'**
  String get compatProfileUnavailable;

  /// No description provided for @compatPerson.
  ///
  /// In en, this message translates to:
  /// **'{person, select, bride{Bride} groom{Groom} other{{person}}}'**
  String compatPerson(String person);

  /// No description provided for @compatInvalidTime.
  ///
  /// In en, this message translates to:
  /// **'{person} profile has an invalid birth time. Edit the saved profile and enter time as HH:mm (24-hour).'**
  String compatInvalidTime(String person);

  /// No description provided for @compatInvalidLocation.
  ///
  /// In en, this message translates to:
  /// **'{person} profile has incomplete or invalid birth-location details. Edit the saved profile and verify its city, coordinates, and timezone.'**
  String compatInvalidLocation(String person);

  /// No description provided for @compatFutureDate.
  ///
  /// In en, this message translates to:
  /// **'{person} profile has a birth date in the future. Please correct the saved profile.'**
  String compatFutureDate(String person);

  /// No description provided for @compatUnable.
  ///
  /// In en, this message translates to:
  /// **'Unable to calculate compatibility: {error}'**
  String compatUnable(String error);

  /// No description provided for @compatExportSelect.
  ///
  /// In en, this message translates to:
  /// **'Please select two available, different profiles before exporting.'**
  String get compatExportSelect;

  /// No description provided for @compatPdfUnable.
  ///
  /// In en, this message translates to:
  /// **'Unable to create the compatibility PDF. Please try again.'**
  String get compatPdfUnable;

  /// No description provided for @compatPdfLanguage.
  ///
  /// In en, this message translates to:
  /// **'PDF language'**
  String get compatPdfLanguage;

  /// No description provided for @compatExportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF (Print or Save)'**
  String get compatExportPdf;

  /// No description provided for @compatDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Traditional astrology interpretation only. This score is not a scientifically validated prediction of relationship quality or success. Consult a qualified practitioner for tradition-specific interpretations and exceptions.'**
  String get compatDisclaimer;

  /// No description provided for @compatScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Ashtakoota score'**
  String get compatScoreLabel;

  /// No description provided for @compatMeetsThreshold.
  ///
  /// In en, this message translates to:
  /// **'Meets the traditional 18-point threshold'**
  String get compatMeetsThreshold;

  /// No description provided for @compatBelowThreshold.
  ///
  /// In en, this message translates to:
  /// **'Below the traditional 18-point threshold'**
  String get compatBelowThreshold;

  /// No description provided for @compatEightKootas.
  ///
  /// In en, this message translates to:
  /// **'Eight Kootas'**
  String get compatEightKootas;

  /// No description provided for @compatInsightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Relative score insights'**
  String get compatInsightsTitle;

  /// No description provided for @compatInsightsBody.
  ///
  /// In en, this message translates to:
  /// **'These compare points earned within each Koota. They are descriptive summaries, not relationship predictions.'**
  String get compatInsightsBody;

  /// No description provided for @compatHighest.
  ///
  /// In en, this message translates to:
  /// **'Highest relative score'**
  String get compatHighest;

  /// No description provided for @compatHighestName.
  ///
  /// In en, this message translates to:
  /// **'Best relative percentage'**
  String get compatHighestName;

  /// No description provided for @compatLowest.
  ///
  /// In en, this message translates to:
  /// **'Lowest relative score'**
  String get compatLowest;

  /// No description provided for @compatLowestName.
  ///
  /// In en, this message translates to:
  /// **'Lowest relative percentage'**
  String get compatLowestName;

  /// No description provided for @compatFlagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Traditional flags to review'**
  String get compatFlagsTitle;

  /// No description provided for @compatFlagsNote.
  ///
  /// In en, this message translates to:
  /// **'Flags are not a final verdict. Interpretations, exceptions, and remedies vary by tradition.'**
  String get compatFlagsNote;

  /// No description provided for @compatFlag.
  ///
  /// In en, this message translates to:
  /// **'{flag, select, nadi{Traditional Nadi dosha flag: both nakshatras share a Nadi.} bhakoot{Traditional Bhakoot dosha flag: the Moon signs have a 2/12, 5/9 or 6/8 relationship.} other{{flag}}}'**
  String compatFlag(String flag);

  /// No description provided for @compatManglikTitle.
  ///
  /// In en, this message translates to:
  /// **'Manglik check'**
  String get compatManglikTitle;

  /// No description provided for @compatManglikNeither.
  ///
  /// In en, this message translates to:
  /// **'Neither chart has an active Manglik dosha.'**
  String get compatManglikNeither;

  /// No description provided for @compatManglikBoth.
  ///
  /// In en, this message translates to:
  /// **'Both charts are Manglik, which is traditionally considered to balance out.'**
  String get compatManglikBoth;

  /// No description provided for @compatManglikOnlyOne.
  ///
  /// In en, this message translates to:
  /// **'Only one chart is Manglik. Traditional matching reviews this further, together with cancellations and the full charts.'**
  String get compatManglikOnlyOne;

  /// No description provided for @compatManglikStatus.
  ///
  /// In en, this message translates to:
  /// **'{status, select, none{Not Manglik} mild{Mild Manglik (from Moon/Venus)} present{Manglik} cancelled{Manglik placement, cancelled} other{{status}}}'**
  String compatManglikStatus(String status);

  /// No description provided for @compatManglikPerson.
  ///
  /// In en, this message translates to:
  /// **'{person}: {status}'**
  String compatManglikPerson(String person, String status);

  /// No description provided for @kootaName.
  ///
  /// In en, this message translates to:
  /// **'{koota, select, varna{Varna} vashya{Vashya} tara{Tara} yoni{Yoni} grahaMaitri{Graha Maitri} gana{Gana} bhakoot{Bhakoot} nadi{Nadi} other{{koota}}}'**
  String kootaName(String koota);

  /// No description provided for @kootaExplanation.
  ///
  /// In en, this message translates to:
  /// **'{koota, select, varna{Points from traditional Varna matching.} vashya{Points from traditional Vashya matching.} tara{Points from the distance between the two nakshatras.} yoni{Points from traditional Yoni matching.} grahaMaitri{Points from the friendship between the Moon-sign lords.} gana{Points from traditional Deva, Manushya and Rakshasa matching.} bhakoot{Points from the 2/12, 5/9 and 6/8 sign-distance rule.} nadi{Points from traditional Nadi matching of the two nakshatras.} other{{koota}}}'**
  String kootaExplanation(String koota);

  /// No description provided for @numerologyTitle.
  ///
  /// In en, this message translates to:
  /// **'Numerology'**
  String get numerologyTitle;

  /// No description provided for @numerologySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mulank, Bhagyank and your name number'**
  String get numerologySubtitle;

  /// No description provided for @numerologyIntro.
  ///
  /// In en, this message translates to:
  /// **'Calculated with the Chaldean system used in Indian numerology, from the active profile\'s date of birth and name.'**
  String get numerologyIntro;

  /// No description provided for @numerologyMulank.
  ///
  /// In en, this message translates to:
  /// **'Mulank (root number)'**
  String get numerologyMulank;

  /// No description provided for @numerologyMulankHint.
  ///
  /// In en, this message translates to:
  /// **'From your day of birth'**
  String get numerologyMulankHint;

  /// No description provided for @numerologyBhagyank.
  ///
  /// In en, this message translates to:
  /// **'Bhagyank (destiny number)'**
  String get numerologyBhagyank;

  /// No description provided for @numerologyBhagyankHint.
  ///
  /// In en, this message translates to:
  /// **'From your full date of birth'**
  String get numerologyBhagyankHint;

  /// No description provided for @numerologyRuledBy.
  ///
  /// In en, this message translates to:
  /// **'Ruled by {planet}'**
  String numerologyRuledBy(String planet);

  /// No description provided for @numerologyNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Name number'**
  String get numerologyNameTitle;

  /// No description provided for @numerologyNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get numerologyNameLabel;

  /// No description provided for @numerologyNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Try other spellings to see how the number changes.'**
  String get numerologyNameHelper;

  /// No description provided for @numerologyNameNumber.
  ///
  /// In en, this message translates to:
  /// **'Name number'**
  String get numerologyNameNumber;

  /// No description provided for @numerologyCompound.
  ///
  /// In en, this message translates to:
  /// **'Compound number {total}'**
  String numerologyCompound(int total);

  /// No description provided for @numerologyNameNone.
  ///
  /// In en, this message translates to:
  /// **'Enter the name in English letters to calculate its number.'**
  String get numerologyNameNone;

  /// No description provided for @numerologyNameInHarmony.
  ///
  /// In en, this message translates to:
  /// **'This name number matches your Mulank or Bhagyank, which numerologists consider harmonious.'**
  String get numerologyNameInHarmony;

  /// No description provided for @numerologyNameDifferent.
  ///
  /// In en, this message translates to:
  /// **'This name number differs from your Mulank and Bhagyank. Numerologists sometimes suggest a spelling that matches one of them.'**
  String get numerologyNameDifferent;

  /// No description provided for @numerologyPersonalYear.
  ///
  /// In en, this message translates to:
  /// **'Personal year {year}: {number}'**
  String numerologyPersonalYear(String year, int number);

  /// No description provided for @numerologyYearTheme.
  ///
  /// In en, this message translates to:
  /// **'{number, select, n1{A year for new beginnings and taking the lead.} n2{A year for patience, partnerships and cooperation.} n3{A year for learning, expression and growth.} n4{A year for building foundations through steady work.} n5{A year of change, travel and new experiences.} n6{A year centred on home, family and responsibilities.} n7{A year for reflection, study and inner work.} n8{A year for ambition, finances and long-term results.} n9{A year of completion — finish old matters and let go.} other{{number}}}'**
  String numerologyYearTheme(String number);

  /// No description provided for @numerologyTraits.
  ///
  /// In en, this message translates to:
  /// **'{number, select, n1{Number 1 (Sun): independent, ambitious and a natural leader; happiest when starting things and setting direction.} n2{Number 2 (Moon): sensitive, imaginative and diplomatic; strong in partnership, care and creative work.} n3{Number 3 (Jupiter): wise, optimistic and disciplined; drawn to teaching, guidance and growth.} n4{Number 4 (Rahu): original and hard-working, with unconventional ideas; life often brings sudden turns.} n5{Number 5 (Mercury): quick, communicative and adaptable; good at business, travel and learning new things.} n6{Number 6 (Venus): warm, artistic and family-minded; values harmony, comfort and beauty.} n7{Number 7 (Ketu): reflective and intuitive; drawn to research, spirituality and solitude.} n8{Number 8 (Saturn): patient, disciplined and serious; success tends to come steadily through effort.} n9{Number 9 (Mars): energetic, courageous and determined; thrives on action and challenges.} other{{number}}}'**
  String numerologyTraits(String number);

  /// No description provided for @numerologyLuckyDay.
  ///
  /// In en, this message translates to:
  /// **'{number, select, n1{Sunday} n2{Monday} n3{Thursday} n4{Saturday} n5{Wednesday} n6{Friday} n7{Monday} n8{Saturday} n9{Tuesday} other{{number}}}'**
  String numerologyLuckyDay(String number);

  /// No description provided for @numerologyLuckyColour.
  ///
  /// In en, this message translates to:
  /// **'{number, select, n1{gold and orange} n2{white and cream} n3{yellow} n4{grey and electric blue} n5{green} n6{white and light pink} n7{light green and grey} n8{dark blue and black} n9{red} other{{number}}}'**
  String numerologyLuckyColour(String number);

  /// No description provided for @numerologyLucky.
  ///
  /// In en, this message translates to:
  /// **'Favourable day: {day}. Colours: {colour}.'**
  String numerologyLucky(String day, String colour);

  /// No description provided for @numerologyDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Numerology is a traditional practice for reflection, not a prediction.'**
  String get numerologyDisclaimer;

  /// No description provided for @homePanchangFallback.
  ///
  /// In en, this message translates to:
  /// **'Showing the Panchang for {city} because your current location isn\'t available.'**
  String homePanchangFallback(String city);

  /// No description provided for @remediesTitle.
  ///
  /// In en, this message translates to:
  /// **'Remedies & gemstones'**
  String get remediesTitle;

  /// No description provided for @remediesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Gemstones, mantras and charity from your chart'**
  String get remediesSubtitle;

  /// No description provided for @remediesIntro.
  ///
  /// In en, this message translates to:
  /// **'Traditional practices chosen from your Lagna, current Dasha and doshas.'**
  String get remediesIntro;

  /// No description provided for @remediesGemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your gemstones'**
  String get remediesGemsTitle;

  /// No description provided for @remediesGemsIntro.
  ///
  /// In en, this message translates to:
  /// **'The common Lagna-based method: stones of the planets ruling your 1st, 5th and 9th houses.'**
  String get remediesGemsIntro;

  /// No description provided for @remediesGemRole.
  ///
  /// In en, this message translates to:
  /// **'{role, select, life{Life stone · Lagna lord} lucky{Lucky stone · 5th lord} fortune{Fortune stone · 9th lord} other{{role}}}'**
  String remediesGemRole(String role);

  /// No description provided for @remediesGemName.
  ///
  /// In en, this message translates to:
  /// **'{planet, select, sun{Ruby (Manik)} moon{Pearl (Moti)} mars{Red Coral (Moonga)} mercury{Emerald (Panna)} jupiter{Yellow Sapphire (Pukhraj)} venus{Diamond (Heera)} saturn{Blue Sapphire (Neelam)} rahu{Hessonite (Gomed)} ketu{Cat\'s Eye (Lahsuniya)} other{{planet}}}'**
  String remediesGemName(String planet);

  /// No description provided for @remediesGemSubstitute.
  ///
  /// In en, this message translates to:
  /// **'{planet, select, sun{red garnet} moon{moonstone} mars{carnelian} mercury{peridot} jupiter{yellow topaz or citrine} venus{white sapphire or opal} saturn{amethyst} rahu{orange zircon} ketu{tiger\'s eye} other{{planet}}}'**
  String remediesGemSubstitute(String planet);

  /// No description provided for @remediesGemWear.
  ///
  /// In en, this message translates to:
  /// **'{planet, select, sun{Ring finger, in gold or copper, on a Sunday morning} moon{Little finger, in silver, on a Monday morning} mars{Ring finger, in gold or copper, on a Tuesday morning} mercury{Little finger, in gold, on a Wednesday morning} jupiter{Index finger, in gold, on a Thursday morning} venus{Middle finger, in silver or platinum, on a Friday morning} saturn{Middle finger, in silver or panchdhatu, on a Saturday evening} rahu{Middle finger, in silver, on a Saturday} ketu{Little finger, in silver, on a Tuesday or Thursday} other{{planet}}}'**
  String remediesGemWear(String planet);

  /// No description provided for @remediesSubstituteLabel.
  ///
  /// In en, this message translates to:
  /// **'Affordable substitute: {stone}'**
  String remediesSubstituteLabel(String stone);

  /// No description provided for @remediesGemCaution.
  ///
  /// In en, this message translates to:
  /// **'{planet} also rules a difficult house in your chart. Consult an astrologer before wearing this stone.'**
  String remediesGemCaution(String planet);

  /// No description provided for @remediesGemAdvice.
  ///
  /// In en, this message translates to:
  /// **'Wear a natural, untreated stone after a trial period, and stop if you feel unwell or uneasy. Never combine stones without advice.'**
  String get remediesGemAdvice;

  /// No description provided for @remediesPeriodsTitle.
  ///
  /// In en, this message translates to:
  /// **'For your current periods'**
  String get remediesPeriodsTitle;

  /// No description provided for @remediesPeriodRole.
  ///
  /// In en, this message translates to:
  /// **'{role, select, mahadasha{Mahadasha} antardasha{Antardasha} other{{role}}}'**
  String remediesPeriodRole(String role);

  /// No description provided for @remediesMantra.
  ///
  /// In en, this message translates to:
  /// **'{planet, select, sun{ॐ ह्रां ह्रीं ह्रौं सः सूर्याय नमः} moon{ॐ श्रां श्रीं श्रौं सः चन्द्राय नमः} mars{ॐ क्रां क्रीं क्रौं सः भौमाय नमः} mercury{ॐ ब्रां ब्रीं ब्रौं सः बुधाय नमः} jupiter{ॐ ग्रां ग्रीं ग्रौं सः गुरवे नमः} venus{ॐ द्रां द्रीं द्रौं सः शुक्राय नमः} saturn{ॐ प्रां प्रीं प्रौं सः शनैश्चराय नमः} rahu{ॐ भ्रां भ्रीं भ्रौं सः राहवे नमः} ketu{ॐ स्रां स्रीं स्रौं सः केतवे नमः} other{{planet}}}'**
  String remediesMantra(String planet);

  /// No description provided for @remediesMantraLatin.
  ///
  /// In en, this message translates to:
  /// **'{planet, select, sun{Om Hraam Hreem Hraum Sah Suryaya Namah} moon{Om Shraam Shreem Shraum Sah Chandraya Namah} mars{Om Kraam Kreem Kraum Sah Bhaumaya Namah} mercury{Om Braam Breem Braum Sah Budhaya Namah} jupiter{Om Graam Greem Graum Sah Gurave Namah} venus{Om Draam Dreem Draum Sah Shukraya Namah} saturn{Om Praam Preem Praum Sah Shanaischaraya Namah} rahu{Om Bhraam Bhreem Bhraum Sah Rahave Namah} ketu{Om Sraam Sreem Sraum Sah Ketave Namah} other{{planet}}}'**
  String remediesMantraLatin(String planet);

  /// No description provided for @remediesMantraHow.
  ///
  /// In en, this message translates to:
  /// **'Chant 108 times, ideally on {day}.'**
  String remediesMantraHow(String day);

  /// No description provided for @remediesDay.
  ///
  /// In en, this message translates to:
  /// **'{planet, select, sun{Sunday} moon{Monday} mars{Tuesday} mercury{Wednesday} jupiter{Thursday} venus{Friday} saturn{Saturday} rahu{Saturday} ketu{Tuesday} other{{planet}}}'**
  String remediesDay(String planet);

  /// No description provided for @remediesCharity.
  ///
  /// In en, this message translates to:
  /// **'Charity: {items} on {day}.'**
  String remediesCharity(String items, String day);

  /// No description provided for @remediesCharityItems.
  ///
  /// In en, this message translates to:
  /// **'{planet, select, sun{wheat, jaggery or copper} moon{rice, milk or white cloth} mars{red lentils (masoor) or red cloth} mercury{green moong or green cloth} jupiter{chana dal, turmeric or yellow cloth} venus{rice, sugar or white clothes} saturn{black sesame, mustard oil or black cloth} rahu{black sesame, a blanket or a coconut} ketu{a blanket, or food for street dogs} other{{planet}}}'**
  String remediesCharityItems(String planet);

  /// No description provided for @remediesDeity.
  ///
  /// In en, this message translates to:
  /// **'Worship: {deity}'**
  String remediesDeity(String deity);

  /// No description provided for @remediesDeityName.
  ///
  /// In en, this message translates to:
  /// **'{planet, select, sun{Surya — Aditya Hridayam} moon{Shiva — Shiva Chalisa or Om Namah Shivaya} mars{Hanuman — Hanuman Chalisa} mercury{Vishnu — Vishnu Sahasranama} jupiter{Vishnu or Brihaspati — Guru stotra} venus{Lakshmi — Shri Suktam} saturn{Hanuman or Shani Dev — Shani Chalisa} rahu{Durga — Durga Saptashati} ketu{Ganesha — Ganesh Atharvashirsha} other{{planet}}}'**
  String remediesDeityName(String planet);

  /// No description provided for @remediesDoshasTitle.
  ///
  /// In en, this message translates to:
  /// **'For your doshas'**
  String get remediesDoshasTitle;

  /// No description provided for @remediesNoDoshas.
  ///
  /// In en, this message translates to:
  /// **'No active Manglik, Kaal Sarp or Sade Sati in your chart right now.'**
  String get remediesNoDoshas;

  /// No description provided for @remediesManglik.
  ///
  /// In en, this message translates to:
  /// **'Manglik: recite Hanuman Chalisa on Tuesdays, offer red flowers and donate red lentils. Traditionally, Kumbh Vivah or marriage to another Manglik is advised.'**
  String get remediesManglik;

  /// No description provided for @remediesSadeSati.
  ///
  /// In en, this message translates to:
  /// **'Sade Sati or Dhaiya: light a mustard-oil lamp under a peepal tree on Saturdays, recite Hanuman Chalisa, and give to workers and the elderly.'**
  String get remediesSadeSati;

  /// No description provided for @remediesKaalSarp.
  ///
  /// In en, this message translates to:
  /// **'Kaal Sarp: a Kaal Sarp shanti puja (often at Trimbakeshwar), and Om Namah Shivaya or the Maha Mrityunjaya mantra daily.'**
  String get remediesKaalSarp;

  /// No description provided for @remediesDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'These are traditional practices, not medical, financial or legal advice. Gemstones in particular should be chosen with a qualified astrologer.'**
  String get remediesDisclaimer;

  /// No description provided for @choghadiyaTitle.
  ///
  /// In en, this message translates to:
  /// **'Choghadiya'**
  String get choghadiyaTitle;

  /// No description provided for @choghadiyaIntro.
  ///
  /// In en, this message translates to:
  /// **'The day and the night are each split into eight parts. Amrit, Shubh and Labh are favourable, Chal is neutral, and Udveg, Rog and Kaal are best avoided for new work.'**
  String get choghadiyaIntro;

  /// No description provided for @choghadiyaName.
  ///
  /// In en, this message translates to:
  /// **'{name, select, amrit{Amrit} shubh{Shubh} labh{Labh} chal{Chal} udveg{Udveg} rog{Rog} kaal{Kaal} other{{name}}}'**
  String choghadiyaName(String name);

  /// No description provided for @choghadiyaQuality.
  ///
  /// In en, this message translates to:
  /// **'{quality, select, good{Good} neutral{Neutral} bad{Avoid} other{{quality}}}'**
  String choghadiyaQuality(String quality);

  /// No description provided for @horaTitle.
  ///
  /// In en, this message translates to:
  /// **'Hora · planetary hours'**
  String get horaTitle;

  /// No description provided for @horaIntro.
  ///
  /// In en, this message translates to:
  /// **'Each hour is ruled by a planet, starting with the weekday\'s lord at sunrise. Choose the hora of a planet that suits the task.'**
  String get horaIntro;

  /// No description provided for @dayDivisionDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get dayDivisionDay;

  /// No description provided for @dayDivisionNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get dayDivisionNight;

  /// No description provided for @dayDivisionNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get dayDivisionNow;

  /// No description provided for @yamagandaTitle.
  ///
  /// In en, this message translates to:
  /// **'Yamaganda'**
  String get yamagandaTitle;

  /// No description provided for @yamagandaDescription.
  ///
  /// In en, this message translates to:
  /// **'Traditionally avoided for travel and new beginnings.'**
  String get yamagandaDescription;

  /// No description provided for @gulikaTitle.
  ///
  /// In en, this message translates to:
  /// **'Gulika Kaal'**
  String get gulikaTitle;

  /// No description provided for @gulikaDescription.
  ///
  /// In en, this message translates to:
  /// **'Work begun now is said to repeat, so it is avoided for anything you would not want again.'**
  String get gulikaDescription;

  /// No description provided for @dayDivisionsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The Sun does not rise or set here today, so these periods can\'t be calculated.'**
  String get dayDivisionsUnavailable;

  /// No description provided for @dayDivisionsBeforeSunrise.
  ///
  /// In en, this message translates to:
  /// **'Before sunrise the timings belong to the previous day\'s night.'**
  String get dayDivisionsBeforeSunrise;

  /// No description provided for @shareAction.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareAction;

  /// No description provided for @panchangShareHeading.
  ///
  /// In en, this message translates to:
  /// **'Panchang · {date}'**
  String panchangShareHeading(String date);

  /// No description provided for @panchangShareGoodChoghadiya.
  ///
  /// In en, this message translates to:
  /// **'Good Choghadiya today'**
  String get panchangShareGoodChoghadiya;

  /// No description provided for @panchangShareFooter.
  ///
  /// In en, this message translates to:
  /// **'Shared from RV Astro Vastu'**
  String get panchangShareFooter;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open sharing on this device.'**
  String get shareFailed;

  /// No description provided for @yourDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Your day'**
  String get yourDayTitle;

  /// No description provided for @yourDayVerdict.
  ///
  /// In en, this message translates to:
  /// **'{verdict, select, good{A favourable day for you} mixed{A mixed day — pick your timing} caution{Go gently today} other{{verdict}}}'**
  String yourDayVerdict(String verdict);

  /// No description provided for @yourDayVerdictHint.
  ///
  /// In en, this message translates to:
  /// **'{verdict, select, good{Your Tara Bala and Chandra Bala both support new work today.} mixed{One of your two daily strengths is weak. Use a good Choghadiya for anything important.} caution{The Moon is in a testing position for you. If you can, keep important beginnings for a better day.} other{{verdict}}}'**
  String yourDayVerdictHint(String verdict);

  /// No description provided for @yourDayTaraTitle.
  ///
  /// In en, this message translates to:
  /// **'Tara Bala'**
  String get yourDayTaraTitle;

  /// No description provided for @yourDayTaraName.
  ///
  /// In en, this message translates to:
  /// **'{tara, select, janma{Janma} sampat{Sampat} vipat{Vipat} kshema{Kshema} pratyari{Pratyari} sadhaka{Sadhaka} vadha{Vadha} mitra{Mitra} paramaMitra{Parama Mitra} other{{tara}}}'**
  String yourDayTaraName(String tara);

  /// No description provided for @yourDayTaraLine.
  ///
  /// In en, this message translates to:
  /// **'{tara} Tara · Moon in {nakshatra}'**
  String yourDayTaraLine(String tara, String nakshatra);

  /// No description provided for @yourDayChandraTitle.
  ///
  /// In en, this message translates to:
  /// **'Chandra Bala'**
  String get yourDayChandraTitle;

  /// No description provided for @yourDayChandraLine.
  ///
  /// In en, this message translates to:
  /// **'Moon in house {house} from your Moon sign, {sign}'**
  String yourDayChandraLine(String house, String sign);

  /// No description provided for @yourDayChandrashtama.
  ///
  /// In en, this message translates to:
  /// **'Chandrashtama: the Moon is in the 8th from your Moon sign'**
  String get yourDayChandrashtama;

  /// No description provided for @yourDayStrength.
  ///
  /// In en, this message translates to:
  /// **'{strength, select, good{Strong} weak{Weak} bad{Avoid} other{{strength}}}'**
  String yourDayStrength(String strength);

  /// No description provided for @yourDayUntil.
  ///
  /// In en, this message translates to:
  /// **'until {time}'**
  String yourDayUntil(String time);

  /// No description provided for @yourDayTimings.
  ///
  /// In en, this message translates to:
  /// **'See today\'s timings'**
  String get yourDayTimings;

  /// No description provided for @premiumTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumTitle;

  /// No description provided for @premiumHeadline.
  ///
  /// In en, this message translates to:
  /// **'RV Astro Vastu Premium'**
  String get premiumHeadline;

  /// No description provided for @premiumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your complete chart, every report and no limits.'**
  String get premiumSubtitle;

  /// No description provided for @premiumFeatureLocked.
  ///
  /// In en, this message translates to:
  /// **'{feature} is part of Premium'**
  String premiumFeatureLocked(String feature);

  /// No description provided for @premiumFeatureName.
  ///
  /// In en, this message translates to:
  /// **'{feature, select, navamsa{Navamsa (D9) chart} yogas{Yogas in your chart} doshaDetails{Full dosha report} transits{Personal transits} dashaTimeline{Full Dasha timeline} remedies{Remedies & gemstones} muhuratPlanner{Muhurat planner} compatibilityDetails{Detailed marriage matching} nameNumerology{Name numerology} unlimitedProfiles{Unlimited profiles} kundliPdf{Detailed Kundali analysis PDF report} compatibilityPdf{Detailed Compatibility analysis PDF report} vastuRemedies{Vastu remedies and grid} pujaVidhi{Complete puja vidhi} vargaCharts{All divisional charts} aiAstrologer{AI astrologer, unlimited} transitAlerts{All transit alerts} strength{Ashtakavarga & Shadbala} varshphal{Varshphal year report} kp{KP system & Prashna} other{{feature}}}'**
  String premiumFeatureName(String feature);

  /// No description provided for @premiumFeatureDescription.
  ///
  /// In en, this message translates to:
  /// **'{feature, select, navamsa{The D9 chart for marriage, dharma and planetary strength, with the yogas in your chart.} yogas{Raj, Dhana, Mahapurusha and other yogas, with how each one forms.} doshaDetails{Kaal Sarp type, Manglik cancellations and your full Sade Sati timeline.} transits{Where Jupiter, Saturn, Rahu and Ketu fall for you, and when they move.} dashaTimeline{Every Mahadasha, Antardasha and Pratyantardasha across your life.} remedies{Gemstones, mantras and charity chosen from your own chart.} muhuratPlanner{Find good dates for marriage, griha pravesh, travel and more.} compatibilityDetails{All eight kootas, dosha flags and the Manglik comparison.} nameNumerology{Check your name number and compare spellings.} unlimitedProfiles{Save charts for the whole family. Free accounts keep 2.} kundliPdf{Download a full Kundli report as a PDF for any profile.} compatibilityPdf{Export marriage-matching reports as PDF.} vastuRemedies{Dosh nivaran, remedies and upay for every dosha in your home plan, with the full 16-zone Vastu grid.} pujaVidhi{Step-by-step puja vidhi, mantras with meanings, the vrat katha and the best puja time at your place for every festival and vrat.} vargaCharts{Dashamsha for career, Saptamsha for children, Hora for wealth and every other Shodashvarga chart from D2 to D60, in North or South Indian style.} aiAstrologer{Ask the AI astrologer as many questions as you like about your own chart, dasha and transits, in your language.} transitAlerts{Be told when Jupiter, Saturn, Rahu or Ketu change sign, with what each move means for your Moon sign.} strength{Points for every house and the strength of each planet} varshphal{Year chart, Muntha lord and every planet\'s house for your year ahead, with a PDF} kp{KP cusps with star and sub lords, ruling planets and horary answers} other{{feature}}}'**
  String premiumFeatureDescription(String feature);

  /// No description provided for @premiumPlanName.
  ///
  /// In en, this message translates to:
  /// **'{period, select, monthly{Monthly} yearly{Yearly} other{{period}}}'**
  String premiumPlanName(String period);

  /// No description provided for @premiumPerPeriod.
  ///
  /// In en, this message translates to:
  /// **'{period, select, monthly{per month} yearly{per year} other{{period}}}'**
  String premiumPerPeriod(String period);

  /// No description provided for @premiumSave.
  ///
  /// In en, this message translates to:
  /// **'Save {percent}%'**
  String premiumSave(String percent);

  /// No description provided for @premiumTrial.
  ///
  /// In en, this message translates to:
  /// **'{days}-day free trial'**
  String premiumTrial(String days);

  /// No description provided for @premiumStartTrial.
  ///
  /// In en, this message translates to:
  /// **'Start {days}-day free trial'**
  String premiumStartTrial(String days);

  /// No description provided for @premiumContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get premiumContinue;

  /// No description provided for @premiumRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get premiumRestore;

  /// No description provided for @premiumRestored.
  ///
  /// In en, this message translates to:
  /// **'Your purchases have been restored.'**
  String get premiumRestored;

  /// No description provided for @premiumNothingToRestore.
  ///
  /// In en, this message translates to:
  /// **'No earlier purchases were found for this store account.'**
  String get premiumNothingToRestore;

  /// No description provided for @premiumWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Premium!'**
  String get premiumWelcome;

  /// No description provided for @premiumPending.
  ///
  /// In en, this message translates to:
  /// **'Your payment is pending. Premium unlocks as soon as it is approved.'**
  String get premiumPending;

  /// No description provided for @premiumFailed.
  ///
  /// In en, this message translates to:
  /// **'The purchase didn\'t go through. You haven\'t been charged.'**
  String get premiumFailed;

  /// No description provided for @premiumUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Purchases aren\'t available in this version of the app yet.'**
  String get premiumUnavailable;

  /// No description provided for @premiumActive.
  ///
  /// In en, this message translates to:
  /// **'You\'re a Premium member'**
  String get premiumActive;

  /// No description provided for @premiumRenewsOn.
  ///
  /// In en, this message translates to:
  /// **'Renews on {date}'**
  String premiumRenewsOn(String date);

  /// No description provided for @premiumEndsOn.
  ///
  /// In en, this message translates to:
  /// **'Ends on {date}'**
  String premiumEndsOn(String date);

  /// No description provided for @premiumManage.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get premiumManage;

  /// No description provided for @premiumAddOnsTitle.
  ///
  /// In en, this message translates to:
  /// **'Just need a report?'**
  String get premiumAddOnsTitle;

  /// No description provided for @premiumAddOnsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Buy once and keep it. No subscription.'**
  String get premiumAddOnsSubtitle;

  /// No description provided for @premiumAddOnDescription.
  ///
  /// In en, this message translates to:
  /// **'{addOn, select, kundliPdf{Unlimited Kundli PDFs for every saved profile. Pay once, keep forever.} compatibilityPdf{Unlimited marriage-matching PDFs. Pay once, keep forever.} varshphalPdf{Your Varshphal year chart and PDF report every year. Pay once, keep forever.} other{{addOn}}}'**
  String premiumAddOnDescription(String addOn);

  /// No description provided for @premiumOwned.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get premiumOwned;

  /// No description provided for @premiumLegal.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions renew automatically at the price shown until you cancel in your App Store or Google Play account settings at least 24 hours before the period (or free trial) ends. Payment is charged to your store account.'**
  String get premiumLegal;

  /// No description provided for @premiumTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get premiumTerms;

  /// No description provided for @premiumPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get premiumPrivacy;

  /// No description provided for @premiumUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock with Premium'**
  String get premiumUnlock;

  /// No description provided for @premiumBadge.
  ///
  /// In en, this message translates to:
  /// **'PREMIUM'**
  String get premiumBadge;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep Premium on every phone'**
  String get accountSignInTitle;

  /// No description provided for @accountSignInBody.
  ///
  /// In en, this message translates to:
  /// **'Use your email to keep Premium and your purchases on any phone you use. We\'ll send you a 6-digit code, no password needed.'**
  String get accountSignInBody;

  /// No description provided for @accountEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get accountEmailLabel;

  /// No description provided for @accountSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get accountSendCode;

  /// No description provided for @accountCodeSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {email}.'**
  String accountCodeSent(String email);

  /// No description provided for @accountCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get accountCodeLabel;

  /// No description provided for @accountVerify.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get accountVerify;

  /// No description provided for @accountChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get accountChangeEmail;

  /// No description provided for @accountInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get accountInvalidEmail;

  /// No description provided for @accountInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'That code didn\'t work. Check it and try again.'**
  String get accountInvalidCode;

  /// No description provided for @accountSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the code. Check the email address and your connection.'**
  String get accountSendFailed;

  /// No description provided for @accountErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get accountErrorGeneric;

  /// No description provided for @accountSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String accountSignedInAs(String email);

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @accountSignedIn.
  ///
  /// In en, this message translates to:
  /// **'You\'re signed in.'**
  String get accountSignedIn;

  /// No description provided for @accountUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sign-in isn\'t set up in this version of the app.'**
  String get accountUnavailable;

  /// No description provided for @accountMembershipTitle.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get accountMembershipTitle;

  /// No description provided for @accountFreePlan.
  ///
  /// In en, this message translates to:
  /// **'Free plan'**
  String get accountFreePlan;

  /// No description provided for @accountPremiumPlan.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get accountPremiumPlan;

  /// No description provided for @accountSeePremium.
  ///
  /// In en, this message translates to:
  /// **'See Premium'**
  String get accountSeePremium;

  /// No description provided for @accountOwnedAddOns.
  ///
  /// In en, this message translates to:
  /// **'Your add-ons'**
  String get accountOwnedAddOns;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get authHaveAccount;

  /// No description provided for @premiumUnlockDetails.
  ///
  /// In en, this message translates to:
  /// **'The full details are part of Premium.'**
  String get premiumUnlockDetails;

  /// No description provided for @premiumUnlockShort.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get premiumUnlockShort;

  /// No description provided for @accountDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDeleteButton;

  /// No description provided for @accountDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get accountDeleteTitle;

  /// No description provided for @accountDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account and every birth profile saved on this device and in the cloud. It can\'t be undone.'**
  String get accountDeleteBody;

  /// No description provided for @accountDeleteSubscriptionWarning.
  ///
  /// In en, this message translates to:
  /// **'Your Premium subscription is billed by the App Store or Google Play and won\'t stop by itself. Cancel it there first with Manage subscription.'**
  String get accountDeleteSubscriptionWarning;

  /// No description provided for @accountDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get accountDeleteConfirm;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account and data have been deleted.'**
  String get accountDeleted;

  /// No description provided for @accountDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete your account. Check your connection and try again.'**
  String get accountDeleteFailed;

  /// No description provided for @reportKundaliTitle.
  ///
  /// In en, this message translates to:
  /// **'Detailed Kundali analysis report'**
  String get reportKundaliTitle;

  /// No description provided for @reportIntro.
  ///
  /// In en, this message translates to:
  /// **'This report reads your birth chart in order: your nature, the planets and the houses they occupy, yogas, planetary periods, doshas, remedies and numerology.'**
  String get reportIntro;

  /// No description provided for @reportNatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Your nature'**
  String get reportNatureTitle;

  /// No description provided for @reportLagnaHeading.
  ///
  /// In en, this message translates to:
  /// **'Ascendant (Lagna) in {sign}'**
  String reportLagnaHeading(String sign);

  /// No description provided for @reportMoonHeading.
  ///
  /// In en, this message translates to:
  /// **'Moon in {sign}'**
  String reportMoonHeading(String sign);

  /// No description provided for @reportLagnaTraits.
  ///
  /// In en, this message translates to:
  /// **'{sign, select, Aries{Energetic, direct and quick to act. You lead from the front, enjoy challenges and do best when you can start things your own way.} Taurus{Steady, patient and practical. You value comfort, loyalty and security, and build slowly but lastingly.} Gemini{Curious, talkative and adaptable. You learn fast, enjoy variety and do well in work that uses words, ideas and contacts.} Cancer{Caring, sensitive and protective. Home and family matter deeply to you, and you read people\'s moods well.} Leo{Confident, warm and generous. You like to be seen, take responsibility naturally and inspire loyalty in others.} Virgo{Careful, analytical and helpful. You notice details, like order and improve whatever you work on.} Libra{Balanced, polite and sociable. You seek harmony and fairness and work best in partnership.} Scorpio{Intense, private and determined. You feel deeply, research thoroughly and do not give up easily.} Sagittarius{Optimistic, honest and freedom-loving. You are drawn to learning, travel, faith and big ideas.} Capricorn{Disciplined, ambitious and responsible. You work patiently towards long-term goals and gain with age.} Aquarius{Independent, thoughtful and humanitarian. You think differently, value friendship and work for larger causes.} Pisces{Gentle, imaginative and intuitive. You are compassionate, spiritual and drawn to art, service or healing.} other{{sign}}}'**
  String reportLagnaTraits(String sign);

  /// No description provided for @reportMoonTraits.
  ///
  /// In en, this message translates to:
  /// **'{sign, select, Aries{Your mind is quick and restless. You react fast, feel strongly in the moment and recover just as fast.} Taurus{Your mind is calm and your moods are stable. Comfort, nature and secure routines keep you content.} Gemini{Your mind is lively and curious. Conversation, reading and variety feed your emotional well-being.} Cancer{Your feelings run deep and you are nurturing by nature. You need a secure home and close bonds to feel settled.} Leo{You need warmth, respect and appreciation. You are generous with your feelings and proud of those you love.} Virgo{Your mind is practical and analytical. You feel best when life is organised, but should avoid over-worrying.} Libra{You seek emotional balance and harmony. Relationships, beauty and fair dealing keep your mind at ease.} Scorpio{Your emotions are strong and private. You are loyal and perceptive, and need trust before you open up.} Sagittarius{Your mind is hopeful and philosophical. Freedom, learning and a sense of purpose lift your mood.} Capricorn{You are emotionally reserved and practical. Reaching goals and being dependable gives you peace of mind.} Aquarius{Your mind is detached and inventive. You value friends and ideas, and need space to be yourself.} Pisces{You are deeply sensitive and empathetic. Quiet time, music, prayer or creative work restore your mind.} other{{sign}}}'**
  String reportMoonTraits(String sign);

  /// No description provided for @reportPlanetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Planets in your houses'**
  String get reportPlanetsTitle;

  /// No description provided for @reportPlanetHouse.
  ///
  /// In en, this message translates to:
  /// **'{planet} in house {house}'**
  String reportPlanetHouse(String planet, int house);

  /// No description provided for @reportPlanetEffect.
  ///
  /// In en, this message translates to:
  /// **'Brings {qualities} into {area}.'**
  String reportPlanetEffect(String qualities, String area);

  /// No description provided for @reportPlanetQualities.
  ///
  /// In en, this message translates to:
  /// **'{planet, select, sun{confidence, authority and vitality} moon{emotions, care and public connection} mars{energy, courage and drive} mercury{intellect, communication and skill} jupiter{wisdom, growth and good fortune} venus{love, comfort and creativity} saturn{discipline, patience and hard lessons} rahu{ambition, unusual paths and restlessness} ketu{detachment, insight and spiritual focus} other{{planet}}}'**
  String reportPlanetQualities(String planet);

  /// No description provided for @reportDignity.
  ///
  /// In en, this message translates to:
  /// **'{dignity, select, exalted{Exalted: at its strongest} debilitated{Debilitated: weaker, needs support} own{In its own sign: strong and steady} other{{dignity}}}'**
  String reportDignity(String dignity);

  /// No description provided for @reportDashaTheme.
  ///
  /// In en, this message translates to:
  /// **'{planet, select, sun{A period of recognition, responsibility and self-assertion. Authority figures, government and father matter more. Avoid ego clashes.} moon{A period of feelings, family and public contact. Home, mother and travel come forward. Keep routines steady to stay balanced.} mars{A period of action, courage and competition. Good for property, sport and bold moves. Avoid haste, anger and accidents.} mercury{A period of learning, trade and communication. Good for study, business, writing and networking. Avoid scattering your energy.} jupiter{A period of growth, wisdom and blessings. Good for education, children, marriage and spiritual life. Avoid overconfidence.} venus{A period of comfort, relationships and creativity. Good for marriage, art, vehicles and home. Avoid overindulgence.} saturn{A period of hard work, patience and lasting results. Rewards come slowly but surely. Avoid shortcuts and keep discipline.} rahu{A period of ambition, change and unusual opportunities, often abroad or through technology. Avoid confusion and risky shortcuts.} ketu{A period of detachment, research and spiritual growth. Material matters may feel uncertain. Good for meditation and inner work.} other{{planet}}}'**
  String reportDashaTheme(String planet);

  /// No description provided for @reportAntardashaTitle.
  ///
  /// In en, this message translates to:
  /// **'Sub-periods of the current Mahadasha'**
  String get reportAntardashaTitle;

  /// No description provided for @reportCompatTitle.
  ///
  /// In en, this message translates to:
  /// **'Detailed Compatibility analysis report'**
  String get reportCompatTitle;

  /// No description provided for @reportCompatIntro.
  ///
  /// In en, this message translates to:
  /// **'This report compares {bride} and {groom} through traditional Ashtakoota Guna Milan, the Manglik check and each person\'s Moon chart.'**
  String reportCompatIntro(String bride, String groom);

  /// No description provided for @reportCompatCharts.
  ///
  /// In en, this message translates to:
  /// **'The two charts'**
  String get reportCompatCharts;

  /// No description provided for @reportCompatBand.
  ///
  /// In en, this message translates to:
  /// **'{band, select, excellent{Excellent match. Scores of 28 and above are traditionally considered very favourable.} good{Good match. Scores from 24 to 27.5 are traditionally considered favourable.} average{Acceptable match. Scores from 18 to 23.5 meet the traditional minimum; review the weaker Kootas below.} low{Below the traditional minimum of 18. Many families consult an astrologer and study the full charts before deciding.} other{{band}}}'**
  String reportCompatBand(String band);

  /// No description provided for @reportKootaArea.
  ///
  /// In en, this message translates to:
  /// **'{koota, select, varna{Work temperament and spiritual outlook} vashya{Mutual attraction and influence} tara{Health and fortune after marriage} yoni{Physical and intimate harmony} grahaMaitri{Mental wavelength and friendship} gana{Temperament and behaviour} bhakoot{Family welfare, finances and growth} nadi{Health and children} other{{koota}}}'**
  String reportKootaArea(String koota);

  /// No description provided for @reportKootaLevel.
  ///
  /// In en, this message translates to:
  /// **'{level, select, full{Full points} partial{Partial} none{No points} other{{level}}}'**
  String reportKootaLevel(String level);

  /// No description provided for @reportColKoota.
  ///
  /// In en, this message translates to:
  /// **'Koota'**
  String get reportColKoota;

  /// No description provided for @reportColPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get reportColPoints;

  /// No description provided for @reportColArea.
  ///
  /// In en, this message translates to:
  /// **'What it shows'**
  String get reportColArea;

  /// No description provided for @reportColResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get reportColResult;

  /// No description provided for @reportCompatStrengths.
  ///
  /// In en, this message translates to:
  /// **'Strengths'**
  String get reportCompatStrengths;

  /// No description provided for @reportCompatWatch.
  ///
  /// In en, this message translates to:
  /// **'Areas to work on'**
  String get reportCompatWatch;

  /// No description provided for @reportCompatRemediesTitle.
  ///
  /// In en, this message translates to:
  /// **'Traditional remedies'**
  String get reportCompatRemediesTitle;

  /// No description provided for @reportCompatRemedy.
  ///
  /// In en, this message translates to:
  /// **'{flag, select, nadi{Nadi dosha: traditionally addressed with Mahamrityunjaya mantra japa, a Nadi dosha nivaran puja, or charity of grain and gold. Some traditions cancel it when the Moon signs or Nakshatra padas differ.} bhakoot{Bhakoot dosha: traditionally eased when the lords of both Moon signs are the same or friends, and through worship of Shiva and Parvati or Lakshmi and Narayan.} other{{flag}}}'**
  String reportCompatRemedy(String flag);

  /// No description provided for @vastuPlansCta.
  ///
  /// In en, this message translates to:
  /// **'Analyse my home plan'**
  String get vastuPlansCta;

  /// No description provided for @vastuPlansTitle.
  ///
  /// In en, this message translates to:
  /// **'Home Vastu analysis'**
  String get vastuPlansTitle;

  /// No description provided for @vastuPlansSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload your house plan for a Vastu score, doshas, remedies and a detailed report.'**
  String get vastuPlansSubtitle;

  /// No description provided for @vastuPlansEmpty.
  ///
  /// In en, this message translates to:
  /// **'No properties yet. Add your home, office or shop to begin.'**
  String get vastuPlansEmpty;

  /// No description provided for @vastuPlansAdd.
  ///
  /// In en, this message translates to:
  /// **'Add property'**
  String get vastuPlansAdd;

  /// No description provided for @vastuPlanNew.
  ///
  /// In en, this message translates to:
  /// **'New property'**
  String get vastuPlanNew;

  /// No description provided for @vastuPlanEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get vastuPlanEdit;

  /// No description provided for @vastuPlanName.
  ///
  /// In en, this message translates to:
  /// **'Property name'**
  String get vastuPlanName;

  /// No description provided for @vastuPlanNameHint.
  ///
  /// In en, this message translates to:
  /// **'Home, office, shop…'**
  String get vastuPlanNameHint;

  /// No description provided for @vastuPlanImageTitle.
  ///
  /// In en, this message translates to:
  /// **'House plan'**
  String get vastuPlanImageTitle;

  /// No description provided for @vastuPlanImageHint.
  ///
  /// In en, this message translates to:
  /// **'Add a photo or screenshot of the floor plan. You can also continue without one and mark rooms on a blank square.'**
  String get vastuPlanImageHint;

  /// No description provided for @vastuPlanChoosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get vastuPlanChoosePhoto;

  /// No description provided for @vastuPlanReplacePhoto.
  ///
  /// In en, this message translates to:
  /// **'Replace photo'**
  String get vastuPlanReplacePhoto;

  /// No description provided for @vastuPlanTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get vastuPlanTakePhoto;

  /// No description provided for @vastuPlanStepEntrance.
  ///
  /// In en, this message translates to:
  /// **'Entrance'**
  String get vastuPlanStepEntrance;

  /// No description provided for @vastuPlanStepRooms.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get vastuPlanStepRooms;

  /// No description provided for @vastuPlanStepOutline.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get vastuPlanStepOutline;

  /// No description provided for @vastuPlanTapEntrance.
  ///
  /// In en, this message translates to:
  /// **'Tap the exact spot of the main door on the plan.'**
  String get vastuPlanTapEntrance;

  /// No description provided for @vastuPlanTapRooms.
  ///
  /// In en, this message translates to:
  /// **'Pick a room, then tap where it is on the plan. Tap a marker again to remove it.'**
  String get vastuPlanTapRooms;

  /// No description provided for @vastuPlanOutlineHelp.
  ///
  /// In en, this message translates to:
  /// **'Move the sliders until the box matches the outer walls of the house.'**
  String get vastuPlanOutlineHelp;

  /// No description provided for @vastuPlanOutlineWidth.
  ///
  /// In en, this message translates to:
  /// **'Left and right walls'**
  String get vastuPlanOutlineWidth;

  /// No description provided for @vastuPlanOutlineHeight.
  ///
  /// In en, this message translates to:
  /// **'Top and bottom walls'**
  String get vastuPlanOutlineHeight;

  /// No description provided for @vastuPlanCutCorners.
  ///
  /// In en, this message translates to:
  /// **'Missing or cut corners'**
  String get vastuPlanCutCorners;

  /// No description provided for @vastuPlanDoorSide.
  ///
  /// In en, this message translates to:
  /// **'The main door is on this side of the plan'**
  String get vastuPlanDoorSide;

  /// No description provided for @vastuPlanFacing.
  ///
  /// In en, this message translates to:
  /// **'Main door faces {degrees}° · {direction}'**
  String vastuPlanFacing(String degrees, String direction);

  /// No description provided for @vastuPlanFacingHelp.
  ///
  /// In en, this message translates to:
  /// **'Stand in the doorway looking out and read the compass, or enter the degree from your property papers.'**
  String get vastuPlanFacingHelp;

  /// No description provided for @vastuPlanUseCompass.
  ///
  /// In en, this message translates to:
  /// **'Use compass'**
  String get vastuPlanUseCompass;

  /// No description provided for @vastuPlanCompassUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This device has no compass. Enter the degree instead.'**
  String get vastuPlanCompassUnavailable;

  /// No description provided for @vastuPlanSave.
  ///
  /// In en, this message translates to:
  /// **'Save and analyse'**
  String get vastuPlanSave;

  /// No description provided for @vastuPlanDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete property'**
  String get vastuPlanDelete;

  /// No description provided for @vastuPlanDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} and its analysis?'**
  String vastuPlanDeleteConfirm(String name);

  /// No description provided for @vastuBrahmasthan.
  ///
  /// In en, this message translates to:
  /// **'Brahmasthan (centre)'**
  String get vastuBrahmasthan;

  /// No description provided for @vastuScoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Vastu score'**
  String get vastuScoreTitle;

  /// No description provided for @vastuEntranceResult.
  ///
  /// In en, this message translates to:
  /// **'Main entrance {pada}'**
  String vastuEntranceResult(String pada);

  /// No description provided for @vastuDoshaCounts.
  ///
  /// In en, this message translates to:
  /// **'Major doshas: {major} · Minor: {minor}'**
  String vastuDoshaCounts(int major, int minor);

  /// No description provided for @vastuDoshasTitle.
  ///
  /// In en, this message translates to:
  /// **'Doshas found'**
  String get vastuDoshasTitle;

  /// No description provided for @vastuDoshasNone.
  ///
  /// In en, this message translates to:
  /// **'No doshas found in what you marked.'**
  String get vastuDoshasNone;

  /// No description provided for @vastuDoshaEntrance.
  ///
  /// In en, this message translates to:
  /// **'Main entrance in {pada}, a traditionally inauspicious pada'**
  String vastuDoshaEntrance(String pada);

  /// No description provided for @vastuDoshaRoom.
  ///
  /// In en, this message translates to:
  /// **'{room} in {zone}'**
  String vastuDoshaRoom(String room, String zone);

  /// No description provided for @vastuDoshaCorner.
  ///
  /// In en, this message translates to:
  /// **'{corner} corner is cut or missing'**
  String vastuDoshaCorner(String corner);

  /// No description provided for @vastuDoshaZoneTheme.
  ///
  /// In en, this message translates to:
  /// **'This zone governs: {theme}.'**
  String vastuDoshaZoneTheme(String theme);

  /// No description provided for @vastuDoshaCentre.
  ///
  /// In en, this message translates to:
  /// **'The Brahmasthan should stay open, light and free of heavy construction.'**
  String get vastuDoshaCentre;

  /// No description provided for @vastuPlacementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Room placements'**
  String get vastuPlacementsTitle;

  /// No description provided for @vastuGridTitle.
  ///
  /// In en, this message translates to:
  /// **'Vastu grid (16 zones)'**
  String get vastuGridTitle;

  /// No description provided for @vastuGridHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap any zone on the plan to see what it governs.'**
  String get vastuGridHelp;

  /// No description provided for @vastuRemediesTitle.
  ///
  /// In en, this message translates to:
  /// **'Dosh nivaran: remedies and upay'**
  String get vastuRemediesTitle;

  /// No description provided for @vastuRemediesIntro.
  ///
  /// In en, this message translates to:
  /// **'Remedies for each dosha are shown with it above.'**
  String get vastuRemediesIntro;

  /// No description provided for @vastuRemedyLabel.
  ///
  /// In en, this message translates to:
  /// **'Remedy (upay)'**
  String get vastuRemedyLabel;

  /// No description provided for @vastuMoveTo.
  ///
  /// In en, this message translates to:
  /// **'Better zones: {zones}'**
  String vastuMoveTo(String zones);

  /// No description provided for @vastuGeneralUpayTitle.
  ///
  /// In en, this message translates to:
  /// **'General upay for every home'**
  String get vastuGeneralUpayTitle;

  /// No description provided for @vastuGeneralUpay.
  ///
  /// In en, this message translates to:
  /// **'Keep the northeast clean and light, and the Brahmasthan open and uncluttered. Light a diya in the evening, let in fresh air and morning sunlight, and repair leaks and broken items quickly. Mop with a little sea salt in the water once a week. A tulsi plant near the entrance or in the northeast is traditional.'**
  String get vastuGeneralUpay;

  /// No description provided for @vastuReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Detailed Vastu report'**
  String get vastuReportTitle;

  /// No description provided for @vastuReportPitch.
  ///
  /// In en, this message translates to:
  /// **'A complete PDF for this property: your plan with the 16-zone grid, every zone, all doshas with remedies, and placement suggestions.'**
  String get vastuReportPitch;

  /// No description provided for @vastuReportOnePerProperty.
  ///
  /// In en, this message translates to:
  /// **'One purchase covers this property. Each property needs its own report.'**
  String get vastuReportOnePerProperty;

  /// No description provided for @vastuReportBuy.
  ///
  /// In en, this message translates to:
  /// **'Get report · {price}'**
  String vastuReportBuy(String price);

  /// No description provided for @vastuReportUseCredit.
  ///
  /// In en, this message translates to:
  /// **'Use your unused report'**
  String get vastuReportUseCredit;

  /// No description provided for @vastuReportDownload.
  ///
  /// In en, this message translates to:
  /// **'Download report'**
  String get vastuReportDownload;

  /// No description provided for @vastuReportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Reports can\'t be bought right now. Please try again later.'**
  String get vastuReportUnavailable;

  /// No description provided for @vastuReportUnable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the report. Please try again.'**
  String get vastuReportUnable;

  /// No description provided for @vastuReportZonesTitle.
  ///
  /// In en, this message translates to:
  /// **'Zone by zone'**
  String get vastuReportZonesTitle;

  /// No description provided for @vastuReportZoneColumn.
  ///
  /// In en, this message translates to:
  /// **'Zone'**
  String get vastuReportZoneColumn;

  /// No description provided for @vastuReportThemeColumn.
  ///
  /// In en, this message translates to:
  /// **'Governs'**
  String get vastuReportThemeColumn;

  /// No description provided for @vastuReportDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Vastu is a traditional practice. This analysis is guidance based on what you marked; it is not structural, legal or financial advice.'**
  String get vastuReportDisclaimer;

  /// No description provided for @vastuCornerName.
  ///
  /// In en, this message translates to:
  /// **'{corner, select, ne{Northeast} se{Southeast} sw{Southwest} nw{Northwest} other{{corner}}}'**
  String vastuCornerName(String corner);

  /// No description provided for @vastuFit.
  ///
  /// In en, this message translates to:
  /// **'{fit, select, ideal{Ideal} acceptable{Acceptable} avoid{Avoid} other{{fit}}}'**
  String vastuFit(String fit);

  /// No description provided for @vastuPlanSide.
  ///
  /// In en, this message translates to:
  /// **'{side, select, top{Top} right{Right} bottom{Bottom} left{Left} other{{side}}}'**
  String vastuPlanSide(String side);

  /// No description provided for @vastuSeverity.
  ///
  /// In en, this message translates to:
  /// **'{severity, select, major{Major} minor{Minor} other{{severity}}}'**
  String vastuSeverity(String severity);

  /// No description provided for @vastuScoreBand.
  ///
  /// In en, this message translates to:
  /// **'{band, select, excellent{Excellent. The plan follows Vastu closely.} good{Good. A few placements could be improved.} average{Average. Some important doshas need attention.} attention{Needs attention. Several major doshas; remedies are strongly suggested.} other{{band}}}'**
  String vastuScoreBand(String band);

  /// No description provided for @vastuRoomName.
  ///
  /// In en, this message translates to:
  /// **'{room, select, kitchen{Kitchen} masterBedroom{Master bedroom} bedroom{Bedroom} childrenRoom{Children\'s room} guestRoom{Guest room} living{Living room} dining{Dining} pooja{Pooja room} study{Study} office{Office} toilet{Toilet} bathroom{Bathroom} store{Store room} staircase{Staircase} undergroundWater{Underground water tank} overheadTank{Overhead water tank} septicTank{Septic tank} parking{Parking} cashLocker{Cash locker} openSpace{Open space} other{{room}}}'**
  String vastuRoomName(String room);

  /// No description provided for @vastuRemedyEntrance.
  ///
  /// In en, this message translates to:
  /// **'{side, select, n{North door: keep it bright and clutter-free, fix a brass or green threshold strip, place a Swastik or Om above the door and hang a toran of fresh mango leaves. Some traditions add a Vastu pyramid on the inner side.} e{East door: keep the threshold clean and lit at sunrise, fix a copper strip on the threshold and hang a Surya symbol or toran above the door.} s{South door: fix a brass or lead strip on the threshold, place a Panchmukhi Hanuman image above the door facing out, and keep the door solid and well kept. Red or maroon tones help.} w{West door: fix a brass threshold strip, place a Varun yantra or a metal wind chime near the door, and keep the entrance well lit with no broken fittings.} other{{side}}}'**
  String vastuRemedyEntrance(String side);

  /// No description provided for @vastuRemedyCorner.
  ///
  /// In en, this message translates to:
  /// **'{corner, select, ne{Keep this area clean and light. Place a Vastu or Shri yantra and a crystal or brass pyramid along the cut, or a mirror on the adjoining wall to visually extend it. Light a lamp here daily.} se{Place a red lamp or bulb in the corner and keep it lit in the evening. A copper pyramid or Agni yantra is commonly used.} sw{Strengthen the corner with heavy furniture or storage nearby, and place a brass or lead helix or pyramid. Avoid water and open space here.} nw{Hang a metal wind chime and place a brass pyramid or Chandra yantra in the corner. Keep the area clean and airy.} other{{corner}}}'**
  String vastuRemedyCorner(String corner);

  /// No description provided for @vastuRemedyRoom.
  ///
  /// In en, this message translates to:
  /// **'{room, select, kitchen{Cook facing east if you can and keep the stove in the southeast part of the kitchen. Don\'t place the stove and sink side by side. Use red, orange or pink tones; a copper pyramid or Agni yantra is traditional.} masterBedroom{Sleep with your head to the south and keep the bed in the southwest part of the room. Use earthy colours, keep heavy furniture along the south and west walls, and avoid mirrors facing the bed.} bedroom{Keep the bed against the south or west wall with your head to the south or east. Avoid sleeping under a beam and use calm, light colours.} childrenRoom{Place the study table so the child faces east or north. Keep the room tidy and well lit, in light green, blue or cream.} guestRoom{Keep the room simple and uncluttered, with the bed in its southwest part. A bowl of rock salt helps keep the energy fresh.} living{Keep the north and east sides light and open, place heavy sofas along the south and west walls, and add fresh flowers and good lighting.} dining{Place the dining table in the west part of the room and eat facing east or north. Keep a bowl of fresh fruit on the table.} pooja{Place idols so you pray facing east or north, keep the space spotless, and never put it under a staircase or against a toilet wall. Light a lamp daily. A small altar in the northeast of the room also helps.} study{Sit facing east or north with a solid wall behind you. Keep the desk uncluttered and well lit; a crystal globe or Saraswati image is traditional.} office{Sit facing north or east with a solid wall behind you. Keep important files and cash in the southwest and avoid sitting under a beam.} toilet{Keep the door closed and the lid down, place a bowl of sea salt or camphor inside and change it weekly, and keep it dry and well ventilated. Many consultants also use a Vastu strip or brass helix. If there is another toilet, prefer that one.} bathroom{Keep it dry and well ventilated, fix dripping taps, keep a little sea salt in a corner and keep the door closed when not in use.} store{Keep heavy storage along the south and west walls, clear out broken or unused items, and keep the room dry.} staircase{A staircase should turn clockwise as you go up. If it is in the northeast or centre, keep the area under it empty and clean and place a brass pyramid at its base.} undergroundWater{Keep the tank covered, clean and leak-free, and the walls around it dry. A Varun yantra nearby is traditional. Plan to move it to the north or northeast when you renovate.} overheadTank{Raise the tank on a platform at least two feet above the roof, keep it in light colours and fix leaks quickly.} septicTank{Keep it sealed, leak-free and clear of the compound wall. A copper strip or Vastu pyramid nearby is traditionally used.} parking{Keep the parking well lit with vehicles facing north or east. Avoid heavy vehicles in the northeast.} cashLocker{Place the locker against the south wall so it opens to the north. Keep a Shri or Kuber yantra inside and keep it clean and organised.} openSpace{Keep this space clean and clutter-free and add tulsi or flowering plants. Avoid heavy items here; open space suits the north, east and northeast best.} other{{room}}}'**
  String vastuRemedyRoom(String room);

  /// No description provided for @vastuCompassManual.
  ///
  /// In en, this message translates to:
  /// **'Drag the slider to turn the dial and explore each direction.'**
  String get vastuCompassManual;

  /// No description provided for @festivalTapForGuide.
  ///
  /// In en, this message translates to:
  /// **'Tap a festival or vrat for its puja vidhi, aarti, and do\'s and don\'ts.'**
  String get festivalTapForGuide;

  /// No description provided for @pujaGuideTab.
  ///
  /// In en, this message translates to:
  /// **'{tab, select, about{About} vidhi{Puja vidhi} aarti{Aarti} other{{tab}}}'**
  String pujaGuideTab(String tab);

  /// No description provided for @pujaGuideSection.
  ///
  /// In en, this message translates to:
  /// **'{section, select, about{What it is and why it matters} story{Vrat katha} benefits{Benefits} dos{Do\'s} donts{Don\'ts} fasting{Fasting} samagri{Puja samagri} steps{Step-by-step puja vidhi} mantras{Mantras} timing{Best time for puja} other{{section}}}'**
  String pujaGuideSection(String section);

  /// No description provided for @pujaGuideDeity.
  ///
  /// In en, this message translates to:
  /// **'Deity: {deity}'**
  String pujaGuideDeity(String deity);

  /// No description provided for @pujaGuideSamagriProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} ready'**
  String pujaGuideSamagriProgress(int done, int total);

  /// No description provided for @pujaGuideStepsPreview.
  ///
  /// In en, this message translates to:
  /// **'{count} steps in all, with mantras and their meanings, the vrat katha and the best puja time at your place.'**
  String pujaGuideStepsPreview(int count);

  /// No description provided for @pujaGuideTimingAt.
  ///
  /// In en, this message translates to:
  /// **'For {date} in {place}'**
  String pujaGuideTimingAt(String date, String place);

  /// No description provided for @pujaGuideYourLocation.
  ///
  /// In en, this message translates to:
  /// **'your location'**
  String get pujaGuideYourLocation;

  /// No description provided for @pujaGuideWindow.
  ///
  /// In en, this message translates to:
  /// **'{rule, select, morning{Morning (pratah kaal)} midday{Midday (madhyahna)} pradosh{Evening (pradosh kaal)} nishita{Midnight (nishita kaal)} moonrise{After moonrise} other{{rule}}}'**
  String pujaGuideWindow(String rule);

  /// No description provided for @pujaGuideMoonrise.
  ///
  /// In en, this message translates to:
  /// **'Moonrise at {time}. Offer arghya to the Moon and break the fast after it.'**
  String pujaGuideMoonrise(String time);

  /// No description provided for @pujaGuideMoonriseUnknown.
  ///
  /// In en, this message translates to:
  /// **'The moonrise time isn\'t available for this place.'**
  String get pujaGuideMoonriseUnknown;

  /// No description provided for @pujaGuideAvoid.
  ///
  /// In en, this message translates to:
  /// **'Avoid starting the puja in these periods'**
  String get pujaGuideAvoid;

  /// No description provided for @pujaGuidePeriod.
  ///
  /// In en, this message translates to:
  /// **'{period, select, rahuKaal{Rahu Kaal} yamaganda{Yamaganda} gulika{Gulika Kaal} other{{period}}}'**
  String pujaGuidePeriod(String period);

  /// No description provided for @pujaGuideClash.
  ///
  /// In en, this message translates to:
  /// **'Part of this window falls in {period}; begin the puja outside it.'**
  String pujaGuideClash(String period);

  /// No description provided for @pujaGuideScript.
  ///
  /// In en, this message translates to:
  /// **'{script, select, devanagari{Devanagari} latin{English letters} other{{script}}}'**
  String pujaGuideScript(String script);

  /// No description provided for @pujaGuideTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get pujaGuideTextSize;

  /// No description provided for @pujaGuideNoAarti.
  ///
  /// In en, this message translates to:
  /// **'No aarti is traditionally sung for this observance. Spend the time in quiet prayer and remembrance.'**
  String get pujaGuideNoAarti;

  /// No description provided for @pujaGuideDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Customs differ between regions and families. Where they differ, follow your family tradition and your purohit.'**
  String get pujaGuideDisclaimer;

  /// No description provided for @pujaGuideUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The puja guide couldn\'t be loaded.'**
  String get pujaGuideUnavailable;

  /// No description provided for @pujaGuideLanguageNote.
  ///
  /// In en, this message translates to:
  /// **'This guide is shown in English for now.'**
  String get pujaGuideLanguageNote;

  /// No description provided for @planetShort.
  ///
  /// In en, this message translates to:
  /// **'{planet, select, Sun{Su} Moon{Mo} Mars{Ma} Mercury{Me} Jupiter{Ju} Venus{Ve} Saturn{Sa} Rahu{Ra} Ketu{Ke} other{{planet}}}'**
  String planetShort(String planet);

  /// No description provided for @chartRetroShort.
  ///
  /// In en, this message translates to:
  /// **'R'**
  String get chartRetroShort;

  /// No description provided for @chartHouseTitle.
  ///
  /// In en, this message translates to:
  /// **'House {house} · {sign}'**
  String chartHouseTitle(int house, String sign);

  /// No description provided for @chartHouseEmpty.
  ///
  /// In en, this message translates to:
  /// **'No planets in this house.'**
  String get chartHouseEmpty;

  /// No description provided for @chartTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a house to see its planets, degrees and nakshatras.'**
  String get chartTapHint;

  /// No description provided for @chartVargaChip.
  ///
  /// In en, this message translates to:
  /// **'{varga, select, d1{D1} moon{Moon} d9{D9} d10{D10} d7{D7} d2{D2} d3{D3} d4{D4} d12{D12} d16{D16} d20{D20} d24{D24} d27{D27} d30{D30} d40{D40} d45{D45} d60{D60} other{{varga}}}'**
  String chartVargaChip(String varga);

  /// No description provided for @chartVargaName.
  ///
  /// In en, this message translates to:
  /// **'{varga, select, d1{Rashi chart (D1)} moon{Chandra chart (Moon as Lagna)} d9{Navamsa (D9)} d10{Dashamsha (D10)} d7{Saptamsha (D7)} d2{Hora (D2)} d3{Drekkana (D3)} d4{Chaturthamsha (D4)} d12{Dwadashamsha (D12)} d16{Shodashamsha (D16)} d20{Vimshamsha (D20)} d24{Chaturvimshamsha (D24)} d27{Bhamsha (D27)} d30{Trimshamsha (D30)} d40{Khavedamsha (D40)} d45{Akshavedamsha (D45)} d60{Shashtiamsha (D60)} other{{varga}}}'**
  String chartVargaName(String varga);

  /// No description provided for @chartVargaAbout.
  ///
  /// In en, this message translates to:
  /// **'{varga, select, d1{Your birth chart: the planets in their signs, with whole-sign houses from your Lagna.} moon{Your birth chart read from the Moon\'s sign. Used for the mind and emotions, and for Gochar and Sade Sati.} d9{Marriage, the spouse, dharma and the inner strength of each planet.} d10{Career, profession, status and achievements.} d7{Children, progeny and creative legacy.} d2{Wealth, savings and the resources you build. Planets fall in Leo (the Sun\'s hora) or Cancer (the Moon\'s hora).} d3{Siblings, courage, initiative and self-effort.} d4{Home, property, vehicles and fortune in settled life.} d12{Parents, ancestry and what you inherit.} d16{Vehicles, comforts and everyday happiness.} d20{Spiritual practice, worship and devotion.} d24{Education, learning and knowledge.} d27{Strengths and weaknesses, and overall stamina.} d30{Misfortunes, illness and hidden challenges to guard against.} d40{Auspicious and inauspicious effects from the mother\'s line.} d45{Character and conduct, and effects from the father\'s line.} d60{Past-life karma, used to fine-tune the whole chart.} other{{varga}}}'**
  String chartVargaAbout(String varga);

  /// No description provided for @chartVargaPrecision.
  ///
  /// In en, this message translates to:
  /// **'This chart changes every few minutes of birth time, so trust it only with an exact birth time.'**
  String get chartVargaPrecision;

  /// No description provided for @rashifalTitle.
  ///
  /// In en, this message translates to:
  /// **'Rashifal'**
  String get rashifalTitle;

  /// No description provided for @rashifalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Horoscope for all 12 Moon signs, from today to the whole year'**
  String get rashifalSubtitle;

  /// No description provided for @rashifalPeriod.
  ///
  /// In en, this message translates to:
  /// **'{period, select, daily{Today} weekly{Week} monthly{Month} yearly{Year} other{{period}}}'**
  String rashifalPeriod(String period);

  /// No description provided for @rashifalOverall.
  ///
  /// In en, this message translates to:
  /// **'{level, select, great{An excellent stretch: plans move smoothly and support comes easily.} good{A good stretch: steady progress, with help when you ask.} mixed{A mixed stretch: some things flow, others need patience.} careful{A careful stretch: go slowly, double-check, and avoid big risks.} other{{level}}}'**
  String rashifalOverall(String level);

  /// No description provided for @rashifalArea.
  ///
  /// In en, this message translates to:
  /// **'{area, select, love{Love} career{Career} money{Money} health{Health} other{{area}}}'**
  String rashifalArea(String area);

  /// No description provided for @rashifalAreaLine.
  ///
  /// In en, this message translates to:
  /// **'{key, select, love_good{Warmth and understanding come easily; a good time to reach out.} love_mixed{Relationships ask for patience; listen more than you speak.} love_careful{Keep expectations gentle; avoid arguments over small things.} career_good{Work moves forward and effort is noticed.} career_mixed{Steady work pays; don\'t expect quick wins.} career_careful{Expect delays or pressure; finish what\'s pending before starting new.} money_good{Gains and good money decisions are favoured.} money_mixed{Keep spending balanced; review before you commit.} money_careful{Avoid lending, speculation and big purchases for now.} health_good{Energy is good; keep up healthy routines.} health_mixed{Rest well and don\'t overdo it.} health_careful{Take extra care of sleep, diet and stress.} other{{key}}}'**
  String rashifalAreaLine(String key);

  /// No description provided for @rashifalMoonFocus.
  ///
  /// In en, this message translates to:
  /// **'Today the Moon puts the focus on {theme}.'**
  String rashifalMoonFocus(String theme);

  /// No description provided for @rashifalLucky.
  ///
  /// In en, this message translates to:
  /// **'Lucky colour: {colour} · Lucky number: {number}'**
  String rashifalLucky(String colour, int number);

  /// No description provided for @rashifalColour.
  ///
  /// In en, this message translates to:
  /// **'{colour, select, orange{orange} white{white} red{red} green{green} yellow{yellow} pink{pink} blue{blue} other{{colour}}}'**
  String rashifalColour(String colour);

  /// No description provided for @rashifalGoodDays.
  ///
  /// In en, this message translates to:
  /// **'Best days: {days}'**
  String rashifalGoodDays(String days);

  /// No description provided for @rashifalKeyTransits.
  ///
  /// In en, this message translates to:
  /// **'Planets shaping this period'**
  String get rashifalKeyTransits;

  /// No description provided for @rashifalShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get rashifalShare;

  /// No description provided for @rashifalDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Rashifal is read from the Moon sign (Chandra rashi) by classical Gochar. It is general guidance; your full chart and dasha matter more.'**
  String get rashifalDisclaimer;

  /// No description provided for @todayWidgetRahuLabel.
  ///
  /// In en, this message translates to:
  /// **'Rahu Kaal'**
  String get todayWidgetRahuLabel;

  /// No description provided for @todayWidgetOpenApp.
  ///
  /// In en, this message translates to:
  /// **'Open RV Astro Vastu to load today\'s Panchang.'**
  String get todayWidgetOpenApp;

  /// No description provided for @reminderMorningRashifalBody.
  ///
  /// In en, this message translates to:
  /// **'{sign} {stars} — {line} Rahu Kaal {rahuKaal}.'**
  String reminderMorningRashifalBody(
    String sign,
    String stars,
    String line,
    String rahuKaal,
  );

  /// No description provided for @shareButton.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareButton;

  /// No description provided for @shareFooter.
  ///
  /// In en, this message translates to:
  /// **'Made with RV Astro Vastu'**
  String get shareFooter;

  /// No description provided for @shareInvite.
  ///
  /// In en, this message translates to:
  /// **'Get your Rashifal, Kundali and Kundali matching free on RV Astro Vastu: {link}'**
  String shareInvite(String link);

  /// No description provided for @compatInviteFriend.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend'**
  String get compatInviteFriend;

  /// No description provided for @aiTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask the AI astrologer'**
  String get aiTitle;

  /// No description provided for @aiIntro.
  ///
  /// In en, this message translates to:
  /// **'Ask anything about your chart: career, marriage, money, health or timing. Answers are based on your own Kundali, dasha and current transits.'**
  String get aiIntro;

  /// No description provided for @aiSuggestion.
  ///
  /// In en, this message translates to:
  /// **'{key, select, s1{What does my current dasha mean for my career?} s2{When is a good period for marriage?} s3{How is this year for money and savings?} s4{What is my biggest strength in my chart?} s5{Which remedy suits me right now?} other{{key}}}'**
  String aiSuggestion(String key);

  /// No description provided for @aiInputHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about your chart…'**
  String get aiInputHint;

  /// No description provided for @aiRemaining.
  ///
  /// In en, this message translates to:
  /// **'{remaining} of {limit} free questions left this month'**
  String aiRemaining(int remaining, int limit);

  /// No description provided for @aiPremiumUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Premium: unlimited questions'**
  String get aiPremiumUnlimited;

  /// No description provided for @aiThinking.
  ///
  /// In en, this message translates to:
  /// **'Reading your chart…'**
  String get aiThinking;

  /// No description provided for @aiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The AI astrologer is busy right now. Please try again in a minute.'**
  String get aiUnavailable;

  /// No description provided for @aiDailyLimit.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached today\'s fair-use limit. Ask again tomorrow.'**
  String get aiDailyLimit;

  /// No description provided for @aiDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'AI answers are guidance from your chart, not certainties. For health, legal or money decisions, also consult a professional.'**
  String get aiDisclaimer;

  /// No description provided for @aiNeedProfile.
  ///
  /// In en, this message translates to:
  /// **'Create your birth profile so the AI can read your chart.'**
  String get aiNeedProfile;

  /// No description provided for @remindersTransitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Planet changes for you'**
  String get remindersTransitsTitle;

  /// No description provided for @remindersTransitsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saturn sign changes and Sade Sati for everyone; Jupiter, Rahu and Ketu with Premium'**
  String get remindersTransitsSubtitle;

  /// No description provided for @transitAlertBody.
  ///
  /// In en, this message translates to:
  /// **'House {house} from your Moon: {theme}. {tone} for you.'**
  String transitAlertBody(int house, String theme, String tone);

  /// No description provided for @transitSadeSatiStart.
  ///
  /// In en, this message translates to:
  /// **'Sade Sati begins: Saturn enters {sign}'**
  String transitSadeSatiStart(String sign);

  /// No description provided for @transitSadeSatiEnd.
  ///
  /// In en, this message translates to:
  /// **'Sade Sati ends: Saturn enters {sign}'**
  String transitSadeSatiEnd(String sign);

  /// No description provided for @babyNamesTitle.
  ///
  /// In en, this message translates to:
  /// **'Baby names by nakshatra'**
  String get babyNamesTitle;

  /// No description provided for @babyNamesIntro.
  ///
  /// In en, this message translates to:
  /// **'Traditionally a child\'s name begins with the syllable of the Moon\'s nakshatra pada at birth. Pick the nakshatra and pada to see its syllables and names.'**
  String get babyNamesIntro;

  /// No description provided for @babyNamesNakshatra.
  ///
  /// In en, this message translates to:
  /// **'Birth nakshatra'**
  String get babyNamesNakshatra;

  /// No description provided for @babyNamesPada.
  ///
  /// In en, this message translates to:
  /// **'Pada {pada}'**
  String babyNamesPada(int pada);

  /// No description provided for @babyNamesSyllables.
  ///
  /// In en, this message translates to:
  /// **'Naming syllables'**
  String get babyNamesSyllables;

  /// No description provided for @babyNamesGender.
  ///
  /// In en, this message translates to:
  /// **'{gender, select, all{All} m{Boy} f{Girl} other{{gender}}}'**
  String babyNamesGender(String gender);

  /// No description provided for @babyNamesNone.
  ///
  /// In en, this message translates to:
  /// **'No names in our list begin with this sound. Families often choose another syllable of the same nakshatra.'**
  String get babyNamesNone;

  /// No description provided for @babyNamesUseMine.
  ///
  /// In en, this message translates to:
  /// **'Use my nakshatra'**
  String get babyNamesUseMine;

  /// No description provided for @calendarView.
  ///
  /// In en, this message translates to:
  /// **'{view, select, list{List} month{Month} other{{view}}}'**
  String calendarView(String view);

  /// No description provided for @hinduMonthSystem.
  ///
  /// In en, this message translates to:
  /// **'{system, select, amanta{Amanta} purnimanta{Purnimanta} other{{system}}}'**
  String hinduMonthSystem(String system);

  /// No description provided for @hinduMonthName.
  ///
  /// In en, this message translates to:
  /// **'{month, select, chaitra{Chaitra} vaishakha{Vaishakha} jyeshtha{Jyeshtha} ashadha{Ashadha} shravana{Shravana} bhadrapada{Bhadrapada} ashvin{Ashvin} kartika{Kartika} margashirsha{Margashirsha} pausha{Pausha} magha{Magha} phalguna{Phalguna} other{{month}}}'**
  String hinduMonthName(String month);

  /// No description provided for @hinduMonthAdhik.
  ///
  /// In en, this message translates to:
  /// **'Adhik {month}'**
  String hinduMonthAdhik(String month);

  /// No description provided for @strengthTitle.
  ///
  /// In en, this message translates to:
  /// **'Ashtakavarga & Strength'**
  String get strengthTitle;

  /// No description provided for @strengthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where your chart is strong, house by house'**
  String get strengthSubtitle;

  /// No description provided for @strengthTab.
  ///
  /// In en, this message translates to:
  /// **'{tab, select, ashtakavarga{Ashtakavarga} shadbala{Planet strength} other{{tab}}}'**
  String strengthTab(String tab);

  /// No description provided for @savTitle.
  ///
  /// In en, this message translates to:
  /// **'Sarvashtakavarga'**
  String get savTitle;

  /// No description provided for @savIntro.
  ///
  /// In en, this message translates to:
  /// **'Points each house gets from all planets. 28 is average; 30 or more supports that house\'s matters, below 25 needs care.'**
  String get savIntro;

  /// No description provided for @savHouse.
  ///
  /// In en, this message translates to:
  /// **'H{house}'**
  String savHouse(int house);

  /// No description provided for @bavTitle.
  ///
  /// In en, this message translates to:
  /// **'Planet by planet (Bhinnashtakavarga)'**
  String get bavTitle;

  /// No description provided for @bavTotal.
  ///
  /// In en, this message translates to:
  /// **'Total {total} points'**
  String bavTotal(int total);

  /// No description provided for @strengthNote.
  ///
  /// In en, this message translates to:
  /// **'A simplified Shadbala: exaltation, sign dignity, direction, natural, lunar-phase and motion strength. Use it to compare your planets with each other.'**
  String get strengthNote;

  /// No description provided for @strengthRupas.
  ///
  /// In en, this message translates to:
  /// **'{value} rupas'**
  String strengthRupas(String value);

  /// No description provided for @strengthComponent.
  ///
  /// In en, this message translates to:
  /// **'{component, select, uchcha{Exaltation} dignity{Sign dignity} dig{Directional} naisargika{Natural} paksha{Lunar phase} chesta{Motion} other{{component}}}'**
  String strengthComponent(String component);

  /// No description provided for @varshphalTitle.
  ///
  /// In en, this message translates to:
  /// **'Varshphal'**
  String get varshphalTitle;

  /// No description provided for @varshphalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your year ahead from your birthday chart'**
  String get varshphalSubtitle;

  /// No description provided for @varshphalNeedProfile.
  ///
  /// In en, this message translates to:
  /// **'Create your birth profile to see your year ahead.'**
  String get varshphalNeedProfile;

  /// No description provided for @varshphalYear.
  ///
  /// In en, this message translates to:
  /// **'{which, select, current{This year} next{Next year} other{{which}}}'**
  String varshphalYear(String which);

  /// No description provided for @varshphalAge.
  ///
  /// In en, this message translates to:
  /// **'Year {age} of your life'**
  String varshphalAge(int age);

  /// No description provided for @varshphalPravesh.
  ///
  /// In en, this message translates to:
  /// **'Begins {date}, when the Sun returns to its birth position'**
  String varshphalPravesh(String date);

  /// No description provided for @varshphalMuntha.
  ///
  /// In en, this message translates to:
  /// **'Muntha'**
  String get varshphalMuntha;

  /// No description provided for @varshphalMunthaLine.
  ///
  /// In en, this message translates to:
  /// **'Muntha in {sign}, house {house} of the year chart'**
  String varshphalMunthaLine(String sign, int house);

  /// No description provided for @varshphalTheme.
  ///
  /// In en, this message translates to:
  /// **'Year theme: {theme}'**
  String varshphalTheme(String theme);

  /// No description provided for @varshphalTone.
  ///
  /// In en, this message translates to:
  /// **'{tone, select, excellent{A strong, rewarding year for this area.} good{A supportive year for this area.} care{Go steady; this area needs care this year.} other{{tone}}}'**
  String varshphalTone(String tone);

  /// No description provided for @varshphalChart.
  ///
  /// In en, this message translates to:
  /// **'Year chart'**
  String get varshphalChart;

  /// No description provided for @varshphalLagna.
  ///
  /// In en, this message translates to:
  /// **'Year Lagna {sign}, ruled by {lord}'**
  String varshphalLagna(String sign, String lord);

  /// No description provided for @varshphalMunthaLord.
  ///
  /// In en, this message translates to:
  /// **'Muntha lord: {lord}'**
  String varshphalMunthaLord(String lord);

  /// No description provided for @varshphalPlanets.
  ///
  /// In en, this message translates to:
  /// **'Planets this year'**
  String get varshphalPlanets;

  /// No description provided for @varshphalPlanetLine.
  ///
  /// In en, this message translates to:
  /// **'House {house}: {theme}'**
  String varshphalPlanetLine(int house, String theme);

  /// No description provided for @varshphalPdf.
  ///
  /// In en, this message translates to:
  /// **'Download year report (PDF)'**
  String get varshphalPdf;

  /// No description provided for @varshphalPdfUnable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t make the PDF. Please try again.'**
  String get varshphalPdfUnable;

  /// No description provided for @varshphalNote.
  ///
  /// In en, this message translates to:
  /// **'Tajik Varshphal: the chart for the moment the Sun returns to its sidereal birth position, cast for your birth place.'**
  String get varshphalNote;

  /// No description provided for @kpTitle.
  ///
  /// In en, this message translates to:
  /// **'KP & Prashna'**
  String get kpTitle;

  /// No description provided for @kpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'KP cusps, star and sub lords, and horary answers'**
  String get kpSubtitle;

  /// No description provided for @kpTab.
  ///
  /// In en, this message translates to:
  /// **'{tab, select, birth{Birth chart} prashna{Prashna} other{{tab}}}'**
  String kpTab(String tab);

  /// No description provided for @kpCusps.
  ///
  /// In en, this message translates to:
  /// **'Cusps (Placidus)'**
  String get kpCusps;

  /// No description provided for @kpPlanets.
  ///
  /// In en, this message translates to:
  /// **'Planets'**
  String get kpPlanets;

  /// No description provided for @kpColumn.
  ///
  /// In en, this message translates to:
  /// **'{column, select, house{House} position{Position} sign{Sign} star{Star} sub{Sub} other{{column}}}'**
  String kpColumn(String column);

  /// No description provided for @kpRuling.
  ///
  /// In en, this message translates to:
  /// **'Ruling planets'**
  String get kpRuling;

  /// No description provided for @kpRulingRole.
  ///
  /// In en, this message translates to:
  /// **'{role, select, ascStar{Lagna star} ascSign{Lagna sign} moonStar{Moon star} moonSign{Moon sign} day{Day} other{{role}}}'**
  String kpRulingRole(String role);

  /// No description provided for @kpPrashnaIntro.
  ///
  /// In en, this message translates to:
  /// **'Hold one clear question in mind, pick its topic, then cast the chart for this moment and place.'**
  String get kpPrashnaIntro;

  /// No description provided for @kpQuestionLabel.
  ///
  /// In en, this message translates to:
  /// **'Question about'**
  String get kpQuestionLabel;

  /// No description provided for @kpQuestion.
  ///
  /// In en, this message translates to:
  /// **'{topic, select, marriage{Marriage} career{Job and career} money{Money and gains} property{Buying property} education{Education} children{Children} travel{Travel abroad} health{Recovery from illness} dispute{Court case or dispute} other{{topic}}}'**
  String kpQuestion(String topic);

  /// No description provided for @kpCast.
  ///
  /// In en, this message translates to:
  /// **'Cast chart now'**
  String get kpCast;

  /// No description provided for @kpCastAt.
  ///
  /// In en, this message translates to:
  /// **'Cast {time}'**
  String kpCastAt(String time);

  /// No description provided for @kpVerdictLine.
  ///
  /// In en, this message translates to:
  /// **'Sub lord of house {house} is {planet}, which signifies houses {houses}.'**
  String kpVerdictLine(int house, String planet, String houses);

  /// No description provided for @kpVerdict.
  ///
  /// In en, this message translates to:
  /// **'{verdict, select, promising{The chart supports this matter.} notPromised{The chart doesn\'t promise this matter right now.} other{{verdict}}}'**
  String kpVerdict(String verdict);

  /// No description provided for @kpNote.
  ///
  /// In en, this message translates to:
  /// **'KP uses the Krishnamurti ayanamsa and Placidus cusps, so signs can differ slightly from your Lahiri chart. Prashna answers are guidance, not certainties.'**
  String get kpNote;

  /// No description provided for @kpNoPlace.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find where you are. Allow location and try again.'**
  String get kpNoPlace;

  /// No description provided for @kpNeedProfile.
  ///
  /// In en, this message translates to:
  /// **'Create your birth profile to see your KP chart.'**
  String get kpNeedProfile;

  /// No description provided for @aiPackTitle.
  ///
  /// In en, this message translates to:
  /// **'Need more answers?'**
  String get aiPackTitle;

  /// No description provided for @aiPackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Buy a pack of questions. Pack questions never expire.'**
  String get aiPackSubtitle;

  /// No description provided for @aiPackBuy.
  ///
  /// In en, this message translates to:
  /// **'Get {count} questions · {price}'**
  String aiPackBuy(int count, String price);

  /// No description provided for @aiPackRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} pack questions left'**
  String aiPackRemaining(int count);

  /// No description provided for @aiPackAdded.
  ///
  /// In en, this message translates to:
  /// **'Questions added. Ask away!'**
  String get aiPackAdded;

  /// No description provided for @aiPackPending.
  ///
  /// In en, this message translates to:
  /// **'Purchase received. Your questions will appear in a minute.'**
  String get aiPackPending;

  /// No description provided for @aiPackFailed.
  ///
  /// In en, this message translates to:
  /// **'The purchase didn\'t go through. Please try again.'**
  String get aiPackFailed;

  /// No description provided for @varshphalMonths.
  ///
  /// In en, this message translates to:
  /// **'Month by month'**
  String get varshphalMonths;
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
