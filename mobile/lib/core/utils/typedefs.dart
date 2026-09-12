import 'package:dartz/dartz.dart';

import '../error/failures.dart';

/// Result of any repository / use case call that can fail.
typedef ResultFuture<T> = Future<Either<Failure, T>>;

/// A decoded JSON object.
typedef DataMap = Map<String, dynamic>;
