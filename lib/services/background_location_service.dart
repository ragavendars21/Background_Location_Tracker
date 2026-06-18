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

@pragma('vm:entry-point')
class BackgroundLocationService {
  BackgroundLocationService._();

  static const _kSessionKey = 'bls_active_session_id';

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionKey);

    if (await FlutterBackgroundService().isRunning()) {
      FlutterBackgroundService().invoke('stopService');
    }

    await FlutterBackgroundService().configure(
      androidConfiguration: _buildAndroidConfig(foreground: false),
      iosConfiguration: _buildIosConfig(),
    );
  }

  static Future<void> start(String sessionId) async {
    final service = FlutterBackgroundService();

    if (await service.isRunning()) {
      service.invoke('stopService');

      await Future.delayed(const Duration(milliseconds: 300));
    }

    await service.configure(
      androidConfiguration: _buildAndroidConfig(foreground: true),
      iosConfiguration: _buildIosConfig(),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSessionKey, sessionId);
    await service.startService();
  }

  static Future<void> stop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionKey);

    FlutterBackgroundService().invoke('stopService');

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

    final datasource = LocationLocalDatasource(DatabaseHelper());

    _updateNotification(service, 'GPS tracking active…');
    AppLogger.d('BackgroundService', 'Session $sessionId — service started');

    service.on('stopService').listen((_) async {
      AppLogger.d('BackgroundService', 'Stop signal received');
      await service.stopSelf();
    });

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

  static Future<int> _captureAndSave(
    String sessionId,
    ServiceInstance service,
    int count,
    LocationLocalDatasource datasource,
  ) async {
    const maxAttempts = 3;
    const retryDelay = Duration(seconds: 5);

    final accuracy = count < AppConstants.highAccuracyCaptures
        ? LocationAccuracy.high
        : LocationAccuracy.medium;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          AppLogger.w(
            'BackgroundService',
            'Permission revoked — skipping interval',
          );
          _updateNotification(service, 'Permission revoked — open app to fix');
          return count;
        }

        final gpsEnabled = await Geolocator.isLocationServiceEnabled();
        if (!gpsEnabled) {
          AppLogger.w('BackgroundService', 'GPS is off — skipping interval');
          _updateNotification(
            service,
            'GPS disabled — enable to resume tracking',
          );
          return count;
        }

        final position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: accuracy,
            timeLimit: const Duration(seconds: 15),
          ),
        );

        final model = LocationModel(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
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
        AppLogger.w(
          'BackgroundService',
          'GPS timeout (attempt $attempt/$maxAttempts)',
        );
        if (attempt < maxAttempts) await Future.delayed(retryDelay);
      } on LocationServiceDisabledException {
        AppLogger.w(
          'BackgroundService',
          'Location service disabled mid-capture',
        );
        _updateNotification(
          service,
          'GPS disabled — enable to resume tracking',
        );
        return count;
      } catch (e) {
        AppLogger.w(
          'BackgroundService',
          'Capture error (attempt $attempt/$maxAttempts): $e',
        );
        if (attempt < maxAttempts) await Future.delayed(retryDelay);
      }
    }

    AppLogger.w(
      'BackgroundService',
      'All $maxAttempts attempts failed — skipping interval',
    );
    return count;
  }

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
