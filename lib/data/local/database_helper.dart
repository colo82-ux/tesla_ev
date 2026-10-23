import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'mock_data_seeder.dart';

/// 앱 내장형 로컬 SQLite 데이터베이스 초기화 및 백업/복원 매니저
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  static const String dbName = 'tesla_ev_offline.db';
  static const int dbVersion = 2;

  // 테이블 명 상수
  static const String tableDriveLogs = 'drive_logs';
  static const String tableChargeLogs = 'charge_logs';
  static const String tableExpenseLogs = 'expense_logs';
  static const String tableMaintenanceItems = 'maintenance_items';
  static const String tableVampireDrainLogs = 'vampire_drain_logs';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, dbName);

    return openDatabase(
      path,
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. drive_logs (주행 기록)
    await db.execute('''
      CREATE TABLE $tableDriveLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        distance_km REAL NOT NULL,
        used_energy_kwh REAL NOT NULL,
        efficiency_km_kwh REAL NOT NULL,
        outside_temp_avg REAL NOT NULL,
        start_soc INTEGER NOT NULL,
        end_soc INTEGER NOT NULL,
        source TEXT NOT NULL CHECK(source IN ('teslamate', 'direct_api', 'manual')),
        UNIQUE(start_time, source)
      )
    ''');

    // 2. charge_logs (충전 기록 - '회사(완속)' 포함)
    await db.execute('''
      CREATE TABLE $tableChargeLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        location_type TEXT NOT NULL CHECK(location_type IN ('수퍼차저', '집밥(완속)', '회사(완속)', '공용급속', '기타')),
        added_energy_kwh REAL NOT NULL,
        unit_price_krw INTEGER NOT NULL,
        total_cost_krw INTEGER NOT NULL,
        start_soc INTEGER NOT NULL,
        end_soc INTEGER NOT NULL,
        UNIQUE(date, location_type)
      )
    ''');

    // 3. expense_logs (차계부 지출 내역)
    await db.execute('''
      CREATE TABLE $tableExpenseLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        category TEXT NOT NULL CHECK(category IN ('충전비', '보험료', '세차/정비', '하이패스/주차', '용품/튜닝')),
        amount_krw INTEGER NOT NULL,
        memo TEXT NOT NULL
      )
    ''');

    // 4. maintenance_items (소모품 관리)
    await db.execute('''
      CREATE TABLE $tableMaintenanceItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_name TEXT NOT NULL,
        last_replaced_odo_km REAL NOT NULL,
        last_replaced_date TEXT NOT NULL,
        replace_cycle_km REAL NOT NULL,
        replace_cycle_months INTEGER NOT NULL
      )
    ''');

    // 5. vampire_drain_logs (주차 중 대기 소모 전력 통계)
    await db.execute('''
      CREATE TABLE $tableVampireDrainLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        start_soc INTEGER NOT NULL,
        end_soc INTEGER NOT NULL,
        lost_energy_kwh REAL NOT NULL,
        lost_range_km REAL NOT NULL,
        sentry_mode_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 초기 실행 시 현실적인 테슬라 더미 데이터 시딩
    await MockDataSeeder.seedInitialData(db);
  }

  /// DB 스키마 업그레이드 (v1 -> v2: '회사(완속)' 허용 및 월별 차트용 과거 샘플 보강)
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.transaction((txn) async {
        final existingCharges = await txn.query(tableChargeLogs);
        await txn.execute('DROP TABLE IF EXISTS $tableChargeLogs');
        await txn.execute('''
          CREATE TABLE $tableChargeLogs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            location_type TEXT NOT NULL CHECK(location_type IN ('수퍼차저', '집밥(완속)', '회사(완속)', '공용급속', '기타')),
            added_energy_kwh REAL NOT NULL,
            unit_price_krw INTEGER NOT NULL,
            total_cost_krw INTEGER NOT NULL,
            start_soc INTEGER NOT NULL,
            end_soc INTEGER NOT NULL,
            UNIQUE(date, location_type)
          )
        ''');
        for (final row in existingCharges) {
          await txn.insert(
            tableChargeLogs,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      await MockDataSeeder.seedHistoricalMonthlyDataIfNeeded(db);
    }
  }

  /// 더미 데이터 초기화 및 재성성
  Future<void> resetWithMockData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableDriveLogs);
      await txn.delete(tableChargeLogs);
      await txn.delete(tableExpenseLogs);
      await txn.delete(tableMaintenanceItems);
      await txn.delete(tableVampireDrainLogs);
    });
    await MockDataSeeder.seedInitialData(db);
  }

  /// 샘플(더미) 주행/충전/지출 기록을 모두 비우고 실차 연동 데이터만 남기기
  Future<void> clearAllSampleLogs() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableDriveLogs);
      await txn.delete(tableChargeLogs);
      await txn.delete(tableExpenseLogs);
      await txn.delete(tableVampireDrainLogs);
    });
  }

  /// 로컬 SQLite 전체 데이터를 JSON 문자열로 내보내기
  Future<String> exportToJsonString() async {
    final db = await database;
    final drives = await db.query(tableDriveLogs, orderBy: 'start_time DESC');
    final charges = await db.query(tableChargeLogs, orderBy: 'date DESC');
    final expenses = await db.query(tableExpenseLogs, orderBy: 'date DESC');
    final maintenance = await db.query(tableMaintenanceItems, orderBy: 'id ASC');
    final drains =
        await db.query(tableVampireDrainLogs, orderBy: 'start_time DESC');

    final payload = {
      'app': 'tesla_ev',
      'version': dbVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': {
        tableDriveLogs: drives,
        tableChargeLogs: charges,
        tableExpenseLogs: expenses,
        tableMaintenanceItems: maintenance,
        tableVampireDrainLogs: drains,
      },
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// JSON 백업 파일을 생성하고 파일 경로를 반환
  Future<File> exportBackupJsonFile() async {
    final jsonStr = await exportToJsonString();
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File(p.join(dir.path, 'tesla_ev_backup_$timestamp.json'));
    return file.writeAsString(jsonStr);
  }

  /// 주행 및 충전/지출 기록을 CSV 문자열로 내보내기
  Future<File> exportSummaryCsvFile() async {
    final db = await database;
    final drives = await db.query(tableDriveLogs, orderBy: 'start_time DESC');
    final charges = await db.query(tableChargeLogs, orderBy: 'date DESC');
    final expenses = await db.query(tableExpenseLogs, orderBy: 'date DESC');

    final buffer = StringBuffer();
    buffer.writeln('--- DRIVE LOGS ---');
    buffer.writeln(
        'id,start_time,end_time,distance_km,used_energy_kwh,efficiency_km_kwh,outside_temp_avg,start_soc,end_soc,source');
    for (final r in drives) {
      buffer.writeln(
          '${r['id']},${r['start_time']},${r['end_time']},${r['distance_km']},${r['used_energy_kwh']},${r['efficiency_km_kwh']},${r['outside_temp_avg']},${r['start_soc']},${r['end_soc']},${r['source']}');
    }

    buffer.writeln('\n--- CHARGE LOGS ---');
    buffer.writeln(
        'id,date,location_type,added_energy_kwh,unit_price_krw,total_cost_krw,start_soc,end_soc');
    for (final r in charges) {
      buffer.writeln(
          '${r['id']},${r['date']},${r['location_type']},${r['added_energy_kwh']},${r['unit_price_krw']},${r['total_cost_krw']},${r['start_soc']},${r['end_soc']}');
    }

    buffer.writeln('\n--- EXPENSE LOGS ---');
    buffer.writeln('id,date,category,amount_krw,memo');
    for (final r in expenses) {
      final safeMemo = (r['memo']?.toString() ?? '').replaceAll(',', ' ');
      buffer.writeln(
          '${r['id']},${r['date']},${r['category']},${r['amount_krw']},$safeMemo');
    }

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File(p.join(dir.path, 'tesla_ev_export_$timestamp.csv'));
    return file.writeAsString(buffer.toString());
  }

  /// JSON 문자열로부터 로컬 SQLite DB 복원
  Future<void> restoreFromJsonString(String jsonContent) async {
    final decoded = jsonDecode(jsonContent) as Map<String, dynamic>;
    final tables = decoded['tables'] as Map<String, dynamic>?;
    if (tables == null) {
      throw const FormatException('유효하지 않은 백업 파일 형식입니다.');
    }

    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableDriveLogs);
      await txn.delete(tableChargeLogs);
      await txn.delete(tableExpenseLogs);
      await txn.delete(tableMaintenanceItems);
      await txn.delete(tableVampireDrainLogs);

      Future<void> insertRows(String tableName) async {
        final rows = tables[tableName] as List<dynamic>?;
        if (rows == null) return;
        for (final row in rows) {
          await txn.insert(
            tableName,
            Map<String, dynamic>.from(row as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      await insertRows(tableDriveLogs);
      await insertRows(tableChargeLogs);
      await insertRows(tableExpenseLogs);
      await insertRows(tableMaintenanceItems);
      await insertRows(tableVampireDrainLogs);
    });
  }
}
