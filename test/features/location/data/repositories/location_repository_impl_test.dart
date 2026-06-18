import 'package:flutter_test/flutter_test.dart';
import 'package:background_location_tracker/features/location/data/datasources/location_local_datasource.dart';
import 'package:background_location_tracker/features/location/data/models/location_model.dart';
import 'package:background_location_tracker/features/location/data/repositories/location_repository_impl.dart';
import 'package:background_location_tracker/features/location/domain/entities/location_entity.dart';

// ── Fake datasource ────────────────────────────────────────────────────────────
//
// Why a manual fake instead of mockito/mocktail?
// • Zero extra packages — the project already avoids mocking libraries.
// • Explicit call recording is clearer than verify() matchers.
// • The fake IS the documentation of what the repository promises to call.

class _FakeDatasource implements LocationLocalDatasource {
  // Programmable returns
  List<LocationModel> locationsToReturn = [];
  LocationModel?      latestToReturn;
  List<String>        sessionIdsToReturn = [];
  int                 countToReturn      = 0;

  // Call recording
  LocationModel?  lastInserted;
  String?         lastDeletedSession;
  bool            deleteAllCalled = false;

  _FakeDatasource();

  @override
  Future<void> insertLocation(LocationModel model) async {
    lastInserted = model;
  }

  @override
  Future<List<LocationModel>> fetchAllLocations() async => locationsToReturn;

  @override
  Future<List<LocationModel>> fetchBySession(String sessionId) async =>
      locationsToReturn.where((l) => l.sessionId == sessionId).toList();

  @override
  Future<LocationModel?> fetchLatestLocation() async => latestToReturn;

  @override
  Future<List<String>> fetchSessionIds() async => sessionIdsToReturn;

  @override
  Future<int> countAll() async => countToReturn;

  @override
  Future<int> countBySession(String sessionId) async =>
      locationsToReturn.where((l) => l.sessionId == sessionId).length;

  @override
  Future<void> deleteBySession(String sessionId) async {
    lastDeletedSession = sessionId;
  }

  @override
  Future<void> deleteAllLocations() async {
    deleteAllCalled = true;
  }
}

// ── Fixtures ───────────────────────────────────────────────────────────────────

LocationModel _makeModel({int id = 1, String sessionId = 'session-a'}) =>
    LocationModel(
      id:        id,
      latitude:  12.971599,
      longitude: 77.594566,
      accuracy:  10.0,
      timestamp: '2026-06-14T10:30:00.000Z',
      sessionId: sessionId,
    );

LocationEntity _makeEntity({String sessionId = 'session-a'}) => LocationEntity(
      latitude:  12.971599,
      longitude: 77.594566,
      accuracy:  10.0,
      timestamp: '2026-06-14T10:30:00.000Z',
      sessionId: sessionId,
    );

void main() {
  late _FakeDatasource  fake;
  late LocationRepositoryImpl repo;

  setUp(() {
    fake = _FakeDatasource();
    repo = LocationRepositoryImpl(fake);
  });

  group('LocationRepositoryImpl', () {
    // ── saveLocation ───────────────────────────────────────────────────────────

    group('saveLocation', () {
      test('delegates to datasource.insertLocation', () async {
        final entity = _makeEntity();
        await repo.saveLocation(entity);
        expect(fake.lastInserted, isNotNull);
      });

      test('converts entity to model before inserting', () async {
        final entity = _makeEntity(sessionId: 'session-xyz');
        await repo.saveLocation(entity);
        expect(fake.lastInserted!.sessionId, 'session-xyz');
        expect(fake.lastInserted!.latitude,  entity.latitude);
      });

      test('inserted model IS-A LocationEntity', () async {
        await repo.saveLocation(_makeEntity());
        expect(fake.lastInserted, isA<LocationEntity>());
      });
    });

    // ── getAllLocations ────────────────────────────────────────────────────────

    group('getAllLocations', () {
      test('returns datasource results as LocationEntity list', () async {
        fake.locationsToReturn = [_makeModel(id: 1), _makeModel(id: 2)];
        final results = await repo.getAllLocations();
        expect(results.length, 2);
        expect(results.first, isA<LocationEntity>());
      });

      test('returns empty list when datasource has no rows', () async {
        fake.locationsToReturn = [];
        expect(await repo.getAllLocations(), isEmpty);
      });
    });

    // ── getLocationsBySession ─────────────────────────────────────────────────

    group('getLocationsBySession', () {
      test('returns only locations for the requested session', () async {
        fake.locationsToReturn = [
          _makeModel(id: 1, sessionId: 'session-a'),
          _makeModel(id: 2, sessionId: 'session-b'),
          _makeModel(id: 3, sessionId: 'session-a'),
        ];
        final results = await repo.getLocationsBySession('session-a');
        expect(results.length, 2);
        expect(results.every((l) => l.sessionId == 'session-a'), isTrue);
      });
    });

    // ── getLatestLocation ─────────────────────────────────────────────────────

    group('getLatestLocation', () {
      test('returns null when table is empty', () async {
        fake.latestToReturn = null;
        expect(await repo.getLatestLocation(), isNull);
      });

      test('returns the latest location when present', () async {
        fake.latestToReturn = _makeModel();
        expect(await repo.getLatestLocation(), isNotNull);
        expect(await repo.getLatestLocation(), isA<LocationEntity>());
      });
    });

    // ── getSessionIds ─────────────────────────────────────────────────────────

    group('getSessionIds', () {
      test('returns empty list when no sessions', () async {
        expect(await repo.getSessionIds(), isEmpty);
      });

      test('returns session ids from datasource', () async {
        fake.sessionIdsToReturn = ['session-a', 'session-b'];
        expect(await repo.getSessionIds(), ['session-a', 'session-b']);
      });
    });

    // ── getLocationCount ──────────────────────────────────────────────────────

    group('getLocationCount', () {
      test('returns zero when table is empty', () async {
        fake.countToReturn = 0;
        expect(await repo.getLocationCount(), 0);
      });

      test('returns count from datasource', () async {
        fake.countToReturn = 42;
        expect(await repo.getLocationCount(), 42);
      });
    });

    // ── deleteSession ─────────────────────────────────────────────────────────

    group('deleteSession', () {
      test('delegates to datasource with the correct sessionId', () async {
        await repo.deleteSession('session-xyz');
        expect(fake.lastDeletedSession, 'session-xyz');
      });
    });

    // ── clearAllLocations ─────────────────────────────────────────────────────

    group('clearAllLocations', () {
      test('delegates to datasource.deleteAllLocations', () async {
        expect(fake.deleteAllCalled, isFalse);
        await repo.clearAllLocations();
        expect(fake.deleteAllCalled, isTrue);
      });
    });
  });
}
