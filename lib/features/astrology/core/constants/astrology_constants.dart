class AstrologyConstants {
  AstrologyConstants._();

  static const int zodiacSigns = 12;
  static const int houses = 12;
  static const int nakshatras = 27;
  static const int padasPerNakshatra = 4;

  static const double degreesPerSign = 30.0;
  static const double degreesPerNakshatra =
      360.0 / nakshatras;

  static const String zodiacSystem = 'Sidereal';
  static const String ayanamsaSystem = 'Lahiri';
  static const String houseSystem = 'Whole Sign';

  static const String chartType = 'D1 Rashi';
}
