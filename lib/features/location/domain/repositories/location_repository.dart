import '../entities/location_entity.dart';

/// The Repository CONTRACT lives in the Domain layer.
///
/// Key idea: Domain defines WHAT operations exist; Data layer defines HOW
/// they work. This lets us swap SQLite for Hive or a REST API without
/// touching a single use case or UI file.
abstract class LocationRepository {
  // ── Write ──────────────────────────────────────────────────────────────────

  /// Persist one GPS fix to local storage.
  Future<void> saveLocation(LocationEntity location);

  // ── Read ───────────────────────────────────────────────────────────────────

  /// All recorded locations, newest first.
  Future<List<LocationEntity>> getAllLocations();

  /// All locations belonging to a single tracking session, oldest first
  /// (chronological order = correct route playback order).
  Future<List<LocationEntity>> getLocationsBySession(String sessionId);

  /// Returns the most recently saved location, or null if none exist.
  Future<LocationEntity?> getLatestLocation();

  /// Returns every distinct session ID, newest session first.
  Future<List<String>> getSessionIds();

  /// Total number of recorded points across all sessions.
  Future<int> getLocationCount();

  // ── Delete ─────────────────────────────────────────────────────────────────

  /// Remove all locations that belong to [sessionId].
  Future<void> deleteSession(String sessionId);

  /// Wipe the entire locations table.
  Future<void> clearAllLocations();
}
