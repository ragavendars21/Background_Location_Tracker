import '../repositories/location_repository.dart';

class ClearAllLocationsUsecase {
  final LocationRepository _repository;
  ClearAllLocationsUsecase(this._repository);

  Future<void> call() => _repository.clearAllLocations();
}
