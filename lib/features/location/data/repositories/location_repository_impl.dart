import '../../domain/entities/location_entity.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_local_datasource.dart';
import '../models/location_model.dart';

/// Concrete implementation of [LocationRepository].
///
/// This class sits in the Data layer and bridges two worlds:
///   • Domain world  — speaks [LocationEntity] (pure Dart objects)
///   • Data world    — speaks [LocationModel] (knows about SQLite maps)
///
/// The repository converts entities ↔ models so that neither the domain
/// nor the datasource needs to know about the other.
class LocationRepositoryImpl implements LocationRepository {
  final LocationLocalDatasource _datasource;

  LocationRepositoryImpl(this._datasource);

  // ── Write ──────────────────────────────────────────────────────────────────

  @override
  Future<void> saveLocation(LocationEntity location) async {
    // Convert domain entity → data model before handing to datasource
    final model = LocationModel.fromEntity(location);
    await _datasource.insertLocation(model);
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  @override
  Future<List<LocationEntity>> getAllLocations() {
    // LocationModel IS-A LocationEntity (inheritance), so no extra mapping needed
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

  // ── Delete ─────────────────────────────────────────────────────────────────

  @override
  Future<void> deleteSession(String sessionId) {
    return _datasource.deleteBySession(sessionId);
  }

  @override
  Future<void> clearAllLocations() {
    return _datasource.deleteAllLocations();
  }
}
