import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:background_location_tracker/features/location/domain/entities/location_entity.dart';
import 'package:background_location_tracker/features/location/presentation/state/location_state.dart';
import 'package:background_location_tracker/core/providers/providers.dart';

// ── Provider declaration ───────────────────────────────────────────────────────
//
// Declared at the top so it is easy to find when reading the file.
// The notifier class itself is below.
//
// Why NotifierProvider and not ChangeNotifierProvider?
//   • State is immutable — accidental mutation bugs are impossible.
//   • No notifyListeners() — Riverpod rebuilds on every `state =` assignment.
//   • ref gives access to the full DI graph without constructor arguments.

/// The single source of truth for all location + tracking UI state.
/// Widgets read it with: ref.watch(locationProvider)
/// Widgets trigger actions with: ref.read(locationProvider.notifier).startTracking()
final locationProvider =
    NotifierProvider<LocationNotifier, LocationState>(LocationNotifier.new);

// ── Notifier ──────────────────────────────────────────────────────────────────

class LocationNotifier extends Notifier<LocationState> {

  // ── Riverpod lifecycle ───────────────────────────────────────────────────────

  /// Called automatically when the first widget calls ref.watch(locationProvider).
  /// Must return synchronously — async init is kicked off via Future.microtask.
  @override
  LocationState build() {
    Future.microtask(_init);
    return const LocationState(isLoading: true);
  }

  Future<void> _init() async {
    // Run the three startup tasks concurrently — no reason to wait for each.
    await Future.wait([
      loadLocations(),
      loadSessionIds(),
      reattachSession(),
    ]);
  }

  // ── Tracking ─────────────────────────────────────────────────────────────────

  Future<void> startTracking() async {
    if (state.isBusy || state.isTracking) return;

    state = state.copyWith(isBusy: true, clearError: true);

    try {
      // ref.read() — correct for actions; ref.watch() is for build() only.
      final session = await ref.read(startTrackingUsecaseProvider)();
      state = state.copyWith(currentSession: session, isBusy: false);
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error:  'Could not start tracking: $e',
      );
    }
  }

  Future<void> stopTracking() async {
    if (state.isBusy || !state.isTracking) return;

    state = state.copyWith(isBusy: true, clearError: true);

    try {
      final stopped =
          await ref.read(stopTrackingUsecaseProvider)(state.currentSession);
      state = state.copyWith(currentSession: stopped, isBusy: false);
      // Refresh history so the just-ended session appears immediately.
      await Future.wait([loadLocations(), loadSessionIds()]);
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        error:  'Could not stop tracking: $e',
      );
    }
  }

  /// Re-attaches the UI to a background service that survived a force-kill
  /// + Android OS restart. If nothing is running this is a cheap no-op.
  Future<void> reattachSession() async {
    try {
      final session = await ref.read(getCurrentSessionUsecaseProvider)();
      if (session != null) {
        state = state.copyWith(currentSession: session);
      }
    } catch (_) {
      // Non-fatal — user just starts a fresh session.
    }
  }

  // ── Data loading ──────────────────────────────────────────────────────────────

  Future<void> loadLocations() async {
    try {
      final locations = await ref.read(getLocationsUsecaseProvider)();
      state = state.copyWith(
        locations:  locations,
        isLoading:  false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error:     'Failed to load locations: $e',
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

  // ── Writes ────────────────────────────────────────────────────────────────────

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
        locations:  const [],
        sessionIds: const [],
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to clear locations: $e');
    }
  }
}
