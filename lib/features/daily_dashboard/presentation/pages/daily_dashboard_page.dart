import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/daily_dashboard.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../providers/daily_dashboard_provider.dart';

class DailyDashboardPage extends ConsumerWidget {
  const DailyDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();

    final dashboard = ref.watch(
      dailyDashboardProvider(
        DailyDashboardInput(
          date: now,
          tithi: '—',
          nakshatra: '—',
          mahadasha: '—',
          antardasha: '—',
        ),
      ),
    );

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.surface,
              scheme.surface,
              scheme.surfaceContainerLowest,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(context, now)),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _cosmicSnapshot(context, dashboard),

                    const SizedBox(height: 16),

                    _panchangCard(context, dashboard),

                    const SizedBox(height: 12),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _timingCard(
                            context,
                            icon: Icons.self_improvement,
                            title: 'Muhurat',
                            value: dashboard.muhurat.isEmpty
                                ? '—'
                                : dashboard.muhurat,
                            subtitle: 'Auspicious',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _timingCard(
                            context,
                            icon: Icons.warning_amber_rounded,
                            title: 'Rahu Kaal',
                            value: dashboard.rahuKaal.isEmpty
                                ? '—'
                                : dashboard.rahuKaal,
                            subtitle: 'Avoid important work',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    _sectionHeading(
                      context,
                      'Your Day',
                      'Personalized guidance for today',
                    ),

                    const SizedBox(height: 14),

                    _insightCard(
                      context,
                      icon: Icons.work_outline_rounded,
                      title: 'Career',
                      text: dashboard.careerGuidance,
                    ),

                    const SizedBox(height: 10),

                    _insightCard(
                      context,
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Finance',
                      text: dashboard.financeGuidance,
                    ),

                    const SizedBox(height: 10),

                    _insightCard(
                      context,
                      icon: Icons.favorite_border_rounded,
                      title: 'Relationships',
                      text: dashboard.relationshipGuidance,
                    ),

                    const SizedBox(height: 24),

                    _largeActionCard(
                      context,
                      icon: Icons.auto_graph_rounded,
                      title: 'Dasha Insight',
                      subtitle:
                          'Your current planetary period and its influence on today.',
                      detail:
                          '${dashboard.mahadasha}  •  ${dashboard.antardasha}',
                      button: 'View Dasha',
                      onTap: () => context.push('/kundali'),
                    ),

                    const SizedBox(height: 12),

                    _largeActionCard(
                      context,
                      icon: Icons.public_rounded,
                      title: 'Transit Insight',
                      subtitle:
                          'Discover planetary movements influencing your chart.',
                      detail: 'Personalized planetary analysis',
                      button: 'View Transits',
                      onTap: () {},
                    ),

                    const SizedBox(height: 12),

                    _largeActionCard(
                      context,
                      icon: Icons.home_outlined,
                      title: 'Vastu Tip of the Day',
                      subtitle:
                          'One practical Vastu action for your home or workspace.',
                      detail: 'Daily Vastu guidance',
                      button: 'Explore Vastu',
                      onTap: () {},
                    ),

                    const SizedBox(height: 26),

                    _dailyGuidance(context, dashboard),

                    const SizedBox(height: 24),

                    SizedBox(
                      height: 54,
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => context.push('/kundali'),
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: Text(context.l10n.viewCompleteKundali),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, DateTime date) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final weekday = _weekday(date.weekday);
    final month = _month(date.month);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'RV ASTRO VASTU',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Text(
                  'Good Morning, Ritesh',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$weekday • $month ${date.day}, ${date.year}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _headerButton(
            context,
            Icons.language_rounded,
            context.l10n.languagePreference,
            () => context.push('/language?edit=true'),
          ),
          _headerButton(
            context,
            Icons.person_outline_rounded,
            context.l10n.editBirthProfile,
            () => context.push('/birth-profile?edit=true'),
          ),
        ],
      ),
    );
  }

  Widget _headerButton(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(icon)),
    );
  }

  Widget _cosmicSnapshot(BuildContext context, DailyDashboard data) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _premiumCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            context,
            Icons.auto_awesome_rounded,
            "Today's Cosmic Snapshot",
          ),
          const SizedBox(height: 22),

          Row(
            children: [
              Expanded(
                child: _cosmicMetric(
                  context,
                  'Rashi',
                  data.rashi.isEmpty ? '—' : data.rashi,
                ),
              ),
              Expanded(
                child: _cosmicMetric(
                  context,
                  'Nakshatra',
                  data.nakshatra.isEmpty ? '—' : data.nakshatra,
                ),
              ),
              Expanded(
                child: _cosmicMetric(
                  context,
                  'Tithi',
                  data.tithi.isEmpty ? '—' : data.tithi,
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: 18),

          Text(
            'CURRENT DASHA',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${data.mahadasha}  •  ${data.antardasha}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panchangCard(BuildContext context, DailyDashboard data) {
    return _premiumCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(context, Icons.wb_sunny_outlined, "Today's Panchang"),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _cosmicMetric(
                  context,
                  'Tithi',
                  data.tithi.isEmpty ? '—' : data.tithi,
                ),
              ),
              Expanded(
                child: _cosmicMetric(
                  context,
                  'Nakshatra',
                  data.nakshatra.isEmpty ? '—' : data.nakshatra,
                ),
              ),
              Expanded(
                child: _cosmicMetric(
                  context,
                  'Yoga',
                  data.yoga.isEmpty ? '—' : data.yoga,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _timingInfo(
                  context,
                  'Sunrise',
                  data.sunrise.isEmpty ? '—' : data.sunrise,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _timingInfo(
                  context,
                  'Sunset',
                  data.sunset.isEmpty ? '—' : data.sunset,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _premiumCard(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }

  Widget _cardHeader(BuildContext context, IconData icon, String title) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primaryContainer,
          ),
          child: Icon(icon, size: 19, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _cosmicMetric(BuildContext context, String label, String value) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 0.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _timingInfo(BuildContext context, String title, String value) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timingCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 23),
          const SizedBox(height: 15),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(BuildContext context, String title, String subtitle) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _insightCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String text,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  text.isEmpty ? 'Personalized guidance coming soon.' : text,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _largeActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String detail,
    required String button,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24),
              const Spacer(),
              Icon(
                Icons.arrow_forward_rounded,
                size: 19,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            detail,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          TextButton(onPressed: onTap, child: Text(button)),
        ],
      ),
    );
  }

  Widget _dailyGuidance(BuildContext context, DailyDashboard data) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        color: theme.colorScheme.primaryContainer,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TODAY'S GUIDANCE",
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.overallGuidance,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _weekday(int day) {
    const values = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return values[day - 1];
  }

  String _month(int month) {
    const values = [
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

    return values[month - 1];
  }
}
