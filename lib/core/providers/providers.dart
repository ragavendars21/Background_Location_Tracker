/// Riverpod dependency-injection graph.
///
/// ── How to read this file ────────────────────────────────────────────────
/// Read it top-to-bottom. Each layer only imports from the layer above it.
///
///   Infrastructure → Datasource → Repository → UseCase
///
/// Notifiers (`LocationNotifier`, `BatteryNotifier`) are declared at the
/// bottom of their own files so they can import this file without circular
/// imports. The UI imports both this file and the notifier files.
///
/// ── Why `Provider<T>` (not ChangeNotifierProvider) ─────────────────────
/// `Provider<T>` in Riverpod is for stateless objects — factories, datasources,
/// repositories, use cases. They are constructed once, shared everywhere, and
/// thrown away only when the ProviderScope closes. No ChangeNotifier overhead.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────
import '../database/database_helper.dart';
import '../../features/location/data/datasources/location_local_datasource.dart';
import '../../features/battery/data/battery_platform_channel.dart';

// ── Data — repositories (implementations) ────────────────────────────────────
import '../../features/location/data/repositories/location_repository_impl.dart';
import '../../features/location/data/repositories/tracking_repository_impl.dart';
import '../../features/battery/data/repositories/battery_repository_impl.dart';

// ── Domain — repository interfaces ───────────────────────────────────────────
import '../../features/location/domain/repositories/location_repository.dart';
import '../../features/location/domain/repositories/tracking_repository.dart';
import '../../features/battery/domain/repositories/battery_repository.dart';

// ── Domain — use cases ────────────────────────────────────────────────────────
import '../../features/location/domain/usecases/start_tracking_usecase.dart';
import '../../features/location/domain/usecases/stop_tracking_usecase.dart';
import '../../features/location/domain/usecases/get_current_session_usecase.dart';
import '../../features/location/domain/usecases/get_locations_usecase.dart';
import '../../features/location/domain/usecases/get_locations_by_session_usecase.dart';
import '../../features/location/domain/usecases/get_session_ids_usecase.dart';
import '../../features/location/domain/usecases/delete_session_usecase.dart';
import '../../features/location/domain/usecases/clear_all_locations_usecase.dart';
import '../../features/battery/domain/usecases/get_battery_info_usecase.dart';

// ══ Layer 1 — Infrastructure ══════════════════════════════════════════════════

/// SQLite singleton. All datasources share this one handle.
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

/// Raw data operations on the locations table.
final locationDatasourceProvider = Provider<LocationLocalDatasource>((ref) {
  return LocationLocalDatasource(ref.watch(databaseHelperProvider));
});

/// Platform Channel wrapper for battery reads. One instance per app lifetime.
final batteryChannelProvider = Provider<BatteryPlatformChannel>((ref) {
  return BatteryPlatformChannel();
});

// ══ Layer 2 — Repositories ════════════════════════════════════════════════════

/// Implements LocationRepository — all CRUD on location rows.
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepositoryImpl(ref.watch(locationDatasourceProvider));
});

/// Implements TrackingRepository — start/stop background service.
final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  return TrackingRepositoryImpl();
});

/// Implements BatteryRepository — delegates to Platform Channel.
final batteryRepositoryProvider = Provider<BatteryRepository>((ref) {
  return BatteryRepositoryImpl(ref.watch(batteryChannelProvider));
});

// ══ Layer 3 — Use cases ═══════════════════════════════════════════════════════
//
// Each Provider wraps ONE use case class. Naming convention: <action>UsecaseProvider.
// Notifiers read these with ref.read() so they are never "watched" (they do not
// change after initial construction).

final startTrackingUsecaseProvider = Provider<StartTrackingUsecase>((ref) {
  return StartTrackingUsecase(ref.watch(trackingRepositoryProvider));
});

final stopTrackingUsecaseProvider = Provider<StopTrackingUsecase>((ref) {
  return StopTrackingUsecase(ref.watch(trackingRepositoryProvider));
});

final getCurrentSessionUsecaseProvider = Provider<GetCurrentSessionUsecase>((ref) {
  return GetCurrentSessionUsecase(ref.watch(trackingRepositoryProvider));
});

final getLocationsUsecaseProvider = Provider<GetLocationsUsecase>((ref) {
  return GetLocationsUsecase(ref.watch(locationRepositoryProvider));
});

final getLocationsBySessionUsecaseProvider =
    Provider<GetLocationsBySessionUsecase>((ref) {
  return GetLocationsBySessionUsecase(ref.watch(locationRepositoryProvider));
});

final getSessionIdsUsecaseProvider = Provider<GetSessionIdsUsecase>((ref) {
  return GetSessionIdsUsecase(ref.watch(locationRepositoryProvider));
});

final deleteSessionUsecaseProvider = Provider<DeleteSessionUsecase>((ref) {
  return DeleteSessionUsecase(ref.watch(locationRepositoryProvider));
});

final clearAllLocationsUsecaseProvider = Provider<ClearAllLocationsUsecase>((ref) {
  return ClearAllLocationsUsecase(ref.watch(locationRepositoryProvider));
});

final getBatteryInfoUsecaseProvider = Provider<GetBatteryInfoUsecase>((ref) {
  return GetBatteryInfoUsecase(ref.watch(batteryRepositoryProvider));
});
