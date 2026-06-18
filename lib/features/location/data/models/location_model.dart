import '../../domain/entities/location_entity.dart';
import '../../../../core/constants/db_constants.dart';

/// Data-layer representation of a location.
///
/// Extends [LocationEntity] so it can be used anywhere the domain
/// expects an entity — no extra mapping step needed upward.
///
/// DTO role
/// ────────
/// In Clean Architecture the Model IS the DTO for local storage:
///   • [toMap()]    → the "write DTO"  — what we hand to SQLite on INSERT
///   • [fromMap()]  → the "read DTO"   — what SQLite hands us on SELECT
///
/// If we later add a REST API, we would add [toJson()] / [fromJson()]
/// alongside [toMap()] — two DTOs, same Model class.
class LocationModel extends LocationEntity {
  const LocationModel({
    super.id,
    required super.latitude,
    required super.longitude,
    required super.accuracy,
    required super.timestamp,
    required super.sessionId,
  });

  // ── Read DTO: SQLite row → LocationModel ──────────────────────────────────

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      id:        map[DbConstants.colId]        as int?,
      // SQLite returns REAL as double, but guard with .toDouble() for safety
      latitude:  (map[DbConstants.colLatitude]  as num).toDouble(),
      longitude: (map[DbConstants.colLongitude] as num).toDouble(),
      accuracy:  (map[DbConstants.colAccuracy]  as num).toDouble(),
      timestamp: map[DbConstants.colTimestamp]  as String,
      sessionId: map[DbConstants.colSessionId]  as String,
    );
  }

  // ── Write DTO: LocationModel → SQLite row ─────────────────────────────────

  /// Excludes [id] intentionally — SQLite auto-increments it on INSERT.
  /// Including it would break AUTOINCREMENT if id happened to already exist.
  Map<String, dynamic> toMap() {
    return {
      DbConstants.colLatitude:  latitude,
      DbConstants.colLongitude: longitude,
      DbConstants.colAccuracy:  accuracy,
      DbConstants.colTimestamp: timestamp,
      DbConstants.colSessionId: sessionId,
    };
  }

  // ── Entity → Model conversion ─────────────────────────────────────────────

  /// Lifts a pure domain [LocationEntity] into a Model so the datasource
  /// can call [toMap()] on it. The repository handles this conversion
  /// before passing data to the datasource.
  factory LocationModel.fromEntity(LocationEntity entity) {
    return LocationModel(
      id:        entity.id,
      latitude:  entity.latitude,
      longitude: entity.longitude,
      accuracy:  entity.accuracy,
      timestamp: entity.timestamp,
      sessionId: entity.sessionId,
    );
  }
}
