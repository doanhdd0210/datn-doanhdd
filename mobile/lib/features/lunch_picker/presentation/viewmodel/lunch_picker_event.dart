part of 'lunch_picker_bloc.dart';

sealed class LunchPickerEvent extends Equatable {
  const LunchPickerEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the page opens: get location, then fetch nearby places.
class LunchPickerStarted extends LunchPickerEvent {
  const LunchPickerStarted();
}

/// "Làm mới vị trí" — re-fetch location and re-query.
class LocationRefreshRequested extends LunchPickerEvent {
  const LocationRefreshRequested();
}

class RadiusChanged extends LunchPickerEvent {
  const RadiusChanged(this.radiusMeters);

  final int radiusMeters;

  @override
  List<Object?> get props => [radiusMeters];
}

class DishFilterToggled extends LunchPickerEvent {
  const DishFilterToggled(this.category);

  final DishCategory category;

  @override
  List<Object?> get props => [category];
}

class OpenNowToggled extends LunchPickerEvent {
  const OpenNowToggled(this.value);

  final bool value;

  @override
  List<Object?> get props => [value];
}

/// "QUAY" — bốc một quán ngẫu nhiên trong các quán đang hiển thị.
class RandomPickRequested extends LunchPickerEvent {
  const RandomPickRequested();
}

/// User tapped a specific row in the list instead of spinning.
class ManualPickSelected extends LunchPickerEvent {
  const ManualPickSelected(this.restaurant);

  final Restaurant restaurant;

  @override
  List<Object?> get props => [restaurant];
}
