import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/location/device_time_zone.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/auth_service.dart';
import '../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../home/presentation/widgets/app_drawer.dart' show supportEmail;
import '../data/consultation_repository.dart';
import '../domain/consultation.dart';
import 'consultation_providers.dart';

/// Book a personal consultation: topic, length, day and time, how to talk
/// and contact details. The request is confirmed by the astrologer, who
/// then sends a payment link; nothing is charged in the app.
class ConsultationPage extends ConsumerStatefulWidget {
  final ConsultationTopic? initialTopic;

  const ConsultationPage({super.key, this.initialTopic});

  @override
  ConsumerState<ConsultationPage> createState() => _ConsultationPageState();
}

class _ConsultationPageState extends ConsumerState<ConsultationPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _question = TextEditingController();

  late ConsultationTopic _topic =
      widget.initialTopic ?? ConsultationTopic.kundli;
  int _minutes = ConsultationConfig.lengths.first;
  int _day = 0;
  DateTime? _slot;
  ConsultationMode _mode = ConsultationMode.whatsapp;
  bool _shareChart = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(birthProfileProvider);
    _name.text = profile?.name ?? '';
    _email.text = AuthService().email ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final deviceZone = ref.watch(deviceTimeZoneProvider).value;
    final zone = _zone(deviceZone);
    final slotsAsync = ref.watch(consultationSlotsProvider);
    final profile = ref.watch(birthProfileProvider);
    final price = ConsultationConfig.priceLabel(_minutes, deviceZone);

    // Bookable times grouped by the user's own calendar day.
    final byDay = <DateTime, List<DateTime>>{};
    final groups =
        slotsAsync.value ?? const <(DateTime, List<DateTime>)>[];
    for (final (_, slots) in groups) {
      for (final slot in slots) {
        final local = tz.TZDateTime.from(slot, zone);
        byDay
            .putIfAbsent(
              DateTime(local.year, local.month, local.day),
              () => [],
            )
            .add(slot);
      }
    }
    final days = byDay.keys.toList()..sort();
    final day = days.isEmpty ? null : days[_day.clamp(0, days.length - 1)];
    final times = day == null ? const <DateTime>[] : byDay[day]!;
    final locale = l10n.localeName;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.consultTitle),
        actions: [
          IconButton(
            tooltip: l10n.consultMyBookings,
            onPressed: () => context.push('/consult/bookings'),
            icon: const Icon(Icons.event_note_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const _Hero(),
              const SizedBox(height: 20),
              _SectionTitle(l10n.consultTopicTitle),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.35,
                children: [
                  for (final topic in ConsultationTopic.values)
                    _TopicCard(
                      topic: topic,
                      selected: topic == _topic,
                      onTap: () => setState(() => _topic = topic),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionTitle(l10n.consultLengthTitle),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final (i, minutes) in ConsultationConfig.lengths.indexed)
                    ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: _LengthCard(
                          minutes: minutes,
                          price: ConsultationConfig.priceLabel(
                            minutes,
                            deviceZone,
                          ),
                          selected: minutes == _minutes,
                          onTap: () => setState(() => _minutes = minutes),
                        ),
                      ),
                    ],
                ],
              ),
              const SizedBox(height: 20),
              _SectionTitle(l10n.consultDateTitle),
              const SizedBox(height: 10),
              if (slotsAsync.isLoading && !slotsAsync.hasValue)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (days.isEmpty)
                Text(
                  l10n.consultNoSlots,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else ...[
                SizedBox(
                  height: 68,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: days.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => _DayChip(
                      weekday: DateFormat.E(locale).format(days[i]),
                      date: DateFormat.MMMd(locale).format(days[i]),
                      selected: days[i] == day,
                      onTap: () => setState(() {
                        _day = i;
                        _slot = null;
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionTitle(l10n.consultTimeTitle),
                const SizedBox(height: 4),
                Text(
                  l10n.consultTimeNote(zone.name),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final slot in times)
                      ChoiceChip(
                        label: Text(
                          DateFormat.jm(
                            locale,
                          ).format(tz.TZDateTime.from(slot, zone)),
                        ),
                        selected: slot == _slot,
                        onSelected: (_) => setState(() => _slot = slot),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              _SectionTitle(l10n.consultModeTitle),
              const SizedBox(height: 10),
              SegmentedButton<ConsultationMode>(
                segments: [
                  for (final mode in ConsultationMode.values)
                    ButtonSegment(
                      value: mode,
                      label: Text(l10n.consultMode(mode.name)),
                      icon: Icon(switch (mode) {
                        ConsultationMode.phone => Icons.call_rounded,
                        ConsultationMode.whatsapp => Icons.chat_rounded,
                        ConsultationMode.video => Icons.videocam_rounded,
                      }),
                    ),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 20),
              _SectionTitle(l10n.consultDetailsTitle),
              const SizedBox(height: 10),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.consultName),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? l10n.consultRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.consultPhone,
                  hintText: '+91 98765 43210',
                ),
                validator: (v) => isValidPhone((v ?? '').trim())
                    ? null
                    : l10n.consultPhoneInvalid,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.consultEmail),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _question,
                maxLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: l10n.consultQuestion,
                  alignLabelWithHint: true,
                ),
              ),
              if (profile != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _shareChart,
                  onChanged: (v) => setState(() => _shareChart = v),
                  title: Text(l10n.consultShareChart(profile.name)),
                ),
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _sending || _slot == null ? null : _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : Text(
                          l10n.consultSubmitTotal(price),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.consultPayLater,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static tz.Location _zone(String? deviceZone) {
    try {
      if (deviceZone != null) return tz.getLocation(deviceZone);
    } catch (_) {}
    return tz.getLocation(ConsultationConfig.consultantTimezone);
  }

  ConsultationRequest _request() {
    final deviceZone = ref.read(deviceTimeZoneProvider).value;
    final profile = ref.read(birthProfileProvider);
    final email = _email.text.trim();
    final question = _question.text.trim();

    return ConsultationRequest(
      topic: _topic,
      minutes: _minutes,
      slotStart: _slot!,
      mode: _mode,
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      email: email.isEmpty ? null : email,
      question: question.isEmpty ? null : question,
      language: ref.read(languageProvider).code,
      priceLabel: ConsultationConfig.priceLabel(_minutes, deviceZone),
      birthDetails: profile == null || !_shareChart
          ? null
          : {
              'name': profile.name,
              'date_of_birth': DateFormat(
                'yyyy-MM-dd',
              ).format(profile.dateOfBirth),
              'birth_time': profile.birthTime,
              'place': [
                profile.location.city,
                profile.location.state,
                profile.location.country,
              ].whereType<String>().where((s) => s.isNotEmpty).join(', '),
              'latitude': profile.location.latitude,
              'longitude': profile.location.longitude,
              'timezone': profile.location.timezone,
            },
    );
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final request = _request();

    setState(() => _sending = true);
    try {
      await ref.read(consultationRepositoryProvider).submit(request);
      ref.invalidate(myConsultationsProvider);
      ref.invalidate(consultationSlotsProvider);
      if (!mounted) return;
      await _showSent(l10n);
      if (mounted) context.pushReplacement('/consult/bookings');
    } on ConsultationSlotTaken {
      ref.invalidate(consultationSlotsProvider);
      setState(() => _slot = null);
      messenger.showSnackBar(SnackBar(content: Text(l10n.consultSlotTaken)));
    } on ConsultationUnavailable {
      await _emailInstead(l10n, request);
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.consultFailed),
          action: SnackBarAction(
            label: l10n.consultEmailInstead,
            onPressed: () => _emailInstead(l10n, request),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showSent(AppLocalizations l10n) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(
        Icons.check_circle_rounded,
        color: AppColors.success,
        size: 40,
      ),
      title: Text(l10n.consultSentTitle),
      content: Text(l10n.consultSentBody),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.consultMyBookings),
        ),
      ],
    ),
  );

  /// The same request as an email to support, when the server can't take
  /// it.
  Future<void> _emailInstead(
    AppLocalizations l10n,
    ConsultationRequest r,
  ) async {
    final zone = tz.getLocation(ConsultationConfig.consultantTimezone);
    final when = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(tz.TZDateTime.from(r.slotStart, zone));
    final birth = r.birthDetails;
    final body = [
      l10n.consultTopic(r.topic.name),
      '${l10n.consultLengthTitle}: ${l10n.consultMinutes(r.minutes)} (${r.priceLabel})',
      '${l10n.consultTimeTitle}: $when (${ConsultationConfig.consultantTimezone})',
      l10n.consultMode(r.mode.name),
      '${l10n.consultName}: ${r.name}',
      '${l10n.consultPhone}: ${r.phone}',
      if (r.email != null) 'Email: ${r.email}',
      if (birth != null)
        'Birth: ${birth['date_of_birth']} ${birth['birth_time']}, ${birth['place']}',
      if (r.question != null) '\n${r.question}',
    ].join('\n');
    await launchUrl(
      Uri(
        scheme: 'mailto',
        path: supportEmail,
        query:
            'subject=${Uri.encodeComponent(l10n.consultEmailSubject(l10n.consultTopic(r.topic.name)))}'
            '&body=${Uri.encodeComponent(body)}',
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    Widget step(int n, String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            child: Text(
              '$n',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A2F5E), AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.16),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.consultSubtitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          step(1, l10n.consultStep1),
          step(2, l10n.consultStep2),
          step(3, l10n.consultStep3),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
  );
}

class _TopicCard extends StatelessWidget {
  final ConsultationTopic topic;
  final bool selected;
  final VoidCallback onTap;

  const _TopicCard({
    required this.topic,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final icon = switch (topic) {
      ConsultationTopic.kundli => Icons.auto_awesome_rounded,
      ConsultationTopic.marriage => Icons.favorite_rounded,
      ConsultationTopic.career => Icons.work_rounded,
      ConsultationTopic.vastu => Icons.home_work_rounded,
    };

    return _Selectable(
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
          const Spacer(),
          Text(
            l10n.consultTopic(topic.name),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.consultTopicHint(topic.name),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LengthCard extends StatelessWidget {
  final int minutes;
  final String price;
  final bool selected;
  final VoidCallback onTap;

  const _LengthCard({
    required this.minutes,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _Selectable(
      selected: selected,
      onTap: onTap,
      child: Column(
        children: [
          Text(
            context.l10n.consultMinutes(minutes),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            price,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String weekday;
  final String date;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
    required this.weekday,
    required this.date,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 72,
      child: _Selectable(
        selected: selected,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekday,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              date,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Selectable extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Selectable({
    required this.selected,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.14)
          : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.outline,
          width: selected ? 1.6 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
