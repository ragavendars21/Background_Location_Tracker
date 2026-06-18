import 'package:flutter/foundation.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/entities/tracking_session.dart';

/// Immutable snapshot of everything the location feature UI needs to render.
///
/// Why immutable?
/// ──────────────
/// Riverpod detects state changes by comparing the old and new state objects
/// with ==. If we mutated a mutable class in place, Riverpod would see the
/// same object reference and skip the rebuild. Immutable + copyWith() is the
/// correct Riverpod (and Flutter) state pattern.
@immutable
class LocationState {
  final List<LocationEntity> locations;
  final List<String>         sessionIds;
  final TrackingSession?     currentSession;
  final bool                 isLoading; // initial data load
  final bool                 isBusy;   // start/stop operation in flight
  final String?              error;

  const LocationState({
    this.locations     = const [],
    this.sessionIds    = const [],
    this.currentSession,
    this.isLoading     = false,
    this.isBusy        = false,
    this.error,
  });

  // ── Convenience getters ────────────────────────────────────────────────────

  bool get isTracking    => currentSession?.isActive ?? false;
  int  get locationCount => locations.length;

  // ── Mutation helper ────────────────────────────────────────────────────────

  LocationState copyWith({
    List<LocationEntity>? locations,
    List<String>?         sessionIds,
    TrackingSession?      currentSession,
    bool?                 isLoading,
    bool?                 isBusy,
    String?               error,
    bool                  clearSession = false,
    bool                  clearError   = false,
  }) {
    return LocationState(
      locations:      locations      ?? this.locations,
      sessionIds:     sessionIds     ?? this.sessionIds,
      currentSession: clearSession   ? null : (currentSession ?? this.currentSession),
      isLoading:      isLoading      ?? this.isLoading,
      isBusy:         isBusy         ?? this.isBusy,
      error:          clearError     ? null : (error ?? this.error),
    );
  }
}
