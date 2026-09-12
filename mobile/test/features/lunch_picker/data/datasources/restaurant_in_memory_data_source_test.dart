import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/lunch_picker/data/datasources/restaurant_in_memory_data_source.dart';

void main() {
  const dataSource = RestaurantInMemoryDataSource();

  test('returns a non-empty, name-only snapshot around Bách Khoa', () async {
    final result = await dataSource.fetchNearby(
      lat: 21.0045,
      lon: 105.8430,
      radiusMeters: 900,
    );

    expect(result, isNotEmpty);
    expect(result.every((r) => r.name.isNotEmpty), true);
  });

  test('every result is sorted by distance, nearest first', () async {
    final result = await dataSource.fetchNearby(
      lat: 21.0045,
      lon: 105.8430,
      radiusMeters: 2000,
    );

    for (var i = 1; i < result.length; i++) {
      expect(
        result[i].distanceMeters,
        greaterThanOrEqualTo(result[i - 1].distanceMeters),
      );
    }
  });

  test('a tight radius returns fewer results than a wide one', () async {
    final tight = await dataSource.fetchNearby(
      lat: 21.0045,
      lon: 105.8430,
      radiusMeters: 100,
    );
    final wide = await dataSource.fetchNearby(
      lat: 21.0045,
      lon: 105.8430,
      radiusMeters: 5000,
    );

    expect(tight.length, lessThan(wide.length));
  });

  test('querying from far outside every baked node returns nothing', () async {
    // The snapshot spans a few km across Hanoi (nodes mixed in from more
    // than one demo area), so "far away" has to clear all of it.
    final result = await dataSource.fetchNearby(
      lat: 21.2,
      lon: 106.0,
      radiusMeters: 900,
    );

    expect(result, isEmpty);
  });
}
