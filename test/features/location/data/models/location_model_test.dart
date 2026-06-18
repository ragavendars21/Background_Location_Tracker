import 'package:flutter_test/flutter_test.dart';
import 'package:background_location_tracker/core/constants/db_constants.dart';
import 'package:background_location_tracker/features/location/data/models/location_model.dart';
import 'package:background_location_tracker/features/location/domain/entities/location_entity.dart';

// ── Shared fixtures ────────────────────────────────────────────────────────────

Map<String, dynamic> _makeRow({
  int    id        = 1,
  double latitude  = 12.971599,
  double longitude = 77.594566,
  double accuracy  = 8.0,
  String timestamp = '2026-06-14T10:30:00.000Z',
  String sessionId = 'session-abc',
}) =>
    {
      DbConstants.colId:        id,
      DbConstants.colLatitude:  latitude,
      DbConstants.colLongitude: longitude,
      DbConstants.colAccuracy:  accuracy,
      DbConstants.colTimestamp: timestamp,
      DbConstants.colSessionId: sessionId,
    };

LocationEntity _makeEntity() => const LocationEntity(
      id:        1,
      latitude:  12.971599,
      longitude: 77.594566,
      accuracy:  8.0,
      timestamp: '2026-06-14T10:30:00.000Z',
      sessionId: 'session-abc',
    );

void main() {
  group('LocationModel', () {
    // ── fromMap (read DTO) ─────────────────────────────────────────────────────

    group('fromMap', () {
      test('parses all columns correctly', () {
        final model = LocationModel.fromMap(_makeRow());
        expect(model.id,        1);
        expect(model.latitude,  12.971599);
        expect(model.longitude, 77.594566);
        expect(model.accuracy,  8.0);
        expect(model.timestamp, '2026-06-14T10:30:00.000Z');
        expect(model.sessionId, 'session-abc');
      });

      test('handles int returned by SQLite for REAL columns via .toDouble()', () {
        // SQLite sometimes returns INTEGER for a REAL column that holds a whole number.
        final row   = _makeRow(latitude: 12.0, longitude: 77.0, accuracy: 5.0);
        row[DbConstants.colLatitude]  = 12; // int, not double
        row[DbConstants.colLongitude] = 77;
        row[DbConstants.colAccuracy]  = 5;

        final model = LocationModel.fromMap(row);
        expect(model.latitude,  12.0);
        expect(model.longitude, 77.0);
        expect(model.accuracy,  5.0);
      });

      test('id may be null when row has no id column', () {
        final row = _makeRow()..remove(DbConstants.colId);
        final model = LocationModel.fromMap({...row, DbConstants.colId: null});
        expect(model.id, isNull);
      });

      test('negative coordinates are preserved', () {
        final model = LocationModel.fromMap(
          _makeRow(latitude: -33.8688, longitude: -70.6693),
        );
        expect(model.latitude,  -33.8688);
        expect(model.longitude, -70.6693);
      });
    });

    // ── toMap (write DTO) ──────────────────────────────────────────────────────

    group('toMap', () {
      late Map<String, dynamic> map;
      setUp(() => map = LocationModel.fromMap(_makeRow()).toMap());

      test('contains latitude', () => expect(map[DbConstants.colLatitude], 12.971599));
      test('contains longitude', () => expect(map[DbConstants.colLongitude], 77.594566));
      test('contains accuracy', () => expect(map[DbConstants.colAccuracy], 8.0));
      test('contains timestamp', () => expect(map[DbConstants.colTimestamp], '2026-06-14T10:30:00.000Z'));
      test('contains sessionId', () => expect(map[DbConstants.colSessionId], 'session-abc'));

      test('does NOT include id — SQLite auto-increments it', () {
        expect(map.containsKey(DbConstants.colId), isFalse);
      });

      test('has exactly 5 keys (no extras leaked)', () {
        expect(map.keys, hasLength(5));
      });
    });

    // ── fromEntity ─────────────────────────────────────────────────────────────

    group('fromEntity', () {
      test('lifts a LocationEntity into a LocationModel', () {
        final model = LocationModel.fromEntity(_makeEntity());
        expect(model.id,        1);
        expect(model.latitude,  12.971599);
        expect(model.longitude, 77.594566);
        expect(model.accuracy,  8.0);
        expect(model.sessionId, 'session-abc');
      });

      test('result IS-A LocationEntity (Liskov substitution)', () {
        final model = LocationModel.fromEntity(_makeEntity());
        expect(model, isA<LocationEntity>());
      });

      test('toMap() works on the lifted model', () {
        final map = LocationModel.fromEntity(_makeEntity()).toMap();
        expect(map[DbConstants.colLatitude], 12.971599);
      });
    });

    // ── Inheritance ────────────────────────────────────────────────────────────

    test('LocationModel is a subtype of LocationEntity', () {
      final model = LocationModel.fromMap(_makeRow());
      expect(model, isA<LocationEntity>());
    });

    test('fromMap → toMap round-trips all non-id fields', () {
      final original = _makeRow();
      final model    = LocationModel.fromMap(original);
      final restored = model.toMap();

      expect(restored[DbConstants.colLatitude],  original[DbConstants.colLatitude]);
      expect(restored[DbConstants.colLongitude], original[DbConstants.colLongitude]);
      expect(restored[DbConstants.colAccuracy],  original[DbConstants.colAccuracy]);
      expect(restored[DbConstants.colTimestamp], original[DbConstants.colTimestamp]);
      expect(restored[DbConstants.colSessionId], original[DbConstants.colSessionId]);
    });
  });
}
