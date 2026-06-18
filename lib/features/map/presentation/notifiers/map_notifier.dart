import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/map_state.dart';

final mapProvider = NotifierProvider<MapNotifier, MapState>(MapNotifier.new);

class MapNotifier extends Notifier<MapState> {
  @override
  MapState build() => const MapState();

  void selectSession(String? sessionId) {
    if (state.selectedSessionId == sessionId) return;
    state = MapState(selectedSessionId: sessionId);
  }

  void reset() => state = const MapState();
}
