import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../core/utils/logger.dart';
import '../features/location/data/datasources/location_local_datasource.dart';
import '../features/location/data/models/location_model.dart';
import '../core/utils/date_formatter.dart';

/// Thin wrapper around [FlutterBackgroundService].
///
/// Responsibilities (and only these):
///   1. Configure the Android foreground service and iOS background task.
///   2. Persist the session ID to SharedPreferences so the background isolate
///      can read it even after a force-kill + OS restart.
///   3. Provide [getSessionId] so the UI can re-attach to a running session
///      after a process restart.
///
/// ─── Why SharedPreferences instead of FlutterBackgroundService.invoke? ───
/// invoke() sends a Dart event to the background isolate, but there is a race:
/// if Android force-kills the app and restarts the service via START_STICKY,
/// the new isolate starts fresh with no pending events. SharedPreferences
/// (backed by a file) survives the kill, so the isolate always finds the ID.
///
/// @pragma required on the CLASS: flutter_background_service resolves _onStart
/// by looking up this class by its library URI from native (Java) code, then
/// finding the method on it. Without the class pragma the DartVM throws
/// "To access BackgroundLocationService from native code, it must be annotated."
/// That error causes the background isolate to crash before startForeground()
/// is called → Android kills the process with ForegroundServiceDidNotStartInTimeException.
@pragma('vm:entry-point')
class BackgroundLocationService {
  BackgroundLocationService._();

  static const _kSessionKey = 'bls_active_session_id';

  // ── Public API ─────────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    // Always clear the session ID on every process start (cold launch / hot
    // restart). A service running at this point was started by WatchdogReceiver
    // in background mode — it is NOT a valid user-initiated session.
    //
    // WHY always (not just when !isRunning):
    // WatchdogReceiver fires 5 s after every onStartCommand. If it fires in the
    // new process BEFORE this method runs, isRunning()=true and the old session
    // ID is still in prefs → reattachSession() reads it → UI incorrectly shows
    // "TRACKING ACTIVE" on every cold launch, with the Start button disabled.
    // Clearing unconditionally ensures a clean state every time the app opens.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionKey);

    // Tell a running watchdog-started service to stop. It will receive the event,
    // find no session ID, and call stopSelf(). Belt-and-suspenders: _onStart()
    // also calls stopSelf() when it reads null from prefs.
    if (await FlutterBackgroundService().isRunning()) {
      FlutterBackgroundService().invoke('stopService');
    }

