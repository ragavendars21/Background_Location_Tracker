import '../../domain/entities/location_entity.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_local_datasource.dart';
import '../models/location_model.dart';

class LocationRepositoryImpl implements LocationRepository {
  final LocationLocalDatasource _datasource;

  LocationRepositoryImpl(this._datasource);

  @override
  Future<void> saveLocation(LocationEntity location) async {
    final model = LocationModel.fromEntity(location);
    await _datasource.insertLocation(model);
  }

  @override
  Future<List<LocationEntity>> getAllLocations() {
    return _datasource.fetchAllLocations();
  }

  @override
  Future<List<LocationEntity>> getLocationsBySession(String sessionId) {
    return _datasource.fetchBySession(sessionId);
  }

  @override
  Future<LocationEntity?> getLatestLocation() {
    return _datasource.fetchLatestLocation();
  }

  @override
  Future<List<String>> getSessionIds() {
    return _datasource.fetchSessionIds();
  }

  @override
  Future<int> getLocationCount() {
    return _datasource.countAll();
  }

  @override
  Future<void> deleteSession(String sessionId) {
    return _datasource.deleteBySession(sessionId);
  }

  @override
  Future<void> clearAllLocations() {
    return _datasource.deleteAllLocations();
  }
}
