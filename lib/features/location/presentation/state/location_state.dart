import 'package:flutter/foundation.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/entities/tracking_session.dart';

@immutable
class LocationState {
  final List<LocationEntity> locations;
  final List<String> sessionIds;
  final TrackingSession? currentSession;
  final bool isLoading;
  final bool isBusy;
  final String? error;

  const LocationState({
    this.locations = const [],
    this.sessionIds = const [],
    this.currentSession,
    this.isLoading = false,
    this.isBusy = false,
    this.error,
  });

  bool get isTracking => currentSession?.isActive ?? false;
  int get locationCount => locations.length;

  LocationState copyWith({
    List<LocationEntity>? locations,
    List<String>? sessionIds,
    TrackingSession? currentSession,
    bool? isLoading,
    bool? isBusy,
    String? error,
    bool clearSession = false,
    bool clearError = false,
  }) {
    return LocationState(
      locations: locations ?? this.locations,
      sessionIds: sessionIds ?? this.sessionIds,
      currentSession: clearSession
          ? null
          : (currentSession ?? this.currentSession),
      isLoading: isLoading ?? this.isLoading,
      isBusy: isBusy ?? this.isBusy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
