/// When the exact birth time isn't known, the user picks a part of the day
/// and the chart is cast for its middle. Moon sign, nakshatra and dasha
/// stay close; the lagna and houses are approximate.
enum RoughBirthTime {
  earlyMorning('03:00'),
  morning('09:00'),
  afternoon('14:30'),
  evening('19:00'),
  night('22:30'),
  noIdea('12:00');

  const RoughBirthTime(this.clock);

  /// The `HH:mm` time the chart is cast for.
  final String clock;

  /// The period a saved time stands for; [noIdea] when it matches none.
  static RoughBirthTime fromClock(String clock) {
    for (final value in values) {
      if (value.clock == clock) return value;
    }
    return noIdea;
  }
}
