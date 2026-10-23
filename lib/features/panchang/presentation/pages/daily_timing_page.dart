import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/location/current_location_provider.dart';
import '../../../../core/time/app_clock_provider.dart';
import '../../domain/entities/daily_panchang.dart';
import '../../domain/entities/daily_panchang_input.dart';
import '../providers/daily_panchang_provider.dart';
import '../widgets/day_divisions_section.dart';
import '../widgets/share_panchang_button.dart';
import '../providers/panchang_location_provider.dart';

class DailyTimingPage extends ConsumerWidget {
  const DailyTimingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final now = ref.watch(appClockProvider);
    final locationAsync = ref.watch(panchangPlaceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dailyTimingTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              l10n.planYourDayWithPanchang,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.selectedLocationTiming,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            locationAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => _message(
                context,
                l10n.homeUnableToDetermineLocation,
                onRetry: () {
                  ref.read(currentLocationProvider.notifier).refresh();
                },
              ),
              data: (place) {
                if (place == null) {
                  return _message(
                    context,
                    l10n.homeCurrentLocationUnavailable,
                    onRetry: () {
                      ref.read(currentLocationProvider.notifier).refresh();
                    },
                  );
                }

                final location = place.location;
                final zone = tz.getLocation(location.timezone);
                final localNow = tz.TZDateTime.from(now.toUtc(), zone);
                final date = DateTime(
                  localNow.year,
                  localNow.month,
                  localNow.day,
                );

                final input = DailyPanchangInput(
                  date: date,
                  latitude: location.latitude,
                  longitude: location.longitude,
                  timezone: location.timezone,
                );

                final timings = ref
                    .watch(dailyPanchangProvider(input))
                    .when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stack) => _message(
                        context,
                        l10n.homeUnableToCalculatePanchang,
                        onRetry: () =>
                            ref.invalidate(dailyPanchangProvider(input)),
                      ),
                      data: (panchang) => _timingContent(
                        context,
                        panchang,
                        input,
                        localNow,
                        now,
                        location.city,
                      ),
                    );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PanchangPlaceNote(place: place),
                    timings,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _message(
    BuildContext context,
    String message, {
    required VoidCallback onRetry,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: TextStyle(color: colors.onSurface)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.tryAgain),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timingContent(
    BuildContext context,
    DailyPanchang panchang,
    DailyPanchangInput input,
    DateTime localNow,
    DateTime now,
    String? city,
  ) {
    final timezone = input.timezone;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final dateLabel =
        '${localNow.year}-${localNow.month.toString().padLeft(2, '0')}-'
        '${localNow.day.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: colors.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.wb_sunny_outlined, color: colors.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.localTimeLabel(timezone),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${panchang.tithi} · ${panchang.nakshatra}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: SharePanchangButton(
            panchang: panchang,
            input: input,
            place: city,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.auspiciousAndCautionaryPeriods,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _timingCard(
          context,
          icon: Icons.auto_awesome_rounded,
          title: l10n.auspiciousMuhuratTitle,
          value: panchang.muhurat,
          description: l10n.auspiciousMuhuratDescription,
        ),
        const SizedBox(height: 10),
        _timingCard(
          context,
          icon: Icons.access_time_rounded,
          title: l10n.rahuKaalTitle,
          value: panchang.rahuKaal,
          description: l10n.rahuKaalDescription,
        ),
        const SizedBox(height: 10),
        // Choghadiya lives in the Muhurat planner.
        DayDivisionsSection(today: input, now: now, withChoghadiya: false),
        const SizedBox(height: 20),
        Text(
          l10n.sunAndMoonTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _eventCard(
                context,
                icon: Icons.wb_twilight_rounded,
                title: l10n.sunrise,
                value: panchang.sunrise,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _eventCard(
                context,
                icon: Icons.nights_stay_rounded,
                title: l10n.sunset,
                value: panchang.sunset,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _eventCard(
          context,
          icon: Icons.nightlight_round,
          title: l10n.moonrise,
          value: panchang.moonrise,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.traditionalPanchangGuidance,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _timingCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String description,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.primary, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(height: 10),
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 5),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
