import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/core/storage/secure_storage_service.dart';
import 'package:valtera_note/features/notes/domain/entities/note.dart';
import 'package:valtera_note/features/setup/data/repositories/setup_repository.dart';
import 'package:valtera_note/features/sync/domain/models/sync_queue_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End App Flow Integration Tests', () {
    test('1. Supabase Setup Validation & Storage Flow', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final storage = SecureStorageService(storage: const FlutterSecureStorage());
      final repo = SetupRepository(storageService: storage);

      // Invalid URLs
      expect(repo.validateUrl(''), isNotNull);
      expect(repo.validateUrl('http://insecure.supabase.co'), contains('HTTPS'));
      expect(repo.validateUrl('https://not-a-domain'), contains('tidak valid'));

      // Valid URLs
      expect(repo.validateUrl('https://myproject.supabase.co'), isNull);
      expect(repo.validateUrl('https://self-hosted.internal:8000'), isNull);

      // Anon Key checks
      expect(repo.validateAnonKey(''), isNotNull);
      expect(
        repo.validateAnonKey(
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJpYXQiOjE2MDAwMDAwMDB9.signature',
        ),
        isNull,
      );

      // Service role key rejection
      const serviceRoleKey =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTYwMDAwMDAwMH0.signature';
      expect(repo.validateAnonKey(serviceRoleKey), contains('Service Role Key'));

      // Save config to secure storage
      await repo.saveConfig(
        url: 'https://myproject.supabase.co',
        anonKey: 'sample-anon-key',
      );

      final config = await repo.getConfig();
      expect(config.isConfigured, isTrue);
      expect(config.url, 'https://myproject.supabase.co');
      expect(config.anonKey, 'sample-anon-key');
    });

    test('2. Complete Note Creation, Edit, Pin & Mutation Flow', () {
      final now = DateTime.utc(2026, 10, 5, 10, 0, 0);

      // Step A: User creates a draft note
      var note = Note(
        id: 'flow-note-101',
        title: 'Project Kickoff',
        content: 'Initial thoughts on architecture',
        createdAt: now,
        updatedAt: now,
        syncStatus: SyncStatus.local,
      );

      expect(note.title, 'Project Kickoff');
      expect(note.syncStatus, SyncStatus.local);
      expect(note.isPinned, isFalse);

      // Step B: User edits content and pins the note
      final editedAt = now.add(const Duration(minutes: 5));
      note = note.copyWith(
        content: 'Architecture updated: Flutter + SQFlite + Supabase RLS',
        isPinned: true,
        updatedAt: editedAt,
      );

      expect(note.isPinned, isTrue);
      expect(note.content, contains('Flutter + SQFlite'));

      // Step C: Enqueue offline mutation
      final queueItem = SyncQueueItem(
        id: 1,
        operation: 'update',
        entityId: note.id,
        payload: note.toPostgresJson(),
        createdAt: editedAt,
        attemptCount: 0,
      );

      expect(queueItem.operation, 'update');
      expect(queueItem.entityId, 'flow-note-101');
      expect(queueItem.status, SyncQueueStatus.pending);
      expect(queueItem.payload['is_pinned'], true);

      // Step D: Simulate successful sync
      note = note.copyWith(syncStatus: SyncStatus.synced);
      expect(note.syncStatus, SyncStatus.synced);

      // Step E: Note deletion flow (soft delete for RLS safety)
      note = note.copyWith(isDeleted: true, syncStatus: SyncStatus.local);
      expect(note.isDeleted, isTrue);

      final deleteQueueItem = SyncQueueItem(
        id: 2,
        operation: 'delete',
        entityId: note.id,
        payload: {'id': note.id, 'is_deleted': true},
        createdAt: editedAt.add(const Duration(minutes: 10)),
      );

      expect(deleteQueueItem.operation, 'delete');
      expect(deleteQueueItem.payload['is_deleted'], true);
    });

    test('3. Search & Filtering Logic Simulation', () {
      final now = DateTime.utc(2026, 10, 5, 12, 0, 0);
      final notesList = [
        Note(
          id: '1',
          title: 'Shopping list',
          content: 'Apples, oranges, oat milk',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: '2',
          title: 'Sprint Planning Notes',
          content: 'Discuss Valtera Note Android release roadmap',
          isPinned: true,
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: '3',
          title: 'Design Review',
          content: 'Swiss minimalism: clean typography, 48dp touch targets',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // Pinned filter
      final pinned = notesList.where((n) => n.isPinned).toList();
      expect(pinned.length, 1);
      expect(pinned.first.title, 'Sprint Planning Notes');

      // Unpinned filter
      final unpinned = notesList.where((n) => !n.isPinned).toList();
      expect(unpinned.length, 2);

      // Search query 'valtera'
      final searchValtera = notesList.where((n) {
        final query = 'valtera'.toLowerCase();
        return n.title.toLowerCase().contains(query) ||
            n.content.toLowerCase().contains(query);
      }).toList();
      expect(searchValtera.length, 1);
      expect(searchValtera.first.id, '2');

      // Search query 'swiss'
      final searchSwiss = notesList.where((n) {
        final query = 'swiss'.toLowerCase();
        return n.title.toLowerCase().contains(query) ||
            n.content.toLowerCase().contains(query);
      }).toList();
      expect(searchSwiss.length, 1);
      expect(searchSwiss.first.id, '3');
    });
  });
}
