import 'package:sqflite/sqflite.dart';
import '../local/database_helper.dart';
import '../models/maintenance_item.dart';

/// 소모품 관리(`maintenance_items`) CRUD Repository
class MaintenanceRepository {
  final DatabaseHelper _dbHelper;

  const MaintenanceRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// 소모품 전체 목록 조회
  Future<List<MaintenanceItem>> getAllItems() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tableMaintenanceItems,
      orderBy: 'id ASC',
    );
    return rows.map(MaintenanceItem.fromMap).toList();
  }

  /// 소모품 항목 추가
  Future<int> insertItem(MaintenanceItem item) async {
    final db = await _dbHelper.database;
    return db.insert(
      DatabaseHelper.tableMaintenanceItems,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 소모품 항목 업데이트 (교체 완료 기록 갱신 포함)
  Future<int> updateItem(MaintenanceItem item) async {
    if (item.id == null) return insertItem(item);
    final db = await _dbHelper.database;
    return db.update(
      DatabaseHelper.tableMaintenanceItems,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// 소모품 항목 삭제
  Future<int> deleteItem(int id) async {
    final db = await _dbHelper.database;
    return db.delete(
      DatabaseHelper.tableMaintenanceItems,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
