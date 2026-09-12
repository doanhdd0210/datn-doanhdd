import '../utils/geo_point.dart';

/// Toạ độ mặc định dùng khi chưa bật GPS thật ([FixedLocationService]) —
/// khu Bách Khoa, Hà Nội. Xem `lunch_picker_module.dart` để đổi sang GPS.
const kDefaultOrigin = GeoPoint(lat: 21.0045, lon: 105.8430);

const kDefaultRadiusMeters = 900;

/// Thanh trượt bán kính trong bộ lọc — kéo tự do thay vì chỉ 3 mốc cố định.
const kMinRadiusMeters = 300;
const kMaxRadiusMeters = 2000;
const kRadiusStepMeters = 100;
