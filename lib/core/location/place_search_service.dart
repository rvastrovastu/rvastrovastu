import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart';

import '../../features/birth_profile/domain/entities/birth_location.dart';
import 'location_search_service.dart';

/// Place search for birth locations.
///
/// Typing searches a bundled list of about 170,000 cities and towns
/// worldwide (every place with more than 1,000 people, from the GeoNames
/// gazetteer, CC BY 4.0). Smaller places come from the phone's own map
/// geocoder via [searchEverywhere]. Time zones are worked out from the
/// coordinates.
class PlaceSearchService implements LocationSearchService {
  static const citiesAsset = 'assets/places/cities.tsv';
  static const regionsAsset = 'assets/places/regions.tsv';
  static const countriesAsset = 'assets/places/countries.tsv';

  /// Countries listed first when names tie: India, then where the
  /// Indian diaspora mostly lives.
  static const preferredCountries = [
    'IN', 'US', 'NP', 'GB', 'CA', 'AU', 'AE', 'SG', 'NZ', 'LK', 'MY', //
    'ZA', 'KE', 'MU', 'FJ', 'TT', 'GY', 'SR', 'QA', 'SA', 'KW', 'OM', 'BH',
  ];

  final AssetBundle _bundle;
  final int limit;
  Future<PlaceIndex>? _index;

  PlaceSearchService({AssetBundle? bundle, this.limit = 12})
    : _bundle = bundle ?? rootBundle;

  /// Starts loading the city list so the first search is instant.
  void warmUp() => _load();

  Future<PlaceIndex> _load() {
    final existing = _index;
    if (existing != null) return existing;
    final loading = _loadIndex();
    _index = loading;
    // Let a later search retry if loading failed.
    loading.then<void>((_) {}, onError: (Object _) => _index = null);
    return loading;
  }

  Future<PlaceIndex> _loadIndex() async {
    final texts = await Future.wait([
      _bundle.loadString(citiesAsset, cache: false),
      _bundle.loadString(regionsAsset),
      _bundle.loadString(countriesAsset),
    ]);
    return compute(PlaceIndex.parse, texts);
  }

  @override
  Future<List<BirthLocation>> search(String query) async {
    if (normalizePlaceText(query.split(',').first).length < 2) return const [];
    final index = await _load();
    return [
      for (final i in index.find(query, limit: limit))
        BirthLocation(
          city: index.names[i],
          state: index.regions[i],
          country: index.countries[i],
          latitude: index.latitudes[i],
          longitude: index.longitudes[i],
          timezone: latLngToTimezoneString(
            index.latitudes[i],
            index.longitudes[i],
          ),
        ),
    ];
  }

  @override
  Future<List<BirthLocation>> searchEverywhere(String query) async {
    final text = query.trim();
    if (text.length < 3) return const [];
    try {
      final geocoding = Geocoding();
      final hits = await geocoding.locationFromAddress(text);
      final results = <BirthLocation>[];
      final seen = <String>{};
      for (final hit in hits.take(5)) {
        String? city;
        String? state;
        String? country;
        try {
          final marks = await geocoding.placemarkFromCoordinates(
            hit.latitude,
            hit.longitude,
          );
          if (marks.isNotEmpty) {
            final mark = marks.first;
            city = _firstFilled([
              mark.locality,
              mark.subLocality,
              mark.subAdministrativeArea,
              mark.name,
            ]);
            state = mark.administrativeArea;
            country = mark.country;
          }
        } catch (error) {
          debugPrint('[PLACES] reverse lookup failed: $error');
        }
        final location = BirthLocation(
          city: city ?? text.split(',').first.trim(),
          state: state,
          country: country,
          latitude: hit.latitude,
          longitude: hit.longitude,
          timezone: latLngToTimezoneString(hit.latitude, hit.longitude),
        );
        if (seen.add(location.displayName)) results.add(location);
      }
      return results;
    } catch (error) {
      // No geocoder on this platform, no network, or nothing found.
      debugPrint('[PLACES] map search failed: $error');
      return const [];
    }
  }

  static String? _firstFilled(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}

/// The bundled city list, held as parallel lists to stay compact.
class PlaceIndex {
  final List<String> names;

  /// Lower-case, accent-free names for matching.
  final List<String> keys;
  final Float64List latitudes;
  final Float64List longitudes;
  final List<String> countryCodes;
  final List<String?> regions;
  final List<String?> countries;

  PlaceIndex._(
    this.names,
    this.keys,
    this.latitudes,
    this.longitudes,
    this.countryCodes,
    this.regions,
    this.countries,
  );

