import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../../dasha/presentation/providers/dasha_provider.dart';
import '../../../dasha/presentation/widgets/dasha_summary_card.dart';
import '../../domain/entities/kundali.dart';
import '../widgets/planetary_positions_card.dart';
import '../widgets/rashi_chart_widget.dart';

class KundaliPage extends ConsumerWidget {
  final Kundali kundali;

  const KundaliPage({super.key, required this.kundali});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(birthProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Kundali'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (profile != null) ...[
                _profileCard(
                  context,
                  profile.name,
                  profile.gender,
                  profile.dateOfBirth,
                  profile.birthTime,
                  profile.location.displayName,
                  profile.location.latitude,
                  profile.location.longitude,
                  profile.location.timezone,
                ),
                const SizedBox(height: 24),
              ],

              Text(
                'Vedic Kundali',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Your personalized birth chart',
                style: theme.textTheme.bodyMedium,
              ),

              const SizedBox(height: 20),

              _coreSummary(context),

              const SizedBox(height: 24),

              if (profile != null)
                DashaSummaryCard(
                  timeline: ref.watch(
                    dashaTimelineProvider(profile.dateOfBirth),
                  ),
                  currentDasha: ref.watch(
                    currentDashaProvider(profile.dateOfBirth),
                  ),
                ),

              const SizedBox(height: 28),

              _sectionTitle(context, 'Rashi Chart'),

              const SizedBox(height: 12),

              if (kundali.rashiChart != null)
                RashiChartWidget(chart: kundali.rashiChart!),

              const SizedBox(height: 28),

              if (kundali.planets.isNotEmpty)
                PlanetaryPositionsCard(planets: kundali.planets),

              const SizedBox(height: 28),

              _sectionTitle(context, 'Astrology Highlights'),

              const SizedBox(height: 12),

              _highlightCard(
                context,
                icon: Icons.auto_awesome,
                title: 'Ascendant',
                value:
                    '${kundali.ascendant} ${kundali.ascendantDegree.toStringAsFixed(2)}°',
              ),

              _highlightCard(
                context,
                icon: Icons.nightlight_round,
                title: 'Moon Sign',
                value: kundali.moonSign,
              ),

              _highlightCard(
                context,
                icon: Icons.wb_sunny_outlined,
                title: 'Sun Sign',
                value: kundali.sunSign,
              ),

              _highlightCard(
                context,
                icon: Icons.star_outline,
                title: 'Nakshatra',
                value: '${kundali.nakshatra} • Pada ${kundali.nakshatraPada}',
              ),

              const SizedBox(height: 28),

              _sectionTitle(context, 'Coming Next'),

              const SizedBox(height: 12),

              _comingSoonCard(
                context,
                Icons.account_tree_outlined,
                'Navamsa D9',
                'Detailed divisional chart',
              ),

              _comingSoonCard(
                context,
                Icons.timeline_outlined,
                'Vimshottari Dasha',
                'Mahadasha and Antardasha timeline',
              ),

              _comingSoonCard(
                context,
                Icons.favorite_outline,
                'Yogas & Doshas',
                'Important combinations in your chart',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileCard(
    BuildContext context,
    String name,
    String gender,
    DateTime dateOfBirth,
    String birthTime,
    String location,
    double latitude,
    double longitude,
    String timezone,
  ) {
    final theme = Theme.of(context);

    final dob =
        '${dateOfBirth.month.toString().padLeft(2, '0')}/'
        '${dateOfBirth.day.toString().padLeft(2, '0')}/'
        '${dateOfBirth.year}';

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(gender),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 28),

            _detailRow(Icons.calendar_today_outlined, 'Date of Birth', dob),

            _detailRow(Icons.access_time_outlined, 'Birth Time', birthTime),

            _detailRow(Icons.location_on_outlined, 'Birth Place', location),

            _detailRow(
              Icons.public,
              'Coordinates',
              '${latitude.toStringAsFixed(4)}, '
                  '${longitude.toStringAsFixed(4)}',
            ),

            _detailRow(Icons.schedule_outlined, 'Timezone', timezone),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 12),
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _coreSummary(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: _summaryItem('Lagna', kundali.ascendant)),
            Expanded(child: _summaryItem('Moon', kundali.moonSign)),
            Expanded(child: _summaryItem('Nakshatra', kundali.nakshatra)),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    );
  }

  Widget _highlightCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon, size: 20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _comingSoonCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon, size: 20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
