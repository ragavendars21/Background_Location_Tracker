class AppConstants {
  AppConstants._();

  static const String appName = 'Background Location Tracker';

  static const int locationIntervalSeconds = 60;

  static const int highAccuracyCaptures = 3;

  static const String batteryChannelName = 'com.backgroundtracker.app/battery';
  static const String getBatteryMethod = 'getBatteryLevel';

  static const int batteryRefreshSeconds = 30;

  static const String notificationChannelId = 'location_tracker_channel';
  static const String notificationChannelName = 'Location Tracking';
  static const int notificationId = 1001;
}
