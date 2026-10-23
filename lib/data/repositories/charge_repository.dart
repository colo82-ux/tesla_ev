import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../models/charge_log.dart';

/// 충전 기록(`charge_logs`) CRUD Repository
class ChargeRepository {
  final DatabaseHelper _dbHelper;

  ChargeRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// 전체 충전 기록 조회 (최신순)
  Future<List<ChargeLog>> getAllCharges() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tableChargeLogs,
      orderBy: 'date DESC',
    );
    return rows.map(ChargeLog.fromMap).toList();
  }

  /// 특정 기간 내 충전 기록 조회
  Future<List<ChargeLog>> getChargesInPeriod(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tableChargeLogs,
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
    return rows.map(ChargeLog.fromMap).toList();
  }

  /// 단건 충전 기록 Upsert (중복 방지: date + location_type 기준)
  Future<int> upsertCharge(ChargeLog log) async {
    final db = await _dbHelper.database;
    return db.insert(
      DatabaseHelper.tableChargeLogs,
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 다건 충전 기록 일괄 Upsert
  Future<int> upsertChargesBatch(List<ChargeLog> logs) async {
    if (logs.isEmpty) return 0;
    final db = await _dbHelper.database;
    var count = 0;
    await db.transaction((txn) async {
      for (final log in logs) {
        await txn.insert(
          DatabaseHelper.tableChargeLogs,
          log.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        count++;
      }
    });
    return count;
  }

  /// 충전 기록 수정
  Future<int> updateCharge(ChargeLog log) async {
    if (log.id == null) return upsertCharge(log);
    final db = await _dbHelper.database;
    return db.update(
      DatabaseHelper.tableChargeLogs,
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  /// 충전 기록 삭제
  Future<int> deleteCharge(int id) async {
    final db = await _dbHelper.database;
    return db.delete(
      DatabaseHelper.tableChargeLogs,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
