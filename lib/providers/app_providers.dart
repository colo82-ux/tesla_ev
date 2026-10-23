import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/utils/unit_converter.dart';
import '../data/local/database_helper.dart';
import '../data/models/charge_log.dart';
import '../data/models/charge_preset.dart';
import '../data/models/drive_log.dart';
import '../data/models/expense_log.dart';
import '../data/models/maintenance_item.dart';
import '../data/models/vehicle_snapshot.dart';
import '../data/remote/sync_service.dart';
import '../data/repositories/charge_repository.dart';
import '../data/repositories/drive_repository.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/maintenance_repository.dart';

/// 최근 7일 일별 전비 추이 데이터 포인트
class DailyEfficiencyPoint {
  final DateTime date;
  final double distanceKm;
  final double usedEnergyKwh;
  final double avgEfficiencyKmKwh;

  const DailyEfficiencyPoint({
    required this.date,
    required this.distanceKm,
    required this.usedEnergyKwh,
    required this.avgEfficiencyKmKwh,
  });
}

/// 월별 지출 추이 데이터 포인트 (충전비 + 일반 유지비 스택 차트용)
class MonthlyExpensePoint {
  final int year;
  final int month;
  final int chargeCostKrw;
  final int otherExpenseKrw;

  const MonthlyExpensePoint({
    required this.year,
    required this.month,
    required this.chargeCostKrw,
    required this.otherExpenseKrw,
  });

  int get totalKrw => chargeCostKrw + otherExpenseKrw;
}

/// 앱 전역 상태 모델
class TeslaAppState {
  final bool isLoading;
  final bool isSyncing;
  final String? lastSyncMessage;
  final VehicleSnapshot snapshot;
  final DateTime? lastSyncTime;
  final SyncMode activeSyncMode;
  final List<DriveLog> drives;
  final List<ChargeLog> charges;
  final List<ExpenseLog> expenses;
  final List<MaintenanceItem> maintenanceItems;
  final List<VampireDrainLog> vampireDrains;
  final List<ChargePreset> chargePresets;

  const TeslaAppState({
    this.isLoading = false,
    this.isSyncing = false,
    this.lastSyncMessage,
    required this.snapshot,
    this.lastSyncTime,
    this.activeSyncMode = SyncMode.teslamate,
    this.drives = const [],
    this.charges = const [],
    this.expenses = const [],
    this.maintenanceItems = const [],
    this.vampireDrains = const [],
    this.chargePresets = ChargePreset.defaultPresets,
  });

  TeslaAppState copyWith({
    bool? isLoading,
    bool? isSyncing,
    String? lastSyncMessage,
    VehicleSnapshot? snapshot,
    DateTime? lastSyncTime,
    SyncMode? activeSyncMode,
    List<DriveLog>? drives,
    List<ChargeLog>? charges,
    List<ExpenseLog>? expenses,
    List<MaintenanceItem>? maintenanceItems,
    List<VampireDrainLog>? vampireDrains,
    List<ChargePreset>? chargePresets,
  }) {
    return TeslaAppState(
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncMessage: lastSyncMessage ?? this.lastSyncMessage,
      snapshot: snapshot ?? this.snapshot,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      activeSyncMode: activeSyncMode ?? this.activeSyncMode,
      drives: drives ?? this.drives,
      charges: charges ?? this.charges,
      expenses: expenses ?? this.expenses,
      maintenanceItems: maintenanceItems ?? this.maintenanceItems,
      vampireDrains: vampireDrains ?? this.vampireDrains,
      chargePresets: chargePresets ?? this.chargePresets,
    );
  }

  // --- 대시보드(Home) 이번 달 요약 지표 계산 ---

  List<DriveLog> get currentMonthDrives {
    final now = DateTime.now();
    return drives
        .where(
          (d) =>
              d.startTime.year == now.year && d.startTime.month == now.month,
        )
        .toList();
  }

  List<ChargeLog> get currentMonthCharges {
    final now = DateTime.now();
    return charges
        .where((c) => c.date.year == now.year && c.date.month == now.month)
        .toList();
  }

