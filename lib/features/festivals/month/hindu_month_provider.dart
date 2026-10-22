import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/providers/festival_calendar_provider.dart';
import 'hindu_month.dart';

/// The month grid for the month holding [month] (any day in it), at the
/// festival calendar's place. Null without a place.
final hinduMonthProvider = FutureProvider.family<List<HinduDay>?, DateTime>((
  ref,
  month,
) async {
  final place = await ref.watch(festivalPlaceProvider.future);
  if (place == null) return null;
  final first = DateTime(month.year, month.month);
  final last = DateTime(month.year, month.month + 1, 0);
  final data = await ref
      .watch(lunarCalendarRepositoryProvider)
      .calculate(
        fromDate: first,
        toDate: last,
        latitude: place.latitude,
        longitude: place.longitude,
        timezone: place.timezone,
      );
  return buildHinduMonth(data, month.year, month.month);
});

/// True for the Purnimanta reckoning, false for Amanta.
final purnimantaProvider = NotifierProvider<PurnimantaNotifier, bool?>(
  PurnimantaNotifier.new,
);

/// Null until the user picks; the grid then defaults by language.
class PurnimantaNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;

  void set(bool value) => state = value;
}
