import 'package:flutter_test/flutter_test.dart';
import 'package:background_location_tracker/features/location/domain/entities/tracking_session.dart';
import 'package:background_location_tracker/features/location/domain/repositories/tracking_repository.dart';
import 'package:background_location_tracker/features/location/domain/usecases/start_tracking_usecase.dart';

// ── Fake tracking repository ───────────────────────────────────────────────────

class _FakeTrackingRepository implements TrackingRepository {
  bool    isTrackingValue     = false;
  String? activeSessionId;

  // Call recording
  String? startedWithSessionId;
  bool    stopCalled = false;

  @override
  Future<bool> isTracking() async => isTrackingValue;

  @override
  Future<void> startTracking(String sessionId) async {
    startedWithSessionId = sessionId;
    isTrackingValue      = true;
    activeSessionId      = sessionId;
  }

  @override
  Future<void> stopTracking() async {
    stopCalled      = true;
    isTrackingValue = false;
    activeSessionId = null;
  }

  @override
  Future<String?> getActiveSessionId() async => activeSessionId;
}

void main() {
  late _FakeTrackingRepository fakeRepo;
  late StartTrackingUsecase    usecase;

  setUp(() {
    fakeRepo = _FakeTrackingRepository();
    usecase  = StartTrackingUsecase(fakeRepo);
  });

  group('StartTrackingUsecase', () {
    // ── Happy path ─────────────────────────────────────────────────────────────

    group('when not already tracking', () {
      test('returns a TrackingSession', () async {
        final session = await usecase();
        expect(session, isA<TrackingSession>());
      });

      test('session has TrackingStatus.active', () async {
        final session = await usecase();
        expect(session.status, TrackingStatus.active);
      });

      test('session.isActive is true', () async {
        expect((await usecase()).isActive, isTrue);
      });

      test('session.id is a non-empty string (UUID v4)', () async {
        final session = await usecase();
        expect(session.id, isNotEmpty);
        expect(session.id.length, greaterThan(10)); // UUID v4 = 36 chars
      });

      test('session.startedAt is close to now (UTC)', () async {
        final before  = DateTime.now().toUtc();
        final session = await usecase();
        final after   = DateTime.now().toUtc();

        expect(
          session.startedAt.millisecondsSinceEpoch,
          inInclusiveRange(
            before.millisecondsSinceEpoch,
            after.millisecondsSinceEpoch,
          ),
        );
      });

      test('session.endedAt is null (session is still open)', () async {
        expect((await usecase()).endedAt, isNull);
      });

      test('calls repository.startTracking with the generated sessionId', () async {
        final session = await usecase();
        expect(fakeRepo.startedWithSessionId, session.id);
      });

      test('two successive calls (different instances) produce unique IDs', () async {
        final repo2    = _FakeTrackingRepository();
        final session1 = await StartTrackingUsecase(fakeRepo)();
        // reset so repo2 thinks nothing is running
        final session2 = await StartTrackingUsecase(repo2)();
        expect(session1.id, isNot(session2.id));
      });
    });

    // ── Guard against double-start ─────────────────────────────────────────────

    group('when already tracking', () {
      setUp(() => fakeRepo.isTrackingValue = true);

      test('throws StateError', () async {
        expect(usecase(), throwsA(isA<StateError>()));
      });

      test('does NOT call repository.startTracking', () async {
        try {
          await usecase();
        } catch (_) {}
        // startedWithSessionId is only set by startTracking(); it should be null
        expect(fakeRepo.startedWithSessionId, isNull);
      });
    });
  });
}
