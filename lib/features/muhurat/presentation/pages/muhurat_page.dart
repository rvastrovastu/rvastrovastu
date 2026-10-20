import 'package:flutter/material.dart';
import '../../../../core/l10n/l10n_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/location/current_location_provider.dart';
import '../../../../core/time/app_clock_provider.dart';
import '../../domain/services/muhurat_candidate_search_service.dart';
import '../../../panchang/domain/entities/daily_panchang.dart';
import '../../../panchang/domain/entities/daily_panchang_input.dart';
import '../../../panchang/presentation/providers/daily_panchang_provider.dart';

class MuhuratPage extends ConsumerStatefulWidget {
  const MuhuratPage({super.key});

  @override
  ConsumerState<MuhuratPage> createState() => _MuhuratPageState();
}

class _MuhuratPageState extends ConsumerState<MuhuratPage> {
  DateTime? _selectedDate;
  String _selectedPurpose = 'general';

  List<MuhuratCandidate> _candidates = [];
  bool _isSearchingCandidates = false;
  bool _candidateSearchFailed = false;
  int _candidateSearchGeneration = 0;

  String _selectedPurposeLabel(BuildContext context) {
    final l10n = context.l10n;
    return switch (_selectedPurpose) {
      'marriage' => l10n.muhuratPurposeMarriage,
      'grihaPravesh' => l10n.muhuratPurposeGrihaPravesh,
      'business' => l10n.muhuratPurposeBusiness,
      'vehicle' => l10n.muhuratPurposeVehicle,
      'travel' => l10n.muhuratPurposeTravel,
      _ => l10n.muhuratPurposeGeneral,
    };
  }

  DateTime _calendarDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _loadCandidates({
    required String purpose,
    required DateTime startDate,
    required double latitude,
    required double longitude,
    required String timezone,
  }) async {
    final generation = ++_candidateSearchGeneration;

    debugPrint(
      '[MUHURAT][CANDIDATES] START '
      'generation=$generation purpose=$purpose '
      'startDate=$startDate lat=$latitude lng=$longitude tz=$timezone',
    );

    setState(() {
      _isSearchingCandidates = true;
      _candidateSearchFailed = false;
      _candidates = [];
    });

    try {
      final service = MuhuratCandidateSearchService(
        ref.read(dailyPanchangRepositoryProvider),
      );
      final results = await service.search(
        purpose: purpose,
        startDate: startDate,
        latitude: latitude,
        longitude: longitude,
        timezone: timezone,
      );

      debugPrint(
        '[MUHURAT][CANDIDATES] RESULT '
        'generation=$generation purpose=$purpose '
        'count=${results.length} mounted=$mounted '
        'currentGeneration=$_candidateSearchGeneration '
        'selectedPurpose=$_selectedPurpose',
      );

      if (!mounted ||
          generation != _candidateSearchGeneration ||
          _selectedPurpose != purpose) {
        return;
      }

      setState(() => _candidates = results);
    } catch (error) {
      debugPrint(
        '[MUHURAT][CANDIDATES] ERROR '
        'generation=$generation purpose=$purpose error=$error',
      );
      if (!mounted ||
          generation != _candidateSearchGeneration ||
          _selectedPurpose != purpose) {
        return;
      }
      setState(() => _candidateSearchFailed = true);
    } finally {
      debugPrint(
        '[MUHURAT][CANDIDATES] FINALLY '
        'generation=$generation currentGeneration=$_candidateSearchGeneration '
        'mounted=$mounted',
      );
      if (mounted && generation == _candidateSearchGeneration) {
        setState(() => _isSearchingCandidates = false);
      }
    }
  }

