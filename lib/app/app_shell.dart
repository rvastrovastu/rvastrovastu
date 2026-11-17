import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';

/// Bottom-tab scaffold for the five main areas. Each tab keeps its own
/// navigation stack; detail screens (Dosha, Muhurat, profiles…) open full
/// screen above the tabs.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the active tab returns to its first screen.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.wb_twilight_outlined),
            selectedIcon: const Icon(Icons.wb_twilight),
            label: l10n.navToday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome),
            label: l10n.kundali,
          ),
          NavigationDestination(
            icon: const Icon(Icons.event_note_outlined),
            selectedIcon: const Icon(Icons.event_note),
            label: l10n.navCalendar,
          ),
          NavigationDestination(
            icon: const Icon(Icons.home_work_outlined),
            selectedIcon: const Icon(Icons.home_work),
            label: l10n.vastu,
          ),
          NavigationDestination(
            icon: const Icon(Icons.support_agent_outlined),
            selectedIcon: const Icon(Icons.support_agent),
            label: l10n.consultShort,
          ),
        ],
      ),
    );
  }
}
