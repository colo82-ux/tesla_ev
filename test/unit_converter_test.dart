import 'package:flutter_test/flutter_test.dart';
import 'package:tesla_ev/core/utils/unit_converter.dart';
import 'package:tesla_ev/data/models/vehicle_snapshot.dart';
import 'package:tesla_ev/data/remote/tesla_direct_api_client.dart';

void main() {
  group('UnitConverter (Wh/km <-> km/kWh 및 온도 구간 분류 테스트)', () {
    test('TeslaMate Wh/km 데이터를 한국형 km/kWh 단위로 정확히 변환한다', () {
      expect(UnitConverter.whPerKmToKmPerKwh(150.0), 6.67);
      expect(UnitConverter.whPerKmToKmPerKwh(200.0), 5.00);
      expect(UnitConverter.whPerKmToKmPerKwh(125.0), 8.00);
    });

    test('주행거리(km)와 소모 전력(kWh)으로 전비(km/kWh)를 계산한다', () {
      expect(
        UnitConverter.calculateEfficiencyKmPerKwh(
          distanceKm: 68.0,
          usedEnergyKwh: 10.0,
        ),
        6.80,
      );
    });

    test('외기온도를 4개 구간(영하, 0~15도, 15~25도, 25도 이상)으로 분류한다', () {
      expect(UnitConverter.classifyTemperature(-5.0), TempBracket.freezing);
      expect(UnitConverter.classifyTemperature(10.0), TempBracket.cold);
      expect(UnitConverter.classifyTemperature(20.0), TempBracket.mild);
      expect(UnitConverter.classifyTemperature(28.0), TempBracket.hot);
    });
  });

  group('TeslaDirectApiClient 스냅샷 비교 (주행/충전/Vampire Drain 판별)', () {
    final baseTime = DateTime(2026, 10, 23, 8, 0);

    test('주차 중 주행거리 변화 없이 SoC가 감소하면 VampireDrainLog를 생성한다', () {
      final prev = VehicleSnapshot(
        timestamp: baseTime,
        soc: 80,
        estimatedRangeKm: 390.0,
        odometerKm: 28400.0,
        outsideTemp: 15.0,
        vehicleState: 'online',
      );
      final curr = VehicleSnapshot(
        timestamp: baseTime.add(const Duration(hours: 12)),
        soc: 78,
        estimatedRangeKm: 380.2,
        odometerKm: 28400.1,
        outsideTemp: 14.0,
        vehicleState: 'online',
      );

      final eval = TeslaDirectApiClient.compareSnapshots(
        previous: prev,
        current: curr,
        batteryCapacityKwh: 75.0,
        defaultChargeUnitPriceKrw: 250,
      );

      expect(eval.generatedVampireDrainLog, isNotNull);
      expect(eval.generatedVampireDrainLog!.lostEnergyKwh, 1.50);
      expect(eval.generatedDriveLog, isNull);
    });
  });
}
