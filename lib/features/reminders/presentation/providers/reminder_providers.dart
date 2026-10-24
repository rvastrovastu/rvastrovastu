import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/localization/language_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../festivals/domain/entities/calendar_observance.dart';
import '../../../festivals/presentation/providers/festival_calendar_provider.dart';
import '../../../panchang/domain/entities/daily_panchang.dart';
import '../../../panchang/presentation/providers/daily_panchang_provider.dart';
import '../../../panchang/presentation/utils/panchang_localization.dart';
import '../../../astrology/presentation/providers/astrology_provider.dart';
import '../../../astrology/presentation/utils/astrology_localization.dart';
import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../../your_day/domain/day_strength.dart';
import '../../../your_day/presentation/your_day_provider.dart';
import '../../../daily_loop/domain/daily_loop.dart';
import '../../../daily_loop/domain/personal_muhurat.dart';
import '../../../dasha/domain/entities/dasha_birth_data.dart';
import '../../../dasha/domain/entities/dasha_period.dart';
import '../../../dasha/domain/usecases/calculate_current_dasha.dart';
import '../../../dasha/presentation/providers/dasha_provider.dart';
import '../../../panchang/domain/entities/day_divisions.dart';
import '../../../panchang/presentation/providers/day_divisions_provider.dart';
import '../../../dosha/domain/entities/zodiac_signs.dart';
import '../../../gochar/domain/entities/transit.dart';
import '../../../gochar/presentation/providers/gochar_provider.dart';
import '../../../membership/domain/membership.dart';
import '../../../membership/presentation/providers/membership_provider.dart';
import '../../../rashifal/domain/rashifal.dart';
import '../../../rashifal/presentation/rashifal_providers.dart';
import '../../../today_widget/today_widget_sync.dart';
import '../../data/local_notification_service.dart';
import '../../data/reminder_settings_storage.dart';
import '../../domain/entities/reminder_settings.dart';
import '../../domain/usecases/plan_reminders.dart';

final reminderSettingsStorageProvider = Provider<ReminderSettingsStorage>(
  (ref) => const ReminderSettingsStorage(),
);

final reminderSettingsProvider =
    AsyncNotifierProvider<ReminderSettingsNotifier, ReminderSettings>(
      ReminderSettingsNotifier.new,
    );

class ReminderSettingsNotifier extends AsyncNotifier<ReminderSettings> {
  @override
  Future<ReminderSettings> build() {
    return ref.read(reminderSettingsStorageProvider).load();
  }

  /// Saves [settings] and reschedules. When turning something on, asks for
  /// notification permission first; returns false if it was declined.
  Future<bool> save(ReminderSettings settings) async {
    final previous = state.value ?? const ReminderSettings();
    final turningOn = settings.anyEnabled && !previous.anyEnabled;

    var granted = true;
    if (turningOn) {
      try {
        granted = await LocalNotificationService.instance.requestPermission();
      } catch (error) {
        debugPrint('[REMINDERS] permission request failed: $error');
        granted = false;
      }
    }

    final saved = granted
        ? settings
        : const ReminderSettings(configured: true);

    await ref.read(reminderSettingsStorageProvider).save(saved);
    state = AsyncData(saved);
    await ref.read(reminderSchedulerProvider).sync();
    return granted;
  }
}

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  ReminderScheduler.new,
);

/// Recomputes and schedules the next ~two weeks of reminders. Called on
/// app start, on resume and whenever settings change, so the rolling
/// window stays current without background work.
class ReminderScheduler {
  final Ref ref;
  bool _running = false;

  ReminderScheduler(this.ref);

  static const int morningDays = 14;

  Future<void> sync() async {
    if (_running) return;
    _running = true;
    try {
      await _sync();
    } catch (error, stack) {
      debugPrint('[REMINDERS] sync failed: $error');
      debugPrint('$stack');
    } finally {
      _running = false;
    }
  }

