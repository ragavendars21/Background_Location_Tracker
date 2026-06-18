import 'package:flutter/foundation.dart';

/// All state the Map UI needs.
///
/// Kept minimal on purpose — the actual map data (locations, sessions) comes
/// from [locationProvider] so there is a single source of truth.
/// [MapState] only carries UI concerns: which session is highlighted.
@immutable
class MapState {
  /// Null  → show every session.
  /// Non-null → filter map to this session's markers + polyline.
  final String? selectedSessionId;

  const MapState({this.selectedSessionId});

  MapState copyWith({
    String? selectedSessionId,
    bool    clearSession = false,
  }) {
    return MapState(
      selectedSessionId: clearSession
          ? null
          : (selectedSessionId ?? this.selectedSessionId),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapState &&
          runtimeType == other.runtimeType &&
          selectedSessionId == other.selectedSessionId;

  @override
  int get hashCode => selectedSessionId.hashCode;
}