  /// 이번 달 총 주행거리 (km) - 만약 월초여서 당월 데이터가 없으면 최근 30일 기준 표시
  double get monthlyTotalDistanceKm {
    final targetDrives =
        currentMonthDrives.isNotEmpty ? currentMonthDrives : drives;
    return targetDrives.fold<double>(0.0, (sum, d) => sum + d.distanceKm);
  }

  /// 이번 달 총 소모 전력 (kWh)
  double get monthlyTotalUsedKwh {
    final targetDrives =
        currentMonthDrives.isNotEmpty ? currentMonthDrives : drives;
    return targetDrives.fold<double>(0.0, (sum, d) => sum + d.usedEnergyKwh);
  }

  /// 이번 달 평균 전비 (km/kWh)
  double get monthlyAvgEfficiencyKmKwh {
    return UnitConverter.calculateEfficiencyKmPerKwh(
      distanceKm: monthlyTotalDistanceKm,
      usedEnergyKwh: monthlyTotalUsedKwh,
    );
  }

  /// 이번 달 총 충전 비용 (원)
  int get monthlyTotalChargeCostKrw {
    final targetCharges =
        currentMonthCharges.isNotEmpty ? currentMonthCharges : charges;
    return targetCharges.fold<int>(0, (sum, c) => sum + c.totalCostKrw);
  }

  /// 1km당 주행 원가 (원/km)
  double get monthlyCostPerKmKrw {
    return UnitConverter.calculateCostPerKm(
      totalChargeCostKrw: monthlyTotalChargeCostKrw,
      totalDistanceKm: monthlyTotalDistanceKm,
    );
  }

  /// 최근 7일간 일별 전비 추이 데이터 생성 (`fl_chart` 꺾은선 차트용)
  List<DailyEfficiencyPoint> get last7DaysEfficiency {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<DailyEfficiencyPoint> result = [];

    for (int i = 6; i >= 0; i--) {
      final dayStart = today.subtract(Duration(days: i));
      final dayEnd = dayStart.add(const Duration(days: 1));

      final dayDrives = drives.where(
        (d) => !d.startTime.isBefore(dayStart) && d.startTime.isBefore(dayEnd),
      );

      final dist = dayDrives.fold<double>(0.0, (s, d) => s + d.distanceKm);
      final kwh = dayDrives.fold<double>(0.0, (s, d) => s + d.usedEnergyKwh);
      final eff = UnitConverter.calculateEfficiencyKmPerKwh(
        distanceKm: dist,
        usedEnergyKwh: kwh,
      );

      result.add(
        DailyEfficiencyPoint(
          date: dayStart,
          distanceKm: dist,
          usedEnergyKwh: kwh,
          avgEfficiencyKmKwh: eff,
        ),
      );
    }
    return result;
  }

  /// 외기온도 구간별(영하, 0~15도, 15~25도, 25도 이상) 평균 전비 통계 (`fl_chart` 막대 차트용)
  Map<TempBracket, double> get efficiencyByTempBracket {
    final Map<TempBracket, double> distSum = {
      for (final b in TempBracket.values) b: 0.0,
    };
    final Map<TempBracket, double> kwhSum = {
      for (final b in TempBracket.values) b: 0.0,
    };

    for (final d in drives) {
      final bracket = UnitConverter.classifyTemperature(d.outsideTempAvg);
      distSum[bracket] = (distSum[bracket] ?? 0.0) + d.distanceKm;
      kwhSum[bracket] = (kwhSum[bracket] ?? 0.0) + d.usedEnergyKwh;
    }

    return {
      for (final b in TempBracket.values)
        b: UnitConverter.calculateEfficiencyKmPerKwh(
          distanceKm: distSum[b] ?? 0.0,
          usedEnergyKwh: kwhSum[b] ?? 0.0,
        ),
    };
  }

  /// 전체 트립 평균 전비 (km/kWh)
  double get overallAvgEfficiencyKmKwh {
    final totalDist = drives.fold<double>(0.0, (s, d) => s + d.distanceKm);
    final totalKwh = drives.fold<double>(0.0, (s, d) => s + d.usedEnergyKwh);
    return UnitConverter.calculateEfficiencyKmPerKwh(
      distanceKm: totalDist,
      usedEnergyKwh: totalKwh,
    );
  }

