import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failures.dart';
import 'package:mobile/core/utils/geo_point.dart';
import 'package:mobile/features/lunch_picker/domain/entities/restaurant.dart';
import 'package:mobile/features/lunch_picker/domain/repositories/restaurant_repository.dart';
import 'package:mobile/features/lunch_picker/domain/usecases/get_nearby_restaurants.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../fixtures/restaurant_fixtures.dart';

class _MockRestaurantRepository extends Mock implements RestaurantRepository {}

void main() {
  late _MockRestaurantRepository repository;
  late GetNearbyRestaurants useCase;

  setUp(() {
    repository = _MockRestaurantRepository();
    useCase = GetNearbyRestaurants(repository);
  });

  const origin = GeoPoint(lat: 21.0, lon: 105.8);
  const params = GetNearbyParams(origin: origin, radiusMeters: 900);

  test('forwards the exact origin/radius to the repository', () async {
    when(
      () => repository.getNearby(origin: origin, radiusMeters: 900),
    ).thenAnswer((_) async => const Right([]));

    await useCase(params);

    verify(
      () => repository.getNearby(origin: origin, radiusMeters: 900),
    ).called(1);
  });

  test('returns Right with whatever the repository returns', () async {
    final restaurants = [buildRestaurant()];
    when(
      () => repository.getNearby(origin: origin, radiusMeters: 900),
    ).thenAnswer((_) async => Right(restaurants));

    final result = await useCase(params);

    expect(result, Right<Failure, List<Restaurant>>(restaurants));
  });

  test('passes a repository failure straight through', () async {
    when(
      () => repository.getNearby(origin: origin, radiusMeters: 900),
    ).thenAnswer((_) async => const Left(NetworkFailure('offline')));

    final result = await useCase(params);

    expect(
      result,
      const Left<Failure, List<Restaurant>>(NetworkFailure('offline')),
    );
  });
}
