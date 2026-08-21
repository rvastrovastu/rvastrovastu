import '../../domain/entities/kundali.dart';
import '../../domain/models/kundali_input.dart';

abstract class AstrologyRepository {
  Future<Kundali> calculateKundali(KundaliInput input);
}
