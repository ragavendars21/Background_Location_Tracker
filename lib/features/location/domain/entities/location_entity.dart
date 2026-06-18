/// Pure domain object — zero Flutter / SQLite dependencies.
///
/// The Domain layer is the heart of Clean Architecture.
/// It knows NOTHING about how data is stored or displayed;
/// it only describes what a "location" means to the business.
class LocationEntity {
  final int?   id;         // null before the row is persisted
  final double latitude;
  final double longitude;
  final double accuracy;   // metres — lower is better
  final String timestamp;  // ISO 8601 UTC, e.g. "2026-06-14T10:30:00.000Z"
  final String sessionId;  // UUID grouping all points in one tracking run

  const LocationEntity({
    this.id,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    required this.sessionId,
  });

  // ── copyWith ───────────────────────────────────────────────────────────────
  // Immutable update pattern — returns a new instance with overridden fields.
  LocationEntity copyWith({
    int?    id,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? timestamp,
    String? sessionId,
  }) {
    return LocationEntity(
      id:        id        ?? this.id,
      latitude:  latitude  ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy:  accuracy  ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  // ── Equality ───────────────────────────────────────────────────────────────
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationEntity &&
          runtimeType == other.runtimeType &&
          id        == other.id &&
          latitude  == other.latitude &&
          longitude == other.longitude &&
          accuracy  == other.accuracy &&
          timestamp == other.timestamp &&
          sessionId == other.sessionId;

  @override
  int get hashCode => Object.hash(
        id, latitude, longitude, accuracy, timestamp, sessionId,
      );

  @override
  String toString() =>
      'LocationEntity(id: $id, lat: $latitude, lng: $longitude, '
      'accuracy: ${accuracy}m, ts: $timestamp, session: $sessionId)';
}
