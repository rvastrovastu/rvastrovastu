import 'package:flutter/material.dart';

import '../widgets/app_drawer.dart';
import '../widgets/home_header.dart';
import '../widgets/dashboard_state_widgets.dart';
import '../widgets/insight_card.dart';
import '../widgets/cosmic_snapshot.dart';
import '../widgets/panchang_section.dart';
import '../widgets/kundali_preview.dart';
import '../widgets/quick_actions.dart';
import '../widgets/home_festival_card.dart';
import '../../../panchang/presentation/widgets/plan_your_day_strip.dart';
import '../../../reminders/presentation/widgets/reminder_prompt_card.dart';
import '../../../../core/widgets/celestial_background.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../astrology/presentation/providers/astrology_provider.dart';
import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../../dasha/domain/entities/dasha_birth_data.dart';
import '../../../dasha/presentation/providers/dasha_provider.dart';
import '../../../horoscope/presentation/providers/daily_horoscope_provider.dart';
import '../../../horoscope/presentation/widgets/daily_horoscope_section.dart';
import '../../../your_day/presentation/your_day_card.dart';
import '../../../daily_loop/presentation/widgets/daily_remedy_card.dart';
import '../../../daily_loop/presentation/widgets/family_day_card.dart';
import '../../../daily_loop/presentation/widgets/night_check_in_card.dart';
import '../../../daily_loop/presentation/widgets/personal_muhurat_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/time/app_clock_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(birthProfileProvider);
    final kundaliAsync = ref.watch(kundaliProvider);
    final dailyHoroscopeAsync = ref.watch(dailyHoroscopeProvider);

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = theme.colorScheme;
    final now = ref.watch(appClockProvider);

    final greeting = _greeting(context, now.hour);
    final profileGreeting = _profileGreeting(context, profile?.name);
    final dateText = _formatDate(l10n, now);

    return Scaffold(
      backgroundColor: colors.surface,
      drawer: const AppDrawer(),
      body: CelestialBackground(
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: HomeHeader(
                  greeting: greeting,
                  profileGreeting: profileGreeting,
                  dateText: dateText,
                ),
              ),
              // Today's Panchang depends only on where you are, so it
              // loads independently of the birth chart.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    children: [
                      PanchangSection(now: now),
                      const SizedBox(height: 12),
                      const HomeFestivalCard(),
                      const SizedBox(height: 12),
                      const PlanYourDayStrip(),
                      const SizedBox(height: 12),
                      const ReminderPromptCard(),
                    ],
                  ),
                ),
              ),
              // Then the personal reading: your day, your horoscope, your
              // chart now.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: kundaliAsync.when(
                    loading: () => const DashboardLoading(),
                    error: (error, stack) => DashboardError(
                      onRetry: () => ref.invalidate(kundaliProvider),
                    ),
                    data: (kundali) {
                      if (profile == null || kundali == null) {
                        return NoProfileCard(
                          onTap: () {
                            context.push('/birth-profile?edit=true');
                          },
                        );
                      }

                      final dashaBirthData = DashaBirthData(
                        birthDate: profile.dateOfBirth,
                        moonLongitude: kundali.moonLongitude,
                      );

                      return Column(
                        children: [
                          YourDayCard(
                            natalMoonLongitude: kundali.moonLongitude,
                          ),
                          const SizedBox(height: 20),
                          DailyHoroscopeSection(
                            horoscopeAsync: dailyHoroscopeAsync,
                            onRetry: () =>
                                ref.invalidate(dailyHoroscopeProvider),
                          ),
                          const SizedBox(height: 20),
                          // The daily loop: best hours, a small remedy,
                          // the evening check-in and the family's day.
                          // Each card brings its own space below.
                          const PersonalMuhuratCard(),
                          const DailyRemedyCard(),
                          const NightCheckInCard(),
                          const FamilyDayCard(),
                          CosmicSnapshot(
                            kundali: kundali,
                            mahadasha: ref.watch(
                              currentDashaProvider(dashaBirthData),
                            ),
                            antardasha: ref.watch(
                              currentAntardashaProvider(dashaBirthData),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (profile != null && kundaliAsync.value != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      children: [
                        KundaliPreview(
                          kundali: kundaliAsync.value!,
                          onTap: () => context.go('/kundali'),
                        ),
                        const SizedBox(height: 16),
                        InsightCard(
                          icon: Icons.timelapse_rounded,
                          title: l10n.homeDashaInsight,
                          description:
                              l10n.homeDashaInsightDescriptionDashboard,
                          onTap: () => context.go('/kundali'),
                        ),
                        const SizedBox(height: 12),
                        InsightCard(
                          icon: Icons.public_rounded,
                          title: l10n.homeTransitInsight,
                          description: l10n.homeTransitInsightDescription,
                          onTap: () => context.push('/gochar'),
                        ),
                        const SizedBox(height: 12),
                        InsightCard(
                          icon: Icons.home_outlined,
                          title: l10n.homeVastuTipOfTheDay,
                          description: l10n.homeVastuTipDescription,
                          onTap: () => context.go('/vastu'),
                        ),
                      ],
                    ),
                  ),
                ),
              // A few shortcuts; the full list is in the menu.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.homeExplore, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 10),
                      const QuickActions(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _profileGreeting(BuildContext context, String? profileName) {
    final name = profileName?.trim();

    return name != null && name.isNotEmpty
        ? name
        : context.l10n.homeYourCosmicJourney;
  }

  String _greeting(BuildContext context, int hour) {
    final l10n = context.l10n;
    if (hour < 12) return l10n.homeGreetingMorning;
    if (hour < 17) return l10n.homeGreetingAfternoon;
    if (hour < 21) return l10n.homeGreetingEvening;
    return l10n.homeGreetingNight;
  }

  String _formatDate(AppLocalizations l10n, DateTime date) {
    final weekdays = [
      l10n.homeWeekdayMonday,
      l10n.homeWeekdayTuesday,
      l10n.homeWeekdayWednesday,
      l10n.homeWeekdayThursday,
      l10n.homeWeekdayFriday,
      l10n.homeWeekdaySaturday,
      l10n.homeWeekdaySunday,
    ];

    final months = [
      l10n.homeMonthJanuary,
      l10n.homeMonthFebruary,
      l10n.homeMonthMarch,
      l10n.homeMonthApril,
      l10n.homeMonthMay,
      l10n.homeMonthJune,
      l10n.homeMonthJuly,
      l10n.homeMonthAugust,
      l10n.homeMonthSeptember,
      l10n.homeMonthOctober,
      l10n.homeMonthNovember,
      l10n.homeMonthDecember,
    ];

    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
