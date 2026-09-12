import '../utils/geo_point.dart';

/// Toạ độ mặc định dùng khi chưa bật GPS thật ([FixedLocationService]) —
/// khu Bách Khoa, Hà Nội. Xem `lunch_picker_module.dart` để đổi sang GPS.
const kDefaultOrigin = GeoPoint(lat: 21.0045, lon: 105.8430);

const kDefaultRadiusMeters = 900;
const kRadiusChoicesMeters = [300, 600, 900];
