import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// All possible outcomes when requesting location permissions.
///
/// Keeping these as a sealed enum (not booleans) forces every call-site to
/// handle the GPS-disabled case explicitly — a common bug in location apps.
enum PermissionResult {
  /// All permissions granted AND GPS is enabled. Safe to start tracking.
  granted,

  /// User tapped "Deny" once — will be asked again next time.
  denied,

  /// User tapped "Don't ask again" (Android) or revoked via Settings (iOS).
  /// The OS will not show a permission dialog; must deep-link to Settings.
  deniedForever,

  /// Permissions are granted but the device GPS switch is off.
  gpsDisabled,
}

/// Handles the two-step Android permission flow and the GPS-enabled check.
///
/// Why two steps?
/// Android 10+ treats ACCESS_FINE_LOCATION (foreground) and
/// ACCESS_BACKGROUND_LOCATION as separate permissions with separate dialogs.
/// Requesting background access before foreground is granted causes a crash.
/// The order here — foreground first, then background — is mandatory.
class LocationPermissionService {
  LocationPermissionService._();

  /// Requests all permissions needed for background GPS tracking.
  ///
  /// Call this exactly once before starting the service. The return value
  /// tells the UI which dialog / snackbar to show.
  static Future<PermissionResult> requestAll() async {
    // Step 0 — notification permission (Android 13+ / API 33+).
    // On Android 14+ a foreground service crashes with
    // CannotPostForegroundServiceNotificationException if this is not granted.
    // permission_handler returns .granted immediately on Android < 13 (no-op).
    await Permission.notification.request();

    // Step 1 — foreground location (both coarse + fine)
    LocationPermission perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) return PermissionResult.denied;
    if (perm == LocationPermission.deniedForever) {
      return PermissionResult.deniedForever;
    }

    // Step 2 — background location ("Allow all the time" on Android 10+)
    // On iOS, geolocator's requestPermission() already asks for "Always" so
    // this step returns .granted immediately there.
    final bgStatus = await Permission.locationAlways.request();
    if (bgStatus.isPermanentlyDenied) return PermissionResult.deniedForever;
    if (bgStatus.isDenied) return PermissionResult.denied;

    // Step 3 — GPS hardware switch
    final gpsOn = await Geolocator.isLocationServiceEnabled();
    if (!gpsOn) return PermissionResult.gpsDisabled;

    return PermissionResult.granted;
  }

  /// Reads current permission state without showing any system dialog.
  /// Use this on app resume to decide whether the UI should reflect a
  /// revoked-permission warning.
  static Future<PermissionResult> checkAll() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) return PermissionResult.denied;
    if (perm == LocationPermission.deniedForever) {
      return PermissionResult.deniedForever;
    }

    final bgStatus = await Permission.locationAlways.status;
    if (bgStatus.isPermanentlyDenied) return PermissionResult.deniedForever;
    if (bgStatus.isDenied) return PermissionResult.denied;

    final gpsOn = await Geolocator.isLocationServiceEnabled();
    if (!gpsOn) return PermissionResult.gpsDisabled;

    return PermissionResult.granted;
  }

  /// Opens the system app-settings page so the user can manually grant
  /// permissions that were permanently denied.
  static Future<void> openSettings() => openAppSettings();

  /// Opens the device location-settings page so the user can toggle GPS on.
  static Future<void> openGpsSettings() => Geolocator.openLocationSettings();
}
