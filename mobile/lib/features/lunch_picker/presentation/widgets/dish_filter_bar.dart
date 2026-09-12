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
    final present =
        DishCategory.values.where((c) => counts.containsKey(c)).toList();
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    final radius =
        filter.radiusMeters.clamp(kMinRadiusMeters, kMaxRadiusMeters);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('THÈM MÓN GÌ', style: labelStyle),
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
            Row(
              children: [
                Text('Bán kính', style: labelStyle),
                const Spacer(),
                Text(
                  '${radius}m',
                  style: labelStyle?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            Slider(
              value: radius.toDouble(),
              min: kMinRadiusMeters.toDouble(),
              max: kMaxRadiusMeters.toDouble(),
              divisions:
                  (kMaxRadiusMeters - kMinRadiusMeters) ~/ kRadiusStepMeters,
              label: '${radius}m',
              onChanged: (v) => onRadiusChanged(v.round()),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Đang mở', style: labelStyle),
                Switch(value: filter.openNowOnly, onChanged: onOpenNowChanged),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
