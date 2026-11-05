import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/share/share_card.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../your_day/domain/day_strength.dart';
import '../daily_loop_providers.dart';
import 'loop_card.dart';

/// "Your family today": everyone saved on this device with their day from
/// their own birth star, and one tap to send it to the family on WhatsApp
/// with an invite to the app.
class FamilyDayCard extends ConsumerWidget {
  const FamilyDayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyDaysProvider).value;
    if (family == null || family.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);

    return LoopCard(
      icon: Icons.diversity_3_rounded,
      title: l10n.familyTitle,
      subtitle: l10n.familySubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final member in family)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _verdictColor(member.strength.verdict),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.profile.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          l10n.horoscopeHeadline(member.headlineKey),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (family.length < 2)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.familyEmpty,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      GoRouter.maybeOf(context)?.push('/saved-profiles'),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text(l10n.familyAdd),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Builder(
                  builder: (buttonContext) => FilledButton.icon(
                    onPressed: () => _share(
                      buttonContext,
                      familyShareText(l10n, family, DateTime.now()),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: Text(l10n.familyShare),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// WhatsApp when it's installed, otherwise the system share sheet.
  static Future<void> _share(BuildContext context, String text) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final whatsapp = Uri.parse(
      'whatsapp://send?text=${Uri.encodeComponent(text)}',
    );
    try {
      if (await launchUrl(whatsapp, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      // Fall through to the share sheet.
    }
    await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
  }
}

/// The message sent to the family: one line per person, then the invite.
String familyShareText(
  AppLocalizations l10n,
  List<FamilyDay> family,
  DateTime date,
) {
  final day = DateFormat.MMMd(l10n.localeName).format(date);
  return [
    l10n.familyShareHeader(day),
    for (final member in family)
      l10n.familyShareLine(
        member.profile.name,
        l10n.horoscopeHeadline(member.headlineKey),
      ),
    '',
    l10n.familyShareInvite(appShareUrl),
  ].join('\n');
}

Color _verdictColor(DayVerdict verdict) => switch (verdict) {
  DayVerdict.good => AppColors.success,
  DayVerdict.mixed => AppColors.accent,
  DayVerdict.caution => AppColors.error,
};
