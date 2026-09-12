import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/exceptions.dart';
import 'package:mobile/core/error/failures.dart';
import 'package:mobile/core/utils/geo_point.dart';
import 'package:mobile/features/lunch_picker/data/datasources/restaurant_remote_data_source.dart';
import 'package:mobile/features/lunch_picker/data/models/restaurant_model.dart';
import 'package:mobile/features/lunch_picker/data/repositories/restaurant_repository_impl.dart';
import 'package:mobile/features/lunch_picker/domain/entities/dish_category.dart';
import 'package:mobile/features/lunch_picker/domain/entities/restaurant.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemoteDataSource extends Mock
    implements RestaurantRemoteDataSource {}

void main() {
  late _MockRemoteDataSource remote;
  late RestaurantRepositoryImpl repository;

  const origin = GeoPoint(lat: 21.0, lon: 105.8);

  setUp(() {
    remote = _MockRemoteDataSource();
    repository = RestaurantRepositoryImpl(remote);
  });

  test('returns Right with whatever the datasource returns', () async {
    const model = RestaurantModel(
      id: 1,
      name: 'Quán A',
      location: origin,
      distanceMeters: 50,
      categories: {DishCategory.com},
    );
    when(
      () => remote.fetchNearby(lat: 21.0, lon: 105.8, radiusMeters: 900),
    ).thenAnswer((_) async => [model]);

    final result = await repository.getNearby(
      origin: origin,
      radiusMeters: 900,
    );

    // Compared unwrapped: `Right`'s `==` delegates to `List.==`, which is
    // identity-based, not structural — two equal-but-distinct list
    // instances (as the mock and this assertion each build) would
    // otherwise be reported as different.
    expect(result.isRight(), true);
    result.fold(
      (_) => fail('expected a Right'),
      (restaurants) => expect(restaurants, const [model]),
    );
  });

  test('maps ServerException to ServerFailure', () async {
    when(
      () => remote.fetchNearby(lat: 21.0, lon: 105.8, radiusMeters: 900),
    ).thenThrow(const ServerException(message: 'lỗi 500', statusCode: 500));

    final result = await repository.getNearby(
      origin: origin,
      radiusMeters: 900,
    );

    expect(
      result,
      const Left<Failure, List<Restaurant>>(ServerFailure('lỗi 500')),
    );
  });

  test('maps NetworkException to NetworkFailure', () async {
    when(
      () => remote.fetchNearby(lat: 21.0, lon: 105.8, radiusMeters: 900),
    ).thenThrow(const NetworkException('mất mạng'));

    final result = await repository.getNearby(
      origin: origin,
      radiusMeters: 900,
    );

    expect(
      result,
      const Left<Failure, List<Restaurant>>(NetworkFailure('mất mạng')),
    );
  });
}
