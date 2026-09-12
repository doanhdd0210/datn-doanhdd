import 'package:equatable/equatable.dart';

import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/geo_point.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/restaurant.dart';
import '../repositories/restaurant_repository.dart';

class GetNearbyRestaurants extends UseCase<List<Restaurant>, GetNearbyParams> {
  const GetNearbyRestaurants(this._repository);

  final RestaurantRepository _repository;

  @override
  ResultFuture<List<Restaurant>> call(GetNearbyParams params) {
    return _repository.getNearby(
      origin: params.origin,
      radiusMeters: params.radiusMeters,
    );
  }
}

class GetNearbyParams extends Equatable {
  const GetNearbyParams({required this.origin, required this.radiusMeters});

  final GeoPoint origin;
  final int radiusMeters;

  @override
  List<Object?> get props => [origin, radiusMeters];
}
