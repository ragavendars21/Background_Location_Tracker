import 'package:flutter_test/flutter_test.dart';
import 'package:background_location_tracker/features/battery/domain/entities/battery_info.dart';
import 'package:background_location_tracker/features/battery/domain/repositories/battery_repository.dart';
import 'package:background_location_tracker/features/battery/domain/usecases/get_battery_info_usecase.dart';
import 'package:background_location_tracker/features/battery/presentation/battery_provider.dart';

/// Manual fake — no mocking package needed.
///
/// We program the fake in each test, which makes it easy to see exactly
/// what input the provider is given without reading mock configuration.
class _FakeBatteryRepository implements BatteryRepository {
  BatteryInfo? returnValue;
  bool         shouldThrow = false;

  @override
  Future<BatteryInfo?> getBatteryInfo() async {
    if (shouldThrow) throw Exception('Simulated channel failure');
    return returnValue;
  }
}

void main() {
  late _FakeBatteryRepository fakeRepo;
  late BatteryProvider        provider;

  setUp(() {
    fakeRepo = _FakeBatteryRepository();
    provider = BatteryProvider(GetBatteryInfoUsecase(fakeRepo));
  });

  tearDown(() => provider.dispose());

  group('BatteryProvider', () {
    test('batteryLevel is null before startRefreshing()', () {
      expect(provider.batteryLevel, isNull);
      expect(provider.isCharging,   false);
    });

    test('startRefreshing() fetches immediately and exposes BatteryInfo', () async {
      fakeRepo.returnValue = const BatteryInfo(level: 65, isCharging: false);

      await provider.startRefreshing();

      expect(provider.batteryLevel, 65);
      expect(provider.isCharging,   false);
      expect(provider.batteryInfo,  isNotNull);
    });

    test('notifyListeners() fires when level changes', () async {
      fakeRepo.returnValue = const BatteryInfo(level: 80, isCharging: false);
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.startRefreshing();

      expect(notifyCount, 1); // first fetch → notify
    });

    test('does NOT notify when value is identical', () async {
      fakeRepo.returnValue = const BatteryInfo(level: 80, isCharging: false);
      int notifyCount = 0;

      await provider.startRefreshing(); // first fetch

      provider.addListener(() => notifyCount++);
      // Manually trigger a second fetch with the SAME value
      await provider.startRefreshing();

      // Provider compares BatteryInfo via == so no rebuild fires
      expect(notifyCount, 0);
    });

    test('batteryLevel stays null when platform returns null', () async {
      fakeRepo.returnValue = null; // simulates emulator / simulator

      await provider.startRefreshing();

      expect(provider.batteryLevel, isNull);
    });

    test('error state is set when use case throws', () async {
      fakeRepo.shouldThrow = true;
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.startRefreshing();

      expect(provider.error,     isNotNull);
      expect(notifyCount,        1); // error notification
      expect(provider.batteryLevel, isNull);
    });

    test('isCharging reflects native charging state', () async {
      fakeRepo.returnValue = const BatteryInfo(level: 42, isCharging: true);

      await provider.startRefreshing();

      expect(provider.isCharging, true);
    });

    test('dispose() does not throw', () {
      // Use a fresh provider so the shared tearDown does not double-dispose.
      final fresh = BatteryProvider(GetBatteryInfoUsecase(fakeRepo));
      expect(() => fresh.dispose(), returnsNormally);
    });
  });
}
