import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:background_location_tracker/features/location/domain/entities/location_entity.dart';
import 'package:background_location_tracker/features/location/presentation/widgets/location_tile.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: child),
    );

const _kTimestamp = '2026-06-14T10:30:00.000Z';

LocationEntity _makeLocation({
  int?   id        = 1,
  double latitude  = 12.971599,
  double longitude = 77.594566,
  double accuracy  = 8.5,
  String sessionId = 'session-abc',
}) =>
    LocationEntity(
      id:        id,
      latitude:  latitude,
      longitude: longitude,
      accuracy:  accuracy,
      timestamp: _kTimestamp,
      sessionId: sessionId,
    );

void main() {
  group('LocationTile', () {
    // ── Rendering ─────────────────────────────────────────────────────────────

    testWidgets('renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap(
        LocationTile(location: _makeLocation(), index: 1),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows latitude formatted to 6 decimal places', (tester) async {
      await tester.pumpWidget(_wrap(
        LocationTile(location: _makeLocation(latitude: 12.971599), index: 1),
      ));
      expect(find.text('12.971599°N'), findsOneWidget);
    });

    testWidgets('shows longitude formatted to 6 decimal places', (tester) async {
      await tester.pumpWidget(_wrap(
        LocationTile(location: _makeLocation(longitude: 77.594566), index: 1),
      ));
      expect(find.text('77.594566°E'), findsOneWidget);
    });

    testWidgets('shows accuracy tag with one decimal place', (tester) async {
      await tester.pumpWidget(_wrap(
        LocationTile(location: _makeLocation(accuracy: 8.5), index: 1),
      ));
      expect(find.textContaining('±8.5m'), findsOneWidget);
    });

    testWidgets('shows the index badge', (tester) async {
      await tester.pumpWidget(_wrap(
        LocationTile(location: _makeLocation(), index: 42),
      ));
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('shows a chevron icon', (tester) async {
      await tester.pumpWidget(_wrap(
        LocationTile(location: _makeLocation(), index: 1),
      ));
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    // ── Edge cases ────────────────────────────────────────────────────────────

    testWidgets('handles negative latitude (southern hemisphere)', (tester) async {
      await tester.pumpWidget(_wrap(
        LocationTile(location: _makeLocation(latitude: -33.868820), index: 1),
      ));
      expect(find.text('-33.868820°N'), findsOneWidget);
    });

    testWidgets('handles negative longitude (western hemisphere)', (tester) async {
      await tester.pumpWidget(_wrap(
        LocationTile(location: _makeLocation(longitude: -70.669266), index: 1),
      ));
      expect(find.text('-70.669266°E'), findsOneWidget);
    });

    testWidgets('handles index 0', (tester) async {
      await tester.pumpWidget(_wrap(
        LocationTile(location: _makeLocation(), index: 0),
      ));
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('ValueKey does not break rendering', (tester) async {
      await tester.pumpWidget(_wrap(
        LocationTile(
          key:      const ValueKey('tile-1'),
          location: _makeLocation(),
          index:    1,
        ),
      ));
      expect(tester.takeException(), isNull);
    });

    // ── List rendering ────────────────────────────────────────────────────────

    testWidgets('renders multiple tiles without key collisions', (tester) async {
      final locations = List.generate(
        3,
        (i) => _makeLocation(id: i, latitude: 12.0 + i),
      );

      await tester.pumpWidget(_wrap(
        ListView(
          children: [
            for (int i = 0; i < locations.length; i++)
              LocationTile(
                key:      ValueKey(locations[i].id),
                location: locations[i],
                index:    i + 1,
              ),
          ],
        ),
      ));

      expect(find.byType(LocationTile), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  });
}
