import '../../core/utils/unit_converter.dart';
import '../models/charge_log.dart';
import '../models/drive_log.dart';
import '../models/vehicle_snapshot.dart';
import 'dio_client.dart';

/// Tesla Fleet API 직접 호출 결과 DTO
class DirectSyncEvaluation {
  final VehicleSnapshot currentSnapshot;
  final bool skippedBecauseAsleep;
  final DriveLog? generatedDriveLog;
  final ChargeLog? generatedChargeLog;
  final VampireDrainLog? generatedVampireDrainLog;

  const DirectSyncEvaluation({
    required this.currentSnapshot,
    this.skippedBecauseAsleep = false,
    this.generatedDriveLog,
    this.generatedChargeLog,
    this.generatedVampireDrainLog,
  });
}

/// 모드 B: Tesla 공식 Fleet API 직접 호출 클라이언트
/// - `GET /api/1/vehicles/{id}` (차량 슬립 상태 확인 -> Vampire Drain 방지)
/// - `GET /api/1/vehicles/{id}/vehicle_data` (단발성 호출 후 이전 스냅샷과 비교)
class TeslaDirectApiClient {
  static const double _milesToKm = 1.60934;

  final String baseUrl;
  final String accessToken;
  final String vehicleId;

  const TeslaDirectApiClient({
    required this.baseUrl,
    required this.accessToken,
    required this.vehicleId,
  });

