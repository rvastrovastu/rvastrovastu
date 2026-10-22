import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme/app_colors.dart';
import '../astrology/presentation/providers/astrology_provider.dart';
import '../astrology/presentation/utils/astrology_localization.dart';
import '../compatibility/domain/usecases/calculate_ashtakoota.dart';
import 'namakshar.dart';

class BabyName {
  final String devanagari;
  final String latin;

  /// 'm' or 'f'.
  final String gender;
  final String meaningEn;
  final String meaningHi;

  const BabyName(
    this.devanagari,
    this.latin,
    this.gender,
    this.meaningEn,
    this.meaningHi,
  );
}

final babyNamesProvider = FutureProvider<List<BabyName>>((ref) async {
  final raw = await rootBundle.loadString('assets/baby_names.json');
  return [
    for (final e in jsonDecode(raw) as List)
      BabyName(e[0] as String, e[1] as String, e[2] as String,
          e[3] as String, e[4] as String),
  ];
});

/// Baby names by nakshatra (namakshar): pick the birth nakshatra and pada,
/// see its four syllables and names that begin with them.
class BabyNamesPage extends ConsumerStatefulWidget {
  const BabyNamesPage({super.key});

  @override
  ConsumerState<BabyNamesPage> createState() => _BabyNamesPageState();
}

class _BabyNamesPageState extends ConsumerState<BabyNamesPage> {
  int? _nakshatra;
  int _pada = 1;
  int? _syllable;
  String _gender = 'all';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final kundali = ref.watch(kundaliProvider).value;
    final mine = kundali == null
        ? null
        : CalculateAshtakoota.nakshatras.indexOf(kundali.nakshatra);

    final nakshatra = _nakshatra ?? (mine != null && mine >= 0 ? mine : 0);
    final syllables = namakshar[nakshatra];
    final pada = _nakshatra == null && mine != null && mine >= 0
        ? kundali!.nakshatraPada.clamp(1, 4)
        : _pada;
    final chosen = _syllable ?? (pada - 1);
    final names = ref.watch(babyNamesProvider).value ?? const <BabyName>[];
    final hindiMeaning = {'hi', 'mr'}.contains(l10n.localeName);

    final matches = [
      for (final n in names)
        if ((_gender == 'all' || n.gender == _gender) &&
            startsWithSyllable(n.devanagari, syllables[chosen].$1))
          n,
    ]..sort((a, b) => a.latin.compareTo(b.latin));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.babyNamesTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(l10n.babyNamesIntro, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: ValueKey('nakshatraPicker-$nakshatra'),
            initialValue: nakshatra,
            decoration: InputDecoration(labelText: l10n.babyNamesNakshatra),
            items: [
              for (var i = 0; i < 27; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    l10n.nakshatraName(CalculateAshtakoota.nakshatras[i]),
                  ),
                ),
            ],
            onChanged: (v) => setState(() {
              _nakshatra = v;
              _pada = 1;
              _syllable = null;
            }),
          ),
          if (mine != null && mine >= 0 && _nakshatra != null && _nakshatra != mine)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() {
                  _nakshatra = null;
                  _syllable = null;
                }),
                child: Text(l10n.babyNamesUseMine),
              ),
            ),
          const SizedBox(height: 12),
          Text(l10n.babyNamesSyllables, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < 4; i++)
                ChoiceChip(
                  key: ValueKey('syllable-$i'),
                  label: Text(
                    '${l10n.babyNamesPada(i + 1)}: '
                    '${syllables[i].$1} (${syllables[i].$2})',
                  ),
                  selected: chosen == i,
                  showCheckmark: false,
                  onSelected: (_) => setState(() {
                    _pada = i + 1;
                    _syllable = i;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final g in const ['all', 'm', 'f'])
                ButtonSegment(value: g, label: Text(l10n.babyNamesGender(g))),
            ],
            selected: {_gender},
            onSelectionChanged: (s) => setState(() => _gender = s.first),
          ),
          const SizedBox(height: 12),
          if (matches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(l10n.babyNamesNone, textAlign: TextAlign.center),
            )
          else
            for (final n in matches)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    n.gender == 'm' ? Icons.boy_rounded : Icons.girl_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text('${n.latin} · ${n.devanagari}'),
                  subtitle: Text(hindiMeaning ? n.meaningHi : n.meaningEn),
                ),
              ),
        ],
      ),
    );
  }
}
