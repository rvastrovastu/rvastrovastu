import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../astrology/presentation/utils/astrology_localization.dart';
import '../../dosha/domain/entities/zodiac_signs.dart';
import '../../panchang/presentation/utils/panchang_share.dart';
import '../domain/rashifal.dart';
import 'rashifal_providers.dart';

/// Daily, weekly, monthly and yearly Rashifal for any of the 12 Moon
/// signs. Opens on the user's own Moon sign when there is a profile.
class RashifalPage extends ConsumerStatefulWidget {
  const RashifalPage({super.key});

  @override
  ConsumerState<RashifalPage> createState() => _RashifalPageState();
}

class _RashifalPageState extends ConsumerState<RashifalPage> {
  int? _sign;
  RashifalPeriod _period = RashifalPeriod.daily;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final userSign = ref.watch(userMoonSignProvider).value;
    final sign = _sign ?? userSign ?? 0;
    final today = ref.watch(rashifalTodayProvider);
    final rashifal = ref.watch(
      rashifalProvider((sign: sign, period: _period, day: today)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.rashifalTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(l10n.rashifalSubtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < 12; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: ValueKey('sign-$i'),
                      avatar: i == userSign
                          ? const Icon(Icons.person_rounded, size: 16)
                          : null,
                      label: Text(l10n.rashiName(zodiacSigns[i])),
                      selected: i == sign,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _sign = i),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<RashifalPeriod>(
            showSelectedIcon: false,
            segments: [
              for (final p in RashifalPeriod.values)
                ButtonSegment(value: p, label: Text(l10n.rashifalPeriod(p.name))),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 16),
          rashifal.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Text(l10n.homeUnableToCalculatePanchang),
            data: (r) => _RashifalCard(rashifal: r),
          ),
          const SizedBox(height: 16),
          Text(l10n.rashifalDisclaimer, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Plain-text version for sharing.
String rashifalShareText(AppLocalizations l10n, Rashifal r) {
  final lines = <String>[
    '${l10n.rashiName(zodiacSigns[r.sign])} · ${l10n.rashifalPeriod(r.period.name)}',
    l10n.rashifalOverall(RashifalEngine.level(r.overall)),
    if (r.moonHouse != null)
      l10n.rashifalMoonFocus(l10n.gocharHouseTheme('h${r.moonHouse}')),
    for (final area in LifeArea.values)
      '${l10n.rashifalArea(area.name)} ${'★' * r.stars[area]!}${'☆' * (5 - r.stars[area]!)} '
          '${l10n.rashifalAreaLine('${area.name}_${RashifalEngine.areaLevel(r.stars[area]!)}')}',
    if (r.luckyPlanet != null)
      l10n.rashifalLucky(
        l10n.rashifalColour(RashifalEngine.luckyColours[r.luckyPlanet]!),
        RashifalEngine.luckyNumbers[r.luckyPlanet]!,
      ),
    '— RV Astro Vastu',
  ];
  return lines.join('\n');
}

class _RashifalCard extends StatelessWidget {
  final Rashifal rashifal;

  const _RashifalCard({required this.rashifal});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final r = rashifal;
    final locale = l10n.localeName;

    final range = switch (r.period) {
      RashifalPeriod.daily => DateFormat.yMMMMEEEEd(locale).format(r.from),
      RashifalPeriod.yearly => '${r.from.year}',
      RashifalPeriod.monthly => DateFormat.yMMMM(locale).format(r.from),
      RashifalPeriod.weekly =>
        '${DateFormat.MMMd(locale).format(r.from)} – '
            '${DateFormat.MMMd(locale).format(r.to)}',
    };

    final dayFormat = r.period == RashifalPeriod.weekly
        ? DateFormat.E(locale)
        : DateFormat.MMMd(locale);

    String? sadeSati;
    if (r.sadeSatiHouse case final h?) {
      final phase = h == 12 ? 'rising' : (h == 1 ? 'peak' : 'setting');
      sadeSati = l10n.sadeSatiActive(l10n.sadeSatiPhase(phase));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.rashiName(zodiacSigns[r.sign]),
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(range, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Builder(
                  builder: (context) => IconButton(
                    tooltip: l10n.rashifalShare,
                    icon: const Icon(Icons.ios_share_rounded),
                    onPressed: () => shareText(
                      context,
                      text: rashifalShareText(l10n, r),
                      subject: l10n.rashifalTitle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Stars(r.overall, size: 26),
            const SizedBox(height: 8),
            Text(
              l10n.rashifalOverall(RashifalEngine.level(r.overall)),
              style: theme.textTheme.titleMedium,
            ),
            if (r.moonHouse != null) ...[
              const SizedBox(height: 6),
              Text(
                l10n.rashifalMoonFocus(
                  l10n.gocharHouseTheme('h${r.moonHouse}'),
                ),
              ),
            ],
            const Divider(height: 28),
            for (final area in LifeArea.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_areaIcon(area), color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.rashifalArea(area.name),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _Stars(r.stars[area]!, size: 16),
                            ],
                          ),
                          Text(
                            l10n.rashifalAreaLine(
                              '${area.name}_${RashifalEngine.areaLevel(r.stars[area]!)}',
                            ),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (r.luckyPlanet case final lucky?)
              _InfoRow(
                icon: Icons.palette_outlined,
                text: l10n.rashifalLucky(
                  l10n.rashifalColour(RashifalEngine.luckyColours[lucky]!),
                  RashifalEngine.luckyNumbers[lucky]!,
                ),
              ),
            if (r.goodDays.isNotEmpty)
              _InfoRow(
                icon: Icons.event_available_rounded,
                text: l10n.rashifalGoodDays(
                  r.goodDays.map(dayFormat.format).join(', '),
                ),
              ),
            if (sadeSati != null)
              _InfoRow(icon: Icons.brightness_3_outlined, text: sadeSati),
            const Divider(height: 28),
            Text(
              l10n.rashifalKeyTransits,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final n in r.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${l10n.gocharPlanetIn(l10n.planetName(n.planet), l10n.rashiName(zodiacSigns[n.signIndex]))}'
                        ' · ${l10n.gocharHouseFromMoon(n.house)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      l10n.gocharTone(n.favourable ? 'favourable' : 'challenging'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: n.favourable ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            for (final i in r.ingresses)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${DateFormat.MMMd(locale).format(i.date.toLocal())}: '
                  '${l10n.gocharIngress(l10n.planetName(i.planet), l10n.rashiName(zodiacSigns[i.signIndex]))}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _areaIcon(LifeArea area) => switch (area) {
    LifeArea.love => Icons.favorite_outline,
    LifeArea.career => Icons.work_outline,
    LifeArea.money => Icons.account_balance_wallet_outlined,
    LifeArea.health => Icons.spa_outlined,
  };
}

class _Stars extends StatelessWidget {
  final int count;
  final double size;

  const _Stars(this.count, {required this.size});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 5; i++)
        Icon(
          i < count ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: AppColors.primary,
        ),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
