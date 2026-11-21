import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/app_clock_provider.dart';
import '../../domain/entities/vastu_zone.dart';
import '../../layout/domain/vastu_analysis.dart';
import '../../layout/domain/vastu_layout.dart';
import '../../layout/presentation/vastu_layout_providers.dart';
import '../../layout/presentation/vastu_layout_text.dart';
import '../providers/vastu_tip_provider.dart';
import '../widgets/vastu_chakra.dart';
import 'package:rv_astro_vastu/core/telemetry/telemetry.dart';

part 'vastu_tip_page_properties.dart';
part 'vastu_tip_page_room_guide.dart';
part 'vastu_tip_page_widgets.dart';

/// The Vastu hub: an interactive 16-zone chakra, the tools, your saved
/// properties with their scores, a room-by-room placement guide and the
/// tip of the day.
class VastuTipPage extends ConsumerStatefulWidget {
  const VastuTipPage({super.key});

  @override
  ConsumerState<VastuTipPage> createState() => _VastuTipPageState();
}

class _VastuTipPageState extends ConsumerState<VastuTipPage> {
  VastuZone _zone = VastuZone.ne;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vastu)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChakraHero(
                zone: _zone,
                onSelect: (zone) => setState(() => _zone = zone),
              ),
              const SizedBox(height: 16),
              const _ToolsRow(),
              const SizedBox(height: 12),
              const _ExpertCta(),
              const SizedBox(height: 24),
              const _PropertiesSection(),
              const SizedBox(height: 24),
              const _RoomGuide(),
              const SizedBox(height: 24),
              const _TipCard(),
            ],
          ),
        ),
      ),
    );
  }
}
