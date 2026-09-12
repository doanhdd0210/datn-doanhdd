import 'package:equatable/equatable.dart';

import 'dish_category.dart';
import 'opening_hours.dart';
import 'restaurant.dart';

/// What the user currently wants for lunch. Pure domain logic — no Flutter,
/// no datasource — so it's trivial to unit test on its own.
class LunchFilter extends Equatable {
  const LunchFilter({
    this.radiusMeters = 900,
    this.categories = const {},
    this.openNowOnly = false,
  });

  final int radiusMeters;

  /// Empty set = no dish filter (everything passes).
  final Set<DishCategory> categories;
  final bool openNowOnly;

  LunchFilter copyWith({
    int? radiusMeters,
    Set<DishCategory>? categories,
    bool? openNowOnly,
  }) {
    return LunchFilter(
      radiusMeters: radiusMeters ?? this.radiusMeters,
      categories: categories ?? this.categories,
      openNowOnly: openNowOnly ?? this.openNowOnly,
    );
  }

  LunchFilter toggling(DishCategory category) {
    final next = Set<DishCategory>.from(categories);
    if (!next.remove(category)) next.add(category);
    return copyWith(categories: next);
  }

  /// Returns [all] narrowed down to what matches this filter, sorted by
  /// distance (nearest first).
  List<Restaurant> apply(List<Restaurant> all, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final matches = all.where((r) {
      if (r.distanceMeters > radiusMeters) return false;
      if (categories.isNotEmpty &&
          r.categories.intersection(categories).isEmpty) {
        return false;
      }
      if (openNowOnly && r.openingHours.statusAt(at) != OpeningStatus.open) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return matches;
  }

  @override
  List<Object?> get props => [radiusMeters, categories, openNowOnly];
}
