// ignore_for_file: avoid_print

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:background_location_tracker/features/battery/data/battery_platform_channel.dart';

/// How we test a Platform Channel without a real device:
/// ───────────────────────────────────────────────────────
/// Flutter's test environment has no Android/iOS runtime, so
/// invokeMethod() would throw MissingPluginException by default.
///
/// The solution: [TestDefaultBinaryMessengerBinding] lets us register a
/// fake MethodCallHandler on the same channel name. Our Flutter code never
/// knows it is talking to a Dart fake instead of Kotlin/Swift — the wire
/// (channel name + codec) is identical.
///
/// This is the ONLY correct way to unit-test platform channels without mocking
/// packages. It is the pattern the Flutter team recommends in their own docs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'com.backgroundtracker.app/battery';
  const channel     = MethodChannel(channelName);

  // Helper: register a fake native handler
  void mockChannel(Future<Object?> Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  // Clean up after every test so they cannot bleed into each other
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('BatteryPlatformChannel.getBatteryInfo', () {
    test('returns BatteryInfo with correct level and charging state', () async {
      mockChannel((_) async => {'level': 78, 'isCharging': false});

      final result = await BatteryPlatformChannel().getBatteryInfo();

      expect(result, isNotNull);
      expect(result!.level,      78);
      expect(result.isCharging,  false);
      expect(result.isLow,       false); // 78 >= 20
    });

    test('returns isCharging=true when plugged in', () async {
      mockChannel((_) async => {'level': 42, 'isCharging': true});

      final result = await BatteryPlatformChannel().getBatteryInfo();

      expect(result!.isCharging, true);
      expect(result.level,       42);
    });

    test('returns null when native reports UNAVAILABLE (emulator)', () async {
      mockChannel((_) async => throw PlatformException(
        code:    'UNAVAILABLE',
        message: 'Battery not available on emulator',
      ));

      final result = await BatteryPlatformChannel().getBatteryInfo();

      // MUST return null — must NOT throw.
      // The UI shows "--" instead of crashing.
      expect(result, isNull);
    });

    test('returns null when channel has no handler (unit-test host)', () async {
      // No mockChannel() call — simulates MissingPluginException
      mockChannel((_) async => throw MissingPluginException());

      final result = await BatteryPlatformChannel().getBatteryInfo();

      expect(result, isNull);
    });

    test('reports isLow=true when level < 20', () async {
      mockChannel((_) async => {'level': 15, 'isCharging': false});

      final result = await BatteryPlatformChannel().getBatteryInfo();

      expect(result!.isLow,      true);
      expect(result.isCritical,  false); // 15 >= 10
    });

    test('reports isCritical=true when level < 10', () async {
      mockChannel((_) async => {'level': 7, 'isCharging': false});

      final result = await BatteryPlatformChannel().getBatteryInfo();

      expect(result!.isCritical, true);
      expect(result.isLow,       true); // isCritical ⊂ isLow
    });

    test('only sends getBatteryLevel method name across the channel', () async {
      String? receivedMethod;
      mockChannel((call) async {
        receivedMethod = call.method;
        return {'level': 50, 'isCharging': false};
      });

      await BatteryPlatformChannel().getBatteryInfo();

      expect(receivedMethod, 'getBatteryLevel');
    });
  });
}
