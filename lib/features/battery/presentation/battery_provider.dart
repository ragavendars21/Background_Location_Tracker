import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/entities/battery_info.dart';
import '../domain/usecases/get_battery_info_usecase.dart';
import '../../../core/constants/app_constants.dart';

class BatteryProvider extends ChangeNotifier {
  final GetBatteryInfoUsecase _usecase;

  BatteryProvider(this._usecase);

  // ── State ──────────────────────────────────────────────────────────────────

  BatteryInfo? _batteryInfo;
  String?      _error;
  Timer?       _refreshTimer;

  // ── Getters ────────────────────────────────────────────────────────────────

  BatteryInfo? get batteryInfo  => _batteryInfo;
  int?         get batteryLevel => _batteryInfo?.level;
  bool         get isCharging   => _batteryInfo?.isCharging ?? false;
  String?      get error        => _error;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Call once from the UI's initState. Fetches immediately, then polls.
  Future<void> startRefreshing() async {
    await _fetchBattery();

    // Poll every 30 s — fine-grained enough to show charging state changes
    // (plug in / unplug) without being wasteful.
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

  // ── Private ────────────────────────────────────────────────────────────────

  Future<void> _fetchBattery() async {
    try {
      final info = await _usecase();
      _error = null;

      // Only rebuild the widget tree when something actually changed.
      // Avoids a rebuild every 30 s just because the battery is the same.
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
