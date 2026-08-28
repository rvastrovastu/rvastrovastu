import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';

extension AstrologyLocalization on AppLocalizations {
  String planetName(String planet) {
    switch (planet) {
      case 'Sun':
        return sun;
      case 'Moon':
        return moon;
      case 'Mars':
        return mars;
      case 'Mercury':
        return mercury;
      case 'Jupiter':
        return jupiter;
      case 'Venus':
        return venus;
      case 'Saturn':
        return saturn;
      case 'Rahu':
        return rahu;
      case 'Ketu':
        return ketu;
      default:
        return planet;
    }
  }

  String rashiName(String rashi) {
    switch (rashi) {
      case 'Aries':
        return 'Aries';
      case 'Taurus':
        return 'Taurus';
      case 'Gemini':
        return 'Gemini';
      case 'Cancer':
        return 'Cancer';
      case 'Leo':
        return 'Leo';
      case 'Virgo':
        return 'Virgo';
      case 'Libra':
        return 'Libra';
      case 'Scorpio':
        return 'Scorpio';
      case 'Sagittarius':
        return 'Sagittarius';
      case 'Capricorn':
        return 'Capricorn';
      case 'Aquarius':
        return 'Aquarius';
      case 'Pisces':
        return 'Pisces';
      default:
        return rashi;
    }
  }

  String nakshatraName(String nakshatra) {
    switch (nakshatra) {
      case 'Ashwini':
        return 'Ashwini';
      case 'Bharani':
        return 'Bharani';
      case 'Krittika':
        return 'Krittika';
      case 'Rohini':
        return 'Rohini';
      case 'Mrigashira':
        return 'Mrigashira';
      case 'Ardra':
        return 'Ardra';
      case 'Punarvasu':
        return 'Punarvasu';
      case 'Pushya':
        return 'Pushya';
      case 'Ashlesha':
        return 'Ashlesha';
      case 'Magha':
        return 'Magha';
      case 'Purva Phalguni':
        return 'Purva Phalguni';
      case 'Uttara Phalguni':
        return 'Uttara Phalguni';
      case 'Hasta':
        return 'Hasta';
      case 'Chitra':
        return 'Chitra';
      case 'Swati':
        return 'Swati';
      case 'Vishakha':
        return 'Vishakha';
      case 'Anuradha':
        return 'Anuradha';
      case 'Jyeshtha':
        return 'Jyeshtha';
      case 'Mula':
        return 'Mula';
      case 'Purva Ashadha':
        return 'Purva Ashadha';
      case 'Uttara Ashadha':
        return 'Uttara Ashadha';
      case 'Shravana':
        return 'Shravana';
      case 'Dhanishta':
        return 'Dhanishta';
      case 'Shatabhisha':
        return 'Shatabhisha';
      case 'Purva Bhadrapada':
        return 'Purva Bhadrapada';
      case 'Uttara Bhadrapada':
        return 'Uttara Bhadrapada';
      case 'Revati':
        return 'Revati';
      default:
        return nakshatra;
    }
  }
}
