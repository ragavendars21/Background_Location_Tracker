enum TrackingStatus { idle, active, stopped }

class TrackingSession {
  final String id;

  final DateTime startedAt;

  final DateTime? endedAt;

  final TrackingStatus status;

  const TrackingSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.status = TrackingStatus.active,
  });

  bool get isActive => status == TrackingStatus.active;

  Duration get elapsed {
    final end = endedAt ?? DateTime.now().toUtc();
    return end.difference(startedAt);
  }

  String get elapsedLabel {
    final d = elapsed;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  TrackingSession copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? endedAt,
    TrackingStatus? status,
  }) {
    return TrackingSession(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
    );
  }

  TrackingSession stopped() =>
      copyWith(status: TrackingStatus.stopped, endedAt: DateTime.now().toUtc());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackingSession &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          status == other.status;

  @override
  int get hashCode => Object.hash(id, status);

  @override
  String toString() =>
      'TrackingSession(id: $id, status: $status, elapsed: $elapsedLabel)';
}