  /// 차량이 asleep 상태인지 먼저 확인한 뒤 vehicle_data를 호출하고,
  /// 이전 스냅샷과 비교하여 주행/충전/대기전력 손실 로그를 생성합니다.
  Future<DirectSyncEvaluation> fetchAndEvaluate({
    required VehicleSnapshot previousSnapshot,
    required bool preventWakeUp,
    required double batteryCapacityKwh,
    required int defaultChargeUnitPriceKrw,
  }) async {
    final dio = DioClient.create(baseUrl: baseUrl, bearerToken: accessToken);

    // 1. Vampire Drain 방지를 위해 차량 상태(online/asleep) 먼저 확인
    if (preventWakeUp) {
      final stateResp =
          await dio.get<Map<String, dynamic>>('/api/1/vehicles/$vehicleId');
      final vehicleState =
          (stateResp.data?['response']?['state'] ?? 'online').toString();

      if (vehicleState == 'asleep' || vehicleState == 'offline') {
        // 차량을 깨우지 않고 기존 스냅샷 상태만 asleep으로 갱신하여 반환
        return DirectSyncEvaluation(
          currentSnapshot: previousSnapshot.copyWith(
            timestamp: DateTime.now(),
            vehicleState: vehicleState,
          ),
          skippedBecauseAsleep: true,
        );
      }
    }

    // 2. 단발성 vehicle_data 호출
    final dataResp = await dio.get<Map<String, dynamic>>(
      '/api/1/vehicles/$vehicleId/vehicle_data',
    );
    final responseObj =
        (dataResp.data?['response'] ?? <String, dynamic>{}) as Map<String, dynamic>;

    final chargeState =
        (responseObj['charge_state'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final vehicleStateMap =
        (responseObj['vehicle_state'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final climateState =
        (responseObj['climate_state'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final vehicleConfig =
        (responseObj['vehicle_config'] ?? <String, dynamic>{}) as Map<String, dynamic>;

    final currentSoc =
        ((chargeState['battery_level'] ?? previousSnapshot.soc) as num).toInt();
    final batteryRangeMiles =
        ((chargeState['battery_range'] ?? 230.0) as num).toDouble();
    final odometerMiles =
        ((vehicleStateMap['odometer'] ?? (previousSnapshot.odometerKm / _milesToKm))
                as num)
            .toDouble();
    final outsideTemp = ((climateState['outside_temp'] ??
                previousSnapshot.outsideTemp) as num)
            .toDouble();
    final sentryMode = (vehicleStateMap['sentry_mode'] as bool?) ?? false;

    // 소프트웨어 버전, 차량 이름, 모델명, 타이어 공기압 실시간 추출
    final softwareVer = (vehicleStateMap['car_version'] as String?) ??
        previousSnapshot.softwareVersion;
    final carName = (vehicleStateMap['vehicle_name'] as String?) ??
        previousSnapshot.carName;

    String carModel = previousSnapshot.carModel;
    final carType = (vehicleConfig['car_type'] as String?)?.toLowerCase();
    if (carType != null) {
      if (carType.contains('modely') || carType == 'y') {
        carModel = 'Model Y';
      } else if (carType.contains('model3') || carType == '3') {
        carModel = 'Model 3';
      } else if (carType.contains('models') || carType == 's') {
        carModel = 'Model S';
      } else if (carType.contains('modelx') || carType == 'x') {
        carModel = 'Model X';
      }
    }

    final tpmsFl = UnitConverter.toTirePsi(
      vehicleStateMap['tpms_pressure_fl'],
      fallback: previousSnapshot.tirePressureFl,
    );
    final tpmsFr = UnitConverter.toTirePsi(
      vehicleStateMap['tpms_pressure_fr'],
      fallback: previousSnapshot.tirePressureFr,
    );
    final tpmsRl = UnitConverter.toTirePsi(
      vehicleStateMap['tpms_pressure_rl'],
      fallback: previousSnapshot.tirePressureRl,
    );
    final tpmsRr = UnitConverter.toTirePsi(
      vehicleStateMap['tpms_pressure_rr'],
      fallback: previousSnapshot.tirePressureRr,
    );

    final currentSnapshot = VehicleSnapshot(
      timestamp: DateTime.now(),
      soc: currentSoc,
      estimatedRangeKm:
          double.parse((batteryRangeMiles * _milesToKm).toStringAsFixed(1)),
      odometerKm: double.parse((odometerMiles * _milesToKm).toStringAsFixed(1)),
      outsideTemp: outsideTemp,
      vehicleState: (responseObj['state'] ?? 'online').toString(),
      carModel: carModel,
      carName: carName,
      softwareVersion: softwareVer,
      tirePressureFl: tpmsFl,
      tirePressureFr: tpmsFr,
      tirePressureRl: tpmsRl,
      tirePressureRr: tpmsRr,
    );

    return compareSnapshots(
      previous: previousSnapshot,
      current: currentSnapshot,
      batteryCapacityKwh: batteryCapacityKwh,
      defaultChargeUnitPriceKrw: defaultChargeUnitPriceKrw,
      sentryModeActive: sentryMode,
    );
  }

  /// 이전 스냅샷과 현재 스냅샷을 비교하여 주행/충전/대기전력 손실(Vampire Drain) 계산
  static DirectSyncEvaluation compareSnapshots({
    required VehicleSnapshot previous,
    required VehicleSnapshot current,
    required double batteryCapacityKwh,
    required int defaultChargeUnitPriceKrw,
    bool sentryModeActive = true,
  }) {
    final distanceDeltaKm = current.odometerKm - previous.odometerKm;
    final socDelta = current.soc - previous.soc; // 음수면 소모, 양수면 충전
    final avgTemp = (previous.outsideTemp + current.outsideTemp) / 2.0;

    DriveLog? driveLog;
    ChargeLog? chargeLog;
    VampireDrainLog? drainLog;

    // 케이스 1: 충전 발생 (SoC가 2% 이상 증가한 경우)
    if (socDelta >= 2) {
      final addedKwh = double.parse(
        ((socDelta / 100.0) * batteryCapacityKwh).toStringAsFixed(2),
      );
      chargeLog = ChargeLog(
        date: current.timestamp,
        locationType: '집밥(완속)',
        addedEnergyKwh: addedKwh,
        unitPriceKrw: defaultChargeUnitPriceKrw,
        totalCostKrw: (addedKwh * defaultChargeUnitPriceKrw).round(),
        startSoc: previous.soc,
        endSoc: current.soc,
      );
    }
    // 케이스 2: 주행 발생 (누적 주행거리가 0.5km 이상 증가하고 배터리가 소모된 경우)
    else if (distanceDeltaKm >= 0.5 && socDelta < 0) {
      final usedKwh = double.parse(
        ((socDelta.abs() / 100.0) * batteryCapacityKwh).toStringAsFixed(2),
      );
      final efficiency = UnitConverter.calculateEfficiencyKmPerKwh(
        distanceKm: distanceDeltaKm,
        usedEnergyKwh: usedKwh,
      );
      driveLog = DriveLog(
        startTime: previous.timestamp,
        endTime: current.timestamp,
        distanceKm: double.parse(distanceDeltaKm.toStringAsFixed(2)),
        usedEnergyKwh: usedKwh,
        efficiencyKmKwh: efficiency,
        outsideTempAvg: double.parse(avgTemp.toStringAsFixed(1)),
        startSoc: previous.soc,
        endSoc: current.soc,
        source: 'direct_api',
      );
    }
    // 케이스 3: 주차 중 대기 전력 손실 (Vampire Drain)
    // 주행거리는 거의 그대로(< 0.5km)인데 주차 중 SoC가 1% 이상 감소한 경우
    else if (distanceDeltaKm < 0.5 && socDelta <= -1) {
      final lostKwh = double.parse(
        ((socDelta.abs() / 100.0) * batteryCapacityKwh).toStringAsFixed(2),
      );
      final lostRangeKm = (previous.estimatedRangeKm - current.estimatedRangeKm)
          .clamp(0.5, 100.0);
      drainLog = VampireDrainLog(
        startTime: previous.timestamp,
        endTime: current.timestamp,
        startSoc: previous.soc,
        endSoc: current.soc,
        lostEnergyKwh: lostKwh,
        lostRangeKm: double.parse(lostRangeKm.toStringAsFixed(1)),
        sentryModeActive: sentryModeActive,
      );
    }

    return DirectSyncEvaluation(
      currentSnapshot: current,
      skippedBecauseAsleep: false,
      generatedDriveLog: driveLog,
      generatedChargeLog: chargeLog,
      generatedVampireDrainLog: drainLog,
    );
  }
}
