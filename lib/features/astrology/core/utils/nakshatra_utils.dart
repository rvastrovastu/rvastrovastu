import '../constants/nakshatra_constants.dart';

class NakshatraUtils {
  NakshatraUtils._();

  static int indexFromLongitude(double longitude) {
    final normalized = longitude % 360.0;

    final index =
        (normalized / (360.0 / 27.0)).floor();

    return index.clamp(0, 26);
  }

  static String nameFromLongitude(double longitude) {
    return NakshatraConstants.nameAt(
      indexFromLongitude(longitude),
    );
  }

  static int padaFromLongitude(double longitude) {
    final normalized = longitude % 360.0;

    final pada =
        ((normalized / (360.0 / 108.0)).floor() % 4) + 1;

    return pada;
  }
}
