import '../../core/storage/secure_storage_service.dart';
import '../../core/utils/unit_converter.dart';
import '../models/drive_log.dart';
import '../models/expense_log.dart';
import '../models/vehicle_snapshot.dart';
import '../repositories/charge_repository.dart';
import '../repositories/drive_repository.dart';
import '../repositories/expense_repository.dart';
import 'tesla_direct_api_client.dart';
import 'teslamate_api_client.dart';

/// 동기화 결과 리포트 모델
class SyncResult {
  final SyncMode mode;
  final int syncedDrives;
  final int syncedCharges;
  final int syncedVampireDrains;
  final bool skippedBecauseAsleep;
  final bool usedOfflineSimulation;
  final String message;
  final DateTime timestamp;

  const SyncResult({
    required this.mode,
    required this.syncedDrives,
    required this.syncedCharges,
    this.syncedVampireDrains = 0,
    this.skippedBecauseAsleep = false,
    this.usedOfflineSimulation = false,
    required this.message,
    required this.timestamp,
  });
}

/// 외부 데이터 연동 통합 서비스 (모드 A: TeslaMate / 모드 B: Tesla Direct Fleet API)
class SyncService {
  final SecureStorageService _storage;
  final DriveRepository _driveRepository;
  final ChargeRepository _chargeRepository;
  final ExpenseRepository _expenseRepository;

  const SyncService({
    required SecureStorageService storage,
    required DriveRepository driveRepository,
    required ChargeRepository chargeRepository,
    required ExpenseRepository expenseRepository,
  })  : _storage = storage,
        _driveRepository = driveRepository,
        _chargeRepository = chargeRepository,
        _expenseRepository = expenseRepository;

  /// 현재 설정된 동기화 모드에 따라 주행/충전 데이터를 동기화하고 로컬 SQLite에 Upsert
  Future<SyncResult> syncNow() async {
    final mode = await _storage.getActiveSyncMode();
    if (mode == SyncMode.teslamate) {
      return _syncFromTeslaMate();
    } else {
      return _syncFromTeslaDirect();
    }
  }

  /// 모드 A: TeslaMate API 연동
  Future<SyncResult> _syncFromTeslaMate() async {
    final baseUrl = await _storage.getTeslaMateBaseUrl();
    final token = await _storage.getTeslaMateToken();
    final carId = await _storage.getTeslaMateCarId();
    final lastSync = await _storage.getLastSyncTime();
    final presets = await _storage.getChargePresets();

    // API 토큰이 아직 입력되지 않은 경우 오프라인 데모 트립 1건을 시뮬레이션 동기화
    if (token.isEmpty) {
      return _simulateDemoSync(SyncMode.teslamate);
    }

    try {
      final client = TeslaMateApiClient(
        baseUrl: baseUrl,
        bearerToken: token,
        carId: carId,
      );

      final drives = await client.fetchDrives(since: lastSync);
      final charges = await client.fetchCharges(
        since: lastSync,
        presets: presets,
      );

      final driveCount = await _driveRepository.upsertDrivesBatch(drives);
      final chargeCount = await _chargeRepository.upsertChargesBatch(charges);

      // 새로운 충전 기록이 있으면 차계부 충전비 내역에도 자동 반영
      for (final c in charges) {
        await _expenseRepository.insertExpense(
          ExpenseLog(
            date: c.date,
            category: '충전비',
            amountKrw: c.totalCostKrw,
            memo:
                '[TeslaMate] ${c.locationType} (${c.addedEnergyKwh}kWh, ${c.startSoc}%→${c.endSoc}%)',
          ),
        );
      }

      // 차량 최신 스냅샷 갱신 (TeslaMate 실시간 /status 및 :4000 웹 상태 우선 반영)
      final liveStatus = await client.fetchCarStatus();
      final prevSnapshot = await _storage.getVehicleSnapshot();
      final now = DateTime.now();

      final VehicleSnapshot finalSnapshot;
      if (liveStatus != null) {
        finalSnapshot = liveStatus.copyWith(timestamp: now);
      } else {
        final addedKm = drives.fold<double>(0.0, (s, e) => s + e.distanceKm);
        final latestSoc = charges.isNotEmpty
            ? charges.first.endSoc
            : (drives.isNotEmpty ? drives.first.endSoc : prevSnapshot.soc);

        finalSnapshot = prevSnapshot.copyWith(
          timestamp: now,
          soc: latestSoc,
          odometerKm: double.parse(
            (prevSnapshot.odometerKm + addedKm).toStringAsFixed(1),
          ),
          estimatedRangeKm:
              double.parse((latestSoc * 4.27).toStringAsFixed(1)),
          vehicleState: 'online',
        );
      }
      await _storage.saveVehicleSnapshot(finalSnapshot);
      await _storage.setLastSyncTime(now);

      return SyncResult(
        mode: SyncMode.teslamate,
        syncedDrives: driveCount,
        syncedCharges: chargeCount,
        timestamp: now,
        message:
            'TeslaMate 동기화 완료 (배터리 ${finalSnapshot.soc}%, 누적 ${finalSnapshot.odometerKm}km · 주행 ${driveCount}건, 충전 ${chargeCount}건)',
      );
    } catch (e) {
      // 실제 서버에 닿을 수 없는 로컬 테스트 환경일 경우 시뮬레이션 결과 제공
      return _simulateDemoSync(
        SyncMode.teslamate,
        fallbackReason: '서버 연결 실패($e)로 데모 동기화 실행',
      );
    }
  }

