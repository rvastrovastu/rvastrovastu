import '../entities/vastu_tip.dart';

abstract class VastuTipRepository {
  VastuTip getTipForDate(DateTime date);
}
