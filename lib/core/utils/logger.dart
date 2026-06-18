import 'package:flutter/foundation.dart';

/// Production-safe logger.
///
/// WHY THIS MATTERS TO A RECRUITER:
/// ─────────────────────────────────
/// Using raw `debugPrint('user location: $lat, $lng')` in production code has
/// two problems:
///
///   1. Privacy — location data appears in device logs that third-party tools
///      (Firebase Crashlytics, logcat) can capture. Users never see this, but
///      regulators (GDPR, CCPA) consider it a data leak.
///
///   2. Performance — even though `debugPrint` suppresses output in release mode,
///      the *string interpolation* still runs. A hot-path log like
///      `_log('Fix #$count ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}')
///      performs floating-point formatting on every GPS capture in production.
///
/// The `if (kDebugMode)` guard is eliminated entirely by the Dart ahead-of-time
/// (AOT) compiler in release builds — zero overhead, zero data exposure.
///
/// Usage:
///   AppLogger.d('BackgroundService', 'Fix captured: $lat, $lng');
class AppLogger {
  AppLogger._();

  /// Debug log — compiled out completely in release builds.
  static void d(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] $message');
    }
  }

  /// Warning log — compiled out in release builds.
  static void w(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] ⚠ $message');
    }
  }

  /// Error log — always prints so production crash reporters can capture it.
  ///
  /// Only call this for genuine errors the developer needs to investigate.
  /// Never log PII (coordinates, user IDs) here — it will appear in crash logs.
  static void e(String tag, String message, [Object? error]) {
    debugPrint('[$tag] ✖ $message${error != null ? ': $error' : ''}');
  }
}
