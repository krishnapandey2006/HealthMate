import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../app/app_config.dart';
import '../models/facility.dart';
import 'api_client.dart';

const bool _isWebBuild = bool.fromEnvironment('dart.library.js_util');

class PlaceResult {
  final String displayName;
  final double latitude;
  final double longitude;

  const PlaceResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
}

/// Human-readable place details for a set of coordinates, used only when the
/// user explicitly asks HealthMate to detect their area.
class DetectedPlace {
  final String displayName;
  final String state;
  final String city;
  final String postcode;
  final double latitude;
  final double longitude;

  const DetectedPlace({
    required this.displayName,
    required this.state,
    required this.city,
    required this.postcode,
    required this.latitude,
    required this.longitude,
  });
}

class FacilityResult {
  final List<Facility> facilities;
  final String? warning;
  final ApiException? error;
  final String source;

  const FacilityResult({
    required this.facilities,
    this.warning,
    this.error,
    this.source = 'OpenStreetMap',
  });

  bool get isError => error != null;
}

class _CachedFacilities {
  final FacilityResult result;
  final DateTime savedAt;

  const _CachedFacilities(this.result, this.savedAt);

  bool get isFresh =>
      DateTime.now().difference(savedAt) < const Duration(minutes: 5);
}

class _FacilityAttempt {
  final List<Facility> facilities;
  final ApiException? error;
  final bool responded;

  const _FacilityAttempt({
    required this.facilities,
    this.error,
    this.responded = false,
  });
}

class FacilityService {
  static const _overpassEndpoint = 'https://overpass-api.de/api/interpreter';
  static const _userAgent =
      'HealthMate/1.0 (healthcare information app; nearby care)';

  final ApiClient _api;
  final http.Client _directClient;
  final bool _preferProxy;
  final bool _allowDirect;
  final Map<String, _CachedFacilities> _cache = {};
  final Map<String, Future<FacilityResult>> _inFlight = {};

  FacilityService({
    ApiClient? api,
    http.Client? client,
    bool? preferProxy,
    bool? allowDirect,
  })  : _api = api ?? ApiClient(),
        _directClient = client ?? http.Client(),
        // Native builds must not rely on the localhost development proxy.
        // Direct public HTTPS endpoints work on the phone itself. Browsers
        // stay proxy-only because these providers do not send CORS headers.
        _preferProxy = preferProxy ??
            (api != null || _isWebBuild || AppConfig.hasExplicitProxy),
        _allowDirect = allowDirect ?? (client != null || !_isWebBuild);

  Future<List<PlaceResult>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    if (_preferProxy) {
      try {
        final json = await _api.getJson(
          '/api/geocode',
          query: {'q': trimmed, 'limit': '5'},
          timeout: const Duration(seconds: 10),
          retries: 0,
        );
        final raw = json['results'];
        if (raw is List) {
          final places = raw
              .whereType<Map>()
              .map((item) => _placeFromMap(Map<String, dynamic>.from(item)))
              .whereType<PlaceResult>()
              .toList();
          if (places.isNotEmpty) return places;
        }
      } on ApiException {
        // Fall through to the public Nominatim endpoint.
      }
    }

