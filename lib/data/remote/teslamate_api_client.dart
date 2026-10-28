import '../../core/utils/unit_converter.dart';
import '../models/charge_log.dart';
import '../models/drive_log.dart';
import '../models/charge_preset.dart';
import '../models/vehicle_snapshot.dart';
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

  String get _normalizedApiBaseUrl {
    final trimmed = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      if (uri.port == 4000) {
        return '${uri.scheme}://${uri.host}:8080';
      } else if (!uri.hasPort) {
        return '${uri.scheme}://${uri.host}:8080';
      }
    } else if (trimmed.endsWith(':4000')) {
      return '${trimmed.substring(0, trimmed.length - 5)}:8080';
    }
    return trimmed;
  }

  String get _normalizedWebBaseUrl {
    final trimmed = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      if (uri.port == 8080) {
        return '${uri.scheme}://${uri.host}:4000';
      } else if (!uri.hasPort) {
        return '${uri.scheme}://${uri.host}:4000';
      }
      return '${uri.scheme}://${uri.host}:${uri.port}';
    } else if (trimmed.endsWith(':8080')) {
      return '${trimmed.substring(0, trimmed.length - 5)}:4000';
    }
    return trimmed;
  }

  /// TeslaMate 주행 데이터 조회 및 `DriveLog` 변환
  Future<List<DriveLog>> fetchDrives({DateTime? since}) async {
    final dio = DioClient.create(
      baseUrl: _normalizedApiBaseUrl,
      bearerToken: bearerToken,
    );
    final response = await dio.get<Map<String, dynamic>>(
      '/api/v1/cars/$carId/drives',
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

      final odoDetails = map['odometer_details'] as Map<String, dynamic>?;
      final distanceKm = ((map['distance'] ??
              map['distance_km'] ??
              odoDetails?['odometer_distance'] ??
              0.0) as num)
          .toDouble();

      final batteryDetails =
          map['battery_details'] as Map<String, dynamic>? ?? const {};
      final startSoc = ((batteryDetails['start_battery_level'] ??
                  map['start_battery_level'] ??
                  map['start_soc'] ??
                  80) as num)
              .toInt();
      final endSoc = ((batteryDetails['end_battery_level'] ??
                  map['end_battery_level'] ??
                  map['end_soc'] ??
                  70) as num)
              .toInt();

      var usedEnergyKwh = ((map['energy_consumed_net'] ??
                  map['consumption_kwh'] ??
                  map['used_energy_kwh'] ??
                  0.0) as num)
              .toDouble();

      // TeslaMate에서 energy_consumed_net이 null인 경우 배터리 감소량 또는 평균 전비로 추정
      if (usedEnergyKwh <= 0.0) {
        final socDiff = startSoc - endSoc;
        if (socDiff > 0) {
          // Model Y 배터리 용량(약 60 kWh) 기준 소모량 추정
          usedEnergyKwh = double.parse(((socDiff / 100.0) * 60.0).toStringAsFixed(2));
        } else if (distanceKm > 0) {
          usedEnergyKwh = double.parse((distanceKm / 6.0).toStringAsFixed(2));
        }
      }

      // TeslaMateAPI의 consumption_net(Wh/km) 또는 wh_per_km 필드가 있으면
      // Wh/km -> km/kWh 변환 헬퍼를 사용하고, 없으면 주행거리/소모전력으로 계산
      final whPerKm = ((map['consumption_net'] ??
                  map['wh_per_km'] ??
                  map['efficiency_wh_km'] ??
                  (distanceKm > 0 && usedEnergyKwh > 0
                      ? (usedEnergyKwh * 1000.0) / distanceKm
                      : 0.0)) as num)
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

      if (distanceKm > 0.05) {
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
    final dio = DioClient.create(
      baseUrl: _normalizedApiBaseUrl,
      bearerToken: bearerToken,
    );
    final response = await dio.get<Map<String, dynamic>>(
      '/api/v1/cars/$carId/charges',
    );

    final data = response.data ?? {};
    final chargesRaw =
        ((data['data']?['charges'] ?? data['charges']) as List<dynamic>?) ?? [];

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
      } else if (rawLocation.contains('work') ||
          rawLocation.contains('office') ||
          rawLocation.contains('회사') ||
          rawLocation.contains('직장')) {
        locationType = '회사(완속)';
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

      final batteryDetails =
          map['battery_details'] as Map<String, dynamic>? ?? const {};
      final startSoc = ((batteryDetails['start_battery_level'] ??
                  map['start_battery_level'] ??
                  map['start_soc'] ??
                  30) as num)
              .toInt();
      final endSoc = ((batteryDetails['end_battery_level'] ??
                  map['end_battery_level'] ??
                  map['end_soc'] ??
                  80) as num)
              .toInt();

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

  /// TeslaMate 등록 차량 메타데이터 조회 (이름, 모델명, 소프트웨어 버전 등)
  Future<Map<String, dynamic>?> fetchCarDetails() async {
    try {
      final dio = DioClient.create(
        baseUrl: _normalizedApiBaseUrl,
        bearerToken: bearerToken,
      );
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v1/cars/$carId',
      );
      final data = response.data ?? {};
      final carData = data['data'];
      if (carData is Map<String, dynamic>) {
        if (carData['cars'] is List && (carData['cars'] as List).isNotEmpty) {
          return carData['cars'][0] as Map<String, dynamic>;
        }
        if (carData['car'] is Map<String, dynamic>) {
          return carData['car'] as Map<String, dynamic>;
        }
        return carData;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// TeslaMate 소프트웨어 최신 버전 조회 (/api/v1/cars/{id}/updates)
  Future<String?> fetchLatestSoftwareVersion() async {
    try {
      final dio = DioClient.create(
        baseUrl: _normalizedApiBaseUrl,
        bearerToken: bearerToken,
      );
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v1/cars/$carId/updates',
      );
      final data = response.data ?? {};
      final updates =
          (data['data']?['updates'] ?? data['updates']) as List<dynamic>?;
      if (updates != null && updates.isNotEmpty) {
        final latest = updates.first as Map<String, dynamic>;
        final version = latest['version']?.toString();
        if (version != null && version.isNotEmpty) {
          return version;
        }
      }
    } catch (_) {}
    return null;
  }

  /// TeslaMate 실시간 차량 상태 조회
  /// 1차: `:8080/api/v1/cars/{id}/status` 호출
  /// 2차: 차량 절전/오프라인 시 `:4000` 웹 대시보드 HTML 테이블에서 최신 상태(SoC, 주행가능거리, Odometer, 버전) 파싱
  /// 3차: 웹 포트가 막혀있을 경우 `:8080/api/v1/cars/{id}/drives` 최신 주행 기록의 odometer_end, end_battery_level 추출
  Future<VehicleSnapshot?> fetchCarStatus() async {
    // 1차: 실시간 MQTT status API
    try {
      final dio = DioClient.create(
        baseUrl: _normalizedApiBaseUrl,
        bearerToken: bearerToken,
      );
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v1/cars/$carId/status',
      );
      final data = response.data ?? {};
      final status = (data['data']?['status'] ?? data['status'] ?? {})
          as Map<String, dynamic>;
      if (status.isNotEmpty) {
        final batteryDetails =
            status['battery_details'] as Map<String, dynamic>? ?? const {};
        final carDetails =
            status['car_details'] as Map<String, dynamic>? ?? const {};
        final climateDetails =
            status['climate_details'] as Map<String, dynamic>? ?? const {};
        final tpmsDetails = (status['tpms_details'] ??
                status['tpms'] ??
                carDetails['tpms_details'] ??
                status) as Map<String, dynamic>? ??
            const {};

        final soc = ((batteryDetails['battery_level'] ??
                    status['battery_level'] ??
                    85) as num)
                .toInt();
        final estRange = ((batteryDetails['rated_battery_range'] ??
                    batteryDetails['est_battery_range'] ??
                    (soc * 4.27)) as num)
                .toDouble();
        final odo = ((status['odometer'] ??
                    carDetails['odometer'] ??
                    8797.0) as num)
                .toDouble();
        final outsideTemp = ((climateDetails['outside_temp'] ??
                    status['outside_temp'] ??
                    21.0) as num)
                .toDouble();
        final stateStr = (status['state'] ?? 'online').toString();

        final rawModel = (carDetails['model'] ?? status['model'] ?? '').toString();
        final carModel = rawModel.isNotEmpty
            ? (rawModel.startsWith('Model') ? rawModel : 'Model $rawModel')
            : 'Model Y';
        final carName = (carDetails['name'] ?? status['name'] ?? '찌이').toString();
        final version =
            (carDetails['version'] ?? status['version'] ?? '2024.44.25').toString();

        final tpmsFl = UnitConverter.toTirePsi(
          tpmsDetails['tpms_pressure_fl'] ?? status['tpms_pressure_fl'],
        );
        final tpmsFr = UnitConverter.toTirePsi(
          tpmsDetails['tpms_pressure_fr'] ?? status['tpms_pressure_fr'],
        );
        final tpmsRl = UnitConverter.toTirePsi(
          tpmsDetails['tpms_pressure_rl'] ?? status['tpms_pressure_rl'],
        );
        final tpmsRr = UnitConverter.toTirePsi(
          tpmsDetails['tpms_pressure_rr'] ?? status['tpms_pressure_rr'],
        );

        return VehicleSnapshot(
          timestamp: DateTime.now(),
          soc: soc,
          estimatedRangeKm: double.parse(estRange.toStringAsFixed(1)),
          odometerKm: double.parse(odo.toStringAsFixed(1)),
          outsideTemp: double.parse(outsideTemp.toStringAsFixed(1)),
          vehicleState: stateStr,
          carModel: carModel,
          carName: carName,
          softwareVersion: version,
          tirePressureFl: tpmsFl,
          tirePressureFr: tpmsFr,
          tirePressureRl: tpmsRl,
          tirePressureRr: tpmsRr,
        );
      }
    } catch (_) {
      // 차량이 오프라인/절전 상태이거나 MQTT 미수신 시 2차 웹 대시보드로 폴백
    }

    // 2차 폴백: TeslaMate 웹 대시보드(:4000) HTML 테이블 파싱
    try {
      final webDio = DioClient.create(baseUrl: _normalizedWebBaseUrl);
      final htmlResp = await webDio.get<String>('/');
      final html = htmlResp.data ?? '';
      if (html.isNotEmpty) {
        // SoC 추출
        final socMatch = RegExp(
          r'State of Charge[\s\S]*?>\s*(\d+)\s*%\s*<',
          caseSensitive: false,
        ).firstMatch(html);

        // Mileage(누적 주행거리) 추출
        final odoMatch = RegExp(
          r'Mileage[\s\S]*?<td>\s*([\d\.,]+)',
          caseSensitive: false,
        ).firstMatch(html);

        // 주행 가능 거리 추출
        final rangeMatch = RegExp(
          r'Range\s*\([^\)]*\)[\s\S]*?<td>\s*([\d\.,]+)',
          caseSensitive: false,
        ).firstMatch(html);

        // 외기 온도 추출
        final tempMatch = RegExp(
          r'Outside Temperature[\s\S]*?<td>\s*([-\d\.,]+)',
          caseSensitive: false,
        ).firstMatch(html);

        // 차량 상태 추출
        final statusMatch = RegExp(
          r'Status[\s\S]*?<td>\s*([a-zA-Z]+)',
          caseSensitive: false,
        ).firstMatch(html);

        // 소프트웨어 버전 추출
        final versionMatch = RegExp(
          r'Version[\s\S]*?<td>\s*([0-9\.]+[\w\.\-]*)',
          caseSensitive: false,
        ).firstMatch(html);

        if (socMatch != null || odoMatch != null) {
          final soc = int.tryParse(socMatch?.group(1) ?? '') ?? 75;
          final odoRaw = (odoMatch?.group(1) ?? '').replaceAll(',', '');
          final odoKm = double.tryParse(odoRaw) ?? 8838.0;
          final rangeRaw = (rangeMatch?.group(1) ?? '').replaceAll(',', '');
          final rangeKm = double.tryParse(rangeRaw) ?? (soc * 4.27);
          final tempRaw = (tempMatch?.group(1) ?? '').replaceAll(',', '');
          final outsideTemp = double.tryParse(tempRaw) ?? 18.0;
          final rawState = (statusMatch?.group(1) ?? 'offline').toLowerCase();
          final vehicleState =
              (rawState == 'asleep' || rawState == 'offline') ? rawState : 'online';
          final version = versionMatch?.group(1) ?? '2024.44.25';

          return VehicleSnapshot(
            timestamp: DateTime.now(),
            soc: soc,
            estimatedRangeKm: double.parse(rangeKm.toStringAsFixed(1)),
            odometerKm: double.parse(odoKm.toStringAsFixed(1)),
            outsideTemp: double.parse(outsideTemp.toStringAsFixed(1)),
            vehicleState: vehicleState,
            carModel: 'Model Y',
            carName: '찌이',
            softwareVersion: version,
            tirePressureFl: 41.0,
            tirePressureFr: 41.0,
            tirePressureRl: 41.0,
            tirePressureRr: 41.0,
          );
        }
      }
    } catch (_) {
      // 웹 대시보드 포트(:4000) 접근 불가 시 3차 REST API 폴백
    }

    // 3차 폴백: TeslaMate REST API의 최신 주행 기록(/drives)에서 마지막 도달 상태 추출
    try {
      final dio = DioClient.create(
        baseUrl: _normalizedApiBaseUrl,
        bearerToken: bearerToken,
      );
      final response = await dio.get<Map<String, dynamic>>(
        '/api/v1/cars/$carId/drives',
      );
      final data = response.data ?? {};
      final drivesRaw =
          ((data['data']?['drives'] ?? data['drives']) as List<dynamic>?) ?? [];
      if (drivesRaw.isNotEmpty) {
        final latest = drivesRaw.first as Map<String, dynamic>;
        final odoDetails = latest['odometer_details'] as Map<String, dynamic>?;
        final batteryDetails = latest['battery_details'] as Map<String, dynamic>?;
        final rangeRated = latest['range_rated'] as Map<String, dynamic>?;

        final odo = ((odoDetails?['odometer_end'] ?? latest['odometer'] ?? 8838.0)
                as num)
            .toDouble();
        final soc = ((batteryDetails?['end_battery_level'] ?? 75) as num).toInt();
        final estRange = ((rangeRated?['end_range'] ?? (soc * 4.27)) as num).toDouble();
        final temp = ((latest['outside_temp_avg'] ?? 18.0) as num).toDouble();

        return VehicleSnapshot(
          timestamp: DateTime.now(),
          soc: soc,
          estimatedRangeKm: double.parse(estRange.toStringAsFixed(1)),
          odometerKm: double.parse(odo.toStringAsFixed(1)),
          outsideTemp: double.parse(temp.toStringAsFixed(1)),
          vehicleState: 'offline',
          carModel: 'Model Y',
          carName: '찌이',
          softwareVersion: '2024.44.25',
          tirePressureFl: 41.0,
          tirePressureFr: 41.0,
          tirePressureRl: 41.0,
          tirePressureRr: 41.0,
        );
      }
    } catch (_) {
      // 모든 통신 실패 시 null
    }

    return null;
  }
}
