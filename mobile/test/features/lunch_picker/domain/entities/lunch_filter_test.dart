import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/lunch_picker/domain/entities/dish_category.dart';
import 'package:mobile/features/lunch_picker/domain/entities/lunch_filter.dart';

import '../../../../fixtures/restaurant_fixtures.dart';

void main() {
  group('LunchFilter.apply', () {
    test('drops restaurants outside the radius', () {
      const filter = LunchFilter(radiusMeters: 500);
      final near = buildRestaurant(id: 1, distanceMeters: 400);
      final far = buildRestaurant(id: 2, distanceMeters: 900);

      final result = filter.apply([near, far]);

      expect(result, [near]);
    });

    test('sorts the surviving restaurants by distance, nearest first', () {
      const filter = LunchFilter(radiusMeters: 1000);
      final a = buildRestaurant(id: 1, distanceMeters: 800);
      final b = buildRestaurant(id: 2, distanceMeters: 200);
      final c = buildRestaurant(id: 3, distanceMeters: 500);

      final result = filter.apply([a, b, c]);

      expect(result.map((r) => r.id), [2, 3, 1]);
    });

    test('an empty category set matches everything', () {
      const filter = LunchFilter();
      final r = buildRestaurant(categories: {DishCategory.haiSan});

      expect(filter.apply([r]), [r]);
    });

    test('a non-empty category set keeps only overlapping restaurants', () {
      final filter = const LunchFilter().toggling(DishCategory.phoBun);
      final matching = buildRestaurant(
        id: 1,
        categories: {DishCategory.phoBun},
      );
      final other = buildRestaurant(id: 2, categories: {DishCategory.cafe});

      final result = filter.apply([matching, other]);

      expect(result, [matching]);
    });

    test('toggling the same category twice clears it again', () {
      final filter = const LunchFilter()
          .toggling(DishCategory.com)
          .toggling(DishCategory.com);

      expect(filter.categories, isEmpty);
    });

    test('openNowOnly drops restaurants that are closed at the given time', () {
      const filter = LunchFilter(openNowOnly: true);
      final open = buildRestaurant(id: 1, openingHours: '10:00-14:00');
      final closed = buildRestaurant(id: 2, openingHours: '18:00-22:00');
      final atNoon = DateTime(2026, 1, 1, 12);

      final result = filter.apply([open, closed], now: atNoon);

      expect(result, [open]);
    });
  });
}
