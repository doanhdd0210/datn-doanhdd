import 'package:flutter/material.dart';

import '../../domain/entities/restaurant.dart';

class LunchTicket extends StatelessWidget {
  const LunchTicket({
    super.key,
    required this.pick,
    required this.isSpinning,
    required this.candidateCount,
    required this.onSpin,
    required this.onDirections,
  });

  final Restaurant? pick;
  final bool isSpinning;
  final int candidateCount;
  final VoidCallback onSpin;
  final ValueChanged<Restaurant> onDirections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: [
            Text(
              pick == null ? 'BẤM ĐỂ BỐC MỘT QUÁN' : 'CHỐT ĐƠN — HÔM NAY ĂN Ở',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                pick?.name ?? 'Trưa nay ăn gì đây…',
                key: ValueKey(pick?.id),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (pick != null) ...[
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 4,
                children: [
                  for (final c in pick!.categories.take(2))
                    Text(
                      '${c.emoji} ${c.label}',
                      style: theme.textTheme.bodySmall,
                    ),
                  Text(
                    '${pick!.distanceMeters.round()}m',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    pick!.openingHours.label(now),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: candidateCount == 0 ? null : onSpin,
                child: Text(isSpinning ? 'ĐANG QUAY…' : 'QUAY 🎲'),
              ),
            ),
            if (pick != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSpin,
                      child: const Text('Quay lại'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => onDirections(pick!),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.secondary,
                        foregroundColor: scheme.onSecondary,
                      ),
                      child: const Text('Chỉ đường ↗'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
