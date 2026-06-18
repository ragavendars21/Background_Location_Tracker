import '../../domain/repositories/tracking_repository.dart';
import '../../../../services/background_location_service.dart';

/// Concrete implementation of [TrackingRepository].
///
/// This class is the single bridge between the domain contract
/// ([TrackingRepository]) and the infrastructure ([BackgroundLocationService]).
/// The domain layer never imports either of those — it only knows the interface.
class TrackingRepositoryImpl implements TrackingRepository {
  /// In-memory cache of the session ID for the current process lifetime.
  ///
  /// After a force-kill + OS restart, this field is null (memory was wiped).
  /// [getActiveSessionId] falls back to SharedPreferences in that case.
  String? _activeSessionId;

  // ── TrackingRepository ─────────────────────────────────────────────────────

  @override
  Future<void> startTracking(String sessionId) async {
    _activeSessionId = sessionId;
    await BackgroundLocationService.start(sessionId);
  }

  @override
  Future<void> stopTracking() async {
    _activeSessionId = null;
    await BackgroundLocationService.stop();
  }

  @override
  Future<bool> isTracking() async {
    // Both conditions must be true: the service must be running AND a session
    // ID must be present in SharedPreferences. Checking only isRunning() is
    // insufficient because the WatchdogReceiver (flutter_background_service's
    // restart mechanism) can start the service briefly in the 5-second window
    // after every onStartCommand(), even when there is no active session.
    // That false positive causes StartTrackingUsecase to throw "already active"
    // and leaves the Stop button permanently disabled.
    final running = await BackgroundLocationService.isRunning();
    if (!running) return false;
    final sessionId = await BackgroundLocationService.getSessionId();
    return sessionId != null;
  }

  @override
  Future<String?> getActiveSessionId() async {
    // Fast path: this process started the session, ID is in memory.
    if (_activeSessionId != null) return _activeSessionId;

    // Slow path (kill+reopen): the service survived but our memory was wiped.
    // BackgroundLocationService.getSessionId() reads from SharedPreferences,
    // which persists across process boundaries.
    return BackgroundLocationService.getSessionId();
  }
}
