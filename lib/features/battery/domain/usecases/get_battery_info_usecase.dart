import '../entities/battery_info.dart';
import '../repositories/battery_repository.dart';

class GetBatteryInfoUsecase {
  final BatteryRepository _repository;

  GetBatteryInfoUsecase(this._repository);

  Future<BatteryInfo?> call() => _repository.getBatteryInfo();
}
