import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/location/current_location_provider.dart';
import '../../../panchang/domain/entities/daily_panchang.dart';
import '../../../panchang/domain/entities/daily_panchang_input.dart';
import '../../../panchang/presentation/providers/daily_panchang_provider.dart';
import '../../../panchang/presentation/utils/panchang_localization.dart';

class PanchangSection extends ConsumerWidget {
  final DateTime now;

  const PanchangSection({super.key, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;

    final currentLocationAsync = ref.watch(currentLocationProvider);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.homeTodaysPanchang,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
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

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _panchangMetric(
                              context,
                              l10n.homeTithi,
                              localizedTithi(l10n, panchang.tithi),
                            ),
                          ),
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
                      _timingCards(context, panchang),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${l10n.homePanchangTimezone}: ${location.timezone}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
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

  Widget _timingCards(BuildContext context, DailyPanchang panchang) {
    return Row(
      children: [
        Expanded(
          child: _smallInsightCard(
            context,
            icon: Icons.auto_awesome,
            title: context.l10n.muhurta,
            value: panchang.muhurat,
            onTap: () {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _smallInsightCard(
            context,
            icon: Icons.access_time_rounded,
            title: context.l10n.rahu,
            value: panchang.rahuKaal,
            onTap: () {},
          ),
        ),
      ],
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

  Widget _smallInsightCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
