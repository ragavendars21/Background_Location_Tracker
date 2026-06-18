import '../entities/location_entity.dart';

abstract class LocationRepository {
  Future<void> saveLocation(LocationEntity location);

  Future<List<LocationEntity>> getAllLocations();

  Future<List<LocationEntity>> getLocationsBySession(String sessionId);

  Future<LocationEntity?> getLatestLocation();

  Future<List<String>> getSessionIds();

  Future<int> getLocationCount();

  Future<void> deleteSession(String sessionId);

  Future<void> clearAllLocations();
}
