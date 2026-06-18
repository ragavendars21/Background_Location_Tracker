import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:background_location_tracker/features/battery/presentation/state/battery_state.dart';
import 'package:background_location_tracker/core/providers/providers.dart';
import 'package:background_location_tracker/core/constants/app_constants.dart';
import 'package:background_location_tracker/core/utils/logger.dart';

final batteryProvider = NotifierProvider<BatteryNotifier, BatteryState>(
  BatteryNotifier.new,
);

class BatteryNotifier extends Notifier<BatteryState>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _isDisposed = false;

  @override
  BatteryState build() {
    _isDisposed = false;

    WidgetsBinding.instance.addObserver(this);

    ref.onDispose(() {
      _isDisposed = true;
      _timer?.cancel();

      WidgetsBinding.instance.removeObserver(this);
    });

    Future.microtask(_startPolling);
    return const BatteryState(isLoading: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        AppLogger.d('BatteryNotifier', 'App paused — polling suspended');
        _timer?.cancel();
        _timer = null;
      case AppLifecycleState.resumed:
        if (!_isDisposed && _timer == null) {
          AppLogger.d('BatteryNotifier', 'App resumed — polling restarted');
          Future.microtask(_startPolling);
        }
      default:
        break;
    }
  }

  Future<void> _startPolling() async {
    await _fetch();

    if (_isDisposed || _timer != null) return;

    _timer = Timer.periodic(
      const Duration(seconds: AppConstants.batteryRefreshSeconds),
      (_) => _fetch(),
    );
  }

  Future<void> _fetch() async {
    if (_isDisposed) return;

    try {
      final info = await ref.read(getBatteryInfoUsecaseProvider)();

      if (_isDisposed) return;

      if (info == state.batteryInfo) return;

      state = BatteryState(batteryInfo: info);
    } catch (e) {
      if (_isDisposed) return;
      AppLogger.e('BatteryNotifier', 'fetch failed', e);
      state = BatteryState(error: 'Battery unavailable: $e');
    }
  }
}
