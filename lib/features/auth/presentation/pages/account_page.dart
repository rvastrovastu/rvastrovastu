import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../../membership/domain/legal_links.dart';
import '../../../membership/domain/membership.dart';
import '../../../membership/presentation/providers/membership_provider.dart';
import '../../../membership/presentation/widgets/premium_gate.dart';
import '../providers/auth_provider.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Email sign-in (6-digit code) and membership status.
class AccountPage extends ConsumerStatefulWidget {
  /// Where to go after a successful sign-in (from onboarding); null stays.
  final String? next;

  /// 'create' when opened from "Create account" on the welcome screen.
  /// The emailed code creates the account either way; only the heading
  /// differs.
  final String? mode;

  const AccountPage({super.key, this.next, this.mode});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  String? _sentTo;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action, String failure) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      debugPrint('[ACCOUNT] $error');
      if (mounted) setState(() => _error = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    final l10n = context.l10n;
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = l10n.accountInvalidEmail);
      return;
    }
    await _guard(() async {
      await ref.read(authServiceProvider).sendEmailCode(email);
      if (mounted) setState(() => _sentTo = email);
    }, l10n.accountSendFailed);
  }

  Future<void> _verify() async {
    final l10n = context.l10n;
    final email = _sentTo;
    if (email == null) return;
    await _guard(() async {
      await ref.read(authServiceProvider).verifyEmailCode(email, _code.text);
      if (!mounted) return;
      setState(() {
        _sentTo = null;
        _code.clear();
      });
      if (widget.next case final next?) {
        context.go(next);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.accountSignedIn)));
    }, l10n.accountInvalidCode);
  }

  Future<void> _signOut() => _guard(
    () => ref.read(authServiceProvider).signOutToGuest(),
    context.l10n.accountErrorGeneric,
  );

  Future<void> _openLink(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  Future<void> _deleteAccount() async {
    final l10n = context.l10n;
    final membership = ref.read(membershipProvider).value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteAccountDialog(
        subscriptionRenews:
            (membership?.premium ?? false) && membership!.willRenew,
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.maybeOf(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).deleteAccount();
      await ref.read(birthProfileRepositoryProvider).clearLocalProfiles();
      ref
        ..invalidate(birthProfilesProvider)
        ..invalidate(birthProfileProvider);
    } catch (error) {
      debugPrint('[ACCOUNT] delete failed: $error');
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.accountDeleteFailed)),
      );
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeleted)));
    router?.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Rebuild on every sign-in or sign-out.
    ref.watch(authUserIdProvider);
    final auth = ref.watch(authServiceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (!auth.isAvailable)
            _Section(child: Text(l10n.accountUnavailable))
          else if (!auth.isAnonymous && auth.email != null)
            _SignedIn(
              email: auth.email!,
              busy: _busy,
              onSignOut: _signOut,
            )
          else
            _signInForm(context),
          const SizedBox(height: 16),
          const _MembershipSection(),
          if (auth.isAvailable) ...[
            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                onPressed: _busy ? null : _deleteAccount,
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(l10n.accountDeleteButton),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: () => _openLink(LegalLinks.terms),
                child: Text(l10n.premiumTerms),
              ),
              if (LegalLinks.privacy.isNotEmpty)
                TextButton(
                  onPressed: () => _openLink(LegalLinks.privacy),
                  child: Text(l10n.premiumPrivacy),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _signInForm(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sentTo = _sentTo;

    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.mode == 'create'
                ? l10n.accountCreateTitle
                : l10n.accountSignInTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(l10n.accountSignInBody, style: theme.textTheme.bodySmall),
          const SizedBox(height: 14),
          if (sentTo == null) ...[
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendCode(),
              decoration: InputDecoration(labelText: l10n.accountEmailLabel),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _sendCode,
              child: Text(l10n.accountSendCode),
            ),
          ] else ...[
            Text(l10n.accountCodeSent(sentTo)),
            const SizedBox(height: 10),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: 6,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _verify(),
              decoration: InputDecoration(labelText: l10n.accountCodeLabel),
            ),
            FilledButton(
              onPressed: _busy ? null : _verify,
              child: Text(l10n.accountVerify),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _sentTo = null;
                      _error = null;
                      _code.clear();
                    }),
              child: Text(l10n.accountChangeEmail),
            ),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(color: AppColors.error)),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final Widget child;

  const _Section({required this.child});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
}

class _SignedIn extends StatelessWidget {
  final String email;
  final bool busy;
  final VoidCallback onSignOut;

  const _SignedIn({
    required this.email,
    required this.busy,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Section(
      child: Row(
        children: [
          const Icon(Icons.account_circle_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(l10n.accountSignedInAs(email))),
          TextButton(
            onPressed: busy ? null : onSignOut,
            child: Text(l10n.accountSignOut),
          ),
        ],
      ),
    );
  }
}

class _MembershipSection extends ConsumerStatefulWidget {
  const _MembershipSection();

  @override
  ConsumerState<_MembershipSection> createState() =>
      _MembershipSectionState();
}

class _MembershipSectionState extends ConsumerState<_MembershipSection> {
  bool _restoring = false;

  Future<void> _restore() async {
    setState(() => _restoring = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final restored = await ref.read(membershipProvider.notifier).restore();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            restored ? l10n.premiumRestored : l10n.premiumNothingToRestore,
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.premiumFailed)));
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final membership =
        ref.watch(membershipProvider).value ?? MembershipState.free;
    final available = ref.watch(purchasesServiceProvider).isAvailable;
    final until = membership.premiumUntil;
    final date = until == null
        ? null
        : DateFormat.yMMMd(
            Localizations.localeOf(context).toString(),
          ).format(until.toLocal());

    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.accountMembershipTitle, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                membership.premium
                    ? Icons.workspace_premium_rounded
                    : Icons.person_outline,
                color: membership.premium
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                membership.premium
                    ? l10n.accountPremiumPlan
                    : l10n.accountFreePlan,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (membership.premium && date != null) ...[
            const SizedBox(height: 4),
            Text(
              membership.willRenew
                  ? l10n.premiumRenewsOn(date)
                  : l10n.premiumEndsOn(date),
            ),
          ],
          if (!membership.premium && membership.addOns.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(l10n.accountOwnedAddOns, style: theme.textTheme.labelLarge),
            for (final addOn in membership.addOns)
              Text('• ${l10n.premiumFeatureName(addOn.feature.name)}'),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              if (!membership.premium)
                FilledButton.icon(
                  onPressed: () => openPaywall(context),
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: Text(l10n.accountSeePremium),
                ),
              if (membership.managementUrl case final url? when membership.premium)
                OutlinedButton(
                  onPressed: () => launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Text(l10n.premiumManage),
                ),
              if (available)
                TextButton(
                  onPressed: _restoring ? null : _restore,
                  child: Text(l10n.premiumRestore),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountDialog extends StatelessWidget {
  final bool subscriptionRenews;

  const _DeleteAccountDialog({required this.subscriptionRenews});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.accountDeleteTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.accountDeleteBody),
          if (subscriptionRenews) ...[
            const SizedBox(height: 12),
            Text(
              l10n.accountDeleteSubscriptionWarning,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.accountDeleteConfirm),
        ),
      ],
    );
  }
}
