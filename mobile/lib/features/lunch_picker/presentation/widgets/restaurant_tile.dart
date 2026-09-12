import 'package:flutter/material.dart';

import '../../domain/entities/opening_hours.dart';
import '../../domain/entities/restaurant.dart';

class RestaurantTile extends StatelessWidget {
  const RestaurantTile({
    super.key,
    required this.restaurant,
    required this.selected,
    required this.onTap,
    required this.onDirections,
  });

  final Restaurant restaurant;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = restaurant.openingHours.statusAt(DateTime.now());
    final dotColor = switch (status) {
      OpeningStatus.open => Colors.green,
      OpeningStatus.closed => Colors.red,
      OpeningStatus.unknown => scheme.outlineVariant,
    };

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final c in restaurant.categories)
                          Text(
                            '${c.emoji} ${c.label}',
                            style: theme.textTheme.bodySmall,
                          ),
                        Text(
                          '${restaurant.distanceMeters.round()}m',
                          style: theme.textTheme.bodySmall,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(
                              restaurant.openingHours.label(DateTime.now()),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Chỉ đường tới ${restaurant.name}',
            onPressed: onDirections,
            icon: Icon(Icons.directions, color: scheme.secondary),
          ),
        ],
      ),
    );
  }
}
