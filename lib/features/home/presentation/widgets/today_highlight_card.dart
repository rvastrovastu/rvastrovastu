import '../../../astrology/presentation/utils/astrology_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../dosha/domain/entities/zodiac_signs.dart';
import '../../../festivals/domain/entities/calendar_observance.dart';
import '../../../festivals/guide/presentation/puja_guide_route.dart';
import '../../../horoscope/domain/entities/daily_horoscope.dart';
import '../providers/today_highlight_provider.dart';
import 'package:rv_astro_vastu/features/panchang/presentation/utils/panchang_localization.dart';

/// What kind of day it is, for the meaning and the action lines.
enum _Theme { devotion, prosperity, newStart, family, reflection, completion }

_Theme _themeOf(TodayHighlight h) {
  if (h.kind == HighlightKind.eclipse) return _Theme.reflection;
  if (h.kind == HighlightKind.sankranti) return _Theme.newStart;
  final id = h.observance;
  if (id == null) return _Theme.completion;
  return switch (id) {
    ObservanceId.dhanteras ||
    ObservanceId.diwali ||
    ObservanceId.akshayaTritiya => _Theme.prosperity,
    ObservanceId.makarSankranti ||
    ObservanceId.vasantPanchami ||
    ObservanceId.ugadi ||
    ObservanceId.ganeshChaturthi ||
    ObservanceId.navratri => _Theme.newStart,
    ObservanceId.rakshaBandhan ||
    ObservanceId.janmashtami ||
    ObservanceId.karvaChauth ||
    ObservanceId.holi => _Theme.family,
    ObservanceId.amavasya => _Theme.reflection,
    ObservanceId.purnima || ObservanceId.dussehra => _Theme.completion,
    _ => _Theme.devotion,
  };
}

/// The life area a theme speaks to. Other themes use the strongest area.
HoroscopeArea? _areaOf(_Theme theme) => switch (theme) {
  _Theme.prosperity => HoroscopeArea.money,
  _Theme.newStart => HoroscopeArea.career,
  _Theme.family => HoroscopeArea.love,
  _ => null,
};

int _rank(Outlook o) => switch (o) {
  Outlook.good => 3,
  Outlook.steady => 2,
  Outlook.careful => 1,
};

AreaReading? _pick(List<AreaReading> areas, HoroscopeArea? wanted) {
  if (areas.isEmpty) return null;
  if (wanted != null) {
    for (final a in areas) {
      if (a.area == wanted) return a;
    }
  }
  var best = areas.first;
  for (final a in areas) {
    if (_rank(a.outlook) > _rank(best.outlook)) best = a;
  }
  return best;
}

String _themeText(AppLocalizations l10n, _Theme theme) => switch (theme) {
  _Theme.devotion => l10n.flashThemeDevotion,
  _Theme.prosperity => l10n.flashThemeProsperity,
  _Theme.newStart => l10n.flashThemeNewStart,
  _Theme.family => l10n.flashThemeFamily,
  _Theme.reflection => l10n.flashThemeReflection,
  _Theme.completion => l10n.flashThemeCompletion,
};

String _doText(AppLocalizations l10n, _Theme theme) => switch (theme) {
  _Theme.devotion => l10n.flashDoDevotion,
  _Theme.prosperity => l10n.flashDoProsperity,
  _Theme.newStart => l10n.flashDoNewStart,
  _Theme.family => l10n.flashDoFamily,
  _Theme.reflection => l10n.flashDoReflection,
  _Theme.completion => l10n.flashDoCompletion,
};

String _advice(AppLocalizations l10n, Outlook outlook) => switch (outlook) {
  Outlook.good => l10n.flashAdviceGood,
  Outlook.steady => l10n.flashAdviceSteady,
  Outlook.careful => l10n.flashAdviceCareful,
};

String _areaLabel(AppLocalizations l10n, HoroscopeArea area) => switch (area) {
  HoroscopeArea.career => l10n.homeCareer,
  HoroscopeArea.money => l10n.homeFinance,
  HoroscopeArea.love => l10n.homeRelationships,
};

/// A short scrolling stripe at the top of Today, in four parts: the event,
/// why it matters, what to do today, and the user's own benefit.
class TodayHighlightStripe extends ConsumerWidget {
  const TodayHighlightStripe({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlight = ref.watch(todayHighlightProvider).value;
    if (highlight == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final kind = _themeOf(highlight);
    final reading = _pick(highlight.areas, _areaOf(kind));
    final yourBenefit = reading == null
        ? null
        : l10n.flashBenefitLine(
            _areaLabel(l10n, reading.area),
            l10n.horoscopeOutlook(reading.outlook.name),
            _advice(l10n, reading.outlook),
          );

    final (IconData icon, String event, List<String> parts) =
        switch (highlight.kind) {
      HighlightKind.festival => (
        Icons.auto_awesome_rounded,
        l10n.festivalName(highlight.observance!.name),
        [_themeText(l10n, kind), _doText(l10n, kind), ?yourBenefit],
      ),
      HighlightKind.eclipse => (
        Icons.dark_mode_rounded,
        highlight.eclipse!.solar ? l10n.flashSolarEclipse : l10n.flashLunarEclipse,
        [_themeText(l10n, kind), _doText(l10n, kind), ?yourBenefit],
      ),
      HighlightKind.sankranti => (
        Icons.wb_twilight_rounded,
        l10n.flashSunEnters(l10n.rashiName(zodiacSigns[highlight.signIndex!])),
        [_themeText(l10n, kind), _doText(l10n, kind), ?yourBenefit],
      ),
      HighlightKind.personal => (
        Icons.wb_sunny_rounded,
        highlight.tithi == null
            ? l10n.flashNoEvent
            : '${localizedTithi(l10n, highlight.tithi!)} \u00b7 ${localizedNakshatra(l10n, highlight.nakshatra!)}',
        [?yourBenefit],
      ),
    };

    final text = [event, ...parts].join('   \u2726   ');
    final festival = highlight.kind == HighlightKind.festival;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: festival
            ? () => context.push(
                pujaGuidePath(highlight.observance!, highlight.observanceDate!),
              )
            : null,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.background),
              const SizedBox(width: 8),
              Expanded(
                child: _Marquee(
                  text: text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.background,
                  ) ?? const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text that scrolls from right to left and loops, when it is wider than
/// the space it has. Shorter text stays still.
class _Marquee extends StatefulWidget {
  const _Marquee({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();
        final textWidth = painter.width;
        final width = constraints.maxWidth;

        if (textWidth <= width) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        const gap = 72.0;
        final travel = textWidth + gap;
        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.translate(
              offset: Offset(width - _controller.value * travel, 0),
              child: child,
            ),
            // The row is allowed to be wider than the stripe; ClipRect hides
            // the overflow, so no overflow warning is drawn.
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
                  const SizedBox(width: gap),
                  Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
