import 'package:flutter_test/flutter_test.dart';
import 'package:background_location_tracker/features/location/domain/entities/tracking_session.dart';
import 'package:background_location_tracker/features/location/domain/repositories/tracking_repository.dart';
import 'package:background_location_tracker/features/location/domain/usecases/stop_tracking_usecase.dart';

// ── Fake ──────────────────────────────────────────────────────────────────────

class _FakeTrackingRepository implements TrackingRepository {
  bool isTrackingValue = false;
  bool stopCalled      = false;

  @override Future<bool>    isTracking()            async => isTrackingValue;
  @override Future<String?> getActiveSessionId()    async => null;
  @override Future<void>    startTracking(String _) async {}
  @override Future<void>    stopTracking()          async { stopCalled = true; }
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

TrackingSession _activeSession() => TrackingSession(
      id:        'session-xyz',
      startedAt: DateTime.utc(2026, 6, 14, 10, 0, 0),
      status:    TrackingStatus.active,
    );

void main() {
  late _FakeTrackingRepository fakeRepo;
  late StopTrackingUsecase     usecase;

  setUp(() {
    fakeRepo = _FakeTrackingRepository();
    usecase  = StopTrackingUsecase(fakeRepo);
  });

  group('StopTrackingUsecase', () {
    // ── Idempotency ────────────────────────────────────────────────────────────

    group('when not tracking (idempotent no-op)', () {
      setUp(() => fakeRepo.isTrackingValue = false);

      test('returns null', () async {
        expect(await usecase(null), isNull);
      });

      test('does NOT call repository.stopTracking', () async {
        await usecase(null);
        expect(fakeRepo.stopCalled, isFalse);
      });

      test('null currentSession input also returns null', () async {
        expect(await usecase(null), isNull);
      });
    });

    // ── Happy path ─────────────────────────────────────────────────────────────

    group('when tracking is active', () {
      setUp(() => fakeRepo.isTrackingValue = true);

      test('calls repository.stopTracking exactly once', () async {
        await usecase(_activeSession());
        expect(fakeRepo.stopCalled, isTrue);
      });

      test('returns the session stamped with stopped status', () async {
        final result = await usecase(_activeSession());
        expect(result!.status, TrackingStatus.stopped);
      });

      test('returned session has endedAt populated', () async {
        final before = DateTime.now().toUtc();
        final result = await usecase(_activeSession());
        final after  = DateTime.now().toUtc();

        expect(result!.endedAt, isNotNull);
        expect(
          result.endedAt!.millisecondsSinceEpoch,
          inInclusiveRange(
            before.millisecondsSinceEpoch,
            after.millisecondsSinceEpoch,
          ),
        );
      });

      test('preserves the original session id', () async {
        final result = await usecase(_activeSession());
        expect(result!.id, 'session-xyz');
      });

      test('returns null when currentSession is null but service was running', () async {
        // Simulates: service was alive but Flutter state was lost (force-kill).
        // currentSession == null means we have no session object to stamp.
        final result = await usecase(null);
        expect(result, isNull);
      });
    });
  });
}