  Future<void> _sync() async {
    final settings = await ref.read(reminderSettingsStorageProvider).load();

    // Never touch the plugin before the user has made a choice.
    if (!settings.configured) return;

    final service = LocalNotificationService.instance;
    if (!settings.anyEnabled) {
      await service.cancelAll();
      return;
    }

    final place = await ref.read(festivalPlaceProvider.future);
    if (place == null) return;

    final location = tz.getLocation(place.timezone);
    final nowLocal = tz.TZDateTime.now(location);
    final now = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
      nowLocal.hour,
      nowLocal.minute,
    );

    final panchangDays = <DailyPanchang>[];
    if (settings.morningEnabled) {
      final repository = ref.read(dailyPanchangRepositoryProvider);
      for (var i = 0; i < morningDays; i++) {
        // Keep the UI responsive between days.
        await Future<void>.delayed(Duration.zero);
        panchangDays.add(
          await repository.calculate(
            date: DateTime(now.year, now.month, now.day + i),
            latitude: place.latitude,
            longitude: place.longitude,
            timezone: place.timezone,
          ),
        );
      }
    }

    var observances = const <CalendarObservance>[];
    try {
      observances =
          (await ref.read(upcomingFestivalsProvider.future))?.observances ??
          const [];
    } catch (error) {
      debugPrint('[REMINDERS] festival calendar unavailable: $error');
    }

    final transitAlerts = settings.transitsEnabled
        ? await _transitAlerts(location)
        : const <TransitAlert>[];

    final plan = const PlanReminders()(
      settings: settings,
      now: now,
      panchangDays: panchangDays,
      observances: observances,
      transitAlerts: transitAlerts,
    );

    final l10n = lookupAppLocalizations(
      Locale(ref.read(languageProvider).code),
    );

    // The user's own daily Rashifal for each morning, when there is a
    // profile.
    final rashifal = <DateTime, Rashifal>{};
    if (settings.morningEnabled && panchangDays.isNotEmpty) {
      try {
        final sign = await ref.read(userMoonSignProvider.future);
        if (sign != null) {
          final skies = await ref.read(skyRepositoryProvider).snapshots([
            for (final d in panchangDays)
              DateTime(d.date.year, d.date.month, d.date.day, 12),
          ]);
          for (final (i, d) in panchangDays.indexed) {
            final day = DateTime(d.date.year, d.date.month, d.date.day);
            rashifal[day] = const RashifalEngine().daily(sign, day, skies[i]);
          }
        }
      } catch (error) {
        debugPrint('[REMINDERS] rashifal unavailable: $error');
      }
    }

    // The user's own morning briefing: their reading, best hour, today's
    // small remedy and Rahu Kaal.
    final personal = settings.morningEnabled
        ? await _personalBriefings(
            l10n,
            location,
            plan,
            latitude: place.latitude,
            longitude: place.longitude,
          )
        : const <DateTime, String>{};

    final requests = [
      for (final reminder in plan)
        _request(
          l10n,
          location,
          reminder,
          rashifal[_dateOnly(reminder.at)],
          personal[_dateOnly(reminder.at)],
        ),
    ];

