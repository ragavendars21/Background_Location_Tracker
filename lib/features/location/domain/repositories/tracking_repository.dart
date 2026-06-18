/// Contract for starting and stopping background GPS tracking.
///
/// Why a separate repository from [LocationRepository]?
/// ──────────────────────────────────────────────────────
/// Single Responsibility: [LocationRepository] owns *data* (CRUD on rows).
/// [TrackingRepository] owns *behaviour* (running/stopping a background process).
/// Keeping them separate means swapping the storage engine never touches
/// the service-start logic, and vice versa.
///
/// The concrete implementation lives in the Data layer
/// (tracking_repository_impl.dart) and calls [BackgroundLocationService].
/// The Domain layer never imports that — it only knows this interface.
abstract class TrackingRepository {
  /// Starts the background GPS service with the given [sessionId].
  /// Every location the service records will carry this ID.
  Future<void> startTracking(String sessionId);

  /// Stops the background GPS service.
  /// Does nothing if the service is already stopped (idempotent).
  Future<void> stopTracking();

  /// Returns true if the background service is currently running.
  Future<bool> isTracking();

  /// Returns the session ID of the currently active session,
  /// or null if no session is running.
  Future<String?> getActiveSessionId();
}
