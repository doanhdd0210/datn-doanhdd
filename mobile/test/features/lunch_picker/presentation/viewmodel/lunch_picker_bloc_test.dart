import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/exceptions.dart';
import 'package:mobile/core/error/failures.dart';
import 'package:mobile/core/location/location_service.dart';
import 'package:mobile/core/utils/geo_point.dart';
import 'package:mobile/features/lunch_picker/domain/entities/dish_category.dart';
import 'package:mobile/features/lunch_picker/domain/usecases/get_nearby_restaurants.dart';
import 'package:mobile/features/lunch_picker/domain/usecases/pick_random_restaurant.dart';
import 'package:mobile/features/lunch_picker/presentation/viewmodel/lunch_picker_bloc.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../fixtures/restaurant_fixtures.dart';

class _MockGetNearbyRestaurants extends Mock implements GetNearbyRestaurants {}

class _MockPickRandomRestaurant extends Mock implements PickRandomRestaurant {}

class _MockLocationService extends Mock implements LocationService {}

void main() {
  late _MockGetNearbyRestaurants getNearby;
  late _MockPickRandomRestaurant pickRandom;
  late _MockLocationService location;

  const origin = GeoPoint(lat: 21.0045, lon: 105.8430);

  setUpAll(() {
    registerFallbackValue(
      const GetNearbyParams(origin: origin, radiusMeters: 900),
    );
    registerFallbackValue(const PickRandomParams([]));
  });

  setUp(() {
    getNearby = _MockGetNearbyRestaurants();
    pickRandom = _MockPickRandomRestaurant();
    location = _MockLocationService();
  });

  LunchPickerBloc buildBloc() => LunchPickerBloc(
    getNearbyRestaurants: getNearby,
    pickRandomRestaurant: pickRandom,
    locationService: location,
  );

  final nearby = [
    buildRestaurant(id: 1, distanceMeters: 100, categories: {DishCategory.com}),
    buildRestaurant(
      id: 2,
      distanceMeters: 800,
      categories: {DishCategory.cafe},
    ),
  ];

  group('LunchPickerStarted', () {
    blocTest<LunchPickerBloc, LunchPickerState>(
      'emits [loading, success] with the fetched restaurants',
      setUp: () {
        when(location.currentLocation).thenAnswer((_) async => origin);
        when(() => getNearby(any())).thenAnswer((_) async => Right(nearby));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const LunchPickerStarted()),
      expect: () => [
        const LunchPickerState(status: LunchPickerStatus.loading),
        LunchPickerState(
          status: LunchPickerStatus.success,
          origin: origin,
          allRestaurants: nearby,
        ),
      ],
    );

    blocTest<LunchPickerBloc, LunchPickerState>(
      'emits [loading, failure] when location cannot be resolved',
      setUp: () {
        when(
          location.currentLocation,
        ).thenThrow(const LocationException('GPS đang tắt'));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const LunchPickerStarted()),
      expect: () => [
        const LunchPickerState(status: LunchPickerStatus.loading),
        const LunchPickerState(
          status: LunchPickerStatus.failure,
          errorMessage: 'GPS đang tắt',
        ),
      ],
      verify: (_) {
        verifyNever(() => getNearby(any()));
      },
    );

    blocTest<LunchPickerBloc, LunchPickerState>(
      'emits [loading, failure] when the repository call fails',
      setUp: () {
        when(location.currentLocation).thenAnswer((_) async => origin);
        when(
          () => getNearby(any()),
        ).thenAnswer((_) async => const Left(NetworkFailure('mất mạng')));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const LunchPickerStarted()),
      expect: () => [
        const LunchPickerState(status: LunchPickerStatus.loading),
        const LunchPickerState(
          status: LunchPickerStatus.failure,
          origin: origin,
          errorMessage: 'mất mạng',
        ),
      ],
    );
  });

  group('filters', () {
    blocTest<LunchPickerBloc, LunchPickerState>(
      'RadiusChanged narrows visibleRestaurants without re-fetching',
      seed: () => LunchPickerState(
        status: LunchPickerStatus.success,
        origin: origin,
        allRestaurants: nearby,
      ),
      build: buildBloc,
      act: (bloc) => bloc.add(const RadiusChanged(300)),
      verify: (bloc) {
        expect(bloc.state.visibleRestaurants, [nearby.first]);
        verifyNever(() => getNearby(any()));
      },
    );

    blocTest<LunchPickerBloc, LunchPickerState>(
      'DishFilterToggled keeps only matching restaurants and clears the pick',
      seed: () => LunchPickerState(
        status: LunchPickerStatus.success,
        allRestaurants: nearby,
        pick: nearby.first,
      ),
      build: buildBloc,
      act: (bloc) => bloc.add(const DishFilterToggled(DishCategory.cafe)),
      verify: (bloc) {
        expect(bloc.state.pick, isNull);
        expect(bloc.state.visibleRestaurants, [nearby.last]);
      },
    );
  });

  group('RandomPickRequested', () {
    blocTest<LunchPickerBloc, LunchPickerState>(
      'sets the pick from the use case result',
      seed: () => LunchPickerState(
        status: LunchPickerStatus.success,
        allRestaurants: nearby,
      ),
      setUp: () {
        when(
          () => pickRandom(any()),
        ).thenAnswer((_) async => Right(nearby.first));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const RandomPickRequested()),
      verify: (bloc) => expect(bloc.state.pick, nearby.first),
    );

    blocTest<LunchPickerBloc, LunchPickerState>(
      'surfaces an error message when there is nothing to pick from',
      seed: () => const LunchPickerState(status: LunchPickerStatus.success),
      setUp: () {
        when(
          () => pickRandom(any()),
        ).thenAnswer((_) async => const Left(EmptySelectionFailure()));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const RandomPickRequested()),
      verify: (bloc) {
        expect(bloc.state.pick, isNull);
        expect(bloc.state.errorMessage, isNotNull);
      },
    );
  });

  blocTest<LunchPickerBloc, LunchPickerState>(
    'ManualPickSelected sets the pick directly, no use case involved',
    seed: () => LunchPickerState(
      status: LunchPickerStatus.success,
      allRestaurants: nearby,
    ),
    build: buildBloc,
    act: (bloc) => bloc.add(ManualPickSelected(nearby.last)),
    verify: (bloc) {
      expect(bloc.state.pick, nearby.last);
      verifyNever(() => pickRandom(any()));
    },
  );
}
