import 'package:flutter_test/flutter_test.dart';
import 'package:background_location_tracker/features/location/domain/entities/location_entity.dart';
import 'package:background_location_tracker/features/location/domain/entities/tracking_session.dart';
import 'package:background_location_tracker/features/location/presentation/state/location_state.dart';

// ── Fixtures ───────────────────────────────────────────────────────────────────

LocationEntity _loc(int n) => LocationEntity(
      id:        n,
      latitude:  12.0 + n,
      longitude: 77.0 + n,
      accuracy:  5.0,
      timestamp: '2026-06-14T10:30:00.000Z',
      sessionId: 'session-a',
    );

TrackingSession _activeSession() => TrackingSession(
      id:        'session-active',
      startedAt: DateTime.utc(2026, 6, 14, 10, 0, 0),
      status:    TrackingStatus.active,
    );

TrackingSession _stoppedSession() => TrackingSession(
      id:        'session-stopped',
      startedAt: DateTime.utc(2026, 6, 14, 10, 0, 0),
      endedAt:   DateTime.utc(2026, 6, 14, 10, 30, 0),
      status:    TrackingStatus.stopped,
    );

void main() {
  group('LocationState', () {
    // ── Default values ─────────────────────────────────────────────────────────

    group('defaults', () {
      const state = LocationState();

      test('locations is empty',      () => expect(state.locations,      isEmpty));
      test('sessionIds is empty',     () => expect(state.sessionIds,     isEmpty));
      test('currentSession is null',  () => expect(state.currentSession, isNull));
      test('isLoading is false',      () => expect(state.isLoading,      isFalse));
      test('isBusy is false',         () => expect(state.isBusy,         isFalse));
      test('error is null',           () => expect(state.error,          isNull));
    });

    // ── Derived getters ────────────────────────────────────────────────────────

    group('isTracking', () {
      test('false with no session', () {
        expect(const LocationState().isTracking, isFalse);
      });

      test('true when currentSession is active', () {
        final state = LocationState(currentSession: _activeSession());
        expect(state.isTracking, isTrue);
      });

      test('false when currentSession is stopped', () {
        final state = LocationState(currentSession: _stoppedSession());
        expect(state.isTracking, isFalse);
      });
    });

    group('locationCount', () {
      test('0 with empty list', () {
        expect(const LocationState().locationCount, 0);
      });

      test('matches list length', () {
        final state = LocationState(locations: [_loc(1), _loc(2), _loc(3)]);
        expect(state.locationCount, 3);
      });
    });

    // ── copyWith ──────────────────────────────────────────────────────────────

    group('copyWith', () {
      final base = LocationState(
        locations:      [_loc(1)],
        sessionIds:     const ['s1'],
        currentSession: _activeSession(),
        isLoading:      true,
        isBusy:         true,
        error:          'boom',
      );

      test('no-op copy preserves all fields', () {
        final copy = base.copyWith();
        expect(copy.locations,      base.locations);
        expect(copy.sessionIds,     base.sessionIds);
        expect(copy.currentSession, base.currentSession);
        expect(copy.isLoading,      base.isLoading);
        expect(copy.isBusy,         base.isBusy);
        expect(copy.error,          base.error);
      });

      test('overrides locations only', () {
        final copy = base.copyWith(locations: [_loc(1), _loc(2)]);
        expect(copy.locations.length, 2);
        expect(copy.sessionIds, base.sessionIds); // unchanged
      });

      test('overrides sessionIds only', () {
        final copy = base.copyWith(sessionIds: ['s1', 's2']);
        expect(copy.sessionIds, ['s1', 's2']);
      });

      test('overrides isLoading only', () {
        final copy = base.copyWith(isLoading: false);
        expect(copy.isLoading, isFalse);
        expect(copy.isBusy,    base.isBusy); // unchanged
      });

      test('overrides isBusy only', () {
        final copy = base.copyWith(isBusy: false);
        expect(copy.isBusy,    isFalse);
        expect(copy.isLoading, base.isLoading); // unchanged
      });

      test('clearError: true sets error to null regardless of error param', () {
        final copy = base.copyWith(clearError: true);
        expect(copy.error, isNull);
      });

      test('clearError: false preserves existing error', () {
        final copy = base.copyWith(clearError: false);
        expect(copy.error, 'boom');
      });

      test('clearSession: true nulls currentSession', () {
        final copy = base.copyWith(clearSession: true);
        expect(copy.currentSession, isNull);
      });

      test('clearSession: false preserves currentSession', () {
        final copy = base.copyWith(clearSession: false);
        expect(copy.currentSession, isNotNull);
      });

      test('setting a new error replaces the old one', () {
        final copy = base.copyWith(error: 'new error');
        expect(copy.error, 'new error');
      });
    });
  });
}
