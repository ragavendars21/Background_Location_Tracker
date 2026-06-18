class LocationEntity {
  final int? id;
  final double latitude;
  final double longitude;
  final double accuracy;
  final String timestamp;
  final String sessionId;

  const LocationEntity({
    this.id,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    required this.sessionId,
  });

  LocationEntity copyWith({
    int? id,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? timestamp,
    String? sessionId,
  }) {
    return LocationEntity(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          accuracy == other.accuracy &&
          timestamp == other.timestamp &&
          sessionId == other.sessionId;

  @override
  int get hashCode =>
      Object.hash(id, latitude, longitude, accuracy, timestamp, sessionId);

  @override
  String toString() =>
      'LocationEntity(id: $id, lat: $latitude, lng: $longitude, '
      'accuracy: ${accuracy}m, ts: $timestamp, session: $sessionId)';
}
