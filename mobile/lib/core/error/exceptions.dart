/// Thrown by datasources. Repositories are the only layer allowed to catch
/// these and translate them into a [Failure].
class ServerException implements Exception {
  const ServerException({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ServerException($statusCode): $message';
}

class NetworkException implements Exception {
  const NetworkException([this.message = 'Không có kết nối mạng']);

  final String message;

  @override
  String toString() => 'NetworkException: $message';
}

class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => 'LocationException: $message';
}
