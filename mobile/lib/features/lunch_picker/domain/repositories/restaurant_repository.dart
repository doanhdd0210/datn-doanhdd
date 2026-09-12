import '../../../../core/utils/geo_point.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/restaurant.dart';

abstract class RestaurantRepository {
  /// All known eating places within [radiusMeters] of [origin], sorted by
  /// distance (nearest first).
  ResultFuture<List<Restaurant>> getNearby({
    required GeoPoint origin,
    required int radiusMeters,
  });
}
