import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RV Astro Vastu'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Astrology Dashboard',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Your personalized cosmic journey',
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
                                'My Kundali',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'View your birth chart, planets, '
                                'houses, Nakshatra and Dasha',
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
                      title: 'Daily Horoscope',
                      subtitle: 'Today',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _featureCard(
                      context,
                      icon: Icons.calendar_month_outlined,
                      title: 'Panchang',
                      subtitle: 'Today',
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
                      title: 'Transits',
                      subtitle: 'Planetary',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _featureCard(
                      context,
                      icon: Icons.favorite_outline,
                      title: 'Marriage',
                      subtitle: 'Analysis',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              Text(
                'Your Kundali Snapshot',
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
                      title: Text('Lagna'),
                      trailing: Text('View Kundali'),
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.nightlight_outlined),
                      title: Text('Rashi'),
                      trailing: Text('View Kundali'),
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.star_outline),
                      title: Text('Nakshatra'),
                      trailing: Text('View Kundali'),
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
                  label: const Text('View Complete Kundali'),
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
  }) {
    return Card(
      child: InkWell(
        onTap: () {
          if (title == 'Daily Horoscope') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Daily Horoscope coming next')),
            );
          } else if (title == 'Panchang') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Panchang coming next')),
            );
          } else if (title == 'Transits') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Planetary Transits coming next')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Marriage analysis coming next')),
            );
          }
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
