class DegreeUtils {
  DegreeUtils._();

  static double normalize(double value) {
    var result = value % 360.0;

    if (result < 0) {
      result += 360.0;
    }

    return result;
  }

  static int signIndex(double longitude) {
    return normalize(longitude) ~/ 30;
  }

  static double degreeWithinSign(double longitude) {
    return normalize(longitude) % 30.0;
  }

  static String format(double degree) {
    return '${degree.toStringAsFixed(2)}°';
  }
}
