import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/logger.dart';
import '../domain/entities/battery_info.dart';

class BatteryPlatformChannel {
  static const _channel = MethodChannel(AppConstants.batteryChannelName);

  Future<BatteryInfo?> getBatteryInfo() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        AppConstants.getBatteryMethod,
      );

      if (raw == null) return null;

      return BatteryInfo(
        level: raw['level'] as int,
        isCharging: raw['isCharging'] as bool,
      );
    } on PlatformException catch (e) {
      AppLogger.d(
        'BatteryChannel',
        'PlatformException [${e.code}]: ${e.message}',
      );
      return null;
    } on MissingPluginException catch (e) {
      AppLogger.d('BatteryChannel', 'MissingPluginException: ${e.message}');
      return null;
    } catch (e) {
      AppLogger.e('BatteryChannel', 'Unexpected error', e);
      return null;
    }
  }
}
