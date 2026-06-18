import '../repositories/location_repository.dart';

class GetSessionIdsUsecase {
  final LocationRepository _repository;
  GetSessionIdsUsecase(this._repository);

  Future<List<String>> call() => _repository.getSessionIds();
}
