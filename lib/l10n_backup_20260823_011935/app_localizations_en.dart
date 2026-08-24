// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languagePreference => 'Language Preference';

  @override
  String get welcomeTitle => 'Welcome to RV Astro Vastu';

  @override
  String get welcomeSubtitle =>
      'Your personalized astrology journey starts here.';

  @override
  String get birthProfileTitle => 'Create Your Birth Profile';

  @override
  String get birthProfileSubtitle =>
      'Accurate birth details help us create your personalized astrology experience.';

  @override
  String get basicInformation => 'Basic Information';

  @override
  String get fullName => 'Full Name';

  @override
  String get enterYourName => 'Enter your name';

  @override
  String get gender => 'Gender';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get other => 'Other';

  @override
  String get dateOfBirth => 'Date of Birth';

  @override
  String get selectDate => 'Select date';

  @override
  String get exactBirthTime => 'Exact Birth Time';

  @override
  String get selectTime => 'Select time';

  @override
  String get placeOfBirth => 'Place of Birth';

  @override
  String get searchCity => 'Search city';

  @override
  String get continueButton => 'Continue';

  @override
  String get pleaseEnterName => 'Please enter your name';

  @override
  String get pleaseSelectGender => 'Please select gender';

  @override
  String get pleaseSelectDateOfBirth => 'Please select date of birth';

  @override
  String get pleaseSelectBirthTime => 'Please select birth time';

  @override
  String get pleaseEnterBirthLocation => 'Please enter your place of birth';

  @override
  String get pleaseSelectBirthLocation =>
      'Please select a birth location from the suggestions';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get getStarted => 'Get Started';
}
