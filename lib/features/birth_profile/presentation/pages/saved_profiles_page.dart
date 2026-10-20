import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../membership/domain/membership.dart';
import '../../../membership/presentation/providers/membership_provider.dart';
import '../../../membership/presentation/widgets/premium_gate.dart';

import '../providers/birth_profile_provider.dart';

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
        return AlertDialog(
          title: const Text('Delete Profile?'),
          content: Text(
            'Are you sure you want to delete $name? '
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => context.pop(true),
              child: const Text('Delete'),
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
        title: const Text('Saved Profiles'),
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
                    'Your Birth Profiles',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select a profile to personalize your astrology insights.',
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
                            if (isActive) const Chip(label: Text('Active')),
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
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
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
                      label: const Text('Add New Profile'),
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
            const Text(
              'No Saved Profiles',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first birth profile to get '
              'personalized astrology insights.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Create Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
