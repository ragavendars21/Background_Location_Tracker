import '../repositories/location_repository.dart';

class DeleteSessionUsecase {
  final LocationRepository _repository;
  DeleteSessionUsecase(this._repository);

  Future<void> call(String sessionId) => _repository.deleteSession(sessionId);
}
