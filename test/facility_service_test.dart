import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate_mb/services/api_client.dart';
import 'package:healthmate_mb/services/facility_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('nearby parses Nominatim fields, filters and sorts by distance',
      () async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return http.Response(
        jsonEncode([
          {
            'place_id': 1,
            'osm_type': 'node',
            'osm_id': 101,
            'lat': '19.2915',
            'lon': '72.8620',
            'display_name': 'Karuna Hospital, Dahisar West, Mumbai',
            'name': 'Karuna Hospital',
            'type': 'hospital',
            'address': {
              'road': 'Vallabh Nagar Ring Road',
              'suburb': 'Dahisar West',
              'city': 'Mumbai',
              'postcode': '400068',
            },
            'extratags': {
              'phone': '+91 22 2890 1234',
              'opening_hours': '24/7',
              'website': 'https://example.org/karuna',
            },
          },
          {
            'place_id': 2,
            'osm_type': 'node',
            'osm_id': 102,
            'lat': '19.2916',
            'lon': '72.8621',
            'display_name': 'Karuna Hospital, Dahisar West, Mumbai',
            'name': 'Karuna Hospital',
            'type': 'hospital',
            'address': {'suburb': 'Dahisar West'},
          },
          {
            'place_id': 3,
            'osm_type': 'node',
            'osm_id': 103,
            'lat': '19.2950',
            'lon': '72.8700',
            'display_name': 'Navneet Hi-Tech Hospital',
            'name': 'Navneet Hi-Tech Hospital',
            'type': 'hospital',
            'address': {'road': 'Lokmanya Tilak Road', 'city': 'Mumbai'},
          },
          {
            'place_id': 4,
            'osm_type': 'node',
            'osm_id': 104,
            'lat': '19.2900',
            'lon': '72.8600',
            'display_name': 'Wellness Pharmacy',
            'name': 'Wellness Pharmacy',
            'type': 'pharmacy',
          },
          {
            'place_id': 5,
            'osm_type': 'node',
            'osm_id': 105,
            'lat': '19.7600',
            'lon': '73.2000',
            'display_name': 'Far Away Hospital',
            'name': 'Far Away Hospital',
            'type': 'hospital',
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = FacilityService(
      client: client,
      preferProxy: false,
      allowDirect: true,
    );
    addTearDown(service.dispose);

    final result = await service.nearby(
      latitude: 19.2813,
      longitude: 72.8554,
      radiusKm: 8,
      type: 'hospital',
    );

    expect(result.isError, isFalse);
    expect(result.facilities, hasLength(2));
    expect(result.facilities.first.name, 'Karuna Hospital');
    expect(result.facilities.first.address, contains('Dahisar West'));
    expect(result.facilities.first.phone, '+91 22 2890 1234');
    expect(result.facilities.first.openingHours, '24/7');
    expect(result.facilities.first.website, 'https://example.org/karuna');
    expect(result.facilities.first.distanceKm, isNotNull);
    expect(result.facilities.first.distanceKm!, lessThan(2));
    expect(
      result.facilities.map((facility) => facility.name),
      isNot(contains('Wellness Pharmacy')),
    );
    expect(
      result.facilities.map((facility) => facility.name),
      isNot(contains('Far Away Hospital')),
    );

    final request = requests.single;
    expect(request.host, 'nominatim.openstreetmap.org');
    expect(request.path, '/search');
    expect(request.queryParameters['q'], 'hospital');
    expect(request.queryParameters['bounded'], '1');
    expect(request.queryParameters['limit'], '40');
    expect(request.queryParameters['viewbox'], isNotNull);
  });

  test('an honest empty Nominatim answer is a warning, not an error', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'nominatim.openstreetmap.org') {
        return http.Response('[]', 200);
      }
      // Overpass is tried afterwards for richer coverage.
      return http.Response('{"elements":[]}', 200);
    });
    final service = FacilityService(
      client: client,
      preferProxy: false,
      allowDirect: true,
    );
    addTearDown(service.dispose);

    final result = await service.nearby(
      latitude: 19.2813,
      longitude: 72.8554,
      radiusKm: 2,
      type: 'clinic',
    );

    expect(result.facilities, isEmpty);
    expect(result.isError, isFalse);
    expect(result.warning, contains('No matching healthcare facilities'));
  });

  test('upstream failures produce a retryable, honest error', () async {
    final client = MockClient((request) async => http.Response('down', 500));
    final service = FacilityService(
      client: client,
      preferProxy: false,
      allowDirect: true,
    );
    addTearDown(service.dispose);

    final result = await service.nearby(
      latitude: 19.2813,
      longitude: 72.8554,
      radiusKm: 8,
      type: 'pharmacy',
    );

    expect(result.facilities, isEmpty);
    expect(result.isError, isTrue);
    expect(result.error?.type, ApiErrorType.server);
    expect(result.error?.message, contains('unavailable'));
  });

  test('rate limiting is reported without inventing facilities', () async {
    final client =
        MockClient((request) async => http.Response('slow down', 429));
    final service = FacilityService(
      client: client,
      preferProxy: false,
      allowDirect: true,
    );
    addTearDown(service.dispose);

    final result = await service.nearby(
      latitude: 19.2813,
      longitude: 72.8554,
      radiusKm: 8,
      type: 'clinic',
    );

    expect(result.facilities, isEmpty);
    expect(result.isError, isTrue);
    expect(result.error?.type, ApiErrorType.rateLimit);
    expect(result.error?.message, contains('busy'));
  });
}
