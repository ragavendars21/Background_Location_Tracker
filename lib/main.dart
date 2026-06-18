import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/utils/logger.dart';
import 'services/background_location_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request POST_NOTIFICATIONS before BackgroundLocationService.initialize().
  //
  // WHY HERE and not just in LocationPermissionService.requestAll():
  // flutter_background_service uses START_STICKY — if the service was running
  // in a prior session and the process was killed (e.g. debugger restart), the
  // OS recreates the service in the new process. The plugin calls
  // startForeground() natively BEFORE any Flutter/Dart code runs. On Android
  // 14+ (API 34+) that crashes with CannotPostForegroundServiceNotificationException
  // if POST_NOTIFICATIONS is not already granted.
  //
  // Calling request() here runs synchronously before initialize(), so the
  // permission is in place before the native service can call startForeground().
  // On Android < 13 this is a no-op (returns .granted immediately, no dialog).
  // On subsequent launches where permission is already granted, also a no-op.
  await Permission.notification.request();

  // ── Production error handlers ─────────────────────────────────────────────
  //
  // WHY THIS MATTERS (production readiness):
  // ─────────────────────────────────────────
  // By default, unhandled Flutter errors print to the console and are silently
  // swallowed in release builds. In production the user just sees a frozen screen.
  //
  // These two hooks let you forward every crash to a reporting service
  // (Firebase Crashlytics, Sentry, Datadog) with one line per hook.
  // The hooks below log to console in debug and are ready to be wired to
  // a real crash reporter — swap the AppLogger.e calls for
  // `FirebaseCrashlytics.instance.recordFlutterFatalError(details)`.

  // Catches Flutter framework errors (widget build exceptions, rendering errors).
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details); // prints in debug
    AppLogger.e('FlutterError', details.exceptionAsString(), details.stack);
    // TODO(production): FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  // Catches errors thrown in async callbacks that Flutter's framework doesn't
  // own — e.g., a Future in a Timer that was never awaited.
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e('PlatformDispatcher', error.toString(), stack);
    // TODO(production): FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true; // true = error handled, don't crash the app
  };

  // Register the Android foreground service and iOS background task config.
  // Must run before runApp so the service can be started from any entry point.
  await BackgroundLocationService.initialize();

  // ProviderScope is Riverpod's dependency container.
  // It must wrap the entire widget tree — all ref.watch/read calls inside
  // any descendant widget will resolve providers from this single scope.
  runApp(const ProviderScope(child: App()));
}
