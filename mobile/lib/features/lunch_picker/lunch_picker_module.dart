import '../../core/constants/app_constants.dart';
import '../../core/location/location_service.dart';
import 'data/datasources/restaurant_in_memory_data_source.dart';
import 'data/datasources/restaurant_remote_data_source.dart';
import 'data/repositories/restaurant_repository_impl.dart';
import 'domain/usecases/get_nearby_restaurants.dart';
import 'domain/usecases/pick_random_restaurant.dart';
import 'presentation/viewmodel/lunch_picker_bloc.dart';

/// Wiring for the "Trưa nay ăn gì" feature — plain factory functions rather
/// than a service locator, to match how the rest of JavaUp is built
/// (Provider + manual construction, no get_it).
///
/// Mặc định chạy offline (snapshot Overpass nhúng sẵn) + vị trí cố định
/// (Bách Khoa) để không cần xin quyền/mạng. Đổi sang thật:
///   RestaurantRemoteDataSource -> RestaurantOverpassDataSource(client: http.Client())
///   LocationService            -> const GeolocatorLocationService()
/// (nhớ khai quyền vị trí trong AndroidManifest.xml / Info.plist trước).
class LunchPickerModule {
  const LunchPickerModule._();

  static const RestaurantRemoteDataSource _dataSource =
      RestaurantInMemoryDataSource();

  static const LocationService _locationService = FixedLocationService(
    kDefaultOrigin,
  );

  static LunchPickerBloc createBloc() {
    const repository = RestaurantRepositoryImpl(_dataSource);
    return LunchPickerBloc(
      getNearbyRestaurants: const GetNearbyRestaurants(repository),
      pickRandomRestaurant: PickRandomRestaurant(),
      locationService: _locationService,
    );
  }
}
