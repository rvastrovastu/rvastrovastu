/// The sixteen 22.5° directional zones used in modern 16-zone Vastu,
/// clockwise from North. Each zone is centred on its direction, so North
/// covers 348.75°–11.25°.
enum VastuZone {
  n,
  nne,
  ne,
  ene,
  e,
  ese,
  se,
  sse,
  s,
  ssw,
  sw,
  wsw,
  w,
  wnw,
  nw,
  nnw,
}

extension VastuZoneInfo on VastuZone {
  static const double width = 22.5;

  /// Short compass label, e.g. "NNE".
  String get abbreviation => name.toUpperCase();

  /// Centre bearing in degrees from North.
  double get centre => index * width;

  double get startBearing => (centre - width / 2 + 360) % 360;
}

/// Zone containing a compass [heading] in degrees (any value; wrapped).
VastuZone vastuZoneForHeading(double heading) {
  final normalized = ((heading % 360) + 360) % 360;
  final index =
      ((normalized + VastuZoneInfo.width / 2) / VastuZoneInfo.width).floor() %
      16;
  return VastuZone.values[index];
}
