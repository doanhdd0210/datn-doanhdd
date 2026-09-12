import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/utils/geo_point.dart';
import '../../domain/entities/dish_category.dart';
import '../../domain/entities/lunch_filter.dart';
import '../../domain/entities/restaurant.dart';
import '../../domain/usecases/get_nearby_restaurants.dart';
import '../../domain/usecases/pick_random_restaurant.dart';

part 'lunch_picker_event.dart';
part 'lunch_picker_state.dart';

class LunchPickerBloc extends Bloc<LunchPickerEvent, LunchPickerState> {
  LunchPickerBloc({
    required GetNearbyRestaurants getNearbyRestaurants,
    required PickRandomRestaurant pickRandomRestaurant,
    required LocationService locationService,
  })  : _getNearbyRestaurants = getNearbyRestaurants,
        _pickRandomRestaurant = pickRandomRestaurant,
        _locationService = locationService,
        super(const LunchPickerState()) {
    on<LunchPickerStarted>(_onStarted);
    on<LocationRefreshRequested>(_onStarted);
    on<RadiusChanged>(_onRadiusChanged);
    on<DishFilterToggled>(_onDishFilterToggled);
    on<OpenNowToggled>(_onOpenNowToggled);
    on<RandomPickRequested>(_onRandomPickRequested);
    on<ManualPickSelected>(_onManualPickSelected);
  }

  final GetNearbyRestaurants _getNearbyRestaurants;
  final PickRandomRestaurant _pickRandomRestaurant;
  final LocationService _locationService;

  Future<void> _onStarted(
    LunchPickerEvent event,
    Emitter<LunchPickerState> emit,
  ) async {
    emit(
      state.copyWith(
        status: LunchPickerStatus.loading,
        pick: () => null,
        errorMessage: () => null,
      ),
    );

    final GeoPoint origin;
    try {
      origin = await _locationService.currentLocation();
    } on LocationException catch (e) {
      emit(
        state.copyWith(
          status: LunchPickerStatus.failure,
          errorMessage: () => e.message,
        ),
      );
      return;
    }

    // Always fetch at the widest possible slider value; every smaller
    // radius the user drags to is then a client-side narrowing via
    // LunchFilter — no need to re-hit the API on every slider tick.
    final result = await _getNearbyRestaurants(
      GetNearbyParams(origin: origin, radiusMeters: kMaxRadiusMeters),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: LunchPickerStatus.failure,
          origin: origin,
          errorMessage: () => failure.message,
        ),
      ),
      (restaurants) => emit(
        state.copyWith(
          status: LunchPickerStatus.success,
          origin: origin,
          allRestaurants: restaurants,
        ),
      ),
    );
  }

  void _onRadiusChanged(RadiusChanged event, Emitter<LunchPickerState> emit) {
    emit(
      state.copyWith(
        filter: state.filter.copyWith(radiusMeters: event.radiusMeters),
        pick: () => null,
      ),
    );
  }

  void _onDishFilterToggled(
    DishFilterToggled event,
    Emitter<LunchPickerState> emit,
  ) {
    emit(
      state.copyWith(
        filter: state.filter.toggling(event.category),
        pick: () => null,
      ),
    );
  }

  void _onOpenNowToggled(OpenNowToggled event, Emitter<LunchPickerState> emit) {
    emit(
      state.copyWith(
        filter: state.filter.copyWith(openNowOnly: event.value),
        pick: () => null,
      ),
    );
  }

  Future<void> _onRandomPickRequested(
    RandomPickRequested event,
    Emitter<LunchPickerState> emit,
  ) async {
    final result = await _pickRandomRestaurant(
      PickRandomParams(state.visibleRestaurants),
    );
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: () => failure.message)),
      (restaurant) => emit(
        state.copyWith(pick: () => restaurant, errorMessage: () => null),
      ),
    );
  }

  void _onManualPickSelected(
    ManualPickSelected event,
    Emitter<LunchPickerState> emit,
  ) {
    emit(
      state.copyWith(pick: () => event.restaurant, errorMessage: () => null),
    );
  }
}
