import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../membership/domain/legal_links.dart';

/// "Cancellations & refunds" link that opens the policy in a sheet. Shown
/// before paying and on each paid booking, so the terms are clear before
/// money changes hands.
class RefundPolicyLink extends StatelessWidget {
  const RefundPolicyLink({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const ValueKey('refundPolicyLink'),
      onPressed: () => showRefundPolicy(context),
      icon: const Icon(Icons.policy_outlined, size: 18),
      label: Text(context.l10n.consultRefundTitle),
    );
  }
}

/// The consultation cancellation and refund rules, with a link to the full
/// terms on the website.
Future<void> showRefundPolicy(BuildContext context) {
  final l10n = context.l10n;
  final theme = Theme.of(context);

  Widget point(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    ),
  );

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.consultRefundTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            point(Icons.event_busy_outlined, l10n.consultRefundCancel),
            point(Icons.support_agent_outlined, l10n.consultRefundOurSide),
            point(Icons.timer_outlined, l10n.consultRefundNoShow),
            point(Icons.undo_rounded, l10n.consultRefundHow),
            if (LegalLinks.terms.isNotEmpty)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse('${LegalLinks.terms}#consultations'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(l10n.consultRefundTerms),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
