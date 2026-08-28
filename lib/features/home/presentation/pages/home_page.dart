import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../astrology/presentation/providers/astrology_provider.dart';
import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../../dasha/domain/entities/dasha_birth_data.dart';
import '../../../dasha/presentation/providers/dasha_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/l10n/l10n_extension.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(birthProfileProvider);
    final kundaliAsync = ref.watch(kundaliProvider);

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = theme.colorScheme;
    final now = DateTime.now();

    final greeting = _greeting(context, now.hour);
    final dateText = _formatDate(now);

    return Scaffold(
      backgroundColor: colors.surface,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.surface,
              colors.surfaceContainerLowest,
              colors.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _header(context, greeting: greeting, dateText: dateText),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: kundaliAsync.when(
                    loading: () => const _DashboardLoading(),
                    error: (error, stack) => _DashboardError(
                      onRetry: () => ref.invalidate(kundaliProvider),
                    ),
                    data: (kundali) {
                      if (profile == null || kundali == null) {
                        return _NoProfileCard(
                          onTap: () {
                            context.push('/birth-profile?edit=true');
                          },
                        );
                      }

                      final dashaBirthData = DashaBirthData(
                        birthDate: profile.dateOfBirth,
                        moonLongitude: kundali.moonLongitude,
                      );

                      final mahadasha = ref.watch(
                        currentDashaProvider(dashaBirthData),
                      );

                      final antardasha = ref.watch(
                        currentAntardashaProvider(dashaBirthData),
                      );

                      return Column(
                        children: [
                          _cosmicSnapshot(
                            context,
                            kundali: kundali,
                            mahadasha: mahadasha,
                            antardasha: antardasha,
                          ),
                          SizedBox(height: 18),
                          _panchangCard(context),
                          SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _smallInsightCard(
                                  context,
                                  icon: Icons.auto_awesome,
                                  title: l10n.muhurta,
                                  value: l10n.homeViewTimings,
                                  onTap: () {},
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _smallInsightCard(
                                  context,
                                  icon: Icons.access_time_rounded,
                                  title: l10n.rahu,
                                  value: l10n.homeToday,
                                  onTap: () {},
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 30),
                          _sectionHeader(
                            context,
                            l10n.homeDailyHoroscope,
                            l10n.homeDailyHoroscopeSubtitle,
                          ),
                          SizedBox(height: 12),
                          _horoscopeCard(
                            context,
                            icon: Icons.work_outline_rounded,
                            title: l10n.homeCareer,
                            text: l10n.homeCareerGuidance,
                          ),
                          SizedBox(height: 10),
                          _horoscopeCard(
                            context,
                            icon: Icons.account_balance_wallet_outlined,
                            title: l10n.homeFinance,
                            text: l10n.homeFinanceGuidance,
                          ),
                          SizedBox(height: 10),
                          _horoscopeCard(
                            context,
                            icon: Icons.favorite_border_rounded,
                            title: l10n.homeRelationships,
                            text: l10n.homeRelationshipsGuidance,
                          ),
                          SizedBox(height: 30),
                          _insightCard(
                            context,
                            icon: Icons.timelapse_rounded,
                            title: l10n.homeDashaInsight,
                            description: mahadasha == null
                                ? l10n.homeDashaInsightDescription
                                : l10n.homeDashaInsightDescriptionWithPlanet(
                                    _dashaName(mahadasha),
                                  ),
                            onTap: () {
                              context.push('/kundali');
                            },
                          ),
                          SizedBox(height: 12),
                          _insightCard(
                            context,
                            icon: Icons.public_rounded,
                            title: l10n.homeTransitInsight,
                            description:
                                context.l10n.homeTransitInsightDescription,
                            onTap: () {
                              context.push('/kundali');
                            },
                          ),
                          SizedBox(height: 12),
                          _insightCard(
                            context,
                            icon: Icons.home_outlined,
                            title: l10n.homeVastuTipOfTheDay,
                            description: l10n.homeVastuTipDescription,
                            onTap: () {},
                          ),
                          const SizedBox(height: 28),
                          _quickActions(context),
                          const SizedBox(height: 28),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context, {
    required String greeting,
    required String dateText,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'RV ASTRO VASTU',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.auto_awesome, size: 15, color: colors.primary),
                  ],
                ),
                SizedBox(height: 22),
                Text(
                  '$greeting,',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _profileGreeting(context),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  dateText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton.filledTonal(
                tooltip: context.l10n.homeLanguage,
                onPressed: () {
                  context.push('/language?edit=true');
                },
                icon: const Icon(Icons.language),
              ),
              SizedBox(height: 4),
              IconButton(
                tooltip: context.l10n.homeEditBirthProfile,
                onPressed: () {
                  context.push('/birth-profile?edit=true');
                },
                icon: const Icon(Icons.person_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cosmicSnapshot(
    BuildContext context, {
    required dynamic kundali,
    required dynamic mahadasha,
    required dynamic antardasha,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primaryContainer, colors.surfaceContainerHighest],
        ),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surface.withValues(alpha: 0.7),
                  ),
                  child: Icon(Icons.auto_awesome, color: colors.primary),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.homeCosmicSnapshot,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        context.l10n.homeCosmicSnapshotSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: _metric(
                    context,
                    label: l10n.homeRashi,
                    value: kundali.moonSign,
                    icon: Icons.nightlight_outlined,
                  ),
                ),
                Expanded(
                  child: _metric(
                    context,
                    label: l10n.homeNakshatra,
                    value: kundali.nakshatra,
                    icon: Icons.star_outline_rounded,
                  ),
                ),
                Expanded(
                  child: _metric(
                    context,
                    label: l10n.homeLagna,
                    value: kundali.ascendant,
                    icon: Icons.explore_outlined,
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),
            Divider(color: colors.outlineVariant.withValues(alpha: 0.5)),
            SizedBox(height: 16),

            Text(
              l10n.homeCurrentDasha,
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: colors.primary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              mahadasha == null
                  ? l10n.homeCalculatingPlanetaryPeriod
                  : _dashaName(mahadasha),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (antardasha != null) ...[
              SizedBox(height: 3),
              Text(
                l10n.homeAntardasha(_dashaName(antardasha)),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metric(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Icon(icon, size: 20, color: colors.primary),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _panchangCard(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 7),
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
              SizedBox(width: 10),
              Text(
                context.l10n.homeTodaysPanchang,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _panchangMetric(context, 'Tithi', '—')),
              Expanded(
                child: _panchangMetric(context, l10n.homeNakshatra, '—'),
              ),
              Expanded(child: _panchangMetric(context, 'Yoga', '—')),
            ],
          ),
          SizedBox(height: 18),
          Text(
            l10n.homePanchangTimezone,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
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
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(height: 16),
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

  Widget _sectionHeader(BuildContext context, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _horoscopeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String text,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, color: colors.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primaryContainer,
                ),
                child: Icon(icon, color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        Expanded(
          child: _quickAction(
            context,
            icon: Icons.auto_awesome,
            title: l10n.homeMyKundali,
            onTap: () => context.push('/kundali'),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _quickAction(
            context,
            icon: Icons.person_outline,
            title: l10n.homeBirthProfile,
            onTap: () => context.push('/birth-profile?edit=true'),
          ),
        ),
      ],
    );
  }

  Widget _quickAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(title),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
    );
  }

  String _profileGreeting(BuildContext context) {
    final profile = ProviderScope.containerOf(
      context,
    ).read(birthProfileProvider);

    return profile?.name.trim().isNotEmpty == true
        ? profile!.name
        : context.l10n.homeYourCosmicJourney;
  }

  String _greeting(BuildContext context, int hour) {
    final l10n = context.l10n;
    if (hour < 12) return l10n.homeGreetingMorning;
    if (hour < 17) return l10n.homeGreetingAfternoon;
    if (hour < 21) return l10n.homeGreetingEvening;
    return l10n.homeGreetingNight;
  }

  String _formatDate(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _dashaName(dynamic dasha) {
    try {
      return dasha.planet.toString();
    } catch (_) {
      return dasha.toString();
    }
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _DashboardError extends StatelessWidget {
  final VoidCallback onRetry;

  const _DashboardError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 42),
          SizedBox(height: 12),
          Text(
            context.l10n.homeUnableToCalculateKundali,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(context.l10n.homePleaseTryAgain, textAlign: TextAlign.center),
          SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: Text(context.l10n.homeRetry)),
        ],
      ),
    );
  }
}

class _NoProfileCard extends StatelessWidget {
  final VoidCallback onTap;

  const _NoProfileCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.person_add_alt_1_rounded, size: 42),
          SizedBox(height: 12),
          Text(
            context.l10n.homeCompleteBirthProfile,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            context.l10n.homeBirthProfileDescription,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 18),
          FilledButton(
            onPressed: onTap,
            child: Text(context.l10n.homeSetUpProfile),
          ),
        ],
      ),
    );
  }
}
