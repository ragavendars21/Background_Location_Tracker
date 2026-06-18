import '../../domain/repositories/tracking_repository.dart';
import '../../../../services/background_location_service.dart';

class TrackingRepositoryImpl implements TrackingRepository {
  String? _activeSessionId;

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
    final running = await BackgroundLocationService.isRunning();
    if (!running) return false;
    final sessionId = await BackgroundLocationService.getSessionId();
    return sessionId != null;
  }

  @override
  Future<String?> getActiveSessionId() async {
    if (_activeSessionId != null) return _activeSessionId;

    return BackgroundLocationService.getSessionId();
  }
}
