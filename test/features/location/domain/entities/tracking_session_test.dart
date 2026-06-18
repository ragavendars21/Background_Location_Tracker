import 'package:flutter_test/flutter_test.dart';
import 'package:background_location_tracker/features/location/domain/entities/tracking_session.dart';

void main() {
  // Pinned start time — fully deterministic, no DateTime.now() in fixtures.
  final start = DateTime.utc(2026, 6, 14, 10, 0, 0);
  final end   = DateTime.utc(2026, 6, 14, 10, 14, 37); // 14m 37s later

  TrackingSession makeSession({
    String         id     = 'test-session-id',
    TrackingStatus status = TrackingStatus.active,
    DateTime?      endedAt,
  }) =>
      TrackingSession(
        id:        id,
        startedAt: start,
        endedAt:   endedAt,
        status:    status,
      );

  group('TrackingSession', () {
    // ── isActive ──────────────────────────────────────────────────────────────

    group('isActive', () {
      test('true when status is active', () {
        expect(makeSession(status: TrackingStatus.active).isActive, isTrue);
      });

      test('false when status is stopped', () {
        expect(makeSession(status: TrackingStatus.stopped).isActive, isFalse);
      });

      test('false when status is idle', () {
        expect(makeSession(status: TrackingStatus.idle).isActive, isFalse);
      });
    });

    // ── elapsed ───────────────────────────────────────────────────────────────

    group('elapsed', () {
      test('uses endedAt when set', () {
        final session = makeSession(endedAt: end);
        expect(session.elapsed.inSeconds, 877); // 14 * 60 + 37
      });

      test('elapsed is positive for a recently started session', () {
        final session = makeSession(); // endedAt null → uses DateTime.now()
        expect(session.elapsed.inMilliseconds, greaterThan(0));
      });
    });

    // ── elapsedLabel ─────────────────────────────────────────────────────────

    group('elapsedLabel', () {
      test('formats mm:ss for durations under one hour', () {
        final session = makeSession(endedAt: end); // 14m 37s
        expect(session.elapsedLabel, '14:37');
      });

      test('formats hh:mm:ss for durations >= one hour', () {
        final longEnd = DateTime.utc(2026, 6, 14, 11, 5, 9); // 1h 5m 9s
        final session = makeSession(endedAt: longEnd);
        expect(session.elapsedLabel, '01:05:09');
      });

      test('pads minutes and seconds with leading zeros', () {
        final shortEnd = DateTime.utc(2026, 6, 14, 10, 1, 3); // 01:03
        final session  = makeSession(endedAt: shortEnd);
        expect(session.elapsedLabel, '01:03');
      });
    });

    // ── stopped() ─────────────────────────────────────────────────────────────

    group('stopped()', () {
      test('returns a new instance with status=stopped', () {
        final active  = makeSession();
        final stopped = active.stopped();
        expect(stopped.status, TrackingStatus.stopped);
      });

      test('sets endedAt to a time close to now', () {
        final before  = DateTime.now().toUtc();
        final stopped = makeSession().stopped();
        final after   = DateTime.now().toUtc();
        expect(
          stopped.endedAt!.millisecondsSinceEpoch,
          inInclusiveRange(
            before.millisecondsSinceEpoch,
            after.millisecondsSinceEpoch,
          ),
        );
      });

      test('preserves the original id', () {
        final original = makeSession(id: 'keep-this-id');
        expect(original.stopped().id, 'keep-this-id');
      });

      test('does not mutate the original', () {
        final active = makeSession();
        active.stopped();
        expect(active.status, TrackingStatus.active);
        expect(active.endedAt, isNull);
      });
    });

    // ── copyWith ──────────────────────────────────────────────────────────────

    group('copyWith', () {
      test('no-op copy is equal', () {
        final s = makeSession(status: TrackingStatus.stopped, endedAt: end);
        expect(s.copyWith(), s);
      });

      test('overrides status only', () {
        final result = makeSession().copyWith(status: TrackingStatus.stopped);
        expect(result.status, TrackingStatus.stopped);
        expect(result.id, 'test-session-id'); // preserved
      });

      test('overrides endedAt only', () {
        final result = makeSession().copyWith(endedAt: end);
        expect(result.endedAt, end);
      });
    });

    // ── Equality ──────────────────────────────────────────────────────────────

    group('equality', () {
      test('same id + same status → equal', () {
        expect(makeSession(), makeSession());
      });

      test('different id → not equal', () {
        expect(makeSession(id: 'a'), isNot(makeSession(id: 'b')));
      });

      test('different status → not equal', () {
        expect(
          makeSession(status: TrackingStatus.active),
          isNot(makeSession(status: TrackingStatus.stopped)),
        );
      });
    });

    // ── toString ──────────────────────────────────────────────────────────────

    test('toString contains id and status', () {
      final s = makeSession().toString();
      expect(s, contains('test-session-id'));
      expect(s, contains('active'));
    });
  });
}
