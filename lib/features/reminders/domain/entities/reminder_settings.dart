class ReminderSettings {
  /// Whether the user has made a choice yet (shows the Home prompt if not).
  final bool configured;

  final bool morningEnabled;
  final int morningHour;
  final int morningMinute;

  /// Evening-before reminders for major festivals.
  final bool festivalsEnabled;

  /// Evening-before reminders for Ekadashi, Purnima, Amavasya, Pradosh,
  /// Sankashti and Masik Shivaratri.
  final bool vratsEnabled;

  const ReminderSettings({
    this.configured = false,
    this.morningEnabled = false,
    this.morningHour = 7,
    this.morningMinute = 0,
    this.festivalsEnabled = false,
    this.vratsEnabled = false,
  });

  /// What "Turn on reminders" enables in one tap.
  static const recommended = ReminderSettings(
    configured: true,
    morningEnabled: true,
    festivalsEnabled: true,
    vratsEnabled: true,
  );

  bool get anyEnabled => morningEnabled || festivalsEnabled || vratsEnabled;

  ReminderSettings copyWith({
    bool? configured,
    bool? morningEnabled,
    int? morningHour,
    int? morningMinute,
    bool? festivalsEnabled,
    bool? vratsEnabled,
  }) {
    return ReminderSettings(
      configured: configured ?? this.configured,
      morningEnabled: morningEnabled ?? this.morningEnabled,
      morningHour: morningHour ?? this.morningHour,
      morningMinute: morningMinute ?? this.morningMinute,
      festivalsEnabled: festivalsEnabled ?? this.festivalsEnabled,
      vratsEnabled: vratsEnabled ?? this.vratsEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.configured == configured &&
      other.morningEnabled == morningEnabled &&
      other.morningHour == morningHour &&
      other.morningMinute == morningMinute &&
      other.festivalsEnabled == festivalsEnabled &&
      other.vratsEnabled == vratsEnabled;

  @override
  int get hashCode => Object.hash(
    configured,
    morningEnabled,
    morningHour,
    morningMinute,
    festivalsEnabled,
    vratsEnabled,
  );
}
