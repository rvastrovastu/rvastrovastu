import '../../features/birth_profile/domain/entities/birth_location.dart';
import 'location_search_service.dart';

class MockLocationSearchService implements LocationSearchService {
  static const locations = [
    BirthLocation(
      city: 'Bhopal',
      state: 'Madhya Pradesh',
      country: 'India',
      latitude: 23.2599,
      longitude: 77.4126,
      timezone: 'Asia/Kolkata',
    ),
    BirthLocation(
      city: 'Dallas',
      state: 'Texas',
      country: 'USA',
      latitude: 32.7767,
      longitude: -96.7970,
      timezone: 'America/Chicago',
    ),
    BirthLocation(
      city: 'Prosper',
      state: 'Texas',
      country: 'USA',
      latitude: 33.2362,
      longitude: -96.8011,
      timezone: 'America/Chicago',
    ),
    BirthLocation(
      city: 'New York',
      state: 'New York',
      country: 'USA',
      latitude: 40.7128,
      longitude: -74.0060,
      timezone: 'America/New_York',
    ),
    BirthLocation(
      city: 'Mumbai',
      state: 'Maharashtra',
      country: 'India',
      latitude: 19.0760,
      longitude: 72.8777,
      timezone: 'Asia/Kolkata',
    ),
    BirthLocation(
      city: 'Delhi',
      state: 'Delhi',
      country: 'India',
      latitude: 28.6139,
      longitude: 77.2090,
      timezone: 'Asia/Kolkata',
    ),
  ];

  @override
  Future<List<BirthLocation>> search(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final normalized = query.trim().toLowerCase();

    if (normalized.isEmpty) {
      return [];
    }

    return locations.where((location) {
      return location.city.toLowerCase().contains(normalized) ||
          (location.state?.toLowerCase().contains(normalized) ?? false) ||
          (location.country?.toLowerCase().contains(normalized) ?? false);
    }).toList();
  }
}
