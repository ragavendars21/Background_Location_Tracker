import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/logger.dart';
import '../domain/entities/battery_info.dart';

/// Dart side of the battery Platform Channel.
///
/// ── How Platform Channels work (recruiter-ready explanation) ──────────────
///
///  Think of it like a walkie-talkie.
///
///  Flutter holds one end (this class). Native Kotlin/Swift holds the other
///  (MainActivity.kt / AppDelegate.swift). Both ends tune to the SAME channel
///  name — "com.backgroundtracker.app/battery" — so they can hear each other.
///
///  Flutter says:    invokeMethod("getBatteryLevel")
///  Native hears it, reads the actual battery sensor from the OS, and replies.
///  Flutter receives: {"level": 78, "isCharging": true}
///
///  The Flutter framework handles all the serialisation between Dart objects
///  and native types (StandardMessageCodec). You never write serialisation code.
///
/// ── Three rules you MUST follow ──────────────────────────────────────────
///  1. Channel name must be IDENTICAL on all three sides (Dart, Kotlin, Swift).
///  2. Only primitive types travel the channel: int, double, bool, String,
///     Uint8List, List, and Map with primitive keys/values.
///  3. Every call is asynchronous — always await it.
///
class BatteryPlatformChannel {
  // Private so the channel object is created once and reused.
  // MethodChannel is cheap to construct but consistency is cleaner.
  static const _channel = MethodChannel(AppConstants.batteryChannelName);

  /// Asks native code for the current battery level and charging state.
  ///
  /// Returns null (instead of throwing) when the information is genuinely
  /// unavailable — e.g., iOS Simulator, some Android emulators. The UI
  /// should show "--" in those cases rather than a crash.
  Future<BatteryInfo?> getBatteryInfo() async {
    try {
      // invokeMethod sends the method name across the channel.
      // The generic type tells Dart what shape to expect back.
      // Native returns Map<String, dynamic>: {"level": 78, "isCharging": false}
      final raw = await _channel
          .invokeMethod<Map<Object?, Object?>>(AppConstants.getBatteryMethod);

      if (raw == null) return null;

      // Cast from Map<Object?, Object?> (what the codec produces) to the
      // concrete types we know native sends. If native ever sends the wrong
      // type, the cast throws a clear TypeError — easier to debug than a
      // silent null.
      return BatteryInfo(
        level:      raw['level']      as int,
        isCharging: raw['isCharging'] as bool,
      );
    } on PlatformException catch (e) {
      // PlatformException = native code called result.error(...)
      // Known codes sent by our native implementations:
      //   "UNAVAILABLE" — BatteryManager returned MIN_VALUE (Android emulator)
      //                    or UIDevice.batteryLevel returned -1.0 (iOS simulator)
      AppLogger.d('BatteryChannel', 'PlatformException [${e.code}]: ${e.message}');
      return null;
    } on MissingPluginException catch (e) {
      // Thrown on unit-test hosts where no native implementation is registered.
      AppLogger.d('BatteryChannel', 'MissingPluginException: ${e.message}');
      return null;
    } catch (e) {
      // Defensive catch — covers codec failures and unexpected platform errors.
      AppLogger.e('BatteryChannel', 'Unexpected error', e);
      return null;
    }
  }
}
