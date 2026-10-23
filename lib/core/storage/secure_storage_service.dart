import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/charge_preset.dart';
import '../../data/models/vehicle_snapshot.dart';

/// 외부 연동 설정 모드
enum SyncMode {
  teslamate('teslamate', 'TeslaMate REST API'),
  directFleet('direct_api', 'Tesla Fleet API (직접 호출)');

  final String code;
  final String label;
  const SyncMode(this.code, this.label);

  static SyncMode fromCode(String? code) {
    return SyncMode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => SyncMode.teslamate,
    );
  }
}

/// API 엔드포인트/토큰(Secure Storage) 및 차량 상태 스냅샷 저장소
class SecureStorageService {
  static const _teslamateUrlKey = 'teslamate_base_url';
  static const _teslamateTokenKey = 'teslamate_api_token';
  static const _teslamateCarIdKey = 'teslamate_car_id';

  static const _teslaFleetBaseUrlKey = 'tesla_fleet_base_url';
  static const _teslaFleetTokenKey = 'tesla_fleet_access_token';
  static const _teslaVehicleIdKey = 'tesla_vehicle_id';
  static const _preventWakeUpKey = 'prevent_asleep_wakeup';

  static const _activeSyncModeKey = 'active_sync_mode';
  static const _lastSyncTimeKey = 'last_sync_timestamp';
  static const _vehicleSnapshotKey = 'latest_vehicle_snapshot';
  static const _chargePresetsKey = 'charge_unit_presets';
  static const _batteryCapacityKwhKey = 'battery_capacity_kwh';

  final FlutterSecureStorage _secureStorage;

  const SecureStorageService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  // --- TeslaMate 설정 ---
  Future<void> saveTeslaMateConfig({
    required String baseUrl,
    required String apiToken,
    int carId = 1,
  }) async {
    await _secureStorage.write(key: _teslamateUrlKey, value: baseUrl.trim());
    await _secureStorage.write(key: _teslamateTokenKey, value: apiToken.trim());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_teslamateCarIdKey, carId);
  }

  Future<String> getTeslaMateBaseUrl() async {
    return (await _secureStorage.read(key: _teslamateUrlKey)) ??
        'https://teslamate.myhome.local';
  }

  Future<String> getTeslaMateToken() async {
    return (await _secureStorage.read(key: _teslamateTokenKey)) ?? '';
  }

  Future<int> getTeslaMateCarId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_teslamateCarIdKey) ?? 1;
  }

  // --- Tesla Direct Fleet API 설정 ---
  Future<void> saveTeslaDirectConfig({
    required String accessToken,
    required String vehicleId,
    String baseUrl = 'https://fleet-api.prd.na.vn.cloud.tesla.com',
    bool preventWakeUp = true,
  }) async {
    await _secureStorage.write(
        key: _teslaFleetTokenKey, value: accessToken.trim());
    await _secureStorage.write(
        key: _teslaVehicleIdKey, value: vehicleId.trim());
    await _secureStorage.write(
        key: _teslaFleetBaseUrlKey, value: baseUrl.trim());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_preventWakeUpKey, preventWakeUp);
  }

  Future<String> getTeslaDirectToken() async {
    return (await _secureStorage.read(key: _teslaFleetTokenKey)) ?? '';
  }

  Future<String> getTeslaVehicleId() async {
    return (await _secureStorage.read(key: _teslaVehicleIdKey)) ?? '1492837465';
  }

  Future<String> getTeslaFleetBaseUrl() async {
    return (await _secureStorage.read(key: _teslaFleetBaseUrlKey)) ??
        'https://fleet-api.prd.na.vn.cloud.tesla.com';
  }

  Future<bool> getPreventWakeUp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_preventWakeUpKey) ?? true;
  }

  // --- 동기화 모드 및 마지막 동기화 시각 ---
  Future<void> setActiveSyncMode(SyncMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeSyncModeKey, mode.code);
  }

  Future<SyncMode> getActiveSyncMode() async {
    final prefs = await SharedPreferences.getInstance();
    return SyncMode.fromCode(prefs.getString(_activeSyncModeKey));
  }

  Future<void> setLastSyncTime(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncTimeKey, timestamp.toIso8601String());
  }

  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastSyncTimeKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  // --- 배터리 용량 설정 (Vampire Drain 및 주행/충전 에너지 역산용, 기본 75kWh Long Range / 60kWh RWD) ---
  Future<double> getBatteryCapacityKwh() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_batteryCapacityKwhKey) ?? 75.0;
  }

  Future<void> setBatteryCapacityKwh(double capacityKwh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_batteryCapacityKwhKey, capacityKwh);
  }

  // --- 차량 최신 스냅샷 (SoC, 주행가능거리, Odometer, 외기온도, 상태) ---
  Future<void> saveVehicleSnapshot(VehicleSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_vehicleSnapshotKey, jsonEncode(snapshot.toMap()));
  }

  Future<VehicleSnapshot> getVehicleSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_vehicleSnapshotKey);
    if (raw == null) {
      return VehicleSnapshot(
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        soc: 78,
        estimatedRangeKm: 382.0,
        odometerKm: 28450.5,
        outsideTemp: 17.5,
        vehicleState: 'online',
      );
    }
    try {
      return VehicleSnapshot.fromMap(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return VehicleSnapshot(
        timestamp: DateTime.now(),
        soc: 78,
        estimatedRangeKm: 382.0,
        odometerKm: 28450.5,
        outsideTemp: 17.5,
        vehicleState: 'online',
      );
    }
  }

  // --- 충전 단가 프리셋 목록 ---
  Future<List<ChargePreset>> getChargePresets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chargePresetsKey);
    if (raw == null) {
      return ChargePreset.defaultPresets;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final saved = list
          .map((e) => ChargePreset.fromMap(e as Map<String, dynamic>))
          .toList();

      // 기존 설치 버전에서 새로 추가된 기본 프리셋(예: '회사(완속)')이 누락되어 있다면 자동 병합
      for (final def in ChargePreset.defaultPresets) {
        final exists = saved.any((p) => p.locationType == def.locationType);
        if (!exists) {
          saved.insert(
            saved.length >= 2 ? 1 : saved.length,
            def,
          );
        }
      }
      return saved;
    } catch (_) {
      return ChargePreset.defaultPresets;
    }
  }

  Future<void> saveChargePresets(List<ChargePreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(presets.map((e) => e.toMap()).toList());
    await prefs.setString(_chargePresetsKey, encoded);
  }
}
