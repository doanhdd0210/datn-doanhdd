import 'package:mobile/core/utils/geo_point.dart';
import 'package:mobile/features/lunch_picker/domain/entities/dish_category.dart';
import 'package:mobile/features/lunch_picker/domain/entities/opening_hours.dart';
import 'package:mobile/features/lunch_picker/domain/entities/restaurant.dart';

/// Test-only builder — every field has a sane default so a call site only
/// has to name the fields it actually cares about.
Restaurant buildRestaurant({
  int id = 1,
  String name = 'Quán Test',
  double distanceMeters = 100,
  Set<DishCategory> categories = const {DishCategory.com},
  String openingHours = '',
}) {
  return Restaurant(
    id: id,
    name: name,
    location: const GeoPoint(lat: 21.0, lon: 105.8),
    distanceMeters: distanceMeters,
    categories: categories,
    openingHours: OpeningHours(openingHours),
  );
}
