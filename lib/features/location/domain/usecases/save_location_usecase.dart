import '../entities/location_entity.dart';
import '../repositories/location_repository.dart';

class SaveLocationUsecase {
  final LocationRepository _repository;
  SaveLocationUsecase(this._repository);

  Future<void> call(LocationEntity location) =>
      _repository.saveLocation(location);
}
