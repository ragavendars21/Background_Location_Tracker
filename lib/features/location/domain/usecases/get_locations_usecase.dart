import '../entities/location_entity.dart';
import '../repositories/location_repository.dart';

class GetLocationsUsecase {
  final LocationRepository _repository;
  GetLocationsUsecase(this._repository);

  Future<List<LocationEntity>> call() => _repository.getAllLocations();
}
