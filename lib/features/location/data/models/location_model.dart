import '../../domain/entities/location_entity.dart';
import '../../../../core/constants/db_constants.dart';

class LocationModel extends LocationEntity {
  const LocationModel({
    super.id,
    required super.latitude,
    required super.longitude,
    required super.accuracy,
    required super.timestamp,
    required super.sessionId,
  });

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      id: map[DbConstants.colId] as int?,

      latitude: (map[DbConstants.colLatitude] as num).toDouble(),
      longitude: (map[DbConstants.colLongitude] as num).toDouble(),
      accuracy: (map[DbConstants.colAccuracy] as num).toDouble(),
      timestamp: map[DbConstants.colTimestamp] as String,
      sessionId: map[DbConstants.colSessionId] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DbConstants.colLatitude: latitude,
      DbConstants.colLongitude: longitude,
      DbConstants.colAccuracy: accuracy,
      DbConstants.colTimestamp: timestamp,
      DbConstants.colSessionId: sessionId,
    };
  }

  factory LocationModel.fromEntity(LocationEntity entity) {
    return LocationModel(
      id: entity.id,
      latitude: entity.latitude,
      longitude: entity.longitude,
      accuracy: entity.accuracy,
      timestamp: entity.timestamp,
      sessionId: entity.sessionId,
    );
  }
}
