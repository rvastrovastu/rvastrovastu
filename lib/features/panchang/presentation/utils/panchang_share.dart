import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/daily_panchang.dart';
import '../../domain/entities/day_divisions.dart';
import 'panchang_localization.dart';

/// Plain-text summary of a day's Panchang, ready for WhatsApp and the like.
///
/// [formatTime] turns a UTC instant into a local clock label; [divisions]
/// adds Yamaganda, Gulika and the favourable daytime Choghadiya.
String buildPanchangShareText({
  required AppLocalizations l10n,
  required DailyPanchang panchang,
  required String dateLabel,
  required String Function(DateTime utc) formatTime,
  String? place,
  DayDivisions? divisions,
}) {
  bool known(String v) => v.trim().isNotEmpty && v != '—';
  String range<T>(TimedPeriod<T> p) =>
      '${formatTime(p.start)} – ${formatTime(p.end)}';

  final lines = <String>[
    '🪔 ${l10n.panchangShareHeading(dateLabel)}',
    if (place != null && place.trim().isNotEmpty) '📍 ${place.trim()}',
    '',
    if (known(panchang.tithi))
      '${l10n.tithi}: ${localizedTithi(l10n, panchang.tithi)}',
    if (known(panchang.nakshatra))
      '${l10n.nakshatra}: ${localizedNakshatra(l10n, panchang.nakshatra)}',
    if (known(panchang.yoga))
      '${l10n.yoga}: ${localizedYoga(l10n, panchang.yoga)}',
    '☀️ ${l10n.sunrise} ${panchang.sunrise} · ${l10n.sunset} ${panchang.sunset}',
    '',
    if (known(panchang.muhurat))
      '✅ ${l10n.auspiciousMuhuratTitle}: ${panchang.muhurat}',
    if (known(panchang.rahuKaal))
      '⚠️ ${l10n.rahuKaalTitle}: ${panchang.rahuKaal}',
    if (divisions != null) ...[
      '⚠️ ${l10n.yamagandaTitle}: ${range(divisions.yamaganda)}',
      '⚠️ ${l10n.gulikaTitle}: ${range(divisions.gulika)}',
      '',
      '${l10n.panchangShareGoodChoghadiya}:',
      for (final p in divisions.dayChoghadiya)
        if (p.value.quality == ChoghadiyaQuality.good)
          '• ${l10n.choghadiyaName(p.value.name)} ${range(p)}',
    ],
    '',
    l10n.panchangShareFooter,
  ];

  // Collapse blank lines left behind by skipped sections.
  final out = <String>[];
  for (final line in lines) {
    if (line.isEmpty && (out.isEmpty || out.last.isEmpty)) continue;
    out.add(line);
  }
  return out.join('\n').trim();
}

/// Formats a UTC instant as a clock time at [timezone], in the app's locale.
String Function(DateTime) localTimeFormatter(
  BuildContext context,
  String timezone,
) {
  final location = tz.getLocation(timezone);
  final material = MaterialLocalizations.of(context);
  return (utc) => material.formatTimeOfDay(
    TimeOfDay.fromDateTime(tz.TZDateTime.from(utc, location)),
  );
}

/// Opens the system share sheet with [text].
Future<void> shareText(
  BuildContext context, {
  required String text,
  required String subject,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null || !box.hasSize
      ? null
      : box.localToGlobal(Offset.zero) & box.size;
  await SharePlus.instance.share(
    ShareParams(text: text, subject: subject, sharePositionOrigin: origin),
  );
}
