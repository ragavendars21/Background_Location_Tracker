import 'package:flutter/foundation.dart';
import '../../domain/entities/battery_info.dart';

@immutable
class BatteryState {
  final BatteryInfo? batteryInfo;
  final bool isLoading;
  final String? error;

  const BatteryState({this.batteryInfo, this.isLoading = false, this.error});

  int? get level => batteryInfo?.level;
  bool get isCharging => batteryInfo?.isCharging ?? false;

  BatteryState copyWith({
    BatteryInfo? batteryInfo,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return BatteryState(
      batteryInfo: batteryInfo ?? this.batteryInfo,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
