import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/restaurant.dart';
import '../../lunch_picker_module.dart';
import '../viewmodel/lunch_picker_bloc.dart';
import '../widgets/dish_filter_bar.dart';
import '../widgets/lunch_ticket.dart';
import '../widgets/restaurant_tile.dart';

class LunchPickerPage extends StatelessWidget {
  const LunchPickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          LunchPickerModule.createBloc()..add(const LunchPickerStarted()),
      child: const _LunchPickerView(),
    );
  }
}

class _LunchPickerView extends StatelessWidget {
  const _LunchPickerView();

  Future<void> _openDirections(BuildContext context, Restaurant r) async {
    // `destination` alone, as raw coordinates, is an exact pin. Do NOT also
    // send `destination_place_id` unless it's a real Google-issued Place
    // ID — passing free text there (e.g. the restaurant's name) makes Maps
    // treat it as authoritative, fail to resolve it, and silently fall back
    // to a text search that can land on a same-named place kilometers away.
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${r.location.lat},${r.location.lon}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trưa nay ăn gì?'),
        actions: [
          IconButton(
            tooltip: 'Làm mới vị trí',
            icon: const Icon(Icons.my_location),
            onPressed: () => context.read<LunchPickerBloc>().add(
                  const LocationRefreshRequested(),
                ),
          ),
        ],
      ),
      body: BlocConsumer<LunchPickerBloc, LunchPickerState>(
        listenWhen: (previous, current) =>
            current.errorMessage != null &&
            current.errorMessage != previous.errorMessage,
        listener: (context, state) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        },
        builder: (context, state) {
          if (state.status == LunchPickerStatus.initial ||
              state.status == LunchPickerStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == LunchPickerStatus.failure &&
              state.allRestaurants.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(state.errorMessage ?? 'Có lỗi xảy ra'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => context.read<LunchPickerBloc>().add(
                            const LunchPickerStarted(),
                          ),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final visible = state.visibleRestaurants;
          final bloc = context.read<LunchPickerBloc>();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LunchTicket(
                pick: state.pick,
                isSpinning: state.isSpinning,
                candidateCount: visible.length,
                onSpin: () => bloc.add(const RandomPickRequested()),
                onDirections: (r) => _openDirections(context, r),
              ),
              const SizedBox(height: 16),
              DishFilterBar(
                allRestaurants: state.allRestaurants,
                filter: state.filter,
                onCategoryToggled: (c) => bloc.add(DishFilterToggled(c)),
                onRadiusChanged: (r) => bloc.add(RadiusChanged(r)),
                onOpenNowChanged: (v) => bloc.add(OpenNowToggled(v)),
              ),
              const SizedBox(height: 16),
              Text(
                'Có ${visible.length} quán trong bán kính ${state.filter.radiusMeters}m',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 8),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Không có quán nào khớp. Nới bán kính hoặc bỏ bớt bộ lọc.',
                    ),
                  ),
                )
              else
                for (final r in visible) ...[
                  RestaurantTile(
                    restaurant: r,
                    selected: state.pick?.id == r.id,
                    onTap: () => bloc.add(ManualPickSelected(r)),
                    onDirections: () => _openDirections(context, r),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
    );
  }
}
