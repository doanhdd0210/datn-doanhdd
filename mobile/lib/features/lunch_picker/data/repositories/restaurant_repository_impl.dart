import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/geo_point.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/entities/restaurant.dart';
import '../../domain/repositories/restaurant_repository.dart';
import '../datasources/restaurant_remote_data_source.dart';

class RestaurantRepositoryImpl implements RestaurantRepository {
  const RestaurantRepositoryImpl(this._remote);

  final RestaurantRemoteDataSource _remote;

  @override
  ResultFuture<List<Restaurant>> getNearby({
    required GeoPoint origin,
    required int radiusMeters,
  }) async {
    try {
      final models = await _remote.fetchNearby(
        lat: origin.lat,
        lon: origin.lon,
        radiusMeters: radiusMeters,
      );
      return Right(models);
    } on ServerException catch (e) {
      return Left(ServerFailure.fromException(e));
    } on NetworkException catch (e) {
      return Left(NetworkFailure.fromException(e));
    }
  }
}
