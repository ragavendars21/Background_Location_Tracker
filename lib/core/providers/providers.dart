library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';
import '../../features/location/data/datasources/location_local_datasource.dart';
import '../../features/battery/data/battery_platform_channel.dart';

import '../../features/location/data/repositories/location_repository_impl.dart';
import '../../features/location/data/repositories/tracking_repository_impl.dart';
import '../../features/battery/data/repositories/battery_repository_impl.dart';

import '../../features/location/domain/repositories/location_repository.dart';
import '../../features/location/domain/repositories/tracking_repository.dart';
import '../../features/battery/domain/repositories/battery_repository.dart';

import '../../features/location/domain/usecases/start_tracking_usecase.dart';
import '../../features/location/domain/usecases/stop_tracking_usecase.dart';
import '../../features/location/domain/usecases/get_current_session_usecase.dart';
import '../../features/location/domain/usecases/get_locations_usecase.dart';
import '../../features/location/domain/usecases/get_locations_by_session_usecase.dart';
import '../../features/location/domain/usecases/get_session_ids_usecase.dart';
import '../../features/location/domain/usecases/delete_session_usecase.dart';
import '../../features/location/domain/usecases/clear_all_locations_usecase.dart';
import '../../features/battery/domain/usecases/get_battery_info_usecase.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

final locationDatasourceProvider = Provider<LocationLocalDatasource>((ref) {
  return LocationLocalDatasource(ref.watch(databaseHelperProvider));
});

final batteryChannelProvider = Provider<BatteryPlatformChannel>((ref) {
  return BatteryPlatformChannel();
});

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepositoryImpl(ref.watch(locationDatasourceProvider));
});

final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  return TrackingRepositoryImpl();
});

final batteryRepositoryProvider = Provider<BatteryRepository>((ref) {
  return BatteryRepositoryImpl(ref.watch(batteryChannelProvider));
});

final startTrackingUsecaseProvider = Provider<StartTrackingUsecase>((ref) {
  return StartTrackingUsecase(ref.watch(trackingRepositoryProvider));
});

final stopTrackingUsecaseProvider = Provider<StopTrackingUsecase>((ref) {
  return StopTrackingUsecase(ref.watch(trackingRepositoryProvider));
});

final getCurrentSessionUsecaseProvider = Provider<GetCurrentSessionUsecase>((
  ref,
) {
  return GetCurrentSessionUsecase(ref.watch(trackingRepositoryProvider));
});

final getLocationsUsecaseProvider = Provider<GetLocationsUsecase>((ref) {
  return GetLocationsUsecase(ref.watch(locationRepositoryProvider));
});

final getLocationsBySessionUsecaseProvider =
    Provider<GetLocationsBySessionUsecase>((ref) {
      return GetLocationsBySessionUsecase(
        ref.watch(locationRepositoryProvider),
      );
    });

final getSessionIdsUsecaseProvider = Provider<GetSessionIdsUsecase>((ref) {
  return GetSessionIdsUsecase(ref.watch(locationRepositoryProvider));
});

final deleteSessionUsecaseProvider = Provider<DeleteSessionUsecase>((ref) {
  return DeleteSessionUsecase(ref.watch(locationRepositoryProvider));
});

final clearAllLocationsUsecaseProvider = Provider<ClearAllLocationsUsecase>((
  ref,
) {
  return ClearAllLocationsUsecase(ref.watch(locationRepositoryProvider));
});

final getBatteryInfoUsecaseProvider = Provider<GetBatteryInfoUsecase>((ref) {
  return GetBatteryInfoUsecase(ref.watch(batteryRepositoryProvider));
});
