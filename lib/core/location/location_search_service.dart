import '../../features/birth_profile/domain/entities/birth_location.dart';

abstract class LocationSearchService {
  Future<List<BirthLocation>> search(String query);
}
