import '../entities/battery_info.dart';
import '../repositories/battery_repository.dart';

/// Retrieves a fresh snapshot of the device battery state.
///
/// There is no business logic here today, but the use case still earns its
/// place: it is the layer that *would* contain rules like
/// "pause tracking if battery < 5%" without that logic leaking into the UI.
class GetBatteryInfoUsecase {
  final BatteryRepository _repository;

  GetBatteryInfoUsecase(this._repository);

  Future<BatteryInfo?> call() => _repository.getBatteryInfo();
}
