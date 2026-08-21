import 'planet_position.dart';
import 'rashi_chart.dart';

class Kundali {
  final String ascendant;
  final double ayanamsa;
  final double ascendantDegree;
  final double moonLongitude;
  final String moonSign;
  final String sunSign;
  final String nakshatra;
  final int nakshatraPada;
  final List<PlanetPosition> planets;
  final RashiChart? rashiChart;

  const Kundali({
    required this.ascendant,
    required this.ayanamsa,
    required this.ascendantDegree,
    required this.moonLongitude,
    required this.moonSign,
    required this.sunSign,
    required this.nakshatra,
    required this.nakshatraPada,
    required this.planets,
    this.rashiChart,
  });
}
