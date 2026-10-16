import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dasha_birth_data.dart';
import '../../domain/entities/dasha_insight.dart';
import '../../domain/usecases/generate_dasha_insight.dart';
import 'dasha_provider.dart';

final dashaInsightGeneratorProvider = Provider<GenerateDashaInsight>((ref) {
  return GenerateDashaInsight();
});

final dashaInsightProvider = Provider.family<DashaInsight, DashaBirthData>((
  ref,
  birthData,
) {
  final mahadasha = ref.watch(currentDashaProvider(birthData));
  final antardasha = ref.watch(currentAntardashaProvider(birthData));
  final generator = ref.watch(dashaInsightGeneratorProvider);

  return generator.call(mahadasha: mahadasha, antardasha: antardasha);
});
