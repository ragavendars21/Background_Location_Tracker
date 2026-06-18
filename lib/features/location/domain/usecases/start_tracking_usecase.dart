import 'package:uuid/uuid.dart';
import '../entities/tracking_session.dart';
import '../repositories/tracking_repository.dart';

/// Begins a new GPS tracking session.
///
/// Business rules enforced here (not in the UI, not in the repository):
///   1. A session cannot be started if one is already running.
///   2. A new unique session ID is generated before the service starts.
///   3. The caller receives a [TrackingSession] object — a receipt of the
///      session they just created — instead of a bare string ID.
///
/// Why does this exist as a separate class instead of a method?
/// ─────────────────────────────────────────────────────────────
/// A use case is the single source of truth for one piece of business logic.
/// If three different UI screens all need to start tracking (dashboard,
/// notification action, widget), they all call [StartTrackingUsecase].
/// When a business rule changes, you update exactly one file.
class StartTrackingUsecase {
  final TrackingRepository _repository;

  StartTrackingUsecase(this._repository);

  Future<TrackingSession> call() async {
    // Rule 1: Guard against double-start
    final alreadyRunning = await _repository.isTracking();
    if (alreadyRunning) {
      throw StateError(
        'A tracking session is already active. Stop it before starting a new one.',
      );
    }

    // Rule 2: Generate a guaranteed-unique session ID
    // UUID v4 = random — collision probability is astronomically small
    // (uuid is a pure-Dart package; acceptable in the domain layer)
    final sessionId = const Uuid().v4();

    // Delegate the actual service start to the repository
    await _repository.startTracking(sessionId);

    // Rule 3: Return a rich domain object, not a raw string
    return TrackingSession(
      id:        sessionId,
      startedAt: DateTime.now().toUtc(),
      status:    TrackingStatus.active,
    );
  }
}
