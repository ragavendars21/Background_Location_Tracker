import '../repositories/location_repository.dart';

/// Wipes every row in the locations table — factory reset for location data.
class ClearAllLocationsUsecase {
  final LocationRepository _repository;
  ClearAllLocationsUsecase(this._repository);

  Future<void> call() => _repository.clearAllLocations();
}
