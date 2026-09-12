import '../../../../core/utils/geo_point.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/entities/dish_category.dart';
import '../../domain/entities/opening_hours.dart';
import '../../domain/entities/restaurant.dart';
import '../mappers/cuisine_classifier.dart';

class RestaurantModel extends Restaurant {
  const RestaurantModel({
    required super.id,
    required super.name,
    required super.location,
    required super.distanceMeters,
    required super.categories,
    super.address,
    super.phone,
    super.openingHours,
  });

  /// Builds a model from one Overpass `node` element (`out body` shape),
  /// computing its distance from [origin] along the way. Returns `null`
  /// when the node has no `name` tag — those aren't useful to show.
  static RestaurantModel? fromOverpassNode(
    DataMap node, {
    required GeoPoint origin,
    CuisineClassifier classifier = const CuisineClassifier(),
  }) {
    final tags = (node['tags'] as DataMap?) ?? const {};
    final name = tags['name'] as String?;
    if (name == null || name.trim().isEmpty) return null;

    final lat = (node['lat'] as num).toDouble();
    final lon = (node['lon'] as num).toDouble();
    final location = GeoPoint(lat: lat, lon: lon);
    final cuisine = (tags['cuisine'] as String?) ?? '';
    final amenity = (tags['amenity'] as String?) ?? '';
    final street = [
      tags['addr:housenumber'],
      tags['addr:street'],
    ].whereType<String>().join(' ').trim();

    return RestaurantModel(
      id: node['id'] as int,
      name: name,
      location: location,
      distanceMeters: origin.distanceTo(location),
      categories: classifier.classify(
        name: name,
        cuisine: cuisine,
        amenity: amenity,
      ),
      address: street,
      phone:
          (tags['phone'] as String?) ??
          (tags['contact:phone'] as String?) ??
          '',
      openingHours: OpeningHours((tags['opening_hours'] as String?) ?? ''),
    );
  }

  factory RestaurantModel.fromMap(DataMap map) {
    return RestaurantModel(
      id: map['id'] as int,
      name: map['name'] as String,
      location: GeoPoint(
        lat: (map['lat'] as num).toDouble(),
        lon: (map['lon'] as num).toDouble(),
      ),
      distanceMeters: (map['distanceMeters'] as num).toDouble(),
      categories: (map['categories'] as List<dynamic>)
          .map((e) => DishCategory.values.byName(e as String))
          .toSet(),
      address: (map['address'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      openingHours: OpeningHours((map['openingHours'] as String?) ?? ''),
    );
  }

  DataMap toMap() {
    return {
      'id': id,
      'name': name,
      'lat': location.lat,
      'lon': location.lon,
      'distanceMeters': distanceMeters,
      'categories': categories.map((c) => c.name).toList(),
      'address': address,
      'phone': phone,
      'openingHours': openingHours.raw,
    };
  }
}
