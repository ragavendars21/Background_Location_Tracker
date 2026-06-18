import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

enum PermissionResult { granted, denied, deniedForever, gpsDisabled }

class LocationPermissionService {
  LocationPermissionService._();

  static Future<PermissionResult> requestAll() async {
    await Permission.notification.request();

    LocationPermission perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) return PermissionResult.denied;
    if (perm == LocationPermission.deniedForever) {
      return PermissionResult.deniedForever;
    }

    final bgStatus = await Permission.locationAlways.request();
    if (bgStatus.isPermanentlyDenied) return PermissionResult.deniedForever;
    if (bgStatus.isDenied) return PermissionResult.denied;

    final gpsOn = await Geolocator.isLocationServiceEnabled();
    if (!gpsOn) return PermissionResult.gpsDisabled;

    return PermissionResult.granted;
  }

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

  static Future<void> openSettings() => openAppSettings();

  static Future<void> openGpsSettings() => Geolocator.openLocationSettings();
}
