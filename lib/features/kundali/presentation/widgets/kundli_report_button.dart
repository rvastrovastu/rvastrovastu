import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../membership/domain/membership.dart';
import '../../../membership/presentation/providers/membership_provider.dart';
import '../../../membership/presentation/widgets/premium_gate.dart';

import '../../../../core/localization/language_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../astrology/domain/entities/kundali.dart';
import '../../../birth_profile/presentation/providers/birth_profile_provider.dart';
import '../../../dasha/domain/entities/dasha_birth_data.dart';
import '../../../dasha/presentation/providers/dasha_provider.dart';
import '../../../dosha/presentation/providers/dosha_provider.dart';
import '../../../gochar/presentation/providers/gochar_provider.dart';
import '../../data/services/kundli_pdf_service.dart';

/// Builds the full Kundli PDF and opens the system print/share sheet.
class KundliReportButton extends ConsumerStatefulWidget {
  final Kundali kundali;

  const KundliReportButton({super.key, required this.kundali});

  @override
  ConsumerState<KundliReportButton> createState() =>
      _KundliReportButtonState();
}

class _KundliReportButtonState extends ConsumerState<KundliReportButton> {
  bool _busy = false;

  Future<void> _export() async {
    if (!ref.read(canUseProvider(PremiumFeature.kundliPdf))) {
      await openPaywall(context, PremiumFeature.kundliPdf);
      return;
    }
    final profile = ref.read(birthProfileProvider);
    if (profile == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final uiL10n = AppLocalizations.of(context);
    setState(() => _busy = true);

    try {
      // The bundled PDF font covers Latin and Devanagari only.
      final code = ref.read(languageProvider).code;
      final l10n = lookupAppLocalizations(
        Locale(code == 'hi' ? 'hi' : 'en'),
      );

      final birthData = DashaBirthData(
        birthDate: profile.dateOfBirth,
        moonLongitude: widget.kundali.moonLongitude,
      );
      final timeline = ref.read(dashaTimelineProvider(birthData));

      final doshas = await ref
          .read(doshaReportProvider.future)
          .catchError((Object _) => null);
      final transits = await ref
          .read(gocharReportProvider.future)
          .catchError((Object _) => null);

      final bytes = await const KundliPdfService().build(
        KundliReportData(
          name: profile.name,
          dateOfBirth: profile.dateOfBirth,
          birthTime: profile.birthTime,
          place: profile.location.displayName,
          kundali: widget.kundali,
          mahadashas: timeline.periods,
          currentMahadasha: ref.read(currentDashaProvider(birthData)),
          currentAntardasha: ref.read(currentAntardashaProvider(birthData)),
          doshas: doshas,
          transits: transits,
        ),
        l10n,
      );

      await Printing.layoutPdf(
        name: 'kundli_${profile.name.replaceAll(RegExp(r'\s+'), '_')}.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (error) {
      debugPrint('[KUNDLI PDF] $error');
      messenger.showSnackBar(
        SnackBar(content: Text(uiL10n.kundliReportUnable)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unlocked = ref.watch(canUseProvider(PremiumFeature.kundliPdf));

    return FilledButton.icon(
      onPressed: _busy ? null : _export,
      icon: _busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              unlocked
                  ? Icons.picture_as_pdf_outlined
                  : Icons.lock_outline_rounded,
            ),
      label: Text(l10n.kundliReportDownload),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    );
  }
}
