import '../entities/battery_info.dart';

abstract class BatteryRepository {
  Future<BatteryInfo?> getBatteryInfo();
}
