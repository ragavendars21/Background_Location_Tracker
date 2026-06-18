import 'package:flutter/foundation.dart';

@immutable
class MapState {
  final String? selectedSessionId;

  const MapState({this.selectedSessionId});

  MapState copyWith({String? selectedSessionId, bool clearSession = false}) {
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
