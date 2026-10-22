import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/celestial_background.dart';
import '../../domain/legal_links.dart';
import '../../domain/membership.dart';
import '../providers/membership_provider.dart';
import '../widgets/premium_gate.dart';

/// Premium plans, one-time add-ons and restore. [highlight] is the feature
/// that brought the user here, if any.
class PaywallPage extends ConsumerStatefulWidget {
  final PremiumFeature? highlight;

  const PaywallPage({super.key, this.highlight});

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage> {
  PlanPeriod _selected = PlanPeriod.yearly;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) _toast(context.l10n.premiumFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _report(PurchaseOutcome outcome) {
    if (!mounted) return;
    final l10n = context.l10n;
    switch (outcome) {
      case PurchaseOutcome.purchased:
        _toast(l10n.premiumWelcome);
      case PurchaseOutcome.pending:
        _toast(l10n.premiumPending);
      case PurchaseOutcome.failed:
        _toast(l10n.premiumFailed);
      case PurchaseOutcome.cancelled:
        break;
    }
  }

  Future<void> _buyPlan(List<PlanOffer> plans) => _run(() async {
    final plan = plans.firstWhere(
      (p) => p.period == _selected,
      orElse: () => plans.first,
    );
    _report(await ref.read(membershipProvider.notifier).buyPlan(plan));
  });

  Future<void> _buyAddOn(AddOnOffer offer) => _run(() async {
    _report(await ref.read(membershipProvider.notifier).buyAddOn(offer));
  });

  Future<void> _restore() => _run(() async {
    final restored = await ref.read(membershipProvider.notifier).restore();
    if (!mounted) return;
    _toast(
      restored
          ? context.l10n.premiumRestored
          : context.l10n.premiumNothingToRestore,
    );
  });

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final service = ref.watch(purchasesServiceProvider);
    final membership = ref.watch(membershipProvider).value;
    final offers = ref.watch(storeOffersProvider);
    final plans = offers.value?.$1 ?? const <PlanOffer>[];
    final addOns = offers.value?.$2 ?? const <AddOnOffer>[];
    final saving = yearlySavingPercent(plans);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.premiumTitle)),
      body: CelestialBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const Center(
              child: Icon(
                Icons.workspace_premium_rounded,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.premiumHeadline,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.premiumSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (widget.highlight case final feature?) ...[
              const SizedBox(height: 14),
              _Banner(
                icon: premiumFeatureIcon(feature),
                text: l10n.premiumFeatureLocked(
                  l10n.premiumFeatureName(feature.name),
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (membership?.premium ?? false)
              _ActiveCard(membership: membership!, onManage: _open)
            else ...[
              for (final feature in _benefits) _BenefitRow(feature: feature),
              const SizedBox(height: 18),
              if (!service.isAvailable)
                _Banner(
                  icon: Icons.info_outline_rounded,
                  text: l10n.premiumUnavailable,
                )
              else if (offers.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (plans.isEmpty)
                _Banner(
                  icon: Icons.info_outline_rounded,
                  text: l10n.premiumUnavailable,
                )
              else ...[
                for (final plan in _ordered(plans))
                  _PlanCard(
                    plan: plan,
                    selected: plan.period == _selected,
                    saving: plan.period == PlanPeriod.yearly ? saving : null,
                    onTap: () => setState(() => _selected = plan.period),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : () => _buyPlan(plans),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_ctaLabel(context, plans)),
                ),
              ],
            ],
            if (service.isAvailable) ...[
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _restore,
                  child: Text(l10n.premiumRestore),
                ),
              ),
            ],
            if (addOns.isNotEmpty && !(membership?.premium ?? false)) ...[
              const SizedBox(height: 18),
              Text(l10n.premiumAddOnsTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(l10n.premiumAddOnsSubtitle, style: theme.textTheme.bodySmall),
              const SizedBox(height: 10),
              for (final offer in addOns)
                _AddOnTile(
                  offer: offer,
                  owned: membership?.owns(offer.addOn) ?? false,
                  onBuy: _busy ? null : () => _buyAddOn(offer),
                ),
            ],
            const SizedBox(height: 20),
            Text(
              l10n.premiumLegal,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: () => _open(LegalLinks.terms),
                  child: Text(l10n.premiumTerms),
                ),
                if (LegalLinks.privacy.isNotEmpty)
                  TextButton(
                    onPressed: () => _open(LegalLinks.privacy),
                    child: Text(l10n.premiumPrivacy),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _ctaLabel(BuildContext context, List<PlanOffer> plans) {
    final selected = plans.where((p) => p.period == _selected).firstOrNull;
    final trial = selected?.trialDays;
    return trial == null
        ? context.l10n.premiumContinue
        : context.l10n.premiumStartTrial(trial.toString());
  }

  static const _benefits = [
    PremiumFeature.navamsa,
    PremiumFeature.doshaDetails,
    PremiumFeature.transits,
    PremiumFeature.dashaTimeline,
    PremiumFeature.remedies,
    PremiumFeature.vastuRemedies,
    PremiumFeature.pujaVidhi,
    PremiumFeature.muhuratPlanner,
    PremiumFeature.compatibilityDetails,
    PremiumFeature.nameNumerology,
    PremiumFeature.unlimitedProfiles,
    PremiumFeature.kundliPdf,
  ];

  /// Yearly first: it is the better deal and the default choice.
  static List<PlanOffer> _ordered(List<PlanOffer> plans) =>
      [...plans]..sort((a, b) => b.period.index.compareTo(a.period.index));
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Banner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _BenefitRow extends StatelessWidget {
  final PremiumFeature feature;

  const _BenefitRow({required this.feature});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(premiumFeatureIcon(feature), color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.premiumFeatureName(feature.name),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  l10n.premiumFeatureDescription(feature.name),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanOffer plan;
  final bool selected;
  final int? saving;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.saving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? AppColors.surfaceLight : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.outline,
            width: selected ? 1.6 : 0.8,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.premiumPlanName(plan.period.name),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${plan.priceLabel} '
                        '${l10n.premiumPerPeriod(plan.period.name)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (plan.trialDays case final days?)
                        Text(
                          l10n.premiumTrial(days.toString()),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                    ],
                  ),
                ),
                if (saving case final percent?)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.premiumSave(percent.toString()),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddOnTile extends StatelessWidget {
  final AddOnOffer offer;
  final bool owned;
  final VoidCallback? onBuy;

  const _AddOnTile({
    required this.offer,
    required this.owned,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              premiumFeatureIcon(offer.addOn.feature),
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.premiumFeatureName(offer.addOn.feature.name),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    l10n.premiumAddOnDescription(offer.addOn.name),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            owned
                ? Text(l10n.premiumOwned, style: theme.textTheme.labelLarge)
                : OutlinedButton(
                    onPressed: onBuy,
                    child: Text(offer.priceLabel),
                  ),
          ],
        ),
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  final MembershipState membership;
  final Future<void> Function(String url) onManage;

  const _ActiveCard({required this.membership, required this.onManage});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final until = membership.premiumUntil;
    final date = until == null
        ? null
        : DateFormat.yMMMd(
            Localizations.localeOf(context).toString(),
          ).format(until.toLocal());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_rounded, color: AppColors.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.premiumActive,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (date != null) ...[
              const SizedBox(height: 6),
              Text(
                membership.willRenew
                    ? l10n.premiumRenewsOn(date)
                    : l10n.premiumEndsOn(date),
              ),
            ],
            if (membership.managementUrl case final url?) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => onManage(url),
                child: Text(l10n.premiumManage),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