  /// 최근 N개월(기본 6개월 또는 12개월) 월별 지출 추이 집계
  List<MonthlyExpensePoint> getMonthlyExpenses({int months = 12}) {
    final now = DateTime.now();
    final List<MonthlyExpensePoint> result = [];

    for (int i = months - 1; i >= 0; i--) {
      final target = DateTime(now.year, now.month - i, 1);
      final y = target.year;
      final m = target.month;

      final monthExpenses = expenses.where(
        (e) => e.date.year == y && e.date.month == m,
      );
      final expenseChargeSum = monthExpenses
          .where((e) => e.category == '충전비')
          .fold<int>(0, (s, e) => s + e.amountKrw);
      final otherExpenseSum = monthExpenses
          .where((e) => e.category != '충전비')
          .fold<int>(0, (s, e) => s + e.amountKrw);

      final directChargeSum = charges
          .where((c) => c.date.year == y && c.date.month == m)
          .fold<int>(0, (s, c) => s + c.totalCostKrw);

      final finalChargeCost =
          expenseChargeSum > 0 ? expenseChargeSum : directChargeSum;

      result.add(
        MonthlyExpensePoint(
          year: y,
          month: m,
          chargeCostKrw: finalChargeCost,
          otherExpenseKrw: otherExpenseSum,
        ),
      );
    }

    return result;
  }
}

// --- Riverpod Providers ---

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return const SecureStorageService();
});

final driveRepositoryProvider = Provider<DriveRepository>((ref) {
  return DriveRepository();
});

final chargeRepositoryProvider = Provider<ChargeRepository>((ref) {
  return ChargeRepository();
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  return MaintenanceRepository();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    storage: ref.watch(secureStorageProvider),
    driveRepository: ref.watch(driveRepositoryProvider),
    chargeRepository: ref.watch(chargeRepositoryProvider),
    expenseRepository: ref.watch(expenseRepositoryProvider),
  );
});

final teslaAppProvider =
    StateNotifierProvider<TeslaAppNotifier, TeslaAppState>((ref) {
  return TeslaAppNotifier(
    storage: ref.watch(secureStorageProvider),
    driveRepository: ref.watch(driveRepositoryProvider),
    chargeRepository: ref.watch(chargeRepositoryProvider),
    expenseRepository: ref.watch(expenseRepositoryProvider),
    maintenanceRepository: ref.watch(maintenanceRepositoryProvider),
    syncService: ref.watch(syncServiceProvider),
  )..loadAll();
});

class TeslaAppNotifier extends StateNotifier<TeslaAppState> {
  final SecureStorageService _storage;
  final DriveRepository _driveRepository;
  final ChargeRepository _chargeRepository;
  final ExpenseRepository _expenseRepository;
  final MaintenanceRepository _maintenanceRepository;
  final SyncService _syncService;

  TeslaAppNotifier({
    required SecureStorageService storage,
    required DriveRepository driveRepository,
    required ChargeRepository chargeRepository,
    required ExpenseRepository expenseRepository,
    required MaintenanceRepository maintenanceRepository,
    required SyncService syncService,
  })  : _storage = storage,
        _driveRepository = driveRepository,
        _chargeRepository = chargeRepository,
        _expenseRepository = expenseRepository,
        _maintenanceRepository = maintenanceRepository,
        _syncService = syncService,
        super(
          TeslaAppState(
            isLoading: true,
            snapshot: VehicleSnapshot(
              timestamp: DateTime.now(),
              soc: 78,
              estimatedRangeKm: 382.0,
              odometerKm: 28450.5,
              outsideTemp: 17.5,
              vehicleState: 'online',
            ),
          ),
        );

  /// 로컬 SQLite 및 SecureStorage에서 전체 데이터 로드
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    final snapshot = await _storage.getVehicleSnapshot();
    final lastSync = await _storage.getLastSyncTime();
    final mode = await _storage.getActiveSyncMode();
    final presets = await _storage.getChargePresets();

    final drives = await _driveRepository.getAllDrives();
    final charges = await _chargeRepository.getAllCharges();
    final expenses = await _expenseRepository.getAllExpenses();
    final maintenance = await _maintenanceRepository.getAllItems();
    final drains = await _driveRepository.getAllVampireDrains();

