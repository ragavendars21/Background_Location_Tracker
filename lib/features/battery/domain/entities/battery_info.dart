class BatteryInfo {
  final int level;
  final bool isCharging;

  const BatteryInfo({required this.level, required this.isCharging});

  bool get isLow => level < 20;

  bool get isCritical => level < 10;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatteryInfo &&
          level == other.level &&
          isCharging == other.isCharging;

  @override
  int get hashCode => Object.hash(level, isCharging);

  @override
  String toString() => 'BatteryInfo(level: $level%, isCharging: $isCharging)';
}
