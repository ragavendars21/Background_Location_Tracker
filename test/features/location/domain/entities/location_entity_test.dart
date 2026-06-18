import 'package:flutter_test/flutter_test.dart';
import 'package:background_location_tracker/features/location/domain/entities/location_entity.dart';

// ── Shared fixture ─────────────────────────────────────────────────────────────

LocationEntity _makeEntity({
  int?    id        = 1,
  double  latitude  = 12.971599,
  double  longitude = 77.594566,
  double  accuracy  = 10.0,
  String  timestamp = '2026-06-14T10:30:00.000Z',
  String  sessionId = 'session-abc',
}) =>
    LocationEntity(
      id:        id,
      latitude:  latitude,
      longitude: longitude,
      accuracy:  accuracy,
      timestamp: timestamp,
      sessionId: sessionId,
    );

void main() {
  group('LocationEntity', () {
    // ── Constructor ───────────────────────────────────────────────────────────

    group('constructor', () {
      test('stores all fields', () {
        final e = _makeEntity();
        expect(e.id,        1);
        expect(e.latitude,  12.971599);
        expect(e.longitude, 77.594566);
        expect(e.accuracy,  10.0);
        expect(e.timestamp, '2026-06-14T10:30:00.000Z');
        expect(e.sessionId, 'session-abc');
      });

      test('id is nullable — null before persistence', () {
        final e = _makeEntity(id: null);
        expect(e.id, isNull);
      });
    });

    // ── copyWith ──────────────────────────────────────────────────────────────

    group('copyWith', () {
      test('returns identical values when no fields overridden', () {
        final original = _makeEntity();
        final copy     = original.copyWith();
        expect(copy, original);
      });

      test('overrides latitude only', () {
        final result = _makeEntity().copyWith(latitude: 99.0);
        expect(result.latitude,  99.0);
        expect(result.longitude, 77.594566); // unchanged
      });

      test('overrides longitude only', () {
        final result = _makeEntity().copyWith(longitude: -43.0);
        expect(result.longitude, -43.0);
        expect(result.latitude,  12.971599); // unchanged
      });

      test('overrides accuracy only', () {
        final result = _makeEntity().copyWith(accuracy: 5.5);
        expect(result.accuracy, 5.5);
      });

      test('overrides timestamp only', () {
        const newTs = '2026-12-31T23:59:59.000Z';
        final result = _makeEntity().copyWith(timestamp: newTs);
        expect(result.timestamp, newTs);
      });

      test('overrides sessionId only', () {
        final result = _makeEntity().copyWith(sessionId: 'new-session');
        expect(result.sessionId, 'new-session');
      });

      test('overrides id — useful after database insert', () {
        final result = _makeEntity(id: null).copyWith(id: 42);
        expect(result.id, 42);
      });
    });

    // ── Equality ──────────────────────────────────────────────────────────────

    group('equality', () {
      test('two entities with the same fields are equal', () {
        expect(_makeEntity(), _makeEntity());
      });

      test('different latitude → not equal', () {
        expect(_makeEntity(latitude: 1.0), isNot(_makeEntity(latitude: 2.0)));
      });

      test('different longitude → not equal', () {
        expect(_makeEntity(longitude: 1.0), isNot(_makeEntity(longitude: 2.0)));
      });

      test('different sessionId → not equal', () {
        expect(
          _makeEntity(sessionId: 'a'),
          isNot(_makeEntity(sessionId: 'b')),
        );
      });

      test('null id vs non-null id → not equal', () {
        expect(_makeEntity(id: null), isNot(_makeEntity(id: 1)));
      });

      test('identical() shortcut works', () {
        final e = _makeEntity();
        // ignore: unrelated_type_equality_checks
        expect(e == e, isTrue);
      });
    });

    // ── hashCode ──────────────────────────────────────────────────────────────

    group('hashCode', () {
      test('equal entities have equal hashCodes', () {
        expect(_makeEntity().hashCode, _makeEntity().hashCode);
      });

      test('different entities produce different hashCodes (probabilistic)', () {
        expect(
          _makeEntity(latitude: 1.0).hashCode,
          isNot(_makeEntity(latitude: 99.0).hashCode),
        );
      });
    });

    // ── toString ──────────────────────────────────────────────────────────────

    test('toString contains key fields', () {
      final s = _makeEntity().toString();
      expect(s, contains('12.971599'));
      expect(s, contains('77.594566'));
      expect(s, contains('session-abc'));
    });
  });
}
