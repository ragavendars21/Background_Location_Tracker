import '../repositories/location_repository.dart';

/// Returns every distinct session ID recorded on this device,
/// ordered with the most recent session first.
///
/// Use this to build a "Session History" list where each row
/// represents one START→STOP tracking run.
class GetSessionIdsUsecase {
  final LocationRepository _repository;
  GetSessionIdsUsecase(this._repository);

  Future<List<String>> call() => _repository.getSessionIds();
}
