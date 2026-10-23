import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/startup_route_resolver.dart';
import '../../../../core/config/app_initialization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/celestial_background.dart';
import '../../../../l10n/app_localizations.dart';

/// First-launch tour: five swipeable pages, one per main feature, with
/// Skip on every page and dots showing how far along you are.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() => context.go(
    StartupRouteResolver.routeAfterOnboarding(
      supabaseConfigured: AppInitialization.supabaseAvailable,
    ),
  );

  void _next(int pageCount) {
    if (_index >= pageCount - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final pages = [
      _Slide(
        icon: Icons.auto_awesome,
        colors: const [Color(0xFFF0B43C), Color(0xFFB8741A)],
        title: l10n.onbKundliTitle,
        body: l10n.onbKundliBody,
      ),
      _Slide(
        icon: Icons.wb_twilight_rounded,
        colors: const [Color(0xFFF7CF78), Color(0xFFE07A3C)],
        title: l10n.onbDailyTitle,
        body: l10n.onbDailyBody,
      ),
      _Slide(
        icon: Icons.home_work_rounded,
        colors: const [Color(0xFF6FC79A), Color(0xFF2E8A6B)],
        title: l10n.onbVastuTitle,
        body: l10n.onbVastuBody,
      ),
      _Slide(
        icon: Icons.celebration_rounded,
        colors: const [Color(0xFFE0605A), Color(0xFFB03A62)],
        title: l10n.onbFestivalsTitle,
        body: l10n.onbFestivalsBody,
      ),
      _Slide(
        icon: Icons.forum_rounded,
        colors: const [Color(0xFFC9C6F2), Color(0xFF6E68D8)],
        title: l10n.onbAiTitle,
        body: l10n.onbAiBody,
      ),
    ];
    final last = _index == pages.length - 1;

    return Scaffold(
      body: CelestialBackground(
        starCoverage: 0.8,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    const AppLogo(size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.appName,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: last ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: TextButton(
                        onPressed: last ? null : _finish,
                        child: Text(l10n.onbSkip),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, index) =>
                      _SlideView(slide: pages[index]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < pages.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _index ? 26 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _index
                                  ? AppColors.primary
                                  : AppColors.outline,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: () => _next(pages.length),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          last ? l10n.onbBegin : l10n.onbNext,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide {
  final IconData icon;
  final List<Color> colors;
  final String title;
  final String body;

  const _Slide({
    required this.icon,
    required this.colors,
    required this.title,
    required this.body,
  });
}

class _SlideView extends StatelessWidget {
  final _Slide slide;

  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final art = (constraints.maxHeight * 0.42).clamp(140.0, 260.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Emblem(size: art, icon: slide.icon, colors: slide.colors),
                SizedBox(height: art * 0.2),
                Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  slide.body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A glowing medallion: concentric gold rings around a gradient disc
/// holding the feature icon, echoing the zodiac wheel in the logo.
class _Emblem extends StatelessWidget {
  final double size;
  final IconData icon;
  final List<Color> colors;

  const _Emblem({required this.size, required this.icon, required this.colors});

  @override
  Widget build(BuildContext context) {
    final ring = AppColors.primary.withValues(alpha: 0.35);

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: 1),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.18),
                  blurRadius: size * 0.3,
                ),
              ],
            ),
          ),
          Container(
            width: size * 0.78,
            height: size * 0.78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: 1),
            ),
          ),
          Container(
            width: size * 0.56,
            height: size * 0.56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.45),
                  blurRadius: size * 0.12,
                  offset: Offset(0, size * 0.04),
                ),
              ],
            ),
            child: Icon(icon, size: size * 0.26, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
