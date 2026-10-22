import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/membership.dart';
import '../providers/membership_provider.dart';

IconData premiumFeatureIcon(PremiumFeature feature) => switch (feature) {
  PremiumFeature.navamsa => Icons.grid_view_rounded,
  PremiumFeature.yogas => Icons.auto_awesome,
  PremiumFeature.doshaDetails => Icons.shield_moon_outlined,
  PremiumFeature.transits => Icons.public_rounded,
  PremiumFeature.dashaTimeline => Icons.timelapse_rounded,
  PremiumFeature.remedies => Icons.diamond_outlined,
  PremiumFeature.muhuratPlanner => Icons.event_available_rounded,
  PremiumFeature.compatibilityDetails => Icons.favorite_outline,
  PremiumFeature.nameNumerology => Icons.abc_rounded,
  PremiumFeature.unlimitedProfiles => Icons.people_outline,
  PremiumFeature.kundliPdf => Icons.picture_as_pdf_outlined,
  PremiumFeature.compatibilityPdf => Icons.picture_as_pdf_outlined,
  PremiumFeature.vastuRemedies => Icons.home_work_outlined,
  PremiumFeature.pujaVidhi => Icons.local_fire_department_outlined,
  PremiumFeature.vargaCharts => Icons.grid_on_rounded,
  PremiumFeature.aiAstrologer => Icons.forum_outlined,
};

/// Opens the paywall, highlighting [feature].
Future<void> openPaywall(BuildContext context, [PremiumFeature? feature]) =>
    context.push(
      feature == null ? '/premium' : '/premium?feature=${feature.name}',
    );

/// Shows [child] to members, and a locked card that leads to the paywall
/// to everyone else.
class PremiumGate extends ConsumerWidget {
  final PremiumFeature feature;
  final Widget child;

  const PremiumGate({super.key, required this.feature, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(membershipProvider);
    if (membership.value?.canUse(feature) ?? false) return child;
    if (membership.isLoading && !membership.hasValue) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return PremiumLockedCard(feature: feature);
  }
}

class PremiumLockedCard extends StatelessWidget {
  final PremiumFeature feature;

  const PremiumLockedCard({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.primary, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(premiumFeatureIcon(feature), color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.premiumFeatureName(feature.name),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const PremiumBadge(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.premiumFeatureDescription(feature.name),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => openPaywall(context, feature),
              icon: const Icon(Icons.lock_open_rounded),
              label: Text(l10n.premiumUnlock),
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      context.l10n.premiumBadge,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.onPrimary,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    ),
  );
}

/// One-line "details are Premium" row with an unlock button, for cards that
/// keep a free summary.
class PremiumUnlockRow extends StatelessWidget {
  final PremiumFeature feature;

  const PremiumUnlockRow({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.premiumUnlockDetails,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        TextButton(
          onPressed: () => openPaywall(context, feature),
          child: Text(l10n.premiumUnlockShort),
        ),
      ],
    );
  }
}

/// Full-screen body for a page that is entirely Premium.
class PremiumLockedBody extends StatelessWidget {
  final PremiumFeature feature;

  const PremiumLockedBody({super.key, required this.feature});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [PremiumLockedCard(feature: feature)],
  );
}
