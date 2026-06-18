import '../entities/tracking_session.dart';
import '../repositories/tracking_repository.dart';

class GetCurrentSessionUsecase {
  final TrackingRepository _repository;

  GetCurrentSessionUsecase(this._repository);

  Future<TrackingSession?> call() async {
    final running = await _repository.isTracking();
    if (!running) return null;

    final sessionId = await _repository.getActiveSessionId();
    if (sessionId == null) return null;

    return TrackingSession(
      id: sessionId,
      startedAt: DateTime.now().toUtc(),
      status: TrackingStatus.active,
    );
  }
}
