/// Describes whether a tracking run is currently in progress.
///
/// idle    — app just opened, no session has started yet
/// active  — background service is running, GPS fixes are being recorded
/// stopped — the user pressed STOP; data is preserved in SQLite
enum TrackingStatus { idle, active, stopped }

/// Represents one complete tracking run: START → (recording) → STOP.
///
/// This is a pure domain object — it knows nothing about Flutter widgets,
/// SQLite, or background services. It only describes WHAT a session IS.
///
/// Every GPS point in the database carries the same [id] as its parent
/// session, which is how we group route history.
class TrackingSession {
  /// UUID that links this session to all its [LocationEntity] rows.
  final String id;

  /// When the user pressed START (UTC).
  final DateTime startedAt;

  /// When the user pressed STOP (UTC). Null while the session is active.
  final DateTime? endedAt;

  final TrackingStatus status;

  const TrackingSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.status = TrackingStatus.active,
  });

  // ── Computed ───────────────────────────────────────────────────────────────

  bool get isActive => status == TrackingStatus.active;

  /// Wall-clock time from START until now (or until STOP if already ended).
  Duration get elapsed {
    final end = endedAt ?? DateTime.now().toUtc();
    return end.difference(startedAt);
  }

  String get elapsedLabel {
    final d = elapsed;
    final h  = d.inHours;
    final m  = d.inMinutes.remainder(60);
    final s  = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
             '${m.toString().padLeft(2, '0')}:'
             '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
           '${s.toString().padLeft(2, '0')}';
  }

  // ── Mutation helpers ───────────────────────────────────────────────────────

  TrackingSession copyWith({
    String?         id,
    DateTime?       startedAt,
    DateTime?       endedAt,
    TrackingStatus? status,
  }) {
    return TrackingSession(
      id:        id        ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt:   endedAt   ?? this.endedAt,
      status:    status    ?? this.status,
    );
  }

  /// Returns a new instance with status = stopped and endedAt = now.
  TrackingSession stopped() => copyWith(
        status:  TrackingStatus.stopped,
        endedAt: DateTime.now().toUtc(),
      );

  // ── Equality ───────────────────────────────────────────────────────────────

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
