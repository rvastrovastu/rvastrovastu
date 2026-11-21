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
import 'widgets/refund_policy.dart';
import 'package:rv_astro_vastu/core/telemetry/telemetry.dart';

part 'consultation_page_widgets.dart';

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
    // The price follows the phone number's country, so redraw as it's typed.
    _phone.addListener(_onPhoneChanged);
  }

  String? _lastPhoneCurrency;
  bool _phonePrefilled = false;

  /// Starts the phone field with the country code of the phone's region,
  /// so users type only their number. Runs once, after the first frame.
  void _prefillPhone(String? zone) {
    if (_phonePrefilled || zone == null) return;
    _phonePrefilled = true;
    final code = phoneCodeForZone(zone);
    if (code == null || _phone.text.trim().isNotEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _phone.text.trim().isEmpty) _phone.text = '$code ';
    });
  }

  void _onPhoneChanged() {
    final currency = ConsultationConfig.currency(
      phone: _phone.text,
      deviceZone: ref.read(deviceTimeZoneProvider).value,
    );
    if (currency != _lastPhoneCurrency) {
      _lastPhoneCurrency = currency;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone
      ..removeListener(_onPhoneChanged)
      ..dispose();
    _email.dispose();
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final deviceZone = ref.watch(deviceTimeZoneProvider).value;
    _prefillPhone(deviceZone);
    // Redraws once the server's prices arrive.
    ref.watch(consultationPricesProvider);
    final zone = _zone(deviceZone);
    final slotsAsync = ref.watch(consultationSlotsProvider);
    final profile = ref.watch(birthProfileProvider);
    final price = ConsultationConfig.priceLabel(
      _minutes,
      phone: _phone.text,
      deviceZone: deviceZone,
    );

    // Bookable times grouped by the user's own calendar day.
    final byDay = <DateTime, List<DateTime>>{};
    // Only start times where the whole session fits (a 60-minute session
    // needs the next half hour free too).
    final groups =
        slotsAsync.value?.slotsFor(_minutes) ??
        const <(DateTime, List<DateTime>)>[];
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
    // A longer session may no longer fit the time picked earlier.
    if (_slot != null && !times.contains(_slot)) _slot = null;
    final locale = l10n.localeName;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.consultTitle),
        actions: [
          IconButton(
            tooltip: l10n.consultMyBookings,
            onPressed: () => context.go('/consult/bookings'),
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
              Builder(
                builder: (context) {
                  // Tablets get short, wide cards. Phones keep the tall cards.
                  final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: tablet ? 2.7 : 1.35,
                    children: [
                      for (final topic in ConsultationTopic.values)
                        _TopicCard(
                          topic: topic,
                          selected: topic == _topic,
                          tablet: tablet,
                          onTap: () => setState(() => _topic = topic),
                        ),
                    ],
                  );
                },
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
                            phone: _phone.text,
                            deviceZone: deviceZone,
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
              _ModePicker(
                modes: ConsultationMode.values,
                selected: _mode,
                label: (mode) => l10n.consultMode(mode.name),
                icon: (mode) => switch (mode) {
                  ConsultationMode.phone => Icons.call_rounded,
                  ConsultationMode.whatsapp => Icons.chat_rounded,
                  ConsultationMode.video => Icons.videocam_rounded,
                },
                onChanged: (mode) => setState(() => _mode = mode),
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
                  helperText: l10n.consultPhoneHint,
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
                  onPressed: _sending ? null : _submit,
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
              const SizedBox(height: 4),
              Text(
                l10n.consultRefundShort,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Center(child: RefundPolicyLink()),
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
      priceLabel: ConsultationConfig.priceLabel(
        _minutes,
        phone: _phone.text,
        deviceZone: deviceZone,
      ),
      currency: ConsultationConfig.currency(
        phone: _phone.text,
        deviceZone: deviceZone,
      ),
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
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (_slot == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.consultPickTime)));
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) return;
    final request = _request();

    setState(() => _sending = true);
    try {
      final booked = await ref
          .read(consultationRepositoryProvider)
          .submit(request);
      ref.invalidate(myConsultationsProvider);
      ref.invalidate(consultationSlotsProvider);
      Telemetry.event('booking_created', {
        'minutes': request.minutes,
        'topic': request.topic.name,
      });
      if (!mounted) return;
      // Book and pay in one step: the slot is held while Checkout is open.
      await _payNow(l10n, messenger, booked.id);
      if (mounted) context.go('/consult/bookings');
    } on ConsultationSlotTaken {
      ref.invalidate(consultationSlotsProvider);
      setState(() => _slot = null);
      messenger.showSnackBar(SnackBar(content: Text(l10n.consultSlotTaken)));
    } on ConsultationNeedsSignIn {
      if (mounted) await _askToSignIn(l10n);
    } on ConsultationNotSetUp {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.consultNotSetUp),
          action: SnackBarAction(
            label: l10n.consultEmailInstead,
            onPressed: () => _emailInstead(l10n, request),
          ),
        ),
      );
    } catch (error, stack) {
      debugPrint('[CONSULT] submit failed: $error');
      Telemetry.recordError(error, stack, reason: 'consult_submit');
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

  /// Booking needs an account (guest sign-in isn't available): offer to
  /// sign in and come back here.
  Future<void> _askToSignIn(AppLocalizations l10n) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.consultSignInTitle),
        content: Text(l10n.consultSignInBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.authSignIn),
          ),
        ],
      ),
    );
    if (go == true && mounted) {
      context.push('/account?next=${Uri.encodeComponent('/consult')}');
    }
  }

  /// Opens Stripe Checkout for a booking just created. If it fails, the
  /// booking stays in My bookings with a Pay button.
  Future<void> _payNow(
    AppLocalizations l10n,
    ScaffoldMessengerState messenger,
    String? id,
  ) async {
    if (id == null) return;
    try {
      final url = await ref
          .read(consultationRepositoryProvider)
          .checkoutUrl(id);
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('Could not open $url');
      Telemetry.event('booking_checkout_opened');
    } catch (error, stack) {
      debugPrint('[CONSULT] payment failed: $error');
      Telemetry.recordError(error, stack, reason: 'consult_checkout');
      messenger.showSnackBar(SnackBar(content: Text(l10n.consultPayFailed)));
    }
  }

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
