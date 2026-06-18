import '../../domain/entities/battery_info.dart';
import '../../domain/repositories/battery_repository.dart';
import '../battery_platform_channel.dart';

/// Bridges the domain contract ([BatteryRepository]) and the infrastructure
/// layer ([BatteryPlatformChannel]).
///
/// Identical pattern to [TrackingRepositoryImpl] — the only place that knows
/// about both the interface and the concrete data source.
class BatteryRepositoryImpl implements BatteryRepository {
  final BatteryPlatformChannel _channel;

  BatteryRepositoryImpl(this._channel);

  @override
  Future<BatteryInfo?> getBatteryInfo() => _channel.getBatteryInfo();
}
