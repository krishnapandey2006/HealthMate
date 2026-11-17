// ignore_for_file: avoid_print
import 'package:healthmate_mb/services/facility_service.dart';

Future<void> main() async {
  final service = FacilityService();
  var failures = 0;

  try {
    for (final type in ['hospital', 'clinic', 'pharmacy']) {
      final started = DateTime.now();
      try {
        final result = await service.nearby(
          latitude: 19.2813,
          longitude: 72.8554,
          radiusKm: 8,
          type: type,
        );
        final elapsed = DateTime.now().difference(started).inMilliseconds;
        final facilities = result.facilities;
        final named = facilities
            .where((facility) => facility.name.trim().isNotEmpty)
            .length;
        final located = facilities
            .where(
                (facility) => facility.latitude != 0 || facility.longitude != 0)
            .length;
        final distances =
            facilities.map((facility) => facility.distanceKm ?? -1).toList();
        var sorted = true;
        for (var i = 1; i < distances.length; i++) {
          if (distances[i] < distances[i - 1]) sorted = false;
        }
        print(
          '$type: ${facilities.length} results in ${elapsed}ms source=${result.source} '
          'named=$named located=$located sorted=$sorted error=${result.error?.message} '
          'warning=${result.warning}',
        );
        for (final facility in facilities.take(5)) {
          print(
            '  - ${facility.name} | ${facility.type} | ${facility.distanceKm} km | '
            '${facility.address.isEmpty ? '(no address)' : facility.address} | phone=${facility.phone}',
          );
        }
        if (result.isError ||
            facilities.isEmpty ||
            named != facilities.length ||
            !sorted) {
          failures++;
        }
      } catch (error) {
        failures++;
        print('$type: FAILED -> $error');
      }
    }

    final started = DateTime.now();
    final places = await service.searchPlaces('Bhayandar');
    print('searchPlaces(Bhayandar): ${places.length} results in '
        '${DateTime.now().difference(started).inMilliseconds}ms');
    for (final place in places.take(3)) {
      print('  - ${place.displayName} (${place.latitude}, ${place.longitude})');
    }
    if (places.isEmpty) failures++;

    final reverse =
        await service.reverseGeocode(latitude: 19.2813, longitude: 72.8554);
    print(
        'reverseGeocode: ${reverse?.displayName} | city=${reverse?.city} state=${reverse?.state} '
        'postcode=${reverse?.postcode}');
    if (reverse == null) failures++;
  } finally {
    service.dispose();
  }

  if (failures > 0) {
    print('DIRECT FACILITY VERIFICATION FAILED ($failures case(s))');
    throw StateError('$failures direct facility case(s) failed');
  }
  print('DIRECT FACILITY VERIFICATION PASSED');
}
