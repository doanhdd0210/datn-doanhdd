import '../../../../core/utils/geo_point.dart';
import '../models/restaurant_model.dart';
import 'restaurant_remote_data_source.dart';

/// Fake datasource — a real snapshot pulled from Overpass around Bách Khoa,
/// baked in so the app runs offline with zero network/API setup. Wired in
/// by default in `injection_container.dart`; swap to
/// [RestaurantOverpassDataSource] to hit the live API.
class RestaurantInMemoryDataSource implements RestaurantRemoteDataSource {
  const RestaurantInMemoryDataSource();

  static final _nodes = <Map<String, dynamic>>[
    {
      'id': 11186157294,
      'lat': 21.00487,
      'lon': 105.8425222,
      'tags': {
        'name': 'Nhà hàng Hải Yến Bách Khoa',
        'cuisine': 'seafood',
        'amenity': 'restaurant',
      },
    },
    {
      'id': 11254919076,
      'lat': 21.0059567,
      'lon': 105.8458379,
      'tags': {'name': 'Bún Ốc Chuối Đậu', 'amenity': 'restaurant'},
    },
    {
      'id': 11846922569,
      'lat': 21.0323689,
      'lon': 105.78739,
      'tags': {'name': 'Cơm văn phòng', 'amenity': 'restaurant'},
    },
    {
      'id': 3769973034,
      'lat': 21.0367552,
      'lon': 105.7941995,
      'tags': {
        'name': 'Nhà hàng Bò Đội Nón',
        'cuisine': 'Lẩu_-_nướng_&_các_món_nhậu',
        'amenity': 'restaurant',
        'opening_hours': '09:00-23:30',
      },
    },
    {
      'id': 7055986053,
      'lat': 21.0308504,
      'lon': 105.7870396,
      'tags': {'name': 'Nhà hàng Gà Cựa', 'amenity': 'restaurant'},
    },
    {
      'id': 7056027929,
      'lat': 21.0346716,
      'lon': 105.7889104,
      'tags': {
        'name': 'Bún Chả Sinh Từ',
        'cuisine': 'vietnamese',
        'amenity': 'restaurant',
      },
    },
    {
      'id': 6224015609,
      'lat': 21.0019669,
      'lon': 105.8452337,
      'tags': {'name': 'Lotteria', 'cuisine': 'burger', 'amenity': 'fast_food'},
    },
    {
      'id': 6335544623,
      'lat': 21.0019966,
      'lon': 105.8463038,
      'tags': {'name': 'Popeyes', 'cuisine': 'chicken', 'amenity': 'fast_food'},
    },
    {
      'id': 11254919071,
      'lat': 21.0057539,
      'lon': 105.8458586,
      'tags': {
        'name': 'Cafe Mộc',
        'cuisine': 'coffee_shop',
        'amenity': 'cafe',
        'opening_hours': '7:00-23:00',
      },
    },
    {
      'id': 8163615939,
      'lat': 21.0008391,
      'lon': 105.8376456,
      'tags': {
        'name': 'Cà Phê Tùng',
        'cuisine': 'cafe;tea',
        'amenity': 'cafe',
        'opening_hours': '24/7',
      },
    },
    {
      'id': 3684899299,
      'lat': 20.9969779,
      'lon': 105.8459666,
      'tags': {
        'name': 'Quán Thị Mẹt',
        'cuisine': 'Bún_đậu_mắm_tôm',
        'amenity': 'restaurant',
      },
    },
    {
      'id': 3671198536,
      'lat': 21.0254125,
      'lon': 105.7913936,
      'tags': {
        'name': 'Nhà Hàng Moto-san',
        'cuisine': 'japanese',
        'amenity': 'restaurant',
      },
    },
  ];

  @override
  Future<List<RestaurantModel>> fetchNearby({
    required double lat,
    required double lon,
    required int radiusMeters,
  }) async {
    final origin = GeoPoint(lat: lat, lon: lon);
    return _nodes
        .map((node) => RestaurantModel.fromOverpassNode(node, origin: origin))
        .whereType<RestaurantModel>()
        .where((r) => r.distanceMeters <= radiusMeters)
        .toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  }
}
