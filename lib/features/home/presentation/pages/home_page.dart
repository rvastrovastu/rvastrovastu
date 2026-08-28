import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../astrology/presentation/providers/astrology_provider.dart';
import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../../dasha/domain/entities/dasha_birth_data.dart';
import '../../../dasha/presentation/providers/dasha_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(birthProfileProvider);
    final kundaliAsync = ref.watch(kundaliProvider);

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = DateTime.now();

    final greeting = _greeting(now.hour);
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
                          const SizedBox(height: 18),
                          _panchangCard(context),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _smallInsightCard(
                                  context,
                                  icon: Icons.auto_awesome,
                                  title: 'Muhurat',
                                  value: 'View timings',
                                  onTap: () {},
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _smallInsightCard(
                                  context,
                                  icon: Icons.access_time_rounded,
                                  title: 'Rahu Kaal',
                                  value: 'Today',
                                  onTap: () {},
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          _sectionHeader(
                            context,
                            'Your Daily Horoscope',
                            'Personalized guidance from your chart',
                          ),
                          const SizedBox(height: 12),
                          _horoscopeCard(
                            context,
                            icon: Icons.work_outline_rounded,
                            title: 'Career',
                            text:
                                'Focus on priorities, communication and steady execution today.',
                          ),
                          const SizedBox(height: 10),
                          _horoscopeCard(
                            context,
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Finance',
                            text:
                                'Review important financial decisions carefully and avoid unnecessary impulsive choices.',
                          ),
                          const SizedBox(height: 10),
                          _horoscopeCard(
                            context,
                            icon: Icons.favorite_border_rounded,
                            title: 'Relationships',
                            text:
                                'Patience and clear communication can create better understanding today.',
                          ),
                          const SizedBox(height: 30),
                          _insightCard(
                            context,
                            icon: Icons.timelapse_rounded,
                            title: 'Dasha Insight',
                            description: mahadasha == null
                                ? 'Your current planetary period will appear here.'
                                : 'Your current planetary period is ${_dashaName(mahadasha)}. Tap to explore the complete Dasha timeline.',
                            onTap: () {
                              context.push('/kundali');
                            },
                          ),
                          const SizedBox(height: 12),
                          _insightCard(
                            context,
                            icon: Icons.public_rounded,
                            title: 'Transit Insight',
                            description:
                                'See how current planetary movements interact with your birth chart.',
                            onTap: () {
                              context.push('/kundali');
                            },
                          ),
                          const SizedBox(height: 12),
                          _insightCard(
                            context,
                            icon: Icons.home_outlined,
                            title: 'Vastu Tip of the Day',
                            description:
                                'Keep the entrance area clean, welcoming and free from unnecessary clutter.',
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
                    const SizedBox(width: 8),
                    Icon(Icons.auto_awesome, size: 15, color: colors.primary),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  '$greeting,',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _profileGreeting(context),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
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
                tooltip: 'Language',
                onPressed: () {
                  context.push('/language?edit=true');
                },
                icon: const Icon(Icons.language),
              ),
              const SizedBox(height: 4),
              IconButton(
                tooltip: 'Edit birth profile',
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Cosmic Snapshot",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Your personal celestial overview',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: _metric(
                    context,
                    label: 'Rashi',
                    value: kundali.moonSign,
                    icon: Icons.nightlight_outlined,
                  ),
                ),
                Expanded(
                  child: _metric(
                    context,
                    label: 'Nakshatra',
                    value: kundali.nakshatra,
                    icon: Icons.star_outline_rounded,
                  ),
                ),
                Expanded(
                  child: _metric(
                    context,
                    label: 'Lagna',
                    value: kundali.ascendant,
                    icon: Icons.explore_outlined,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Divider(color: colors.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),

            Text(
              'CURRENT DASHA',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mahadasha == null
                  ? 'Calculating your planetary period…'
                  : _dashaName(mahadasha),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (antardasha != null) ...[
              const SizedBox(height: 3),
              Text(
                'Antardasha: ${_dashaName(antardasha)}',
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
              const SizedBox(width: 10),
              Text(
                "Today's Panchang",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _panchangMetric(context, 'Tithi', '—')),
              Expanded(child: _panchangMetric(context, 'Nakshatra', '—')),
              Expanded(child: _panchangMetric(context, 'Yoga', '—')),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Panchang calculations will use the selected birth/location timezone.',
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
                    const SizedBox(height: 5),
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
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _quickAction(
            context,
            icon: Icons.auto_awesome,
            title: 'My Kundali',
            onTap: () => context.push('/kundali'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _quickAction(
            context,
            icon: Icons.person_outline,
            title: 'Birth Profile',
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
        : 'Your Cosmic Journey';
  }

  String _greeting(int hour) {
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
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
          const SizedBox(height: 12),
          Text(
            'Unable to calculate your Kundali',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text('Please try again.', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
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
          const SizedBox(height: 12),
          Text(
            'Complete your Birth Profile',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your birth details to unlock your personalized cosmic dashboard.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: onTap, child: const Text('Set Up Profile')),
        ],
      ),
    );
  }
}