  Widget _candidateResults(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.muhuratCandidateHeading,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(l10n.muhuratCandidateDisclaimer, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        if (_isSearchingCandidates) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(l10n.muhuratCandidateSearching),
        ] else if (_candidateSearchFailed) ...[
          Text(
            l10n.muhuratCandidateSearchError,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ] else if (_candidates.isEmpty) ...[
          Text(l10n.muhuratCandidateNoResults),
        ],
        for (final candidate in _candidates)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(candidate.date),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${l10n.homeTithi}: ${candidate.panchang.tithi}'),
                  Text(
                    '${l10n.homeNakshatra}: ${candidate.panchang.nakshatra}',
                  ),
                  Text('${l10n.homeYoga}: ${candidate.panchang.yoga}'),
                  const SizedBox(height: 6),
                  Text(
                    candidate.screeningReason,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _chooseDate(DateTime currentDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: context.l10n.chooseMuhuratDate,
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = _calendarDate(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = ref.watch(appClockProvider);
    final locationAsync = ref.watch(currentLocationProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.muhuratPlannerTitle)),
      body: SafeArea(
        child: locationAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _message(
            context,
            context.l10n.unableToDetermineLocation,
            onRetry: () {
              ref.read(currentLocationProvider.notifier).refresh();
            },
          ),
          data: (location) {
            if (location == null) {
              return _message(
                context,
                context.l10n.locationUnavailable,
                onRetry: () {
                  ref.read(currentLocationProvider.notifier).refresh();
                },
              );
            }

            final zone = tz.getLocation(location.timezone);
            final localNow = tz.TZDateTime.from(now.toUtc(), zone);
            final today = _calendarDate(localNow);
            final date = _selectedDate ?? today;

            final input = DailyPanchangInput(
              date: date,
              latitude: location.latitude,
              longitude: location.longitude,
              timezone: location.timezone,
            );

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  context.l10n.planWithPanchang,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.muhuratPlannerDescription,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_month),
                    title: Text(context.l10n.selectedDate),
                    subtitle: Text(_formatDate(date)),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () => _chooseDate(date),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _selectedPurpose,
                          decoration: InputDecoration(
                            labelText: context.l10n.muhuratPurposeLabel,
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'general',
                              child: Text(context.l10n.muhuratPurposeGeneral),
                            ),
                            DropdownMenuItem(
                              value: 'marriage',
                              child: Text(context.l10n.muhuratPurposeMarriage),
                            ),
                            DropdownMenuItem(
                              value: 'grihaPravesh',
                              child: Text(
                                context.l10n.muhuratPurposeGrihaPravesh,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'business',
                              child: Text(context.l10n.muhuratPurposeBusiness),
                            ),
                            DropdownMenuItem(
                              value: 'vehicle',
                              child: Text(context.l10n.muhuratPurposeVehicle),
                            ),
                            DropdownMenuItem(
                              value: 'travel',
                              child: Text(context.l10n.muhuratPurposeTravel),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;

                            if (value == 'general') {
                              _candidateSearchGeneration++;
                              setState(() {
                                _selectedPurpose = value;
                                _candidates = [];
                                _isSearchingCandidates = false;
                                _candidateSearchFailed = false;
                              });
                              return;
                            }

                            setState(() {
                              _selectedPurpose = value;
                              _candidates = [];
                              _candidateSearchFailed = false;
                            });

                            _loadCandidates(
                              purpose: value,
                              startDate: today,
                              latitude: location.latitude,
                              longitude: location.longitude,
                              timezone: location.timezone,
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${context.l10n.muhuratPurposeLabel}: '
                          '${_selectedPurposeLabel(context)}',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.muhuratPurposeNote,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.muhuratPurposeGuidance(
                            _selectedPurposeLabel(context),
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_selectedPurpose != 'general') ...[
                  const SizedBox(height: 12),
                  _candidateResults(context),
                ],
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(
                      [
                            if (location.city != null &&
                                location.city!.trim().isNotEmpty)
                              location.city!.trim(),
                            if (location.state != null &&
                                location.state!.trim().isNotEmpty)
                              location.state!.trim(),
                            if (location.country != null &&
                                location.country!.trim().isNotEmpty)
                              location.country!.trim(),
                          ].join(', ').isEmpty
                          ? context.l10n.currentLocation
                          : [
                              if (location.city != null &&
                                  location.city!.trim().isNotEmpty)
                                location.city!.trim(),
                              if (location.state != null &&
                                  location.state!.trim().isNotEmpty)
                                location.state!.trim(),
                              if (location.country != null &&
                                  location.country!.trim().isNotEmpty)
                                location.country!.trim(),
                            ].join(', '),
                    ),
                    subtitle: Text(location.timezone),
                  ),
                ),
                const SizedBox(height: 18),
                ref
                    .watch(dailyPanchangProvider(input))
                    .when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(36),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stack) => _message(
                        context,
                        context.l10n.unableToCalculatePanchang,
                        onRetry: () {
                          ref.invalidate(dailyPanchangProvider(input));
                        },
                      ),
                      data: (panchang) => _panchangContent(
                        context,
                        panchang,
                        date,
                        location.timezone,
                      ),
                    ),
                const SizedBox(height: 18),
                Card(
                  color: colors.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(context.l10n.traditionalMuhuratDisclaimer),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _panchangContent(
    BuildContext context,
    DailyPanchang panchang,
    DateTime date,
    String timezone,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.abhijitMuhurat,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  panchang.muhurat,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.traditionalGeneralPurposeWindow,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _detailCard(
          context,
          icon: Icons.warning_amber_rounded,
          title: context.l10n.homeRahuKaal,
          value: panchang.rahuKaal,
          description: context.l10n.rahuKaalDescription,
        ),
        const SizedBox(height: 10),
        _detailCard(
          context,
          icon: Icons.wb_twilight,
          title: context.l10n.sunrise,
          value: panchang.sunrise,
        ),
        const SizedBox(height: 10),
        _detailCard(
          context,
          icon: Icons.wb_sunny_outlined,
          title: context.l10n.sunset,
          value: panchang.sunset,
        ),
        const SizedBox(height: 10),
        _detailCard(
          context,
          icon: Icons.nightlight_round,
          title: context.l10n.moonrise,
          value: panchang.moonrise,
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.panchangForDate(_formatDate(date)),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _panchangRow(context.l10n.homeTithi, panchang.tithi),
                _panchangRow(context.l10n.homeNakshatra, panchang.nakshatra),
                _panchangRow(context.l10n.homeYoga, panchang.yoga),
                const Divider(height: 24),
                Text(
                  context.l10n.timesLocalTo(timezone),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    String? description,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(value, style: theme.textTheme.titleLarge),
                  if (description != null) ...[
                    const SizedBox(height: 4),
                    Text(description, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panchangRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(
    BuildContext context,
    String message, {
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}
