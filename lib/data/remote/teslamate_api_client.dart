import '../../core/utils/unit_converter.dart';
import '../models/charge_log.dart';
import '../models/drive_log.dart';
import '../models/charge_preset.dart';
import 'dio_client.dart';

/// 모드 A: TeslaMate REST API 클라이언트
/// - `GET /api/v1/cars/1/drives`
/// - `GET /api/v1/cars/1/charges`
/// - Wh/km 전비 데이터를 한국 친화적인 km/kWh 단위로 자동 변환
class TeslaMateApiClient {
  final String baseUrl;
  final String bearerToken;
  final int carId;

  const TeslaMateApiClient({
    required this.baseUrl,
    required this.bearerToken,
    this.carId = 1,
  });

  /// TeslaMate 주행 데이터 조회 및 `DriveLog` 변환
  Future<List<DriveLog>> fetchDrives({DateTime? since}) async {
    final dio = DioClient.create(baseUrl: baseUrl, bearerToken: bearerToken);
    final response = await dio.get<Map<String, dynamic>>(
      '/api/v1/cars/$carId/drives',
      queryParameters: {
        if (since != null) 'start_date': since.toUtc().toIso8601String(),
      },
    );

    final data = response.data ?? {};
    final drivesRaw = (data['data']?['drives'] ?? data['drives'] ?? []) as List<dynamic>;

    final List<DriveLog> results = [];
    for (final item in drivesRaw) {
      final map = item as Map<String, dynamic>;
      final startTime = DateTime.parse(
        (map['start_date'] ?? map['start_time']) as String,
      ).toLocal();
      if (since != null && !startTime.isAfter(since)) {
        continue;
      }

      final endTime = DateTime.parse(
        (map['end_date'] ?? map['end_time'] ?? map['start_date']) as String,
      ).toLocal();

      final distanceKm =
          ((map['distance'] ?? map['distance_km'] ?? 0.0) as num).toDouble();
      final usedEnergyKwh = ((map['consumption_kwh'] ??
                  map['used_energy_kwh'] ??
                  0.0) as num)
              .toDouble();

      // TeslaMate가 제공하는 consumption_kwh_per_100km 또는 wh_per_km 필드가 있으면
      // Wh/km -> km/kWh 변환 헬퍼를 사용하고, 없으면 주행거리/소모전력으로 계산
      final whPerKm = ((map['wh_per_km'] ??
                  map['efficiency_wh_km'] ??
                  (distanceKm > 0 ? (usedEnergyKwh * 1000.0) / distanceKm : 0.0))
              as num)
          .toDouble();

      final efficiencyKmKwh = whPerKm > 0
          ? UnitConverter.whPerKmToKmPerKwh(whPerKm)
          : UnitConverter.calculateEfficiencyKmPerKwh(
              distanceKm: distanceKm,
              usedEnergyKwh: usedEnergyKwh,
            );

      final outsideTempAvg =
          ((map['outside_temp_avg'] ?? map['outside_temp'] ?? 18.0) as num)
              .toDouble();
      final startSoc = ((map['start_battery_level'] ??
                  map['start_soc'] ??
                  80) as num)
              .toInt();
      final endSoc =
          ((map['end_battery_level'] ?? map['end_soc'] ?? 70) as num).toInt();

      if (distanceKm > 0.1) {
        results.add(
          DriveLog(
            startTime: startTime,
            endTime: endTime,
            distanceKm: double.parse(distanceKm.toStringAsFixed(2)),
            usedEnergyKwh: double.parse(usedEnergyKwh.toStringAsFixed(2)),
            efficiencyKmKwh: efficiencyKmKwh,
            outsideTempAvg: outsideTempAvg,
            startSoc: startSoc,
            endSoc: endSoc,
            source: 'teslamate',
          ),
        );
      }
    }

    return results;
  }

  /// TeslaMate 충전 데이터 조회 및 `ChargeLog` 변환
  Future<List<ChargeLog>> fetchCharges({
    DateTime? since,
    List<ChargePreset> presets = ChargePreset.defaultPresets,
  }) async {
    final dio = DioClient.create(baseUrl: baseUrl, bearerToken: bearerToken);
    final response = await dio.get<Map<String, dynamic>>(
      '/api/v1/cars/$carId/charges',
      queryParameters: {
        if (since != null) 'start_date': since.toUtc().toIso8601String(),
      },
    );

    final data = response.data ?? {};
    final chargesRaw =
        (data['data']?['charges'] ?? data['charges'] ?? []) as List<dynamic>;

    final List<ChargeLog> results = [];
    for (final item in chargesRaw) {
      final map = item as Map<String, dynamic>;
      final date = DateTime.parse(
        (map['start_date'] ?? map['date']) as String,
      ).toLocal();
      if (since != null && !date.isAfter(since)) {
        continue;
      }

      final addedEnergyKwh = ((map['charge_energy_added'] ??
                  map['added_energy_kwh'] ??
                  0.0) as num)
              .toDouble();
      if (addedEnergyKwh <= 0.1) continue;

      final rawLocation = (map['address'] ??
              map['geofence'] ??
              map['location_type'] ??
              '')
          .toString()
          .toLowerCase();

      String locationType = '기타';
      if (rawLocation.contains('supercharger') ||
          rawLocation.contains('수퍼차저')) {
        locationType = '수퍼차저';
      } else if (rawLocation.contains('home') ||
          rawLocation.contains('집') ||
          rawLocation.contains('apt')) {
        locationType = '집밥(완속)';
      } else if (rawLocation.contains('fast') ||
          rawLocation.contains('급속') ||
          rawLocation.contains('e-pit')) {
        locationType = '공용급속';
      }

      final preset = presets.firstWhere(
        (p) => p.locationType == locationType,
        orElse: () => ChargePreset.defaultPresets.first,
      );

      final unitPriceKrw =
          ((map['unit_price_krw'] ?? preset.unitPriceKrw) as num).toInt();
      final totalCostKrw = ((map['cost'] ??
                  map['total_cost_krw'] ??
                  (addedEnergyKwh * unitPriceKrw)) as num)
              .round();

      final startSoc = ((map['start_battery_level'] ??
                  map['start_soc'] ??
                  30) as num)
              .toInt();
      final endSoc =
          ((map['end_battery_level'] ?? map['end_soc'] ?? 80) as num).toInt();

      results.add(
        ChargeLog(
          date: date,
          locationType: locationType,
          addedEnergyKwh: double.parse(addedEnergyKwh.toStringAsFixed(2)),
          unitPriceKrw: unitPriceKrw,
          totalCostKrw: totalCostKrw,
          startSoc: startSoc,
          endSoc: endSoc,
        ),
      );
    }

    return results;
  }
}
