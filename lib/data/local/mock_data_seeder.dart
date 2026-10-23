import 'package:sqflite/sqflite.dart';
import '../../core/utils/unit_converter.dart';
import '../models/charge_log.dart';
import '../models/drive_log.dart';
import '../models/expense_log.dart';
import '../models/maintenance_item.dart';
import '../models/vehicle_snapshot.dart';
import 'database_helper.dart';

/// 실제 API 연결 전에도 모든 차트/통계/타임라인이 즉시 동작하도록 지원하는
/// 현실적인 테슬라 주행/충전/지출/소모품 더미 데이터(Mock Data) 생성기
class MockDataSeeder {
  MockDataSeeder._();

  static Future<void> seedInitialData(DatabaseExecutor db) async {
    final now = DateTime.now();

    // 1. 최근 7일 일별 주행 데이터 + 온도 구간별(영하, 0~15도, 15~25도, 25도 이상) 전비 비교용 데이터
    final List<DriveLog> mockDrives = [
      // 최근 7일 주행 트립 (라인 차트 및 이번 달 요약에 즉시 반영)
      _buildDrive(
        start: now.subtract(const Duration(hours: 3)),
        durationMinutes: 42,
        distanceKm: 34.8,
        usedKwh: 5.1, // 약 6.82 km/kWh
        tempC: 18.5,
        startSoc: 85,
        endSoc: 78,
        source: 'teslamate',
      ),
      _buildDrive(
        start: now.subtract(const Duration(days: 1, hours: 4)),
        durationMinutes: 55,
        distanceKm: 48.2,
        usedKwh: 7.4, // 약 6.51 km/kWh
        tempC: 16.0,
        startSoc: 74,
        endSoc: 64,
        source: 'teslamate',
      ),
      _buildDrive(
        start: now.subtract(const Duration(days: 2, hours: 2)),
        durationMinutes: 35,
        distanceKm: 26.5,
        usedKwh: 4.3, // 약 6.16 km/kWh
        tempC: 12.5,
        startSoc: 80,
        endSoc: 74,
        source: 'teslamate',
      ),
      _buildDrive(
        start: now.subtract(const Duration(days: 3, hours: 5)),
        durationMinutes: 95,
        distanceKm: 88.4,
        usedKwh: 12.6, // 약 7.02 km/kWh (고속/간선 정속 주행)
        tempC: 20.0,
        startSoc: 90,
        endSoc: 73,
        source: 'teslamate',
      ),
      _buildDrive(
        start: now.subtract(const Duration(days: 4, hours: 3)),
        durationMinutes: 28,
        distanceKm: 19.2,
        usedKwh: 3.1, // 약 6.19 km/kWh
        tempC: 14.0,
        startSoc: 68,
        endSoc: 64,
        source: 'direct_api',
      ),
      _buildDrive(
        start: now.subtract(const Duration(days: 5, hours: 6)),
        durationMinutes: 64,
        distanceKm: 54.0,
        usedKwh: 8.0, // 6.75 km/kWh
        tempC: 21.5,
        startSoc: 79,
        endSoc: 68,
        source: 'teslamate',
      ),
      _buildDrive(
        start: now.subtract(const Duration(days: 6, hours: 2)),
        durationMinutes: 48,
        distanceKm: 41.5,
        usedKwh: 6.5, // 6.38 km/kWh
        tempC: 15.5,
        startSoc: 88,
        endSoc: 79,
        source: 'teslamate',
      ),

      // 외기온도 구간별 비교 차트를 풍부하게 만드는 계절/기온별 주행 기록
      // [25도 이상 구간 - 에어컨 가동]
      _buildDrive(
        start: now.subtract(const Duration(days: 10, hours: 5)),
        durationMinutes: 70,
        distanceKm: 62.0,
        usedKwh: 10.5, // 5.90 km/kWh
        tempC: 28.5,
        startSoc: 85,
        endSoc: 71,
        source: 'teslamate',
      ),
      _buildDrive(
        start: now.subtract(const Duration(days: 14, hours: 4)),
        durationMinutes: 50,
        distanceKm: 39.5,
        usedKwh: 6.9, // 5.72 km/kWh
        tempC: 31.0,
        startSoc: 75,
        endSoc: 66,
        source: 'teslamate',
      ),
      // [0~15도 구간 - 쌀쌀한 날씨]
      _buildDrive(
        start: now.subtract(const Duration(days: 18, hours: 1)),
        durationMinutes: 60,
        distanceKm: 45.0,
        usedKwh: 8.1, // 5.56 km/kWh
        tempC: 6.5,
        startSoc: 82,
        endSoc: 71,
        source: 'teslamate',
      ),
      // [영하 구간 - 히터 및 배터리 워밍 가동]
      _buildDrive(
        start: now.subtract(const Duration(days: 24, hours: 3)),
        durationMinutes: 45,
        distanceKm: 31.0,
        usedKwh: 6.8, // 4.56 km/kWh
        tempC: -4.5,
        startSoc: 80,
        endSoc: 70,
        source: 'teslamate',
      ),
      _buildDrive(
        start: now.subtract(const Duration(days: 27, hours: 6)),
        durationMinutes: 80,
        distanceKm: 58.0,
        usedKwh: 13.2, // 4.39 km/kWh
        tempC: -7.0,
        startSoc: 90,
        endSoc: 72,
        source: 'manual',
      ),
    ];

    for (final drive in mockDrives) {
      await db.insert(
        DatabaseHelper.tableDriveLogs,
        drive.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 2. 충전 기록 (charge_logs) 및 연동 차계부 충전비 지출 내역
    final List<ChargeLog> mockCharges = [
      ChargeLog(
        date: now.subtract(const Duration(days: 1, hours: 1)),
        locationType: '집밥(완속)',
        addedEnergyKwh: 32.5,
        unitPriceKrw: 250,
        totalCostKrw: (32.5 * 250).round(),
        startSoc: 42,
        endSoc: 85,
      ),
      ChargeLog(
        date: now.subtract(const Duration(days: 3, hours: 2)),
        locationType: '수퍼차저',
        addedEnergyKwh: 41.0,
        unitPriceKrw: 420,
        totalCostKrw: (41.0 * 420).round(),
        startSoc: 20,
        endSoc: 75,
      ),
      ChargeLog(
        date: now.subtract(const Duration(days: 6, hours: 5)),
        locationType: '집밥(완속)',
        addedEnergyKwh: 38.0,
        unitPriceKrw: 250,
        totalCostKrw: (38.0 * 250).round(),
        startSoc: 38,
        endSoc: 88,
      ),
      ChargeLog(
        date: now.subtract(const Duration(days: 11, hours: 3)),
        locationType: '공용급속',
        addedEnergyKwh: 28.4,
        unitPriceKrw: 347,
        totalCostKrw: (28.4 * 347).round(),
        startSoc: 32,
        endSoc: 70,
      ),
      ChargeLog(
        date: now.subtract(const Duration(days: 19, hours: 4)),
        locationType: '집밥(완속)',
        addedEnergyKwh: 44.0,
        unitPriceKrw: 250,
        totalCostKrw: (44.0 * 250).round(),
        startSoc: 22,
        endSoc: 80,
      ),
    ];

    for (final charge in mockCharges) {
      await db.insert(
        DatabaseHelper.tableChargeLogs,
        charge.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 3. 일반 차계부 지출 내역 (expense_logs)
    final List<ExpenseLog> mockExpenses = [
      ExpenseLog(
        date: now.subtract(const Duration(days: 1, hours: 1)),
        category: '충전비',
        amountKrw: (32.5 * 250).round(),
        memo: '아파트 지하주차장 완속 충전 (32.5kWh)',
      ),
      ExpenseLog(
        date: now.subtract(const Duration(days: 2, hours: 5)),
        category: '하이패스/주차',
        amountKrw: 6800,
        memo: '수도권제1순환고속도로 통행료 및 공영주차장',
      ),
      ExpenseLog(
        date: now.subtract(const Duration(days: 3, hours: 2)),
        category: '충전비',
        amountKrw: (41.0 * 420).round(),
        memo: '판교 수퍼차저 V3 급속 충전 (41.0kWh)',
      ),
      ExpenseLog(
        date: now.subtract(const Duration(days: 7, hours: 4)),
        category: '세차/정비',
        amountKrw: 25000,
        memo: '노터치 자동세차 및 실내 클리닝',
      ),
      ExpenseLog(
        date: now.subtract(const Duration(days: 12, hours: 6)),
        category: '용품/튜닝',
        amountKrw: 42000,
        memo: '센터콘솔 수납 트레이 & 실리콘 컵홀더',
      ),
      ExpenseLog(
        date: now.subtract(const Duration(days: 15, hours: 2)),
        category: '보험료',
        amountKrw: 89000,
        memo: '다이렉트 자동차보험 월 분납금 (자차 포함)',
      ),
    ];

    for (final expense in mockExpenses) {
      await db.insert(
        DatabaseHelper.tableExpenseLogs,
        expense.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 4. 소모품 관리 항목 (maintenance_items) - 현재 누적주행거리 28,450km 기준
    final List<MaintenanceItem> mockMaintenance = [
      MaintenanceItem(
        itemName: '캐빈 에어컨 필터 (헤파/활성탄)',
        lastReplacedOdoKm: 15200.0,
        lastReplacedDate: now.subtract(const Duration(days: 165)),
        replaceCycleKm: 15000.0,
        replaceCycleMonths: 6,
      ),
      MaintenanceItem(
        itemName: '타이어 위치교환 (전/후륜)',
        lastReplacedOdoKm: 19800.0,
        lastReplacedDate: now.subtract(const Duration(days: 110)),
        replaceCycleKm: 10000.0,
        replaceCycleMonths: 6,
      ),
      MaintenanceItem(
        itemName: '와이퍼 블레이드 세트',
        lastReplacedOdoKm: 18000.0,
        lastReplacedDate: now.subtract(const Duration(days: 140)),
        replaceCycleKm: 15000.0,
        replaceCycleMonths: 12,
      ),
      MaintenanceItem(
        itemName: '브레이크 오일 점검/교체',
        lastReplacedOdoKm: 0.0,
        lastReplacedDate: now.subtract(const Duration(days: 420)),
        replaceCycleKm: 40000.0,
        replaceCycleMonths: 24,
      ),
    ];

    for (final item in mockMaintenance) {
      await db.insert(
        DatabaseHelper.tableMaintenanceItems,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 5. 주차 중 대기 소모 전력 (Vampire Drain) 기록
    final List<VampireDrainLog> mockDrains = [
      VampireDrainLog(
        startTime: now.subtract(const Duration(days: 1, hours: 18)),
        endTime: now.subtract(const Duration(days: 1, hours: 6)),
        startSoc: 76,
        endSoc: 74,
        lostEnergyKwh: 1.45,
        lostRangeKm: 9.5,
        sentryModeActive: true,
      ),
      VampireDrainLog(
        startTime: now.subtract(const Duration(days: 3, hours: 20)),
        endTime: now.subtract(const Duration(days: 3, hours: 8)),
        startSoc: 80,
        endSoc: 79,
        lostEnergyKwh: 0.35,
        lostRangeKm: 2.3,
        sentryModeActive: false,
      ),
      VampireDrainLog(
        startTime: now.subtract(const Duration(days: 5, hours: 22)),
        endTime: now.subtract(const Duration(days: 5, hours: 8)),
        startSoc: 71,
        endSoc: 68,
        lostEnergyKwh: 2.10,
        lostRangeKm: 13.8,
        sentryModeActive: true,
      ),
    ];

    for (final drain in mockDrains) {
      await db.insert(
        DatabaseHelper.tableVampireDrainLogs,
        drain.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static DriveLog _buildDrive({
    required DateTime start,
    required int durationMinutes,
    required double distanceKm,
    required double usedKwh,
    required double tempC,
    required int startSoc,
    required int endSoc,
    required String source,
  }) {
    return DriveLog(
      startTime: start,
      endTime: start.add(Duration(minutes: durationMinutes)),
      distanceKm: distanceKm,
      usedEnergyKwh: usedKwh,
      efficiencyKmKwh: UnitConverter.calculateEfficiencyKmPerKwh(
        distanceKm: distanceKm,
        usedEnergyKwh: usedKwh,
      ),
      outsideTempAvg: tempC,
      startSoc: startSoc,
      endSoc: endSoc,
      source: source,
    );
  }
}
