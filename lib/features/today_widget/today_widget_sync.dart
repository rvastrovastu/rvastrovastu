import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/localization/language_provider.dart';
import '../../l10n/app_localizations.dart';
import '../astrology/presentation/utils/astrology_localization.dart';
import '../dosha/domain/entities/zodiac_signs.dart';
import '../festivals/domain/entities/calendar_observance.dart';
import '../festivals/presentation/providers/festival_calendar_provider.dart';
import '../panchang/presentation/providers/daily_panchang_provider.dart';
import '../panchang/presentation/utils/panchang_localization.dart';
import '../rashifal/domain/rashifal.dart';
import '../rashifal/presentation/rashifal_providers.dart';

/// Names shared with the native widgets (iOS kind, Android provider) and
/// the App Group the iOS widget reads from.
abstract final class TodayWidgetIds {
  static const appGroup = 'group.com.rvastrovastu.rvAstroVastu';
  static const iOSKind = 'TodayWidget';
  static const androidProvider =
      'com.rvastrovastu.rv_astro_vastu.TodayWidgetProvider';
}

/// One day as the widget shows it; every string already localized.
class TodayWidgetDay {
  final DateTime date;
  final String title;
  final String detail;
  final String rahuKaal;
  final String? rashifal;

  const TodayWidgetDay({
    required this.date,
    required this.title,
    required this.detail,
    required this.rahuKaal,
    this.rashifal,
  });

  Map<String, Object?> toJson() => {
    'date':
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}',
    'title': title,
    'detail': detail,
    'rahu': rahuKaal,
    'rashifal': rashifal,
  };
}

/// Stars as text, e.g. ★★★★☆.
String starText(int stars) => '${'★' * stars}${'☆' * (5 - stars)}';

final todayWidgetSyncProvider = Provider<TodayWidgetSync>(TodayWidgetSync.new);

/// Writes the next week of Panchang (and the user's daily Rashifal) for the
/// home-screen widget, so it stays right for days without opening the app.
class TodayWidgetSync {
  static const days = 7;

  final Ref ref;
  bool _running = false;

  TodayWidgetSync(this.ref);

  Future<void> sync() async {
    if (_running || kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return;
    _running = true;
    try {
      final entries = await build();
      if (entries == null) return;
      final l10n = lookupAppLocalizations(
        Locale(ref.read(languageProvider).code),
      );
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(TodayWidgetIds.appGroup);
      }
      await HomeWidget.saveWidgetData<String>(
        'days',
        jsonEncode([for (final e in entries) e.toJson()]),
      );
      await HomeWidget.saveWidgetData<String>(
        'rahuLabel',
        l10n.todayWidgetRahuLabel,
      );
      await HomeWidget.saveWidgetData<String>(
        'emptyText',
        l10n.todayWidgetOpenApp,
      );
      await HomeWidget.updateWidget(
        iOSName: TodayWidgetIds.iOSKind,
        qualifiedAndroidName: TodayWidgetIds.androidProvider,
      );
    } catch (error) {
      // No widget added, no App Group yet, or a test run: nothing to do.
      debugPrint('[TODAY WIDGET] sync skipped: $error');
    } finally {
      _running = false;
    }
  }

  /// The entries to show, or null without a place to calculate for.
  @visibleForTesting
  Future<List<TodayWidgetDay>?> build() async {
    final place = await ref.read(festivalPlaceProvider.future);
    if (place == null) return null;

    final l10n = lookupAppLocalizations(
      Locale(ref.read(languageProvider).code),
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var observances = const <CalendarObservance>[];
    try {
      observances =
          (await ref.read(upcomingFestivalsProvider.future))?.observances ??
          const [];
    } catch (_) {}

    int? sign;
    try {
      sign = await ref.read(userMoonSignProvider.future);
    } catch (_) {}
    final skies = sign == null
        ? null
        : await ref
              .read(skyRepositoryProvider)
              .snapshots([
                for (var i = 0; i < days; i++)
                  DateTime(today.year, today.month, today.day + i, 12),
              ]);

    final repository = ref.read(dailyPanchangRepositoryProvider);
    final entries = <TodayWidgetDay>[];
    for (var i = 0; i < days; i++) {
      await Future<void>.delayed(Duration.zero);
      final date = DateTime(today.year, today.month, today.day + i);
      final panchang = await repository.calculate(
        date: date,
        latitude: place.latitude,
        longitude: place.longitude,
        timezone: place.timezone,
      );

      final festivals =
          observances
              .where(
                (o) =>
                    o.date.year == date.year &&
                    o.date.month == date.month &&
                    o.date.day == date.day,
              )
              .toList()
            ..sort(
              (a, b) =>
                  (b.id.isMajorFestival ? 1 : 0) -
                  (a.id.isMajorFestival ? 1 : 0),
            );

      final tithi = localizedTithi(l10n, panchang.tithi);
      final nakshatra = localizedNakshatra(l10n, panchang.nakshatra);

      String? rashifal;
      if (sign != null && skies != null) {
        final r = const RashifalEngine().daily(sign, date, skies[i]);
        rashifal =
            '${l10n.rashiName(zodiacSigns[sign])} ${starText(r.overall)}';
      }

      entries.add(
        TodayWidgetDay(
          date: date,
          title: festivals.isEmpty
              ? tithi
              : l10n.festivalName(festivals.first.id.name),
          detail: festivals.isEmpty ? nakshatra : '$tithi · $nakshatra',
          rahuKaal: panchang.rahuKaal,
          rashifal: rashifal,
        ),
      );
    }
    return entries;
  }
}
