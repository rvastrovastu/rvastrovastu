import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../membership/domain/legal_links.dart';

/// Support address shown in the menu.
const supportEmail = 'rvastrovastu@gmail.com';

/// The three-bar menu: every feature in one place, grouped, plus the
/// account, settings and help links.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // Rebuild on sign-in and sign-out.
    ref.watch(authUserIdProvider);
    final auth = ref.watch(authServiceProvider);

    void open(String route, {bool tab = false}) {
      final router = GoRouter.of(context);
      Scaffold.of(context).closeDrawer();
      if (tab) {
        router.go(route);
      } else {
        router.push(route);
      }
    }

    Widget item(
      IconData icon,
      String title,
      String route, {
      bool tab = false,
    }) => ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(title, style: theme.textTheme.bodyLarge),
      onTap: () => open(route, tab: tab),
    );

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );

    return Drawer(
      backgroundColor: AppColors.background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(
            appName: l10n.appName,
            tagline: l10n.authTagline,
          ),
          if (auth.isAvailable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _AccountCard(
                signedInEmail: auth.isAnonymous ? null : auth.email,
                onTap: () => open('/account'),
              ),
            ),
          section(l10n.menuSectionDaily),
          item(Icons.wb_twilight_outlined, l10n.navToday, '/home', tab: true),
          item(Icons.wb_sunny_outlined, l10n.rashifalTitle, '/rashifal'),
          item(
            Icons.event_note_outlined,
            l10n.festivalCalendarTitle,
            '/festivals',
            tab: true,
          ),
          item(Icons.calendar_month, l10n.muhuratPlannerTitle, '/muhurat'),
          item(Icons.public_rounded, l10n.gocharTitle, '/gochar'),
          item(Icons.forum_outlined, l10n.aiTitle, '/ask'),
          item(
            Icons.support_agent_rounded,
            l10n.consultTitle,
            '/consult',
            tab: true,
          ),
          section(l10n.menuSectionCharts),
          item(Icons.auto_awesome, l10n.homeMyKundali, '/kundali', tab: true),
          item(Icons.shield_moon_outlined, l10n.doshaCheckTitle, '/dosha'),
          item(Icons.diamond_outlined, l10n.remediesTitle, '/remedies'),
          item(Icons.favorite_outline, l10n.compatTitle, '/compatibility'),
          item(Icons.cake_outlined, l10n.varshphalTitle, '/varshphal'),
          item(Icons.grid_view_rounded, l10n.strengthTitle, '/strength'),
          item(Icons.blur_circular_rounded, l10n.kpTitle, '/kp'),
          item(Icons.pin_outlined, l10n.numerologyTitle, '/numerology'),
          item(Icons.child_care_rounded, l10n.babyNamesTitle, '/baby-names'),
          section(l10n.menuSectionVastu),
          item(Icons.home_work_outlined, l10n.vastu, '/vastu', tab: true),
          item(
            Icons.explore_outlined,
            l10n.vastuCompassTitle,
            '/vastu/compass',
            tab: true,
          ),
          item(
            Icons.architecture_rounded,
            l10n.vastuPlansTitle,
            '/vastu/plans',
            tab: true,
          ),
          section(l10n.menuSectionYou),
          item(Icons.people_outline, l10n.homeBirthProfile, '/saved-profiles'),
          item(
            Icons.notifications_active_outlined,
            l10n.remindersTitle,
            '/reminders',
          ),
          item(Icons.language, l10n.homeLanguage, '/language?edit=true'),
          item(
            Icons.workspace_premium_rounded,
            l10n.premiumTitle,
            '/premium',
          ),
          item(Icons.account_circle_outlined, l10n.accountTitle, '/account'),
          section(l10n.menuSectionHelp),
          ListTile(
            dense: true,
            leading: const Icon(
              Icons.mail_outline_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            title: Text(l10n.menuSupport, style: theme.textTheme.bodyLarge),
            subtitle: const Text(supportEmail),
            onTap: () => launchUrl(
              Uri(
                scheme: 'mailto',
                path: supportEmail,
                query: 'subject=${Uri.encodeComponent(l10n.appName)}',
              ),
            ),
          ),
          Builder(
            builder: (tileContext) => ListTile(
              dense: true,
              leading: const Icon(
                Icons.ios_share_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              title: Text(l10n.menuShareApp, style: theme.textTheme.bodyLarge),
              onTap: () => _shareApp(tileContext, l10n.menuShareText),
            ),
          ),
          ListTile(
            dense: true,
            leading: const Icon(
              Icons.description_outlined,
              color: AppColors.primary,
              size: 22,
            ),
            title: Text(l10n.premiumTerms, style: theme.textTheme.bodyLarge),
            onTap: () => launchUrl(
              Uri.parse(LegalLinks.terms),
              mode: LaunchMode.externalApplication,
            ),
          ),
          if (LegalLinks.privacy.isNotEmpty)
            ListTile(
              dense: true,
              leading: const Icon(
                Icons.privacy_tip_outlined,
                color: AppColors.primary,
                size: 22,
              ),
              title: Text(
                l10n.premiumPrivacy,
                style: theme.textTheme.bodyLarge,
              ),
              onTap: () => launchUrl(
                Uri.parse(LegalLinks.privacy),
                mode: LaunchMode.externalApplication,
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static Future<void> _shareApp(BuildContext context, String text) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
  }
}

class _Header extends StatelessWidget {
  final String appName;
  final String tagline;

  const _Header({required this.appName, required this.tagline});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 20,
        20,
        20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF232861), AppColors.background],
        ),
      ),
      child: Row(
        children: [
          const AppLogo(size: 64, glow: true),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tagline,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  /// Null for a guest.
  final String? signedInEmail;
  final VoidCallback onTap;

  const _AccountCard({required this.signedInEmail, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final email = signedInEmail;

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outline, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.surfaceLight,
                child: Icon(
                  email == null
                      ? Icons.person_outline_rounded
                      : Icons.verified_user_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email == null ? l10n.menuGuestTitle : l10n.accountTitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email ?? l10n.menuGuestAction,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: email == null
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
