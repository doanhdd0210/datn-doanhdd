import 'package:equatable/equatable.dart';

import '../utils/typedefs.dart';

/// Base contract for every use case: takes [P] params, returns a
/// [ResultFuture] of [T].
abstract class UseCase<T, P> {
  const UseCase();

  ResultFuture<T> call(P params);
}

/// Use for use cases that need no parameters.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
