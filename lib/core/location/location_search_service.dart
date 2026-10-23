import '../../features/birth_profile/domain/entities/birth_location.dart';

abstract class LocationSearchService {
  /// Fast suggestions while typing.
  Future<List<BirthLocation>> search(String query);

  /// A slower, wider lookup for places the quick search doesn't know
  /// (small towns and villages). Empty when unavailable.
  Future<List<BirthLocation>> searchEverywhere(String query);
}
