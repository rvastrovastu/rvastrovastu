import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../membership/domain/membership.dart';
import '../../../membership/presentation/providers/membership_provider.dart';
import '../../../membership/presentation/widgets/premium_gate.dart';

import '../providers/birth_profile_provider.dart';
import '../../../../core/l10n/l10n_extension.dart';

class SavedProfilesPage extends ConsumerStatefulWidget {
  const SavedProfilesPage({super.key});

  @override
  ConsumerState<SavedProfilesPage> createState() => _SavedProfilesPageState();
}

class _SavedProfilesPageState extends ConsumerState<SavedProfilesPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(birthProfilesProvider.notifier).reload();
    });
  }

  Future<void> _selectProfile(String id) async {
    await ref.read(birthProfilesProvider.notifier).setActiveProfile(id);

    if (!mounted) return;

    final profiles = ref.read(birthProfilesProvider);
    final matching = profiles.where((p) => p.id == id);
    final selected = matching.isEmpty ? null : matching.first;

    if (selected != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${selected.name} is now active')));
    }

    setState(() {});
  }

  Future<void> _deleteProfile(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
          title: Text(l10n.profilesDeleteTitle),
          content: Text(l10n.profilesDeleteBody(name)),
          actions: [
            TextButton(
              onPressed: () => context.pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => context.pop(true),
              child: Text(l10n.profilesDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await ref.read(birthProfilesProvider.notifier).deleteProfile(id);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name deleted')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profiles = ref.watch(birthProfilesProvider);
    final activeProfile = ref.watch(birthProfileProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(context.l10n.profilesTitle),
        centerTitle: true,
      ),
      body: profiles.isEmpty
          ? _EmptyProfiles(onAdd: () => context.push('/birth-profile'))
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(birthProfilesProvider.notifier).reload();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
                  Text(
                    context.l10n.profilesHeading,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.profilesSubtitle,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),

                  ...profiles.map((profile) {
                    final isActive = activeProfile?.id == profile.id;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          child: Text(
                            profile.name.isNotEmpty
                                ? profile.name[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                profile.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (isActive) Chip(label: Text(context.l10n.profilesActive)),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${profile.location.displayName}\n'
                            '${profile.dateOfBirth.month.toString().padLeft(2, '0')}/'
                            '${profile.dateOfBirth.day.toString().padLeft(2, '0')}/'
                            '${profile.dateOfBirth.year} • '
                            '${profile.birthTime}',
                          ),
                        ),
                        isThreeLine: true,
                        onTap: () => _selectProfile(profile.id),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              context.push('/birth-profile?edit=true');
                            } else if (value == 'delete') {
                              _deleteProfile(profile.id, profile.name);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text(context.l10n.profilesEdit),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(context.l10n.profilesDelete),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () {
                        final membership = ref.read(membershipProvider).value;
                        if (!canAddProfile(membership, profiles.length)) {
                          openPaywall(
                            context,
                            PremiumFeature.unlimitedProfiles,
                          );
                          return;
                        }
                        context.push('/birth-profile');
                      },
                      icon: const Icon(Icons.person_add_alt_1),
                      label: Text(context.l10n.profilesAddNew),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _EmptyProfiles extends StatelessWidget {
  const _EmptyProfiles({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64),
            const SizedBox(height: 20),
            Text(
              context.l10n.profilesEmptyTitle,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.profilesEmptyBody,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(context.l10n.profilesCreate),
            ),
          ],
        ),
      ),
    );
  }
}
