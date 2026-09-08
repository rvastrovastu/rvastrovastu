import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/local_vastu_tip_repository.dart';
import '../../domain/entities/vastu_tip.dart';
import '../../domain/repositories/vastu_tip_repository.dart';

final vastuTipRepositoryProvider = Provider<VastuTipRepository>((ref) {
  return const LocalVastuTipRepository();
});

final vastuTipProvider = Provider.family<VastuTip, DateTime>((ref, date) {
  final repository = ref.watch(vastuTipRepositoryProvider);

  return repository.getTipForDate(date);
});
