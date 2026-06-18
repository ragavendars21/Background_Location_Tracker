import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:background_location_tracker/features/map/presentation/notifiers/map_notifier.dart';
import 'package:background_location_tracker/features/map/presentation/state/map_state.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

ProviderContainer _makeContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('MapNotifier', () {
    // ── Initial state ─────────────────────────────────────────────────────────

    group('initial state', () {
      test('selectedSessionId is null (show all sessions)', () {
        final container = _makeContainer();
        expect(container.read(mapProvider).selectedSessionId, isNull);
      });

      test('state is typed as MapState', () {
        final container = _makeContainer();
        expect(container.read(mapProvider), isA<MapState>());
      });
    });

    // ── selectSession ─────────────────────────────────────────────────────────

    group('selectSession()', () {
      test('sets selectedSessionId', () {
        final container = _makeContainer();
        container.read(mapProvider.notifier).selectSession('session-abc');
        expect(container.read(mapProvider).selectedSessionId, 'session-abc');
      });

      test('null clears the selection (show all)', () {
        final container = _makeContainer();
        container.read(mapProvider.notifier).selectSession('session-abc');
        container.read(mapProvider.notifier).selectSession(null);
        expect(container.read(mapProvider).selectedSessionId, isNull);
      });

      test('calling with the same id is a no-op (state reference unchanged)', () {
        final container = _makeContainer();
        container.read(mapProvider.notifier).selectSession('session-abc');

        int notifyCount = 0;
        container.listen<MapState>(mapProvider, (_, _) => notifyCount++);

        container.read(mapProvider.notifier).selectSession('session-abc');
        expect(notifyCount, 0); // no new state emitted
      });

      test('switching sessions updates selectedSessionId', () {
        final container = _makeContainer();
        container.read(mapProvider.notifier).selectSession('session-a');
        container.read(mapProvider.notifier).selectSession('session-b');
        expect(container.read(mapProvider).selectedSessionId, 'session-b');
      });
    });

    // ── reset ─────────────────────────────────────────────────────────────────

    group('reset()', () {
      test('clears selectedSessionId back to null', () {
        final container = _makeContainer();
        container.read(mapProvider.notifier).selectSession('session-xyz');
        container.read(mapProvider.notifier).reset();
        expect(container.read(mapProvider).selectedSessionId, isNull);
      });

      test('reset on already-null state does not throw', () {
        final container = _makeContainer();
        expect(
          () => container.read(mapProvider.notifier).reset(),
          returnsNormally,
        );
      });
    });

    // ── State notifications ───────────────────────────────────────────────────

    group('state change notifications', () {
      test('listener fires when session selection changes', () {
        final container = _makeContainer();
        int count = 0;
        container.listen<MapState>(mapProvider, (_, _) => count++);

        container.read(mapProvider.notifier).selectSession('session-a');
        expect(count, 1);

        container.read(mapProvider.notifier).selectSession('session-b');
        expect(count, 2);
      });

      test('listener fires on reset', () {
        final container = _makeContainer();
        container.read(mapProvider.notifier).selectSession('session-a');

        int count = 0;
        container.listen<MapState>(mapProvider, (_, _) => count++);

        container.read(mapProvider.notifier).reset();
        expect(count, 1);
      });
    });

    // ── MapState equality (used by Riverpod for rebuild decisions) ────────────

    group('MapState equality', () {
      test('same selectedSessionId → equal', () {
        const a = MapState(selectedSessionId: 'session-a');
        const b = MapState(selectedSessionId: 'session-a');
        expect(a, b);
      });

      test('different selectedSessionId → not equal', () {
        const a = MapState(selectedSessionId: 'session-a');
        const b = MapState(selectedSessionId: 'session-b');
        expect(a, isNot(b));
      });

      test('null vs non-null → not equal', () {
        const a = MapState();
        const b = MapState(selectedSessionId: 'session-a');
        expect(a, isNot(b));
      });

      test('hashCode is consistent with equality', () {
        const a = MapState(selectedSessionId: 'session-x');
        const b = MapState(selectedSessionId: 'session-x');
        expect(a.hashCode, b.hashCode);
      });
    });
  });
}