    if (!_allowDirect) return const [];

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'jsonv2',
        'limit': '5',
        'addressdetails': '1',
        'q': trimmed,
      });
      final response = await _directClient.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': _userAgent,
        },
      ).timeout(const Duration(seconds: 9));
      if (response.statusCode == 429) {
        throw const ApiException(
          ApiErrorType.rateLimit,
          'The place search service is busy. Please wait a moment and try again.',
        );
      }
      if (response.statusCode != 200) {
        throw ApiException(
          ApiErrorType.server,
          'The place search service is unavailable right now.',
          statusCode: response.statusCode,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => _placeFromMap(Map<String, dynamic>.from(item)))
            .whereType<PlaceResult>()
            .toList();
      }
    } catch (_) {
      // Return an empty list; the UI explains that search is unavailable.
    }
    return const [];
  }

  Future<DetectedPlace?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (_preferProxy) {
      try {
        final json = await _api.getJson(
          '/api/geocode',
          query: {
            'reverse': '1',
            'lat': latitude.toStringAsFixed(5),
            'lon': longitude.toStringAsFixed(5),
          },
          timeout: const Duration(seconds: 12),
          retries: 0,
        );
        final raw = json['result'];
        if (raw is Map) {
          final place = _detectedFromMap(Map<String, dynamic>.from(raw));
          if (place != null) return place;
        }
      } on ApiException {
        // Fall through to the public Nominatim endpoint.
      }
    }

    if (!_allowDirect) return null;

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'zoom': '10',
        'addressdetails': '1',
        'lat': '$latitude',
        'lon': '$longitude',
      });
      final response = await _directClient.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': _userAgent,
        },
      ).timeout(const Duration(seconds: 9));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          return _detectedFromMap(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (_) {
      // The screen explains that automatic detection failed and lets the user
      // choose an area manually.
    }
    return null;
  }

  DetectedPlace? _detectedFromMap(Map<String, dynamic> map) {
    final address = map['address'] is Map
        ? Map<String, dynamic>.from(map['address'] as Map)
        : <String, dynamic>{};
    final displayName =
        (map['display_name'] ?? map['name'] ?? '').toString().trim();
    final state = (map['state'] ?? address['state'] ?? '').toString().trim();
    final city = (map['city'] ??
            address['city'] ??
            address['town'] ??
            address['village'] ??
            address['county'] ??
            '')
        .toString()
        .trim();
    if (displayName.isEmpty && state.isEmpty && city.isEmpty) return null;
    return DetectedPlace(
      displayName: displayName,
      state: state,
      city: city,
      postcode:
          (map['postcode'] ?? address['postcode'] ?? '').toString().trim(),
      latitude: _asDouble(map['lat']),
      longitude: _asDouble(map['lon']),
    );
  }

  PlaceResult? _placeFromMap(Map<String, dynamic> map) {
    final lat = _asDouble(map['lat'] ?? map['latitude']);
    final lon = _asDouble(map['lon'] ?? map['longitude']);
    final name = (map['display_name'] ?? map['name'] ?? '').toString().trim();
    if (name.isEmpty || (lat == 0 && lon == 0)) return null;
    return PlaceResult(displayName: name, latitude: lat, longitude: lon);
  }

  Future<FacilityResult> nearby({
    required double latitude,
    required double longitude,
    double radiusKm = 8,
    String type = 'all',
    bool forceRefresh = false,
  }) async {
    final key = '${latitude.toStringAsFixed(3)}|${longitude.toStringAsFixed(3)}'
        '|${radiusKm.toStringAsFixed(1)}|$type';
    final cached = _cache[key];
    if (!forceRefresh && cached != null && cached.isFresh) {
      return cached.result;
    }

    final running = _inFlight[key];
    if (running != null) return running;

    final future = _loadNearby(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      type: type,
      cached: cached,
    );
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<FacilityResult> _loadNearby({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required String type,
    required _CachedFacilities? cached,
  }) async {
    ApiException? failure;
    FacilityResult? proxyEmpty;

    if (_preferProxy) {
      try {
        final result = await _proxyNearby(
          latitude: latitude,
          longitude: longitude,
          radiusKm: radiusKm,
          type: type,
        );
        if (result.facilities.isNotEmpty) {
          _cache[_cacheKey(latitude, longitude, radiusKm, type)] =
              _CachedFacilities(result, DateTime.now());
          return result;
        }
        proxyEmpty = result;
      } on ApiException catch (error) {
        failure = error;
      }
    }

    if (_allowDirect) {
      try {
        final attempt = await _directNearby(
          latitude: latitude,
          longitude: longitude,
          radiusKm: radiusKm,
          type: type,
        );
        if (attempt.facilities.isNotEmpty) {
          final result = FacilityResult(
            facilities: attempt.facilities,
            source: attempt.error == null
                ? 'OpenStreetMap / Nominatim'
                : 'OpenStreetMap / Overpass',
          );
          _cache[_cacheKey(latitude, longitude, radiusKm, type)] =
              _CachedFacilities(result, DateTime.now());
          return result;
        }
        if (attempt.responded) {
          return proxyEmpty ??
              const FacilityResult(
                facilities: [],
                source: 'OpenStreetMap',
                warning:
                    'No matching healthcare facilities were found within this radius. Try a wider area or search another location.',
              );
        }
        if (attempt.error != null) failure ??= attempt.error;
      } catch (_) {
        failure ??= const ApiException(
          ApiErrorType.network,
          'Nearby facilities could not be loaded. Check your connection and try again.',
        );
      }
    }

    if (proxyEmpty != null) return proxyEmpty;

    if (cached != null && cached.result.facilities.isNotEmpty) {
      return FacilityResult(
        facilities: cached.result.facilities,
        source: cached.result.source,
        warning:
            'Live results could not be refreshed right now. Showing the last results for this area.',
      );
    }

    return FacilityResult(
      facilities: const [],
      source: 'OpenStreetMap',
      error: failure ??
          const ApiException(
            ApiErrorType.network,
            'Nearby facilities could not be loaded. Check your connection and try again.',
          ),
    );
  }

  String _cacheKey(double lat, double lon, double radiusKm, String type) =>
      '${lat.toStringAsFixed(3)}|${lon.toStringAsFixed(3)}'
      '|${radiusKm.toStringAsFixed(1)}|$type';

  Future<FacilityResult> _proxyNearby({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required String type,
  }) async {
    final json = await _api.getJson(
      '/api/facilities',
      query: {
        'lat': latitude.toStringAsFixed(5),
        'lon': longitude.toStringAsFixed(5),
        'radius': radiusKm.toStringAsFixed(1),
        'type': type,
      },
      // The proxy races two upstream providers. It normally answers in a few
      // seconds; a dead proxy should not stall the phone for a minute.
      timeout: const Duration(seconds: 14),
      retries: 0,
    );
    final raw = json['facilities'];
    final facilities = <Facility>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final facility = Facility.fromMap(Map<String, dynamic>.from(item));
          if (facility.name.trim().isNotEmpty &&
              (facility.latitude != 0 || facility.longitude != 0)) {
            facilities.add(facility);
          }
        }
      }
    }
    return FacilityResult(
      facilities: _dedupe(facilities),
      warning: json['warning']?.toString(),
      source: json['source']?.toString() ?? 'OpenStreetMap',
    );
  }

  Future<_FacilityAttempt> _directNearby({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required String type,
  }) async {
    ApiException? nominatimError;
    try {
      final facilities = await _nominatimFacilities(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        type: type,
      );
      if (facilities.isNotEmpty) {
        return _FacilityAttempt(facilities: facilities, responded: true);
      }

      // Nominatim answered honestly with no matches. Overpass can still add
      // richer coverage, but a failure there must not hide that empty answer.
      final overpass = await _overpassAttempt(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        type: type,
      );
      if (overpass.facilities.isNotEmpty) return overpass;
      return const _FacilityAttempt(facilities: [], responded: true);
    } on ApiException catch (error) {
      nominatimError = error;
    }

    final overpass = await _overpassAttempt(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      type: type,
    );
    if (overpass.facilities.isNotEmpty || overpass.responded) return overpass;
    return _FacilityAttempt(
      facilities: const [],
      error: overpass.error ?? nominatimError,
    );
  }

  Future<_FacilityAttempt> _overpassAttempt({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required String type,
  }) async {
    try {
      final facilities = await _overpassFacilities(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        type: type,
      );
      return _FacilityAttempt(facilities: facilities, responded: true);
    } on ApiException catch (error) {
      return _FacilityAttempt(facilities: const [], error: error);
    }
  }

  Future<List<Facility>> _nominatimFacilities({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required String type,
  }) async {
    final firstQuery = type == 'all' ? 'hospital' : type;
    final facilities = await _nominatimQuery(
      query: firstQuery,
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      requestedType: type,
    );

    // Hospitals are the priority for Nearby Care. Clinics are added only when
    // hospitals are sparse, respecting Nominatim's one-request-per-second
    // public usage policy.
    if (type == 'all' && facilities.length < 12) {
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      facilities.addAll(
        await _nominatimQuery(
          query: 'clinic',
          latitude: latitude,
          longitude: longitude,
          radiusKm: radiusKm,
          requestedType: type,
        ),
      );
    }
    return _dedupe(facilities);
  }

  Future<List<Facility>> _nominatimQuery({
    required String query,
    required double latitude,
    required double longitude,
    required double radiusKm,
    required String requestedType,
  }) async {
    final latDelta = radiusKm / 111.32;
    final lonDelta = radiusKm /
        (111.32 * math.max(0.01, math.cos(latitude * math.pi / 180)));
    final viewbox = [
      longitude - lonDelta,
      latitude + latDelta,
      longitude + lonDelta,
      latitude - latDelta,
    ].join(',');

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'jsonv2',
      'limit': '40',
      'addressdetails': '1',
      'extratags': '1',
      'bounded': '1',
      'viewbox': viewbox,
      'q': query,
    });

    final response = await _directClient.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'User-Agent': _userAgent,
      },
    ).timeout(const Duration(seconds: 9));

    if (response.statusCode == 429) {
      throw const ApiException(
        ApiErrorType.rateLimit,
        'The nearby facility service is busy. Please wait a moment and try again.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        ApiErrorType.server,
        'The nearby facility service is unavailable right now.',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'The nearby facility service returned an unreadable response.',
      );
    }

    final facilities = <Facility>[];
    for (final item in decoded.whereType<Map>()) {
      final facility = _facilityFromNominatim(
        Map<String, dynamic>.from(item),
        latitude,
        longitude,
        requestedType,
      );
      if (facility != null && (facility.distanceKm ?? 0) <= radiusKm * 1.05) {
        facilities.add(facility);
      }
    }
    return facilities;
  }

  Facility? _facilityFromNominatim(
    Map<String, dynamic> result,
    double originLat,
    double originLon,
    String requestedType,
  ) {
    final lat = _asDouble(result['lat']);
    final lon = _asDouble(result['lon']);
    if (lat == 0 && lon == 0) return null;

    final rawType =
        '${result['type'] ?? ''} ${result['class'] ?? ''}'.toLowerCase();
    String? type;
    if (rawType.contains('pharmacy') || rawType.contains('chemist')) {
      type = 'pharmacy';
    } else if (rawType.contains('hospital')) {
      type = 'hospital';
    } else if (rawType.contains('clinic') ||
        rawType.contains('doctor') ||
        rawType.contains('dentist') ||
        rawType.contains('dispensary') ||
        rawType.contains('health_centre') ||
        rawType.contains('health centre')) {
      type = 'clinic';
    }
    if (type == null) return null;
    if (requestedType != 'all' && type != requestedType) return null;

    final address = result['address'] is Map
        ? Map<String, dynamic>.from(result['address'] as Map)
        : <String, dynamic>{};
    final displayName = (result['display_name'] ?? '').toString().trim();
    final name = (result['name'] ??
            (displayName.isNotEmpty ? displayName.split(',').first : ''))
        .toString()
        .trim();
    if (name.isEmpty) return null;

    final addressParts = [
      address['house_number'],
      address['road'],
      address['neighbourhood'],
      address['suburb'],
      address['city'] ?? address['town'] ?? address['village'],
      address['postcode'],
    ]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .map((value) => value.toString().trim())
        .toList();

    final extra = result['extratags'] is Map
        ? Map<String, dynamic>.from(result['extratags'] as Map)
        : <String, dynamic>{};

    final distance = _haversineKm(originLat, originLon, lat, lon);
    return Facility(
      id: 'nominatim:${result['osm_type'] ?? ''}:'
          '${result['osm_id'] ?? result['place_id'] ?? '$lat,$lon'}',
      name: name,
      type: type,
      address: addressParts.join(', '),
      phone: _cleanPhone(extra['phone'] ?? extra['contact:phone']),
      website: _cleanUrl(extra['website'] ?? extra['contact:website']),
      latitude: lat,
      longitude: lon,
      distanceKm: double.parse(distance.toStringAsFixed(2)),
      openingHours: _cleanText(extra['opening_hours'], 120),
    );
  }

  Future<List<Facility>> _overpassFacilities({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required String type,
  }) async {
    final amenity = _amenityFilter(type);
    final radius = (radiusKm * 1000).round();
    final query = '''
[out:json][timeout:10];
(
  node["amenity"~"$amenity"](around:$radius,$latitude,$longitude);
  way["amenity"~"$amenity"](around:$radius,$latitude,$longitude);
  relation["amenity"~"$amenity"](around:$radius,$latitude,$longitude);
);
out center tags 80;
''';
    final uri = Uri.parse(_overpassEndpoint).replace(
      queryParameters: {'data': query},
    );
    final response = await _directClient.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'User-Agent': _userAgent,
      },
    ).timeout(const Duration(seconds: 9));

    if (response.statusCode == 429) {
      throw const ApiException(
        ApiErrorType.rateLimit,
        'The nearby facility service is busy. Please wait a moment and try again.',
      );
    }
    if (response.statusCode != 200) {
      throw ApiException(
        ApiErrorType.server,
        'The nearby facility service is unavailable right now.',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['elements'] is! List) {
      throw const ApiException(
        ApiErrorType.invalidResponse,
        'The nearby facility service returned an unreadable response.',
      );
    }

    final facilities = (decoded['elements'] as List)
        .whereType<Map>()
        .map((element) => _facilityFromOverpass(
              Map<String, dynamic>.from(element),
              latitude,
              longitude,
              type,
            ))
        .whereType<Facility>()
        .toList();
    return _dedupe(facilities);
  }

  String _amenityFilter(String type) {
    switch (type) {
      case 'hospital':
        return 'hospital';
      case 'clinic':
        return 'clinic|doctors';
      case 'pharmacy':
        return 'pharmacy';
      default:
        return 'hospital|clinic|doctors|pharmacy';
    }
  }

  Facility? _facilityFromOverpass(
    Map<String, dynamic> element,
    double originLat,
    double originLon,
    String requestedType,
  ) {
    final tags = element['tags'] is Map
        ? Map<String, dynamic>.from(element['tags'] as Map)
        : <String, dynamic>{};
    final name = (tags['name'] ?? tags['name:en'] ?? tags['operator'] ?? '')
        .toString()
        .trim();
    // Unnamed OSM entries are not useful as hospital names and must not be
    // presented as if they were a real facility name.
    if (name.isEmpty) return null;

    final lat = _asDouble(
      element['lat'] ??
          (element['center'] is Map ? element['center']['lat'] : null),
    );
    final lon = _asDouble(
      element['lon'] ??
          (element['center'] is Map ? element['center']['lon'] : null),
    );
    if (lat == 0 && lon == 0) return null;

    var type = (tags['amenity'] ?? 'hospital').toString();
    if (type == 'doctors') type = 'clinic';
    if (requestedType != 'all' && type != requestedType) return null;

    final addressParts = [
      tags['addr:housenumber'],
      tags['addr:street'],
      tags['addr:suburb'],
      tags['addr:city'],
      tags['addr:postcode'],
    ]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .map((value) => value.toString().trim())
        .toList();

    return Facility(
      id: (element['id'] ?? '$lat,$lon').toString(),
      name: name,
      type: type,
      address: addressParts.join(', '),
      phone: _cleanPhone(tags['phone'] ?? tags['contact:phone']),
      website: _cleanUrl(tags['website'] ?? tags['contact:website']),
      latitude: lat,
      longitude: lon,
      distanceKm: double.parse(
        _haversineKm(originLat, originLon, lat, lon).toStringAsFixed(2),
      ),
      openingHours: _cleanText(tags['opening_hours'], 120),
    );
  }

  List<Facility> _dedupe(List<Facility> input) {
    final byId = <String, Facility>{};
    for (final facility in input) {
      final key = _normalizeName(facility.name);
      final existing = byId[key];
      if (existing == null) {
        byId[key] = facility;
        continue;
      }
      final distance = _haversineKm(
        existing.latitude,
        existing.longitude,
        facility.latitude,
        facility.longitude,
      );
      // The same OSM object can appear in both providers, sometimes with a
      // slightly different label. Treat same-name facilities within 200 m as
      // one result and keep the one with the richer contact details.
      if (distance <= 0.2) {
        final keepNew = (existing.phone == null && facility.phone != null) ||
            (existing.address.isEmpty && facility.address.isNotEmpty);
        if (keepNew) byId[key] = facility;
      } else {
        byId['${key}_${facility.id}'] = facility;
      }
    }
    final list = byId.values.toList()
      ..sort(
        (a, b) => (a.distanceKm ?? double.infinity)
            .compareTo(b.distanceKm ?? double.infinity),
      );
    return list.take(80).toList(growable: false);
  }

  String _normalizeName(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  String? _cleanPhone(dynamic raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  String? _cleanText(dynamic raw, int maxLength) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value.length > maxLength
        ? '${value.substring(0, maxLength - 1).trim()}…'
        : value;
  }

  String? _cleanUrl(dynamic raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri.toString();
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    return earthRadiusKm * 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
  }

  double _radians(double degrees) => degrees * math.pi / 180;

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  void dispose() {
    _api.close();
    _directClient.close();
  }
}
