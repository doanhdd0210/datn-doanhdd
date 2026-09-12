import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/dish_category.dart';
import '../../domain/entities/lunch_filter.dart';
import '../../domain/entities/restaurant.dart';

class DishFilterBar extends StatelessWidget {
  const DishFilterBar({
    super.key,
    required this.allRestaurants,
    required this.filter,
    required this.onCategoryToggled,
    required this.onRadiusChanged,
    required this.onOpenNowChanged,
  });

  final List<Restaurant> allRestaurants;
  final LunchFilter filter;
  final ValueChanged<DishCategory> onCategoryToggled;
  final ValueChanged<int> onRadiusChanged;
  final ValueChanged<bool> onOpenNowChanged;

  @override
  Widget build(BuildContext context) {
    final counts = <DishCategory, int>{};
    for (final r in allRestaurants) {
      for (final c in r.categories) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }
    final present = DishCategory.values
        .where((c) => counts.containsKey(c))
        .toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('THÈM MÓN GÌ', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in present)
                  FilterChip(
                    label: Text('${c.emoji} ${c.label} · ${counts[c]}'),
                    selected: filter.categories.contains(c),
                    onSelected: (_) => onCategoryToggled(c),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<int>(
                  segments: [
                    for (final r in kRadiusChoicesMeters)
                      ButtonSegment(value: r, label: Text('${r}m')),
                  ],
                  selected: {filter.radiusMeters},
                  onSelectionChanged: (s) => onRadiusChanged(s.first),
                  showSelectedIcon: false,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Đang mở',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    Switch(
                      value: filter.openNowOnly,
                      onChanged: onOpenNowChanged,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
