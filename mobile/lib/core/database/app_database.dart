import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const String databaseName = 'valtera_note.db';
  static const int databaseVersion = 1;

  // Table local_notes
  static const String tableNotes = 'local_notes';
  static const String colId = 'id';
  static const String colUserId = 'user_id';
  static const String colTitle = 'title';
  static const String colContent = 'content';
  static const String colFileExtension = 'file_extension';
  static const String colFolder = 'folder';
  static const String colIsPinned = 'is_pinned';
  static const String colIsDeleted = 'is_deleted';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';
  static const String colSyncStatus = 'sync_status';

  // Table sync_queue
  static const String tableSyncQueue = 'sync_queue';
  static const String colQueueId = 'id';
  static const String colQueueOperation = 'operation';
  static const String colQueueEntityId = 'entity_id';
  static const String colQueuePayload = 'payload';
  static const String colQueueCreatedAt = 'created_at';
  static const String colQueueAttemptCount = 'attempt_count';
  static const String colQueueLastError = 'last_error';
  static const String colQueueStatus = 'status';

  // DDL Scripts
  static const String createNotesTableSql = '''
    CREATE TABLE IF NOT EXISTS $tableNotes (
      $colId TEXT PRIMARY KEY,
      $colUserId TEXT,
      $colTitle TEXT NOT NULL DEFAULT 'Untitled',
      $colContent TEXT NOT NULL DEFAULT '',
      $colFileExtension TEXT NOT NULL DEFAULT 'md',
      $colFolder TEXT,
      $colIsPinned INTEGER NOT NULL DEFAULT 0,
      $colIsDeleted INTEGER NOT NULL DEFAULT 0,
      $colCreatedAt TEXT NOT NULL,
      $colUpdatedAt TEXT NOT NULL,
      $colSyncStatus TEXT NOT NULL DEFAULT 'synced'
    );
    CREATE INDEX IF NOT EXISTS idx_local_notes_updated_at ON $tableNotes($colUpdatedAt DESC);
    CREATE INDEX IF NOT EXISTS idx_local_notes_pinned ON $tableNotes($colIsPinned DESC);
  ''';

  static const String createSyncQueueTableSql = '''
    CREATE TABLE IF NOT EXISTS $tableSyncQueue (
      $colQueueId INTEGER PRIMARY KEY AUTOINCREMENT,
      $colQueueOperation TEXT NOT NULL,
      $colQueueEntityId TEXT NOT NULL,
      $colQueuePayload TEXT NOT NULL,
      $colQueueCreatedAt TEXT NOT NULL,
      $colQueueAttemptCount INTEGER NOT NULL DEFAULT 0,
      $colQueueLastError TEXT,
      $colQueueStatus TEXT NOT NULL DEFAULT 'pending'
    );
    CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON $tableSyncQueue($colQueueStatus);
  ''';

  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, databaseName);

    return await openDatabase(
      path,
      version: databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableNotes (
            $colId TEXT PRIMARY KEY,
            $colUserId TEXT,
            $colTitle TEXT NOT NULL DEFAULT 'Untitled',
            $colContent TEXT NOT NULL DEFAULT '',
            $colFileExtension TEXT NOT NULL DEFAULT 'md',
            $colFolder TEXT,
            $colIsPinned INTEGER NOT NULL DEFAULT 0,
            $colIsDeleted INTEGER NOT NULL DEFAULT 0,
            $colCreatedAt TEXT NOT NULL,
            $colUpdatedAt TEXT NOT NULL,
            $colSyncStatus TEXT NOT NULL DEFAULT 'synced'
          );
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_local_notes_updated_at ON $tableNotes($colUpdatedAt DESC);');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_local_notes_pinned ON $tableNotes($colIsPinned DESC);');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS $tableSyncQueue (
            $colQueueId INTEGER PRIMARY KEY AUTOINCREMENT,
            $colQueueOperation TEXT NOT NULL,
            $colQueueEntityId TEXT NOT NULL,
            $colQueuePayload TEXT NOT NULL,
            $colQueueCreatedAt TEXT NOT NULL,
            $colQueueAttemptCount INTEGER NOT NULL DEFAULT 0,
            $colQueueLastError TEXT,
            $colQueueStatus TEXT NOT NULL DEFAULT 'pending'
          );
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON $tableSyncQueue($colQueueStatus);');
      },
    );
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
