import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/l10n/l10n_extension.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../domain/vastu_analysis.dart';
import '../vastu_layout_providers.dart';

/// Saved properties with their Vastu score, and a button to add one.
class VastuPlansPage extends ConsumerWidget {
  const VastuPlansPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final layouts = ref.watch(vastuLayoutsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vastuPlansTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/vastu/plans/new'),
        icon: const Icon(Icons.add_home_outlined),
        label: Text(l10n.vastuPlansAdd),
      ),
      body: layouts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.vastuPlansEmpty)),
        data: (all) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Text(l10n.vastuPlansSubtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            if (all.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.home_work_outlined,
                        size: 40,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(l10n.vastuPlansEmpty, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            for (final layout in all)
              Builder(
                builder: (context) {
                  final analysis = VastuAnalysis.of(layout);
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.surfaceLight,
                        child: Text(
                          '${analysis.score}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(layout.name),
                      subtitle: Text(
                        l10n.vastuDoshaCounts(
                          analysis.majorCount,
                          analysis.doshas.length - analysis.majorCount,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/vastu/plans/${layout.id}'),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
