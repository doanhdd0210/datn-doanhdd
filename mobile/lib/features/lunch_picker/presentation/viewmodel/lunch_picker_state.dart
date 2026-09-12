part of 'lunch_picker_bloc.dart';

enum LunchPickerStatus { initial, loading, success, failure }

class LunchPickerState extends Equatable {
  const LunchPickerState({
    this.status = LunchPickerStatus.initial,
    this.origin,
    this.allRestaurants = const [],
    this.filter = const LunchFilter(),
    this.pick,
    this.isSpinning = false,
    this.errorMessage,
  });

  final LunchPickerStatus status;
  final GeoPoint? origin;
  final List<Restaurant> allRestaurants;
  final LunchFilter filter;
  final Restaurant? pick;
  final bool isSpinning;
  final String? errorMessage;

  /// What the list/spin pool should actually show right now.
  List<Restaurant> get visibleRestaurants => filter.apply(allRestaurants);

  LunchPickerState copyWith({
    LunchPickerStatus? status,
    GeoPoint? origin,
    List<Restaurant>? allRestaurants,
    LunchFilter? filter,
    ValueGetter<Restaurant?>? pick,
    bool? isSpinning,
    ValueGetter<String?>? errorMessage,
  }) {
    return LunchPickerState(
      status: status ?? this.status,
      origin: origin ?? this.origin,
      allRestaurants: allRestaurants ?? this.allRestaurants,
      filter: filter ?? this.filter,
      pick: pick != null ? pick() : this.pick,
      isSpinning: isSpinning ?? this.isSpinning,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    origin,
    allRestaurants,
    filter,
    pick,
    isSpinning,
    errorMessage,
  ];
}
