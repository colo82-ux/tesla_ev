import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../models/expense_log.dart';

/// 차계부 지출 내역(`expense_logs`) CRUD Repository
class ExpenseRepository {
  final DatabaseHelper _dbHelper;

  const ExpenseRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// 전체 지출 내역 조회 (최신순)
  Future<List<ExpenseLog>> getAllExpenses() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tableExpenseLogs,
      orderBy: 'date DESC',
    );
    return rows.map(ExpenseLog.fromMap).toList();
  }

  /// 지출 내역 추가
  Future<int> insertExpense(ExpenseLog log) async {
    final db = await _dbHelper.database;
    return db.insert(
      DatabaseHelper.tableExpenseLogs,
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 지출 내역 수정
  Future<int> updateExpense(ExpenseLog log) async {
    if (log.id == null) return insertExpense(log);
    final db = await _dbHelper.database;
    return db.update(
      DatabaseHelper.tableExpenseLogs,
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  /// 지출 내역 삭제
  Future<int> deleteExpense(int id) async {
    final db = await _dbHelper.database;
    return db.delete(
      DatabaseHelper.tableExpenseLogs,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
