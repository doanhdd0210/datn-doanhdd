import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/geo_point.dart';
import '../../../../core/utils/typedefs.dart';
import '../models/restaurant_model.dart';

abstract class RestaurantRemoteDataSource {
  /// All restaurants/cafes/fast-food/food-courts within [radiusMeters] of
  /// ([lat], [lon]), sorted by distance.
  Future<List<RestaurantModel>> fetchNearby({
    required double lat,
    required double lon,
    required int radiusMeters,
  });
}

/// Queries OpenStreetMap through the free, keyless Overpass API. No account,
/// no billing — see the two mirrored endpoints below for why a second one
/// is worth keeping: the public instance rate-limits under load.
class RestaurantOverpassDataSource implements RestaurantRemoteDataSource {
  RestaurantOverpassDataSource({
    required http.Client client,
    this.primaryEndpoint = 'https://overpass-api.de/api/interpreter',
    this.fallbackEndpoint = 'https://overpass.kumi.systems/api/interpreter',
  }) : _client = client;

  final http.Client _client;
  final String primaryEndpoint;
  final String fallbackEndpoint;

  @override
  Future<List<RestaurantModel>> fetchNearby({
    required double lat,
    required double lon,
    required int radiusMeters,
  }) async {
    final query = _buildQuery(lat: lat, lon: lon, radiusMeters: radiusMeters);
    final origin = GeoPoint(lat: lat, lon: lon);

    DataMap json;
    try {
      json = await _post(primaryEndpoint, query);
    } on NetworkException {
      json = await _post(fallbackEndpoint, query);
    }

    final elements = json['elements'] as List<dynamic>? ?? const [];
    return elements
        .cast<Map<String, dynamic>>()
        .map((node) => RestaurantModel.fromOverpassNode(node, origin: origin))
        .whereType<RestaurantModel>()
        .toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  }

  Future<DataMap> _post(String endpoint, String query) async {
    final http.Response response;
    try {
      response = await _client
          .post(Uri.parse(endpoint), body: {'data': query})
          .timeout(const Duration(seconds: 25));
    } on SocketException {
      throw const NetworkException();
    }

    if (response.statusCode != 200) {
      throw ServerException(
        message: 'Overpass trả lỗi (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw const ServerException(
        message: 'Không đọc được phản hồi từ Overpass',
      );
    }
  }

  String _buildQuery({
    required double lat,
    required double lon,
    required int radiusMeters,
  }) {
    return '[out:json][timeout:25];'
        '(node["amenity"~"restaurant|fast_food|cafe|food_court"]'
        '(around:$radiusMeters,$lat,$lon););'
        'out body 80;';
  }
}
