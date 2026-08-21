class PlanetConstants {
  PlanetConstants._();

  static const List<String> classicalPlanets = [
    'Sun',
    'Moon',
    'Mars',
    'Mercury',
    'Jupiter',
    'Venus',
    'Saturn',
  ];

  static const List<String> vedicPlanets = [
    'Sun',
    'Moon',
    'Mars',
    'Mercury',
    'Jupiter',
    'Venus',
    'Saturn',
    'Rahu',
    'Ketu',
  ];

  static const Map<String, String> symbols = {
    'Sun': '☉',
    'Moon': '☽',
    'Mars': '♂',
    'Mercury': '☿',
    'Jupiter': '♃',
    'Venus': '♀',
    'Saturn': '♄',
    'Rahu': '☊',
    'Ketu': '☋',
  };

  static const Map<String, String> hindiNames = {
    'Sun': 'Surya',
    'Moon': 'Chandra',
    'Mars': 'Mangal',
    'Mercury': 'Budha',
    'Jupiter': 'Guru',
    'Venus': 'Shukra',
    'Saturn': 'Shani',
    'Rahu': 'Rahu',
    'Ketu': 'Ketu',
  };

  static String symbolFor(String planet) {
    return symbols[planet] ?? '•';
  }
}
