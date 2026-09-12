import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// A latitude/longitude pair, plus the one operation every feature that
/// deals with "nearby" things needs: distance to another point.
class GeoPoint extends Equatable {
  const GeoPoint({required this.lat, required this.lon});

  final double lat;
  final double lon;

  static const _earthRadiusMeters = 6371000.0;

  /// Great-circle distance to [other], in meters (haversine formula).
  double distanceTo(GeoPoint other) {
    final dLat = _radians(other.lat - lat);
    final dLon = _radians(other.lon - lon);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat)) *
            math.cos(_radians(other.lat)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  double _radians(double degrees) => degrees * math.pi / 180;

  @override
  List<Object?> get props => [lat, lon];
}
