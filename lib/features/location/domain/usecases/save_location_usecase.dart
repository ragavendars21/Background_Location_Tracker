import '../entities/location_entity.dart';
import '../repositories/location_repository.dart';

/// Persists a single GPS fix.
/// Called every 60 seconds by the background service.
class SaveLocationUsecase {
  final LocationRepository _repository;
  SaveLocationUsecase(this._repository);

  Future<void> call(LocationEntity location) =>
      _repository.saveLocation(location);
}
