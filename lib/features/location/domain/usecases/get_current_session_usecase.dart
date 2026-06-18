import '../entities/tracking_session.dart';
import '../repositories/tracking_repository.dart';

/// Reconstructs the active [TrackingSession] from persisted state.
///
/// Why is this needed?
/// ───────────────────
/// After Android kills the app process (swipe-to-dismiss), Flutter's in-memory
/// provider state is wiped. When the user reopens the app, the background
/// service may still be running. This use case lets the UI re-attach to that
/// live session without restarting it.
///
/// What it does NOT do: query the database for start time or history — that is
/// the job of [LocationRepository]. This use case only answers "is something
/// running, and if so, what is its session ID?"
class GetCurrentSessionUsecase {
  final TrackingRepository _repository;

  GetCurrentSessionUsecase(this._repository);

  Future<TrackingSession?> call() async {
    final running = await _repository.isTracking();
    if (!running) return null;

    final sessionId = await _repository.getActiveSessionId();
    if (sessionId == null) return null;

    // We do not know the original startedAt after a process restart.
    // Use DateTime.now() as a best-effort fallback so the elapsed timer
    // starts from a reasonable point rather than crashing.
    return TrackingSession(
      id:        sessionId,
      startedAt: DateTime.now().toUtc(),
      status:    TrackingStatus.active,
    );
  }
}
