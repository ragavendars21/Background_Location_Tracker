import '../repositories/location_repository.dart';

/// Deletes every GPS point that belongs to [sessionId].
/// The user can swipe-to-delete a single session without losing all history.
class DeleteSessionUsecase {
  final LocationRepository _repository;
  DeleteSessionUsecase(this._repository);

  Future<void> call(String sessionId) => _repository.deleteSession(sessionId);
}
