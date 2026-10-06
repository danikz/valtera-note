import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/core/crypto/crypto_service.dart';
import 'package:valtera_note/features/notes/domain/entities/note.dart';
import 'package:valtera_note/features/sync/domain/sync_engine.dart';
import 'package:valtera_note/core/storage/secure_storage_service.dart';
import 'package:valtera_note/features/auth/data/repositories/auth_repository.dart';
import 'package:valtera_note/features/notes/data/local/notes_local_data_source.dart';
import 'package:valtera_note/features/notes/data/remote/notes_remote_data_source.dart';
import 'package:valtera_note/features/sync/data/local/sync_queue_data_source.dart';
import 'package:valtera_note/core/network/connectivity_service.dart';

class InMemoryNotesLocalDataSource extends NotesLocalDataSource {
  final Map<String, Note> _store = {};

  @override
  Future<List<Note>> getAllNotes({bool includeDeleted = false}) async {
    return _store.values.where((n) => includeDeleted || !n.isDeleted).toList();
  }

  @override
  Future<Note?> getNoteById(String id) async {
    return _store[id];
  }

  @override
  Future<void> upsertNote(Note note) async {
    _store[note.id] = note;
  }

  @override
  Future<void> deleteNote(String id, {bool hardDelete = false}) async {
    if (hardDelete) {
      _store.remove(id);
    } else if (_store.containsKey(id)) {
      _store[id] = _store[id]!.copyWith(isDeleted: true);
    }
  }
}

class FakeRemoteDataSource extends NotesRemoteDataSource {
  List<Note> remoteNotes = [];
  Note? lastUpsertedNote;

  @override
  Future<List<Note>> fetchRemoteNotes({
    required String url,
    required String anonKey,
    String? accessToken,
  }) async {
    return remoteNotes;
  }

  @override
  Future<Note> upsertRemoteNote({
    required String url,
    required String anonKey,
    required Note note,
    String? accessToken,
  }) async {
    lastUpsertedNote = note;
    return note.copyWith(syncStatus: SyncStatus.synced);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E2E Sync Engine Integration', () {
    late CryptoService crypto;
    late InMemoryNotesLocalDataSource localDb;
    late FakeRemoteDataSource remoteDb;
    late SyncEngine engine;
    late List<int> keyBytes;

    setUp(() async {
      crypto = CryptoService();
      localDb = InMemoryNotesLocalDataSource();
      remoteDb = FakeRemoteDataSource();

      const password = 'myMasterPassword123';
      final salt = List<int>.generate(16, (i) => i * 3);
      keyBytes = await crypto.deriveKey(password, salt);

      List<int>? currentKey = keyBytes;

      engine = SyncEngine(
        storageService: const SecureStorageService(),
        authRepository: AuthRepository(storageService: const SecureStorageService()),
        localDataSource: localDb,
        remoteDataSource: remoteDb,
        queueDataSource: SyncQueueDataSource(),
        connectivityService: ConnectivityService(),
        cryptoService: crypto,
        getKeyBytes: () => currentKey,
      );
    });

    test('decryptExistingLocalNotes decrypts all encrypted notes in local database', () async {
      const plaintext1 = 'Rahasia 1';
      const plaintext2 = 'Rahasia 2';
      final cipher1 = await crypto.encrypt(keyBytes, plaintext1);
      final cipher2 = await crypto.encrypt(keyBytes, plaintext2);

      await localDb.upsertNote(Note(id: '1', title: 'Note 1', content: cipher1));
      await localDb.upsertNote(Note(id: '2', title: 'Note 2', content: cipher2));
      await localDb.upsertNote(Note(id: '3', title: 'Note 3', content: 'Plain text biasa'));

      final count = await engine.decryptExistingLocalNotes(keyBytes);
      expect(count, 2);

      final n1 = await localDb.getNoteById('1');
      final n2 = await localDb.getNoteById('2');
      final n3 = await localDb.getNoteById('3');

      expect(n1?.content, plaintext1);
      expect(n2?.content, plaintext2);
      expect(n3?.content, 'Plain text biasa');
    });
  });
}