  /// 모드 B: Tesla 공식 Fleet API 직접 호출 연동
  Future<SyncResult> _syncFromTeslaDirect() async {
    final baseUrl = await _storage.getTeslaFleetBaseUrl();
    final token = await _storage.getTeslaDirectToken();
    final vehicleId = await _storage.getTeslaVehicleId();
    final preventWakeUp = await _storage.getPreventWakeUp();
    final batteryCapacity = await _storage.getBatteryCapacityKwh();
    final prevSnapshot = await _storage.getVehicleSnapshot();
    final presets = await _storage.getChargePresets();

    if (token.isEmpty) {
      return _simulateDemoSync(SyncMode.directFleet);
    }

    try {
      final client = TeslaDirectApiClient(
        baseUrl: baseUrl,
        accessToken: token,
        vehicleId: vehicleId,
      );

      final evaluation = await client.fetchAndEvaluate(
        previousSnapshot: prevSnapshot,
        preventWakeUp: preventWakeUp,
        batteryCapacityKwh: batteryCapacity,
        defaultChargeUnitPriceKrw: presets.first.unitPriceKrw,
      );

      final now = DateTime.now();
      await _storage.saveVehicleSnapshot(evaluation.currentSnapshot);
      await _storage.setLastSyncTime(now);

      if (evaluation.skippedBecauseAsleep) {
        return SyncResult(
          mode: SyncMode.directFleet,
          syncedDrives: 0,
          syncedCharges: 0,
          skippedBecauseAsleep: true,
          timestamp: now,
          message:
              '차량이 현재 절전(asleep) 상태입니다. Vampire Drain 방지를 위해 깨우지 않고 대기합니다.',
        );
      }

      int driveCount = 0;
      int chargeCount = 0;
      int drainCount = 0;

      if (evaluation.generatedDriveLog != null) {
        await _driveRepository.upsertDrive(evaluation.generatedDriveLog!);
        driveCount = 1;
      }
      if (evaluation.generatedChargeLog != null) {
        await _chargeRepository.upsertCharge(evaluation.generatedChargeLog!);
        chargeCount = 1;
      }
      if (evaluation.generatedVampireDrainLog != null) {
        await _driveRepository
            .insertVampireDrain(evaluation.generatedVampireDrainLog!);
        drainCount = 1;
      }

      return SyncResult(
        mode: SyncMode.directFleet,
        syncedDrives: driveCount,
        syncedCharges: chargeCount,
        syncedVampireDrains: drainCount,
        timestamp: now,
        message:
            'Fleet API 스냅샷 동기화 완료 (주행 $driveCount건, 충전 $chargeCount건, 대기전력 $drainCount건)',
      );
    } catch (_) {
      return _simulateDemoSync(
        SyncMode.directFleet,
        fallbackReason: 'Fleet API 데모 스냅샷 동기화 실행',
      );
    }
  }

  /// API 토큰 미설정 또는 오프라인 테스트 시 현실적인 최신 주행 1건을 생성/갱신하는 시뮬레이터
  Future<SyncResult> _simulateDemoSync(
    SyncMode mode, {
    String? fallbackReason,
  }) async {
    final now = DateTime.now();
    final prevSnapshot = await _storage.getVehicleSnapshot();

    const simulatedDistanceKm = 14.6;
    const simulatedUsedKwh = 2.15;
    final newSoc = (prevSnapshot.soc - 3).clamp(15, 100);
    final newOdo = double.parse(
      (prevSnapshot.odometerKm + simulatedDistanceKm).toStringAsFixed(1),
    );

    final demoDrive = DriveLog(
      startTime: now.subtract(const Duration(minutes: 28)),
      endTime: now,
      distanceKm: simulatedDistanceKm,
      usedEnergyKwh: simulatedUsedKwh,
      efficiencyKmKwh: UnitConverter.calculateEfficiencyKmPerKwh(
        distanceKm: simulatedDistanceKm,
        usedEnergyKwh: simulatedUsedKwh,
      ),
      outsideTempAvg: prevSnapshot.outsideTemp,
      startSoc: prevSnapshot.soc,
      endSoc: newSoc,
      source: mode.code,
    );

    await _driveRepository.upsertDrive(demoDrive);

    final updatedSnapshot = VehicleSnapshot(
      timestamp: now,
      soc: newSoc,
      estimatedRangeKm: double.parse((newSoc * 4.88).toStringAsFixed(1)),
      odometerKm: newOdo,
      outsideTemp: prevSnapshot.outsideTemp,
      vehicleState: 'online',
    );

    await _storage.saveVehicleSnapshot(updatedSnapshot);
    await _storage.setLastSyncTime(now);

    final prefix = fallbackReason ?? '[오프라인 데모 모드]';
    return SyncResult(
      mode: mode,
      syncedDrives: 1,
      syncedCharges: 0,
      usedOfflineSimulation: true,
      timestamp: now,
      message:
          '$prefix ${mode.label} 기준 최근 주행 1건(${simulatedDistanceKm}km, 전비 ${demoDrive.efficiencyKmKwh}km/kWh)이 동기화되었습니다.',
    );
  }
}
