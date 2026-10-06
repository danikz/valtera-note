import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/models/sync_queue_item.dart';

class SyncQueueDataSource {
  Future<Database> get _db => AppDatabase.database;

  Future<void> enqueue({
    required String operation,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _db;
    final item = SyncQueueItem(
      operation: operation,
      entityId: entityId,
      payload: payload,
      createdAt: DateTime.now().toUtc(),
      status: SyncQueueStatus.pending,
    );

    // If an item for this entityId already exists in pending state, update it (or replace)
    await db.insert(
      AppDatabase.tableSyncQueue,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SyncQueueItem>> getPendingItems() async {
    final db = await _db;
    final result = await db.query(
      AppDatabase.tableSyncQueue,
      where:
          "${AppDatabase.colQueueStatus} = ? OR (${AppDatabase.colQueueStatus} = ? AND ${AppDatabase.colQueueAttemptCount} < ?)",
      whereArgs: [
        SyncQueueStatus.pending.name,
        SyncQueueStatus.failed.name,
        SyncQueueItem.maxRetryAttempts,
      ],
      orderBy: '${AppDatabase.colQueueCreatedAt} ASC',
    );

    return result.map((e) => SyncQueueItem.fromMap(e)).toList();
  }

  Future<void> markProcessing(int id) async {
    final db = await _db;
    await db.update(
      AppDatabase.tableSyncQueue,
      {AppDatabase.colQueueStatus: SyncQueueStatus.processing.name},
      where: '${AppDatabase.colQueueId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> markSuccess(int id) async {
    final db = await _db;
    await db.delete(
      AppDatabase.tableSyncQueue,
      where: '${AppDatabase.colQueueId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> markFailed(int id, String error, int currentAttempts) async {
    final db = await _db;
    final nextAttempts = currentAttempts + 1;
    await db.update(
      AppDatabase.tableSyncQueue,
      {
        AppDatabase.colQueueStatus: SyncQueueStatus.failed.name,
        AppDatabase.colQueueLastError: error,
        AppDatabase.colQueueAttemptCount: nextAttempts,
      },
      where: '${AppDatabase.colQueueId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearQueue() async {
    final db = await _db;
    await db.delete(AppDatabase.tableSyncQueue);
  }
}
