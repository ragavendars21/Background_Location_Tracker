import '../entities/location_entity.dart';
import '../repositories/location_repository.dart';

/// Fetches all recorded GPS points across every session, newest first.
/// Used by the location list screen to show history.
class GetLocationsUsecase {
  final LocationRepository _repository;
  GetLocationsUsecase(this._repository);

  Future<List<LocationEntity>> call() => _repository.getAllLocations();
}