    // Configure with isForegroundMode: false so the plugin stores
    // is_foreground=false in SharedPreferences.
    //
    // Combined with MainApplication.kt pre-writing false before Dart runs,
    // any watchdog alarm uses startService() (background, no notification)
    // instead of startForegroundService(). Foreground mode is re-enabled in
    // start() only after the user deliberately starts a session.
    await FlutterBackgroundService().configure(
      androidConfiguration: _buildAndroidConfig(foreground: false),
      iosConfiguration: _buildIosConfig(),
    );
  }

  static Future<void> start(String sessionId) async {
    final service = FlutterBackgroundService();

    // If the service is already running in background mode (e.g. the watchdog
    // restarted it before initialize() could stop it), we MUST stop it first.
    //
    // WHY: calling startForegroundService() on an ALREADY RUNNING service
    // triggers onStartCommand() — not onCreate(). The plugin calls startForeground()
    // inside onCreate() via updateNotificationInfo(). Since onCreate() is skipped,
    // startForeground() is never called → Android throws
    // ForegroundServiceDidNotStartInTimeException after 10 seconds.
    //
    // Stopping first guarantees the next startService() call triggers a fresh
    // onCreate() → startForeground() is called correctly.
    if (await service.isRunning()) {
      service.invoke('stopService');
      // Wait for the Dart stop event to be processed and the service to tear down.
      // Typically < 50 ms; 300 ms is a conservative upper bound.
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Switch to foreground mode — configure() must precede startService() because
    // startService() reads the stored is_foreground flag to decide whether to call
    // startForegroundService() or startService().
    await service.configure(
      androidConfiguration: _buildAndroidConfig(foreground: true),
      iosConfiguration: _buildIosConfig(),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSessionKey, sessionId);
    await service.startService();
  }

  static Future<void> stop() async {
    // Remove session ID FIRST — before invoking stopService — so any
    // WatchdogReceiver restart in the brief stop window reads null and
    // immediately calls stopSelf() instead of resuming the old session.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionKey);

    FlutterBackgroundService().invoke('stopService');

    // Reset is_foreground=false so the watchdog (if it fires in the brief window
    // before "manually stopped" is fully committed) restarts as a background
    // service rather than a foreground one.
    await FlutterBackgroundService().configure(
      androidConfiguration: _buildAndroidConfig(foreground: false),
      iosConfiguration: _buildIosConfig(),
    );
  }

  static Future<bool> isRunning() => FlutterBackgroundService().isRunning();

  static Future<String?> getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSessionKey);
  }

  // ── Background isolate entry points ────────────────────────────────────────

  @pragma('vm:entry-point')
  static Future<void> _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString(_kSessionKey);

    if (sessionId == null) {
      AppLogger.d('BackgroundService', 'No session ID found — stopping');
      await service.stopSelf();
      return;
    }

    // ── OPTIMIZATION: create the datasource ONCE per service lifetime ─────
    //
    // WHY THIS MATTERS (background service optimization):
    // ────────────────────────────────────────────────────
    // Previously, `LocationLocalDatasource(DatabaseHelper())` was created inside
    // the Timer callback — meaning a new Dart object was allocated on every
    // GPS capture (every 60 seconds). While the DatabaseHelper singleton keeps
    // the SQLite connection open, the repeated object allocation adds unnecessary
    // GC pressure in the background isolate which has limited memory headroom.
    //
    // Creating the datasource once here and reusing it across all captures is
    // the correct pattern: one service lifetime → one datasource instance.
    final datasource = LocationLocalDatasource(DatabaseHelper());

    _updateNotification(service, 'GPS tracking active…');
    AppLogger.d('BackgroundService', 'Session $sessionId — service started');

    service.on('stopService').listen((_) async {
      AppLogger.d('BackgroundService', 'Stop signal received');
      await service.stopSelf();
    });

    // Capture immediately, then every 60 s.
    int count = 0;
    count = await _captureAndSave(sessionId, service, count, datasource);

    Timer.periodic(
      const Duration(seconds: AppConstants.locationIntervalSeconds),
      (_) async {
        count = await _captureAndSave(sessionId, service, count, datasource);
      },
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  // ── GPS capture with retry ─────────────────────────────────────────────────

  /// WHY ADAPTIVE ACCURACY (battery optimization):
  /// ──────────────────────────────────────────────
  /// LocationAccuracy.high forces the GPS satellite chip on for every fix.
  /// That chip consumes ~150 mA — one of the biggest battery drains on a phone.
  ///
  /// Strategy: use HIGH for the first [AppConstants.highAccuracyCaptures] fixes
  /// to establish a precise starting position, then drop to MEDIUM (fused
  /// GPS + WiFi + cell towers). MEDIUM is accurate to ~100 m — sufficient for
  /// route visualisation while using ~40 % less power on a long tracking session.
  ///
  /// The [count] parameter (total fixes so far) drives the accuracy decision.
  static Future<int> _captureAndSave(
    String                  sessionId,
    ServiceInstance         service,
    int                     count,
    LocationLocalDatasource datasource, // injected once — not created per tick
  ) async {
    const maxAttempts = 3;
    const retryDelay  = Duration(seconds: 5);

    // Adaptive accuracy: high precision for the first N fixes, medium after.
    final accuracy = count < AppConstants.highAccuracyCaptures
        ? LocationAccuracy.high
        : LocationAccuracy.medium;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // ── Guard 1: permission ────────────────────────────────────────────
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          AppLogger.w('BackgroundService', 'Permission revoked — skipping interval');
          _updateNotification(service, 'Permission revoked — open app to fix');
          return count;
        }

        // ── Guard 2: GPS hardware switch ───────────────────────────────────
        final gpsEnabled = await Geolocator.isLocationServiceEnabled();
        if (!gpsEnabled) {
          AppLogger.w('BackgroundService', 'GPS is off — skipping interval');
          _updateNotification(service, 'GPS disabled — enable to resume tracking');
          return count;
        }

        // ── Acquire fix ────────────────────────────────────────────────────
        // timeLimit: 15 s → GPS chip runs at most 15 s per fix.
        final position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy:  accuracy,
            timeLimit: const Duration(seconds: 15),
          ),
        );

        // ── Persist ────────────────────────────────────────────────────────
        final model = LocationModel(
          latitude:  position.latitude,
          longitude: position.longitude,
          accuracy:  position.accuracy,
          timestamp: DateFormatter.toIso8601(position.timestamp),
          sessionId: sessionId,
        );

        await datasource.insertLocation(model);

        count++;
        _updateNotification(
          service,
          'Tracking · $count point${count == 1 ? '' : 's'} recorded',
        );
        AppLogger.d(
          'BackgroundService',
          'Fix #$count [${accuracy.name}] '
          '${position.latitude.toStringAsFixed(5)}, '
          '${position.longitude.toStringAsFixed(5)}  '
          '±${position.accuracy.toStringAsFixed(0)} m',
        );
        return count;

      } on TimeoutException {
        AppLogger.w('BackgroundService', 'GPS timeout (attempt $attempt/$maxAttempts)');
        if (attempt < maxAttempts) await Future.delayed(retryDelay);

      } on LocationServiceDisabledException {
        AppLogger.w('BackgroundService', 'Location service disabled mid-capture');
        _updateNotification(service, 'GPS disabled — enable to resume tracking');
        return count;

      } catch (e) {
        AppLogger.w('BackgroundService', 'Capture error (attempt $attempt/$maxAttempts): $e');
        if (attempt < maxAttempts) await Future.delayed(retryDelay);
      }
    }

    AppLogger.w('BackgroundService', 'All $maxAttempts attempts failed — skipping interval');
    return count;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static AndroidConfiguration _buildAndroidConfig({required bool foreground}) =>
      AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: foreground,
        autoStart: false,
        notificationChannelId: AppConstants.notificationChannelId,
        initialNotificationTitle: AppConstants.notificationChannelName,
        initialNotificationContent: foreground
            ? 'GPS tracking active…'
            : 'Initializing location service…',
        foregroundServiceNotificationId: AppConstants.notificationId,
      );

  static IosConfiguration _buildIosConfig() => IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      );

  static void _updateNotification(ServiceInstance service, String content) {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: AppConstants.notificationChannelName,
        content: content,
      );
    }
  }
}