    await service.replaceAll(requests);
    debugPrint('[REMINDERS] scheduled ${requests.length}');
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The morning briefing for each morning reminder's day, one line each:
  /// the personal reading, the best hour, today's small remedy and Rahu
  /// Kaal. Empty without a profile; a line that can't be worked out is
  /// left out.
  Future<Map<DateTime, String>> _personalBriefings(
    AppLocalizations l10n,
    tz.Location location,
    List<PlannedReminder> plan, {
    required double latitude,
    required double longitude,
  }) async {
    final briefings = <DateTime, String>{};
    try {
      final profile = ref.read(birthProfileProvider);
      final kundali = await ref.read(kundaliProvider.future);
      if (profile == null || kundali == null) return briefings;

      final moons = ref.read(moonRepositoryProvider);
      final sunTimes = ref.read(sunTimesRepositoryProvider);
      final timeline = ref.read(
        dashaTimelineProvider(
          DashaBirthData(
            birthDate: profile.dateOfBirth,
            moonLongitude: kundali.moonLongitude,
          ),
        ),
      );
      final birthNakshatra = nakshatraIndexOf(kundali.moonLongitude);
      final clock = DateFormat.jm(l10n.localeName);
      String time(DateTime utc) =>
          clock.format(tz.TZDateTime.from(utc, location));

      for (final reminder in plan) {
        if (reminder.kind != ReminderKind.morning) continue;
        await Future<void>.delayed(Duration.zero);
        final day = _dateOnly(reminder.at);
        final at = tz.TZDateTime(
          location,
          reminder.at.year,
          reminder.at.month,
          reminder.at.day,
          reminder.at.hour,
          reminder.at.minute,
        );
        final moon = await moons.moonAt(at);
        final strength = DayStrength.fromLongitudes(
          natalMoon: kundali.moonLongitude,
          transitMoon: moon.longitude,
        );
        final lines = <String>[];

        final name = profile.name.trim();
        final reading = l10n.horoscopeHeadline(
          strength.isChandrashtama ? 'chandrashtama' : strength.tara.name,
        );
        lines.add(
          name.isEmpty
              ? reading
              : l10n.reminderMorningPersonalLine(name, reading),
        );

        try {
          final sun = await sunTimes.sunTimes(
            date: day,
            latitude: latitude,
            longitude: longitude,
            timezone: location.name,
          );
          if (sun != null) {
            final divisions = DayDivisions.calculate(
              sun,
              tz.TZDateTime.from(sun.sunrise, location).weekday,
            );
            final best = const FindPersonalMuhurat()(
              days: [divisions],
              now: at,
              birthNakshatra: birthNakshatra,
              nakshatraNow: nakshatraIndexOf(moon.longitude),
              nakshatraEndsUtc: moon.nakshatraEndsUtc,
              purpose: MuhuratPurpose.start,
              limit: 1,
            );
            if (best.isNotEmpty) {
              final w = best.first;
              lines.add(
                l10n.reminderMorningBest(
                  '${time(w.start)} – ${time(w.end)}',
                  l10n.choghadiyaName(w.choghadiya.name),
                  l10n.planetName(w.hora),
                ),
              );
            }
          }
        } catch (error) {
          debugPrint('[REMINDERS] best hour unavailable: $error');
        }

        final dasha = CalculateCurrentDasha().call(
          timeline: timeline,
          date: at,
        );
        final remedy = pickDailyRemedy(
          date: day,
          mahadasha: dasha.mahadasha?.planet.name,
          antardasha: dasha.antardasha?.planet.name,
        );
        lines.add(l10n.reminderMorningRemedy(_remedyText(l10n, remedy)));

        if (reminder.panchang case final panchang?) {
          lines.add(l10n.reminderMorningRahu(panchang.rahuKaal));
        }
        briefings[day] = lines.join('\n');
      }
    } catch (error) {
      debugPrint('[REMINDERS] personal briefing unavailable: $error');
    }
    return briefings;
  }

  static String _remedyText(AppLocalizations l10n, DailyRemedy remedy) =>
      switch (remedy.kind) {
        RemedyKind.mantra => l10n.dailyRemedyMantraShort(
          l10n.remediesMantraLatin(remedy.planet),
        ),
        RemedyKind.charity => l10n.dailyRemedyCharity(
          l10n.remediesCharityItems(remedy.planet),
        ),
        RemedyKind.worship => l10n.dailyRemedyWorship(
          l10n.remediesDeityName(remedy.planet),
        ),
      };

