import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/core/database/app_database.dart';
import 'package:valtera_note/core/errors/app_failures.dart';

void main() {
  group('AppDatabase DDL & Schema Constants', () {
    test('table and column definitions match Supabase public.notes schema', () {
      expect(AppDatabase.tableNotes, 'local_notes');
      expect(AppDatabase.colId, 'id');
      expect(AppDatabase.colUserId, 'user_id');
      expect(AppDatabase.colTitle, 'title');
      expect(AppDatabase.colContent, 'content');
      expect(AppDatabase.colFileExtension, 'file_extension');
      expect(AppDatabase.colFolder, 'folder');
      expect(AppDatabase.colIsPinned, 'is_pinned');
      expect(AppDatabase.colIsDeleted, 'is_deleted');
      expect(AppDatabase.colCreatedAt, 'created_at');
      expect(AppDatabase.colUpdatedAt, 'updated_at');
      expect(AppDatabase.colSyncStatus, 'sync_status');

      expect(AppDatabase.tableSyncQueue, 'sync_queue');
      expect(AppDatabase.colQueueOperation, 'operation');
      expect(AppDatabase.colQueueEntityId, 'entity_id');
      expect(AppDatabase.colQueuePayload, 'payload');
      expect(AppDatabase.colQueueStatus, 'status');
    });

    test('create tables DDL script contains required indices', () {
      expect(AppDatabase.createNotesTableSql, contains('CREATE TABLE IF NOT EXISTS local_notes'));
      expect(AppDatabase.createNotesTableSql, contains('PRIMARY KEY'));
      expect(AppDatabase.createSyncQueueTableSql, contains('CREATE TABLE IF NOT EXISTS sync_queue'));
      expect(AppDatabase.createNotesTableSql, contains('idx_local_notes_updated_at'));
    });
  });

  group('AppFailures Tests', () {
    test('NetworkFailure maps message and retains type', () {
      const failure = NetworkFailure('Tidak dapat menghubungi server');
      expect(failure.message, 'Tidak dapat menghubungi server');
      expect(failure.toString(), contains('NetworkFailure'));
    });

    test('AuthFailure holds authentication error', () {
      const failure = AuthFailure('Sesi telah berakhir');
      expect(failure.message, 'Sesi telah berakhir');
    });

    test('ValidationFailure holds field validation errors', () {
      const failure = ValidationFailure('URL harus diawali dengan https://');
      expect(failure.message, 'URL harus diawali dengan https://');
    });
  });
}
