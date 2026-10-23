import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../domain/ssh_host.dart';

class SshLocalDataSource {
  Future<Database> get _db => AppDatabase.database;

  Future<List<SshConnectionRecord>> getAll({bool includeDeleted = false}) async {
    final db = await _db;
    final result = await db.query(
      AppDatabase.tableSsh,
      where: includeDeleted ? null : '${AppDatabase.colSshIsDeleted} = 0',
      orderBy: '${AppDatabase.colSshLabel} COLLATE NOCASE',
    );
    return result.map(SshConnectionRecord.fromMap).toList();
  }

  Future<SshConnectionRecord?> getById(String id) async {
    final db = await _db;
    final result = await db.query(
      AppDatabase.tableSsh,
      where: '${AppDatabase.colSshId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return SshConnectionRecord.fromMap(result.first);
  }

  Future<void> upsert(SshConnectionRecord record) async {
    final db = await _db;
    await db.insert(
      AppDatabase.tableSsh,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> hardDelete(String id) async {
    final db = await _db;
    await db.delete(
      AppDatabase.tableSsh,
      where: '${AppDatabase.colSshId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAll() async {
    final db = await _db;
    await db.delete(AppDatabase.tableSsh);
  }
}
