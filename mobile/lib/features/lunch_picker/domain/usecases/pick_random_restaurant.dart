import 'dart:math';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/restaurant.dart';

/// "QUAY" — bốc một quán ngẫu nhiên trong các quán đã qua bộ lọc.
class PickRandomRestaurant extends UseCase<Restaurant, PickRandomParams> {
  PickRandomRestaurant({Random? random}) : _random = random ?? Random();

  final Random _random;

  @override
  ResultFuture<Restaurant> call(PickRandomParams params) async {
    if (params.candidates.isEmpty) {
      return const Left(EmptySelectionFailure());
    }
    final pick = params.candidates[_random.nextInt(params.candidates.length)];
    return Right(pick);
  }
}

class PickRandomParams extends Equatable {
  const PickRandomParams(this.candidates);

  final List<Restaurant> candidates;

  @override
  List<Object?> get props => [candidates];
}
