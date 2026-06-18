import '../entities/battery_info.dart';

/// Contract for reading battery state.
///
/// The domain layer declares WHAT it needs (this interface).
/// The data layer decides HOW to get it (BatteryRepositoryImpl via MethodChannel).
///
/// This inversion means you can swap the native implementation for a fake
/// in tests without changing a single line of business logic.
abstract class BatteryRepository {
  /// Returns the current battery info, or null if the platform cannot supply it
  /// (e.g., iOS simulator, some emulators).
  Future<BatteryInfo?> getBatteryInfo();
}
