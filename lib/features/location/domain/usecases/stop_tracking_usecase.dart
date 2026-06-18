import '../entities/tracking_session.dart';
import '../repositories/tracking_repository.dart';

/// Stops the active GPS tracking session.
///
/// Business rule: this operation is *idempotent* — calling StopTracking when
/// nothing is running is a no-op, not an error. This prevents crashes if the
/// user somehow taps STOP twice, or if the OS killed the service independently.
///
/// Returns the [TrackingSession] stamped with its end time, so the caller
/// can display "Session lasted 14 minutes" without extra state.
class StopTrackingUsecase {
  final TrackingRepository _repository;

  StopTrackingUsecase(this._repository);

  Future<TrackingSession?> call(TrackingSession? currentSession) async {
    final running = await _repository.isTracking();

    // Idempotency: if nothing is running, return null — not an error
    if (!running) return null;

    await _repository.stopTracking();

    // Stamp the session with its end time and return it
    return currentSession?.stopped();
  }
}
