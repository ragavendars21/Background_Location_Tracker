import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/entities/battery_info.dart';
import '../domain/usecases/get_battery_info_usecase.dart';
import '../../../core/constants/app_constants.dart';

class BatteryProvider extends ChangeNotifier {
  final GetBatteryInfoUsecase _usecase;

  BatteryProvider(this._usecase);

  BatteryInfo? _batteryInfo;
  String? _error;
  Timer? _refreshTimer;

  BatteryInfo? get batteryInfo => _batteryInfo;
  int? get batteryLevel => _batteryInfo?.level;
  bool get isCharging => _batteryInfo?.isCharging ?? false;
  String? get error => _error;

  Future<void> startRefreshing() async {
    await _fetchBattery();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: AppConstants.batteryRefreshSeconds),
      (_) => _fetchBattery(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchBattery() async {
    try {
      final info = await _usecase();
      _error = null;

      if (info != _batteryInfo) {
        _batteryInfo = info;
        notifyListeners();
      }
    } catch (e) {
      _error = 'Battery unavailable: $e';
      notifyListeners();
    }
  }
}
