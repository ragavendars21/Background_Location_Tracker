import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/map_state.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

/// Widgets read map selection with: ref.watch(mapProvider)
/// Widgets change selection with:   ref.read(mapProvider.notifier).selectSession(id)
final mapProvider = NotifierProvider<MapNotifier, MapState>(MapNotifier.new);

// ── Notifier ──────────────────────────────────────────────────────────────────

/// Manages which session the map is currently focused on.
///
/// Why a separate notifier instead of local widget state?
///   • The selected session could later drive other widgets (e.g. a stats panel).
///   • Keeps [MapScreen] a pure view — it just reads providers and renders.
///   • Easy to unit test without a widget tree.
class MapNotifier extends Notifier<MapState> {
  @override
  MapState build() => const MapState(); // start with "All sessions"

  /// Pass [null] to show every session.
  void selectSession(String? sessionId) {
    if (state.selectedSessionId == sessionId) return; // no-op
    state = MapState(selectedSessionId: sessionId);
  }

  void reset() => state = const MapState();
}
