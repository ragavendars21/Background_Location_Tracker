import '../entities/location_entity.dart';
import '../repositories/location_repository.dart';

/// Fetches all GPS points belonging to one tracking session, oldest first.
/// Oldest-first = chronological route order for map display.
class GetLocationsBySessionUsecase {
  final LocationRepository _repository;
  GetLocationsBySessionUsecase(this._repository);

  Future<List<LocationEntity>> call(String sessionId) =>
      _repository.getLocationsBySession(sessionId);
}