  /// Upcoming sign changes from the user's Moon: Saturn (and Sade Sati)
  /// for everyone, Jupiter, Rahu and Ketu too with Premium.
  Future<List<TransitAlert>> _transitAlerts(tz.Location location) async {
    try {
      final report = await ref.read(gocharReportProvider.future);
      if (report == null) return const [];
      var premium = false;
      try {
        premium = (await ref.read(membershipProvider.future)).canUse(
          PremiumFeature.transitAlerts,
        );
      } catch (_) {}
      return [
        for (final i in report.upcoming)
          if (premium || i.planet == TransitPlanet.saturn)
            _alertFor(i, location),
      ];
    } catch (error) {
      debugPrint('[REMINDERS] transits unavailable: $error');
      return const [];
    }
  }

  static TransitAlert _alertFor(UpcomingIngress i, tz.Location location) {
    final local = tz.TZDateTime.from(i.date, location);
    final saturn = i.planet == TransitPlanet.saturn;
    return TransitAlert(
      planet: i.planet.displayKey,
      signIndex: i.signIndex,
      houseFromMoon: i.houseFromMoon,
      favourable: i.tone == TransitTone.favourable,
      date: DateTime(local.year, local.month, local.day),
      sadeSati: !saturn
          ? null
          : switch (i.houseFromMoon) {
              12 => 'start',
              3 => 'end',
              _ => null,
            },
    );
  }

  NotificationRequest _request(
    AppLocalizations l10n,
    tz.Location location,
    PlannedReminder reminder, [
    Rashifal? rashifal,
    String? personal,
  ]) {
    final at = tz.TZDateTime(
      location,
      reminder.at.year,
      reminder.at.month,
      reminder.at.day,
      reminder.at.hour,
      reminder.at.minute,
    );

    switch (reminder.kind) {
      case ReminderKind.morning:
        final panchang = reminder.panchang!;
        final festival = reminder.observances.isEmpty
            ? null
            : l10n.festivalName(reminder.observances.first.name);
        return NotificationRequest(
          id: reminder.id,
          at: at,
          isDaily: true,
          title: festival == null
              ? l10n.reminderMorningTitle(localizedTithi(l10n, panchang.tithi))
              : l10n.reminderMorningFestivalTitle(festival),
          body: personal != null
              ? personal
              : rashifal == null
              ? l10n.reminderMorningBody(
                  localizedNakshatra(l10n, panchang.nakshatra),
                  panchang.rahuKaal,
                )
              : l10n.reminderMorningRashifalBody(
                  l10n.rashiName(zodiacSigns[rashifal.sign]),
                  starText(rashifal.overall),
                  l10n.rashifalOverall(RashifalEngine.level(rashifal.overall)),
                  panchang.rahuKaal,
                ),
        );
      case ReminderKind.transit:
        final t = reminder.transit!;
        final planet = l10n.planetName(t.planet);
        final sign = l10n.rashiName(zodiacSigns[t.signIndex]);
        return NotificationRequest(
          id: reminder.id,
          at: at,
          isDaily: false,
          title: switch (t.sadeSati) {
            'start' => l10n.transitSadeSatiStart(sign),
            'end' => l10n.transitSadeSatiEnd(sign),
            _ => l10n.gocharIngress(planet, sign),
          },
          body: l10n.transitAlertBody(
            t.houseFromMoon,
            l10n.gocharHouseTheme('h${t.houseFromMoon}'),
            l10n.gocharTone(t.favourable ? 'favourable' : 'challenging'),
          ),
        );
      case ReminderKind.checkIn:
        return NotificationRequest(
          id: reminder.id,
          at: at,
          isDaily: true,
          title: l10n.checkInTitle,
          body: l10n.reminderCheckInBody,
        );
      case ReminderKind.festivalEve:
      case ReminderKind.vratEve:
        return NotificationRequest(
          id: reminder.id,
          at: at,
          isDaily: false,
          title: l10n.reminderEveTitle(
            l10n.festivalName(reminder.observances.first.name),
          ),
          body: l10n.reminderEveBody,
        );
    }
  }
}
