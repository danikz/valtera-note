import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/note.dart';

class NotesLocalDataSource {
  Future<Database> get _db => AppDatabase.database;

  Future<List<Note>> getAllNotes({bool includeDeleted = false}) async {
    final db = await _db;
    final where = includeDeleted ? null : '${AppDatabase.colIsDeleted} = 0';

    final result = await db.query(
      AppDatabase.tableNotes,
      where: where,
      orderBy: '${AppDatabase.colIsPinned} DESC, ${AppDatabase.colUpdatedAt} DESC',
    );

    return result.map((e) => Note.fromMap(e)).toList();
  }

  Future<Note?> getNoteById(String id) async {
    final db = await _db;
    final result = await db.query(
      AppDatabase.tableNotes,
      where: '${AppDatabase.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return Note.fromMap(result.first);
  }

  Future<void> upsertNote(Note note) async {
    final db = await _db;
    await db.insert(
      AppDatabase.tableNotes,
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteNote(String id, {bool hardDelete = false}) async {
    final db = await _db;
    if (hardDelete) {
      await db.delete(
        AppDatabase.tableNotes,
        where: '${AppDatabase.colId} = ?',
        whereArgs: [id],
      );
    } else {
      await db.update(
        AppDatabase.tableNotes,
        {
          AppDatabase.colIsDeleted: 1,
          AppDatabase.colSyncStatus: SyncStatus.local.name,
          AppDatabase.colUpdatedAt: DateTime.now().toUtc().toIso8601String(),
        },
        where: '${AppDatabase.colId} = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> togglePin(String id) async {
    final note = await getNoteById(id);
    if (note == null) return;

    final updated = note.copyWith(
      isPinned: !note.isPinned,
      syncStatus: SyncStatus.local,
      updatedAt: DateTime.now().toUtc(),
    );
    await upsertNote(updated);
  }

  Future<List<Note>> searchNotes(String query) async {
    final db = await _db;
    final q = '%${query.trim()}%';

    final result = await db.query(
      AppDatabase.tableNotes,
      where:
          '${AppDatabase.colIsDeleted} = 0 AND (${AppDatabase.colTitle} LIKE ? OR ${AppDatabase.colContent} LIKE ?)',
      whereArgs: [q, q],
      orderBy: '${AppDatabase.colIsPinned} DESC, ${AppDatabase.colUpdatedAt} DESC',
    );

    return result.map((e) => Note.fromMap(e)).toList();
  }

  Future<void> clearAll() async {
    final db = await _db;
    await db.delete(AppDatabase.tableNotes);
  }
}
