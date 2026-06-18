/// Immutable snapshot of the device battery state at a point in time.
///
/// This is a pure Dart class — it knows nothing about BatteryManager (Android),
/// UIDevice (iOS), or MethodChannel. That isolation means you can unit-test
/// any logic that uses BatteryInfo without a device or simulator.
class BatteryInfo {
  final int level;        // 0–100 (percentage)
  final bool isCharging;  // true when plugged in (charging or full)

  const BatteryInfo({required this.level, required this.isCharging});

  // ── Convenience getters ────────────────────────────────────────────────────

  /// Battery is getting low — consider showing a warning.
  bool get isLow      => level < 20;

  /// Battery is critically low — location tracking may be suspended by OS.
  bool get isCritical => level < 10;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatteryInfo &&
          level      == other.level &&
          isCharging == other.isCharging;

  @override
  int get hashCode => Object.hash(level, isCharging);

  @override
  String toString() =>
      'BatteryInfo(level: $level%, isCharging: $isCharging)';
}
