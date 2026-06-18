abstract class TrackingRepository {
  Future<void> startTracking(String sessionId);

  Future<void> stopTracking();

  Future<bool> isTracking();

  Future<String?> getActiveSessionId();
}
