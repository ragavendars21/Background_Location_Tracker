import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:background_location_tracker/features/battery/presentation/state/battery_state.dart';
import 'package:background_location_tracker/core/providers/providers.dart';
import 'package:background_location_tracker/core/constants/app_constants.dart';
import 'package:background_location_tracker/core/utils/logger.dart';

// ── Provider declaration ───────────────────────────────────────────────────────

/// Widgets read battery state with: ref.watch(batteryProvider)
final batteryProvider =
    NotifierProvider<BatteryNotifier, BatteryState>(BatteryNotifier.new);

// ── Notifier ──────────────────────────────────────────────────────────────────

/// WHY WidgetsBindingObserver (battery optimization):
/// ──────────────────────────────────────────────────
/// Without lifecycle awareness, the battery notifier polls every 30 seconds
/// even when the app is in the background (user switched to another app).
/// Those polls invoke a Platform Channel round-trip to native code, wake up
/// the Dart isolate, and trigger UI rebuilds — all completely invisible to
/// the user but measurable in battery drain.
///
/// WidgetsBindingObserver lets us hook into the Flutter app lifecycle:
///   • paused   → app moved to background → STOP the timer
///   • resumed  → app came back to foreground → START the timer + fetch immediately
///
/// On a typical phone this eliminates 12–20 unnecessary platform channel
/// calls per hour when the user isn't actively looking at the app.
class BatteryNotifier extends Notifier<BatteryState> with WidgetsBindingObserver {
  Timer? _timer;
  bool   _isDisposed = false;

  @override
  BatteryState build() {
    _isDisposed = false;

    // Register for app lifecycle events so we can pause when backgrounded.
    WidgetsBinding.instance.addObserver(this);

    ref.onDispose(() {
      _isDisposed = true;
      _timer?.cancel();
      // Always unregister — a leaked observer fires callbacks forever.
      WidgetsBinding.instance.removeObserver(this);
    });

    Future.microtask(_startPolling);
    return const BatteryState(isLoading: true);
  }

  // ── App lifecycle ─────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App is no longer visible — stop polling to save battery.
        AppLogger.d('BatteryNotifier', 'App paused — polling suspended');
        _timer?.cancel();
        _timer = null; // null signals that polling needs to restart on resume
      case AppLifecycleState.resumed:
        // App came back to foreground — fetch immediately so the UI isn't stale,
        // then restart the periodic timer.
        if (!_isDisposed && _timer == null) {
          AppLogger.d('BatteryNotifier', 'App resumed — polling restarted');
          Future.microtask(_startPolling);
        }
      default:
        break;
    }
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<void> _startPolling() async {
    await _fetch();

    // Guards against two concurrent _startPolling calls (e.g. build() microtask
    // and a resume event racing each other) both trying to create a timer.
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

      // Skip rebuild when nothing changed — avoids a full repaint every 30 s.
      if (info == state.batteryInfo) return;

      state = BatteryState(batteryInfo: info);
    } catch (e) {
      if (_isDisposed) return;
      AppLogger.e('BatteryNotifier', 'fetch failed', e);
      state = BatteryState(error: 'Battery unavailable: $e');
    }
  }
}
