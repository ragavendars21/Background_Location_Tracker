import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:background_location_tracker/features/location/domain/entities/location_entity.dart';
import 'package:background_location_tracker/features/location/presentation/state/location_state.dart';
import 'package:background_location_tracker/core/providers/providers.dart';

final locationProvider = NotifierProvider<LocationNotifier, LocationState>(
  LocationNotifier.new,
);

class LocationNotifier extends Notifier<LocationState> {
  @override
  LocationState build() {
    Future.microtask(_init);
    return const LocationState(isLoading: true);
  }

  Future<void> _init() async {
    await Future.wait([loadLocations(), loadSessionIds(), reattachSession()]);
  }

  Future<void> startTracking() async {
    if (state.isBusy || state.isTracking) return;

    state = state.copyWith(isBusy: true, clearError: true);

    try {
      final session = await ref.read(startTrackingUsecaseProvider)();
      state = state.copyWith(currentSession: session, isBusy: false);
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: 'Could not start tracking: $e',
      );
    }
  }

  Future<void> stopTracking() async {
    if (state.isBusy || !state.isTracking) return;

    state = state.copyWith(isBusy: true, clearError: true);

    try {
      final stopped = await ref.read(stopTrackingUsecaseProvider)(
        state.currentSession,
      );
      state = state.copyWith(currentSession: stopped, isBusy: false);

      await Future.wait([loadLocations(), loadSessionIds()]);
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error: 'Could not stop tracking: $e',
      );
    }
  }

  Future<void> reattachSession() async {
    try {
      final session = await ref.read(getCurrentSessionUsecaseProvider)();
      if (session != null) {
        state = state.copyWith(currentSession: session);
      }
    } catch (_) {}
  }

  Future<void> loadLocations() async {
    try {
      final locations = await ref.read(getLocationsUsecaseProvider)();
      state = state.copyWith(
        locations: locations,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load locations: $e',
      );
    }
  }

  Future<void> loadSessionIds() async {
    try {
      final ids = await ref.read(getSessionIdsUsecaseProvider)();
      state = state.copyWith(sessionIds: ids, clearError: true);
    } catch (e) {
      state = state.copyWith(error: 'Failed to load sessions: $e');
    }
  }

  Future<List<LocationEntity>> getLocationsBySession(String sessionId) async {
    try {
      return await ref.read(getLocationsBySessionUsecaseProvider)(sessionId);
    } catch (e) {
      state = state.copyWith(error: 'Failed to load session: $e');
      return [];
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      await ref.read(deleteSessionUsecaseProvider)(sessionId);
      await Future.wait([loadLocations(), loadSessionIds()]);
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete session: $e');
    }
  }

  Future<void> clearLocations() async {
    try {
      await ref.read(clearAllLocationsUsecaseProvider)();
      state = state.copyWith(
        locations: const [],
        sessionIds: const [],
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to clear locations: $e');
    }
  }
}
