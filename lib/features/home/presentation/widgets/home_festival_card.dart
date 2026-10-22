import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../festivals/guide/presentation/puja_guide_route.dart';
import '../../../festivals/presentation/providers/festival_calendar_provider.dart';
import '../../../festivals/presentation/widgets/observance_tile.dart';

/// The next major festival, linking to its puja guide. Renders nothing
/// while loading or if dates can't be calculated, so Home never waits on it.
class HomeFestivalCard extends ConsumerWidget {
  const HomeFestivalCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendar = ref.watch(upcomingFestivalsProvider).value;
    if (calendar == null) return const SizedBox.shrink();

    final today = ref.watch(festivalTodayProvider);
    final upcoming = calendar.upcoming(today, majorOnly: true);
    if (upcoming.isEmpty) return const SizedBox.shrink();

    final next = upcoming.first;
    return NextFestivalCard(
      observance: next,
      today: today,
      onTap: () => context.push(pujaGuidePath(next.id, next.date)),
    );
  }
}
