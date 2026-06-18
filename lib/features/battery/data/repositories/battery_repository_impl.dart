import '../../domain/entities/battery_info.dart';
import '../../domain/repositories/battery_repository.dart';
import '../battery_platform_channel.dart';

class BatteryRepositoryImpl implements BatteryRepository {
  final BatteryPlatformChannel _channel;

  BatteryRepositoryImpl(this._channel);

  @override
  Future<BatteryInfo?> getBatteryInfo() => _channel.getBatteryInfo();
}
