import 'package:equatable/equatable.dart';

import 'exceptions.dart';

abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);

  factory ServerFailure.fromException(ServerException e) =>
      ServerFailure(e.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);

  factory NetworkFailure.fromException(NetworkException e) =>
      NetworkFailure(e.message);
}

class LocationFailure extends Failure {
  const LocationFailure(super.message);

  factory LocationFailure.fromException(LocationException e) =>
      LocationFailure(e.message);
}

/// Returned by [PickRandomRestaurant] when there is nothing left to pick
/// from — every candidate was filtered out.
class EmptySelectionFailure extends Failure {
  const EmptySelectionFailure()
      : super('Không có quán nào khớp bộ lọc — nới bán kính hoặc bỏ bớt món.');
}
