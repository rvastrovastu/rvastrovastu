import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extension.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.appName), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.yourAstrologyDashboard,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                context.l10n.yourPersonalizedCosmicJourney,
                style: Theme.of(context).textTheme.bodyLarge,
              ),

              const SizedBox(height: 24),

              // KUNDALI
              Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    context.push('/kundali');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),

                        const SizedBox(width: 16),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.myKundali,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${context.l10n.viewYourBirthChart}, '
                                context.l10n.viewYourBirthChart,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),

                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _featureCard(
                      context,
                      icon: Icons.wb_sunny_outlined,
                      title: context.l10n.dailyHoroscope,
                      subtitle: context.l10n.today,
                      comingNext: context.l10n.dailyHoroscopeComingNext,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _featureCard(
                      context,
                      icon: Icons.calendar_month_outlined,
                      title: context.l10n.panchang,
                      subtitle: context.l10n.today,
                      comingNext: context.l10n.panchangComingNext,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _featureCard(
                      context,
                      icon: Icons.public,
                      title: context.l10n.transits,
                      subtitle: context.l10n.planetary,
                      comingNext: context.l10n.planetaryTransitsComingNext,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _featureCard(
                      context,
                      icon: Icons.favorite_outline,
                      title: context.l10n.marriage,
                      subtitle: context.l10n.analysis,
                      comingNext: context.l10n.marriageAnalysisComingNext,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              Text(
                context.l10n.yourKundaliSnapshot,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 12),

              Card(
                child: Column(
                  children: const [
                    ListTile(
                      leading: Icon(Icons.explore_outlined),
                      title: Text(context.l10n.lagna),
                      trailing: Text(context.l10n.viewKundali),
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.nightlight_outlined),
                      title: Text(context.l10n.rashi),
                      trailing: Text(context.l10n.viewKundali),
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.star_outline),
                      title: Text(context.l10n.nakshatra),
                      trailing: Text(context.l10n.viewKundali),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: () {
                    context.push('/kundali');
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(context.l10n.viewCompleteKundali),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String comingNext,
  }) {
    return Card(
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(comingNext)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