  /// Builds the index from [texts]: the cities, regions and countries
  /// files, in that order. Runs in a background isolate.
  static PlaceIndex parse(List<String> texts) {
    final regionNames = <String, String>{};
    for (final line in texts[1].split('\n')) {
      final tab = line.indexOf('\t');
      if (tab > 0) regionNames[line.substring(0, tab)] = line.substring(tab + 1);
    }
    final countryNames = <String, String>{};
    for (final line in texts[2].split('\n')) {
      final tab = line.indexOf('\t');
      if (tab > 0) {
        countryNames[line.substring(0, tab)] = line.substring(tab + 1);
      }
    }

    final lines = texts[0].split('\n');
    final names = <String>[];
    final keys = <String>[];
    final lats = <double>[];
    final lngs = <double>[];
    final codes = <String>[];
    final regions = <String?>[];
    final countries = <String?>[];

    for (final line in lines) {
      final cols = line.split('\t');
      if (cols.length < 6) continue;
      final lat = double.tryParse(cols[2]);
      final lng = double.tryParse(cols[3]);
      if (lat == null || lng == null) continue;
      names.add(cols[0]);
      keys.add(cols[1].isEmpty ? cols[0].toLowerCase() : cols[1]);
      lats.add(lat);
      lngs.add(lng);
      codes.add(cols[4]);
      // '-' marks a place with no state or province.
      regions.add(regionNames['${cols[4]}.${cols[5]}']);
      countries.add(countryNames[cols[4]]);
    }

    return PlaceIndex._(
      names,
      keys,
      Float64List.fromList(lats),
      Float64List.fromList(lngs),
      codes,
      regions,
      countries,
    );
  }

  /// Indexes of the best matches for [query], best first.
  ///
  /// The text before the first comma is the place name; anything after it
  /// narrows by state or country ("Springfield, Illinois").
  List<int> find(String query, {int limit = 12}) {
    final parts = query.split(',');
    final name = normalizePlaceText(parts.first);
    final within = normalizePlaceText(parts.skip(1).join(' '));
    if (name.length < 2) return const [];

    final matches = <(int, int, int, int)>[];
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      final int tier;
      if (key == name) {
        tier = 0;
      } else if (key.startsWith(name)) {
        tier = 1;
      } else if (key.contains(' $name') || key.contains('-$name')) {
        tier = 2;
      } else if (name.length >= 4 && key.contains(name)) {
        tier = 3;
      } else {
        continue;
      }
      if (within.isNotEmpty) {
        final where = normalizePlaceText(
          '${regions[i] ?? ''} ${countries[i] ?? ''} ${countryCodes[i]}',
        );
        if (!where.contains(within)) continue;
      }
      final preferred = PlaceSearchService.preferredCountries.indexOf(
        countryCodes[i],
      );
      matches.add((
        tier,
        preferred < 0 ? 99 : preferred,
        key.length,
        i,
      ));
    }

    matches.sort((a, b) {
      var c = a.$1.compareTo(b.$1);
      if (c != 0) return c;
      c = a.$2.compareTo(b.$2);
      if (c != 0) return c;
      c = a.$3.compareTo(b.$3);
      if (c != 0) return c;
      return names[a.$4].compareTo(names[b.$4]);
    });

    return [for (final match in matches.take(limit)) match.$4];
  }
}

const _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', //
  'ă': 'a', 'ą': 'a', 'ç': 'c', 'ć': 'c', 'č': 'c', 'ď': 'd', 'đ': 'd',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e',
  'ě': 'e', 'ğ': 'g', 'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
  'ı': 'i', 'ł': 'l', 'ñ': 'n', 'ń': 'n', 'ň': 'n', 'ò': 'o', 'ó': 'o',
  'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ő': 'o', 'ř': 'r',
  'ś': 's', 'š': 's', 'ş': 's', 'ș': 's', 'ť': 't', 'ţ': 't', 'ț': 't',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u',
  'ý': 'y', 'ÿ': 'y', 'ź': 'z', 'ż': 'z', 'ž': 'z',
};

/// Lower-case, accent-free, single-spaced text for matching place names.
String normalizePlaceText(String text) {
  final lower = text.trim().toLowerCase();
  final buffer = StringBuffer();
  var space = false;
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    if (char.trim().isEmpty) {
      space = buffer.isNotEmpty;
      continue;
    }
    if (space) {
      buffer.write(' ');
      space = false;
    }
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}
