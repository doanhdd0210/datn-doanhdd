import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/geo_point.dart';
import 'package:mobile/features/lunch_picker/data/models/restaurant_model.dart';
import 'package:mobile/features/lunch_picker/domain/entities/dish_category.dart';

void main() {
  const origin = GeoPoint(lat: 21.0045, lon: 105.8430);

  group('RestaurantModel.fromOverpassNode', () {
    test('returns null when the node has no name tag', () {
      final node = {
        'id': 1,
        'lat': 21.005,
        'lon': 105.844,
        'tags': <String, dynamic>{'amenity': 'restaurant'},
      };

      expect(RestaurantModel.fromOverpassNode(node, origin: origin), isNull);
    });

    test('parses a full node into a model with distance + address', () {
      final node = {
        'id': 11254919071,
        'lat': 21.0057539,
        'lon': 105.8458586,
        'tags': {
          'name': 'Cafe Mộc',
          'cuisine': 'coffee_shop',
          'amenity': 'cafe',
          'opening_hours': '7:00-23:00',
          'addr:housenumber': '75',
          'addr:street': 'Phố Trần Đại Nghĩa',
          'phone': '04 2212 3600',
        },
      };

      final model = RestaurantModel.fromOverpassNode(node, origin: origin);

      expect(model, isNotNull);
      expect(model!.id, 11254919071);
      expect(model.name, 'Cafe Mộc');
      expect(model.categories, {DishCategory.cafe});
      expect(model.address, '75 Phố Trần Đại Nghĩa');
      expect(model.phone, '04 2212 3600');
      expect(model.openingHours.raw, '7:00-23:00');
      // ~328m in reality; just sanity-check it's in that ballpark.
      expect(model.distanceMeters, closeTo(328, 25));
    });

    test('missing address parts do not crash and join to nothing', () {
      final node = {
        'id': 2,
        'lat': 21.005,
        'lon': 105.844,
        'tags': {'name': 'No Address Quán'},
      };

      final model = RestaurantModel.fromOverpassNode(node, origin: origin);

      expect(model!.address, '');
    });
  });

  test('toMap/fromMap round-trips every field', () {
    final node = {
      'id': 42,
      'lat': 21.03,
      'lon': 105.79,
      'tags': {
        'name': 'Bún Chả Sinh Từ',
        'cuisine': 'vietnamese',
        'amenity': 'restaurant',
        'opening_hours': '11:00-14:00',
      },
    };
    final original = RestaurantModel.fromOverpassNode(node, origin: origin)!;

    final roundTripped = RestaurantModel.fromMap(original.toMap());

    // Model types differ from a plain round-trip in general, so compare
    // the Equatable props rather than `==`/identity.
    expect(roundTripped.props, original.props);
  });
}
