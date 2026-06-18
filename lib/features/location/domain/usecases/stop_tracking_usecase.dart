import '../entities/tracking_session.dart';
import '../repositories/tracking_repository.dart';

class StopTrackingUsecase {
  final TrackingRepository _repository;

  StopTrackingUsecase(this._repository);

  Future<TrackingSession?> call(TrackingSession? currentSession) async {
    final running = await _repository.isTracking();

    if (!running) return null;

    await _repository.stopTracking();

    return currentSession?.stopped();
  }
}
