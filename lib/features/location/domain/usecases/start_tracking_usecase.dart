import 'package:uuid/uuid.dart';
import '../entities/tracking_session.dart';
import '../repositories/tracking_repository.dart';

class StartTrackingUsecase {
  final TrackingRepository _repository;

  StartTrackingUsecase(this._repository);

  Future<TrackingSession> call() async {
    final alreadyRunning = await _repository.isTracking();
    if (alreadyRunning) {
      throw StateError(
        'A tracking session is already active. Stop it before starting a new one.',
      );
    }

    final sessionId = const Uuid().v4();

    await _repository.startTracking(sessionId);

    return TrackingSession(
      id: sessionId,
      startedAt: DateTime.now().toUtc(),
      status: TrackingStatus.active,
    );
  }
}
