import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/time/app_clock_provider.dart';
import '../../astrology/domain/models/kundali_input.dart';
import '../../astrology/presentation/providers/astrology_provider.dart';
import '../../birth_profile/data/models/birth_profile_model.dart';
import '../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../horoscope/presentation/providers/daily_horoscope_provider.dart';
import '../../panchang/domain/entities/daily_panchang_input.dart';
import '../../panchang/presentation/providers/day_divisions_provider.dart';
import '../../panchang/presentation/providers/panchang_location_provider.dart';
import '../../your_day/domain/day_strength.dart';
import '../../your_day/presentation/your_day_provider.dart';
import '../data/daily_loop_storage.dart';
import '../domain/daily_loop.dart';
import '../domain/personal_muhurat.dart';

final dailyLoopStorageProvider = Provider<DailyLoopStorage>(
  (ref) => const DailyLoopStorage(),
);

/// Today's local calendar date; changes at midnight, not every minute.
final loopTodayProvider = Provider<DateTime>((ref) {
  final now = ref.watch(appClockProvider);
  return DateTime(now.year, now.month, now.day);
});

/// The remedy days and check-ins saved on this device.
final dailyLoopProvider =
    AsyncNotifierProvider<DailyLoopNotifier, DailyLoopRecord>(
      DailyLoopNotifier.new,
    );

class DailyLoopNotifier extends AsyncNotifier<DailyLoopRecord> {
  @override
  Future<DailyLoopRecord> build() =>
      ref.read(dailyLoopStorageProvider).load();

  Future<void> markRemedyDone() async {
    final today = ref.read(loopTodayProvider);
    final current = state.value ?? const DailyLoopRecord();
    await _save(
      current.copyWith(remedyDays: {...current.remedyDays, dayKey(today)}),
      today,
    );
  }

  Future<void> checkIn(CheckIn answer) async {
    final today = ref.read(loopTodayProvider);
    final current = state.value ?? const DailyLoopRecord();
    await _save(
      current.copyWith(checkIns: {...current.checkIns, dayKey(today): answer}),
      today,
    );
  }

  Future<void> _save(DailyLoopRecord record, DateTime today) async {
    state = AsyncData(record);
    try {
      await ref.read(dailyLoopStorageProvider).save(record, today);
    } catch (error) {
      debugPrint('[DAILY LOOP] save failed: $error');
    }
  }
}

/// Today's free remedy, from the running dasha; null without a profile.
final dailyRemedyProvider = Provider.autoDispose<DailyRemedy?>((ref) {
  final horoscope = ref.watch(dailyHoroscopeProvider).value;
  if (horoscope == null) return null;
  return pickDailyRemedy(
    date: ref.watch(loopTodayProvider),
    mahadasha: horoscope.mahadasha,
    antardasha: horoscope.antardasha,
  );
});

/// The purpose chosen on the personal muhurat card.
final muhuratPurposeProvider =
    NotifierProvider<MuhuratPurposeNotifier, MuhuratPurpose>(
      MuhuratPurposeNotifier.new,
    );

class MuhuratPurposeNotifier extends Notifier<MuhuratPurpose> {
  @override
  MuhuratPurpose build() => MuhuratPurpose.start;

  void select(MuhuratPurpose purpose) => state = purpose;
}

/// The best hours left today for the chosen purpose, with the place's
/// time zone for showing them. Null without a profile or a place.
final personalMuhuratProvider = FutureProvider.autoDispose<
  ({List<MuhuratWindow> windows, String timezone})?
>((ref) async {
  final kundali = await ref.watch(kundaliProvider.future);
  if (kundali == null) return null;
  final place = ref.watch(panchangPlaceProvider).value;
  if (place == null) return null;

  final now = ref.watch(appClockProvider);
  final location = place.location;
  final zone = tz.getLocation(location.timezone);
  final localNow = tz.TZDateTime.from(now.toUtc(), zone);
  final input = DailyPanchangInput(
    date: DateTime(localNow.year, localNow.month, localNow.day),
    latitude: location.latitude,
    longitude: location.longitude,
    timezone: location.timezone,
  );

  final vedicDays = await ref.watch(dayDivisionsProvider(input).future);
  final moon = await ref.watch(
    moonNowProvider(ref.watch(horoscopeMoonKeyProvider)).future,
  );

  final windows = const FindPersonalMuhurat()(
    days: [
      if (vedicDays.yesterday case final day?) day,
      if (vedicDays.today case final day?) day,
    ],
    now: now,
    birthNakshatra: nakshatraIndexOf(kundali.moonLongitude),
    nakshatraNow: nakshatraIndexOf(moon.longitude),
    nakshatraEndsUtc: moon.nakshatraEndsUtc,
    purpose: ref.watch(muhuratPurposeProvider),
  );
  return (windows: windows, timezone: location.timezone);
});

/// One family member's day.
class FamilyDay {
  final BirthProfileModel profile;
  final DayStrength strength;

  const FamilyDay({required this.profile, required this.strength});

  /// Key for the headline, as in the daily horoscope.
  String get headlineKey =>
      strength.isChandrashtama ? 'chandrashtama' : strength.tara.name;
}

/// A saved profile's natal Moon, calculated once per profile.
final _natalMoonProvider = FutureProvider.autoDispose
    .family<double?, BirthProfileModel>((ref, profile) async {
      if (profile.location.timezone.trim().isEmpty) return null;
      try {
        final kundali = await ref
            .watch(astrologyRepositoryProvider)
            .calculateKundali(
              KundaliInput(
                dateOfBirth: profile.dateOfBirth,
                birthTime: profile.birthTime,
                latitude: profile.location.latitude,
                longitude: profile.location.longitude,
                timezone: profile.location.timezone,
              ),
            );
        return kundali.moonLongitude;
      } catch (error) {
        debugPrint('[DAILY LOOP] chart for ${profile.name} failed: $error');
        return null;
      }
    });

/// Everyone saved on this device, each with their own day from their own
/// birth star. At most [familyLimit] people.
const familyLimit = 8;

final familyDaysProvider = FutureProvider.autoDispose<List<FamilyDay>>((
  ref,
) async {
  final profiles = ref.watch(birthProfilesProvider).take(familyLimit).toList();
  if (profiles.isEmpty) return const [];
  final moon = await ref.watch(
    moonNowProvider(ref.watch(horoscopeMoonKeyProvider)).future,
  );

  final days = <FamilyDay>[];
  for (final profile in profiles) {
    final natal = await ref.watch(_natalMoonProvider(profile).future);
    if (natal == null) continue;
    days.add(
      FamilyDay(
        profile: profile,
        strength: DayStrength.fromLongitudes(
          natalMoon: natal,
          transitMoon: moon.longitude,
        ),
      ),
    );
  }
  return days;
});
