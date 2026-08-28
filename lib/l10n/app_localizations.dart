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
  /// **'Panchang calculations will use the selected birth/location timezone.'**
  String get homePanchangTimezone;

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
