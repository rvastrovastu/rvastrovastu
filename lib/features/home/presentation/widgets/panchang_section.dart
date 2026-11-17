import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/location/current_location.dart';
import '../../../../core/location/current_location_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/moon_phase_disc.dart';
import '../../../panchang/domain/entities/daily_panchang_input.dart';
import '../../../panchang/presentation/providers/daily_panchang_provider.dart';
import '../../../panchang/presentation/providers/panchang_location_provider.dart';
import '../../../panchang/presentation/utils/panchang_localization.dart';
import '../../../panchang/presentation/widgets/share_panchang_button.dart';

class PanchangSection extends ConsumerWidget {
  final DateTime now;

  const PanchangSection({super.key, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;

    // The phone's location, or the birth-profile city when it isn't
    // available, so Today never shows an error or waits on GPS.
    final placeAsync = ref.watch(panchangPlaceProvider);
    final AsyncValue<CurrentLocation?> currentLocationAsync = placeAsync
        .whenData((place) => place?.location);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceLight, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.outline, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.homeTodaysPanchang,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (placeAsync.value case final place?) ...[
            const SizedBox(height: 6),
            PanchangPlaceNote(place: place),
          ],
          const SizedBox(height: 14),
          currentLocationAsync.when(
            loading: () {
              debugPrint('[PANCHANG][HOME] CURRENT LOCATION LOADING');

              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            },
            error: (error, stack) {
              debugPrint('[PANCHANG][HOME] CURRENT LOCATION ERROR: $error');

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homeUnableToDetermineLocation,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.error,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.homeEnableLocationAccess,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(currentLocationProvider.notifier).refresh();
                    },
                    icon: const Icon(Icons.my_location_rounded),
                    label: Text(l10n.homeUseCurrentLocation),
                  ),
                ],
              );
            },
            data: (location) {
              if (location == null) {
                debugPrint('[PANCHANG][HOME] CURRENT LOCATION UNAVAILABLE');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeCurrentLocationUnavailable,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.read(currentLocationProvider.notifier).refresh();
                      },
                      icon: const Icon(Icons.my_location_rounded),
                      label: Text(l10n.homeUseCurrentLocation),
                    ),
                  ],
                );
              }

              final timezoneLocation = tz.getLocation(location.timezone);
              final localNow = tz.TZDateTime.from(
                now.toUtc(),
                timezoneLocation,
              );
              final today = DateTime(
                localNow.year,
                localNow.month,
                localNow.day,
              );

              debugPrint(
                '[PANCHANG][HOME] LOCATION LOCAL DATE '
                'deviceNow=$now '
                'localNow=$localNow '
                'date=$today '
                'tz=${location.timezone}',
              );

              final input = DailyPanchangInput(
                date: today,
                latitude: location.latitude,
                longitude: location.longitude,
                timezone: location.timezone,
              );

              debugPrint(
                '[PANCHANG][HOME] CURRENT LOCATION '
                'lat=${location.latitude} '
                'lng=${location.longitude} '
                'tz=${location.timezone}',
              );

              final panchangAsync = ref.watch(dailyPanchangProvider(input));

              return panchangAsync.when(
                loading: () {
                  debugPrint(
                    '[PANCHANG][HOME] LOADING '
                    'date=$today '
                    'lat=${input.latitude} '
                    'lng=${input.longitude} '
                    'tz=${input.timezone}',
                  );

                  return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                error: (error, stack) {
                  debugPrint('[PANCHANG][HOME] ERROR: $error');
                  debugPrint('[PANCHANG][HOME] STACK: $stack');

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.homeUnableToCalculatePanchang,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.error,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        error.toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
                data: (panchang) {
                  debugPrint(
                    '[PANCHANG][HOME] SUCCESS '
                    'date=${panchang.date} '
                    'tithi=${panchang.tithi} '
                    'nakshatra=${panchang.nakshatra} '
                    'yoga=${panchang.yoga} '
                    'sunrise=${panchang.sunrise} '
                    'sunset=${panchang.sunset} '
                    'moonrise=${panchang.moonrise} '
                    'rahuKaal=${panchang.rahuKaal} '
                    'muhurat=${panchang.muhurat}',
                  );

                  final tithiIndex = tithiIndexFromName(panchang.tithi);

                  return Column(
                    children: [
                      _TithiHero(
                        tithiIndex: tithiIndex,
                        tithiLabel: localizedTithi(l10n, panchang.tithi),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _panchangMetric(
                              context,
                              l10n.homeNakshatra,
                              localizedNakshatra(l10n, panchang.nakshatra),
                            ),
                          ),
                          Expanded(
                            child: _panchangMetric(
                              context,
                              l10n.homeYoga,
                              localizedYoga(l10n, panchang.yoga),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _panchangMetric(
                              context,
                              l10n.homeSunrise,
                              panchang.sunrise,
                            ),
                          ),
                          Expanded(
                            child: _panchangMetric(
                              context,
                              l10n.homeSunset,
                              panchang.sunset,
                            ),
                          ),
                          Expanded(
                            child: _panchangMetric(
                              context,
                              l10n.homeMoonrise,
                              panchang.moonrise,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${l10n.homePanchangTimezone}: '
                              '${location.timezone}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          SharePanchangButton(
                            panchang: panchang,
                            input: input,
                            place: location.city,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _panchangMetric(BuildContext context, String label, String value) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

}

/// The memorable moment on Home: today's Moon drawn at its real phase, with
/// the tithi set large in the display serif.
class _TithiHero extends StatelessWidget {
  final int? tithiIndex;
  final String tithiLabel;

  const _TithiHero({required this.tithiIndex, required this.tithiLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final index = tithiIndex;

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    Widget moon = index == null
        ? const SizedBox.square(dimension: 92)
        : MoonPhaseDisc(tithiIndex: index, size: 92);

    if (!reduceMotion && index != null) {
      moon = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.scale(scale: 0.85 + 0.15 * value, child: child),
        ),
        child: moon,
      );
    }

    return Row(
      children: [
        moon,
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tithiLabel,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              if (index != null) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.homeMoonPhase(
                    l10n.festivalPaksha(index < 15 ? 'shukla' : 'krishna'),
                    _illuminationPercent(index),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.accent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static int _illuminationPercent(int tithiIndex) {
    final elongation = (tithiIndex + 0.5) * 12 * math.pi / 180;
    return ((1 - math.cos(elongation)) / 2 * 100).round();
  }
}