    state = state.copyWith(
      isLoading: false,
      snapshot: snapshot,
      lastSyncTime: lastSync ?? snapshot.timestamp,
      activeSyncMode: mode,
      drives: drives,
      charges: charges,
      expenses: expenses,
      maintenanceItems: maintenance,
      vampireDrains: drains,
      chargePresets: presets,
    );
  }

  /// [지금 동기화] 실행
  Future<SyncResult> syncNow() async {
    state = state.copyWith(isSyncing: true, lastSyncMessage: null);
    final result = await _syncService.syncNow();
    await loadAll();
    state = state.copyWith(
      isSyncing: false,
      lastSyncMessage: result.message,
    );
    return result;
  }

  /// 동기화 모드 전환 (TeslaMate <-> Tesla Direct Fleet API)
  Future<void> setSyncMode(SyncMode mode) async {
    await _storage.setActiveSyncMode(mode);
    state = state.copyWith(activeSyncMode: mode);
  }

  /// 수기 주행 기록 추가
  Future<void> addDriveLog(DriveLog log) async {
    await _driveRepository.upsertDrive(log);
    await loadAll();
  }

  Future<void> deleteDriveLog(int id) async {
    await _driveRepository.deleteDrive(id);
    await loadAll();
  }

  /// 수기 충전 기록 추가 (차계부 지출 내역에도 자동 연동 옵션 지원)
  Future<void> addChargeLog(
    ChargeLog log, {
    bool registerAsExpense = true,
  }) async {
    await _chargeRepository.upsertCharge(log);
    if (registerAsExpense) {
      await _expenseRepository.insertExpense(
        ExpenseLog(
          date: log.date,
          category: '충전비',
          amountKrw: log.totalCostKrw,
          memo:
              '${log.locationType} (${log.addedEnergyKwh}kWh @ ${log.unitPriceKrw}원/kWh, ${log.startSoc}%→${log.endSoc}%)',
        ),
      );
    }
    await loadAll();
  }

  Future<void> deleteChargeLog(int id) async {
    await _chargeRepository.deleteCharge(id);
    await loadAll();
  }

  /// 수기 지출 내역 추가
  Future<void> addExpenseLog(ExpenseLog log) async {
    await _expenseRepository.insertExpense(log);
    await loadAll();
  }

  Future<void> deleteExpenseLog(int id) async {
    await _expenseRepository.deleteExpense(id);
    await loadAll();
  }

  /// 소모품 항목 추가 또는 업데이트
  Future<void> saveMaintenanceItem(MaintenanceItem item) async {
    await _maintenanceRepository.updateItem(item);
    await loadAll();
  }

  /// 소모품 교체 완료 처리 (현재 누적 주행거리와 오늘 날짜로 갱신)
  Future<void> markMaintenanceReplacedNow(MaintenanceItem item) async {
    final updated = item.copyWith(
      lastReplacedOdoKm: state.snapshot.odometerKm,
      lastReplacedDate: DateTime.now(),
    );
    await _maintenanceRepository.updateItem(updated);
    await loadAll();
  }

  Future<void> deleteMaintenanceItem(int id) async {
    await _maintenanceRepository.deleteItem(id);
    await loadAll();
  }

  /// 충전 단가 프리셋 업데이트
  Future<void> updateChargePresets(List<ChargePreset> presets) async {
    await _storage.saveChargePresets(presets);
    state = state.copyWith(chargePresets: presets);
  }

  /// 차량 현재 누적 주행거리(Odometer) 및 SoC 수동 보정
  Future<void> updateVehicleSnapshot(VehicleSnapshot newSnapshot) async {
    await _storage.saveVehicleSnapshot(newSnapshot);
    state = state.copyWith(snapshot: newSnapshot);
  }

  /// 더미 데이터로 DB 초기화
  Future<void> resetWithMockData() async {
    state = state.copyWith(isLoading: true);
    await DatabaseHelper.instance.resetWithMockData();
    await loadAll();
  }

  /// JSON 백업으로부터 DB 복원
  Future<void> restoreFromJson(String jsonContent) async {
    state = state.copyWith(isLoading: true);
    await DatabaseHelper.instance.restoreFromJsonString(jsonContent);
    await loadAll();
  }
}
