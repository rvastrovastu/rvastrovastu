import '../../../../l10n/app_localizations.dart';

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
        return aries;
      case 'Taurus':
        return taurus;
      case 'Gemini':
        return gemini;
      case 'Cancer':
        return cancer;
      case 'Leo':
        return leo;
      case 'Virgo':
        return virgo;
      case 'Libra':
        return libra;
      case 'Scorpio':
        return scorpio;
      case 'Sagittarius':
        return sagittarius;
      case 'Capricorn':
        return capricorn;
      case 'Aquarius':
        return aquarius;
      case 'Pisces':
        return pisces;
      default:
        return rashi;
    }
  }

  String nakshatraName(String nakshatra) {
    switch (nakshatra) {
      case 'Ashwini':
        return ashwini;
      case 'Bharani':
        return bharani;
      case 'Krittika':
        return krittika;
      case 'Rohini':
        return rohini;
      case 'Mrigashira':
        return mrigashira;
      case 'Ardra':
        return ardra;
      case 'Punarvasu':
        return punarvasu;
      case 'Pushya':
        return pushya;
      case 'Ashlesha':
        return ashlesha;
      case 'Magha':
        return magha;
      case 'Purva Phalguni':
        return purvaPhalguni;
      case 'Uttara Phalguni':
        return uttaraPhalguni;
      case 'Hasta':
        return hasta;
      case 'Chitra':
        return chitra;
      case 'Swati':
        return swati;
      case 'Vishakha':
        return vishakha;
      case 'Anuradha':
        return anuradha;
      case 'Jyeshtha':
        return jyeshtha;
      case 'Mula':
        return mula;
      case 'Purva Ashadha':
        return purvaAshadha;
      case 'Uttara Ashadha':
        return uttaraAshadha;
      case 'Shravana':
        return shravana;
      case 'Dhanishta':
        return dhanishta;
      case 'Shatabhisha':
        return shatabhisha;
      case 'Purva Bhadrapada':
        return purvaBhadrapada;
      case 'Uttara Bhadrapada':
        return uttaraBhadrapada;
      case 'Revati':
        return revati;
      default:
        return nakshatra;
    }
  }
}
