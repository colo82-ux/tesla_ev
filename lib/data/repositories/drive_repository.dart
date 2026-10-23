import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../models/drive_log.dart';
import '../models/vehicle_snapshot.dart';

/// 주행 기록(`drive_logs`) 및 대기 전력 소모(`vampire_drain_logs`) CRUD Repository
class DriveRepository {
  final DatabaseHelper _dbHelper;

  DriveRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// 전체 주행 기록 조회 (최신순)
  Future<List<DriveLog>> getAllDrives() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tableDriveLogs,
      orderBy: 'start_time DESC',
    );
    return rows.map(DriveLog.fromMap).toList();
  }

  /// 특정 기간 내 주행 기록 조회
  Future<List<DriveLog>> getDrivesInPeriod(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tableDriveLogs,
      where: 'start_time >= ? AND start_time <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'start_time DESC',
    );
    return rows.map(DriveLog.fromMap).toList();
  }

  /// 단건 주행 기록 Upsert (중복 방지: start_time + source 기준)
  Future<int> upsertDrive(DriveLog log) async {
    final db = await _dbHelper.database;
    return db.insert(
      DatabaseHelper.tableDriveLogs,
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 다건 주행 기록 일괄 Upsert (동기화 시 트랜잭션 처리)
  Future<int> upsertDrivesBatch(List<DriveLog> logs) async {
    if (logs.isEmpty) return 0;
    final db = await _dbHelper.database;
    var count = 0;
    await db.transaction((txn) async {
      for (final log in logs) {
        await txn.insert(
          DatabaseHelper.tableDriveLogs,
          log.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        count++;
      }
    });
    return count;
  }

  /// 주행 기록 수정
  Future<int> updateDrive(DriveLog log) async {
    if (log.id == null) return upsertDrive(log);
    final db = await _dbHelper.database;
    return db.update(
      DatabaseHelper.tableDriveLogs,
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  /// 주행 기록 삭제
  Future<int> deleteDrive(int id) async {
    final db = await _dbHelper.database;
    return db.delete(
      DatabaseHelper.tableDriveLogs,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 주차 중 대기 전력 소모(Vampire Drain) 기록 전체 조회
  Future<List<VampireDrainLog>> getAllVampireDrains() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tableVampireDrainLogs,
      orderBy: 'start_time DESC',
    );
    return rows.map(VampireDrainLog.fromMap).toList();
  }

  /// 주차 중 대기 전력 소모 기록 추가
  Future<int> insertVampireDrain(VampireDrainLog log) async {
    final db = await _dbHelper.database;
    return db.insert(
      DatabaseHelper.tableVampireDrainLogs,
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
