import 'package:equatable/equatable.dart';

import '../../../../core/utils/geo_point.dart';
import 'dish_category.dart';
import 'opening_hours.dart';

class Restaurant extends Equatable {
  const Restaurant({
    required this.id,
    required this.name,
    required this.location,
    required this.distanceMeters,
    required this.categories,
    this.address = '',
    this.phone = '',
    this.openingHours = const OpeningHours(''),
  });

  /// OSM node id.
  final int id;
  final String name;
  final GeoPoint location;

  /// Distance from whatever origin the query used — filled in by the
  /// repository, not a property of the place itself.
  final double distanceMeters;

  final Set<DishCategory> categories;
  final String address;
  final String phone;
  final OpeningHours openingHours;

  @override
  List<Object?> get props => [
        id,
        name,
        location,
        distanceMeters,
        categories,
        address,
        phone,
        openingHours.raw,
      ];
}
