import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valtera_note/core/crypto/crypto_service.dart';
import 'package:valtera_note/core/crypto/e2e_controller.dart';
import 'package:valtera_note/core/network/connectivity_service.dart';
import 'package:valtera_note/core/storage/secure_storage_service.dart';
import 'package:valtera_note/features/auth/data/repositories/auth_repository.dart';
import 'package:valtera_note/features/notes/data/local/notes_local_data_source.dart';
import 'package:valtera_note/features/notes/data/remote/notes_remote_data_source.dart';
import 'package:valtera_note/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:valtera_note/features/notes/domain/entities/note.dart';
import 'package:valtera_note/features/setup/data/repositories/setup_repository.dart';
import 'package:valtera_note/features/sync/data/local/sync_queue_data_source.dart';

enum SyncEngineState { idle, syncing, error }

class SyncStatusInfo {
  final SyncEngineState state;
  final String? message;
  final DateTime? lastSyncedAt;

  const SyncStatusInfo({
    this.state = SyncEngineState.idle,
    this.message,
    this.lastSyncedAt,
  });
}

final syncQueueDataSourceProvider = Provider<SyncQueueDataSource>((ref) {
  return SyncQueueDataSource();
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  final localNotes = ref.watch(notesLocalDataSourceProvider);
  final remoteNotes = ref.watch(notesRemoteDataSourceProvider);
  final queue = ref.watch(syncQueueDataSourceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final crypto = ref.watch(cryptoServiceProvider);

  final engine = SyncEngine(
    storageService: storage,
    authRepository: authRepo,
    localDataSource: localNotes,
    remoteDataSource: remoteNotes,
    queueDataSource: queue,
    connectivityService: connectivity,
    cryptoService: crypto,
    getKeyBytes: () => ref.read(e2eControllerProvider).keyBytes,
  );

  ref.onDispose(() => engine.dispose());
  return engine;
});

final syncStatusStreamProvider = StreamProvider<SyncStatusInfo>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine.statusStream;
});

class SyncEngine {
  final SecureStorageService _storageService;
  final AuthRepository _authRepository;
  final NotesLocalDataSource _local;
  final NotesRemoteDataSource _remote;
  final SyncQueueDataSource _queue;
  final ConnectivityService _connectivity;
  final CryptoService? _crypto;
  final List<int>? Function()? _getKeyBytes;

  final _statusController = StreamController<SyncStatusInfo>.broadcast();
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;
  DateTime? _lastSyncedAt;

  SyncEngine({
    required SecureStorageService storageService,
    required AuthRepository authRepository,
    required NotesLocalDataSource localDataSource,
    required NotesRemoteDataSource remoteDataSource,
    required SyncQueueDataSource queueDataSource,
    required ConnectivityService connectivityService,
    CryptoService? cryptoService,
    List<int>? Function()? getKeyBytes,
  })  : _storageService = storageService,
        _authRepository = authRepository,
        _local = localDataSource,
        _remote = remoteDataSource,
        _queue = queueDataSource,
        _connectivity = connectivityService,
        _crypto = cryptoService,
        _getKeyBytes = getKeyBytes {
    _statusController.add(const SyncStatusInfo());
    _listenToConnectivity();
  }

  Stream<SyncStatusInfo> get statusStream => _statusController.stream;
  SyncStatusInfo get currentStatus => SyncStatusInfo(
        state: _isSyncing ? SyncEngineState.syncing : SyncEngineState.idle,
        lastSyncedAt: _lastSyncedAt,
      );

  void _listenToConnectivity() {
    _connectivitySubscription = _connectivity.isOnlineStream.listen((isOnline) {
      if (isOnline && !_isSyncing) {
        // Auto-drain queue when back online
        syncAll(silent: true);
      }
    });
  }

  Future<void> syncAll({bool silent = false}) async {
    if (_isSyncing) return;

    final config = await _storageService.getSupabaseConfig();
    if (!config.isConfigured) return;

    final isOnline = await _connectivity.checkOnline();
    if (!isOnline) {
      _statusController.add(SyncStatusInfo(
        state: SyncEngineState.idle,
        message: 'Offline — perubahan dicatat di antrean lokal',
        lastSyncedAt: _lastSyncedAt,
      ));
      return;
    }

    _isSyncing = true;
    _statusController.add(SyncStatusInfo(
      state: SyncEngineState.syncing,
      message: silent ? null : 'Menyinkronkan catatan...',
      lastSyncedAt: _lastSyncedAt,
    ));

    try {
      final token = await _authRepository.getEffectiveToken();

      // 1. Drain offline queue first
      await _drainQueue(
        url: config.url!,
        anonKey: config.anonKey!,
        accessToken: token,
      );

      // 2. Two-way pull: fetch remote notes and merge
      await _pullAndMergeRemoteNotes(
        url: config.url!,
        anonKey: config.anonKey!,
        accessToken: token,
      );

      _lastSyncedAt = DateTime.now();
      _statusController.add(SyncStatusInfo(
        state: SyncEngineState.idle,
        message: 'Tersinkronisasi dengan Supabase',
        lastSyncedAt: _lastSyncedAt,
      ));
    } catch (e) {
      _statusController.add(SyncStatusInfo(
        state: SyncEngineState.error,
        message: 'Gagal sinkronisasi: $e',
        lastSyncedAt: _lastSyncedAt,
      ));
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _drainQueue({
    required String url,
    required String anonKey,
    String? accessToken,
  }) async {
    final pending = await _queue.getPendingItems();
    final key = _getKeyBytes?.call();

    for (final item in pending) {
      if (item.id == null) continue;
      await _queue.markProcessing(item.id!);

      try {
        if (item.operation == 'create' || item.operation == 'update') {
          final note = Note.fromMap(item.payload);
          var remoteNote = note;

          // If E2E is active and content not yet encrypted, encrypt for remote storage
          if (_crypto != null && key != null && !_crypto!.isEncrypted(note.content)) {
            try {
              final encryptedContent = await _crypto!.encrypt(key, note.content);
              remoteNote = note.copyWith(content: encryptedContent);
            } catch (_) {}
          }

          await _remote.upsertRemoteNote(
            url: url,
            anonKey: anonKey,
            note: remoteNote,
            accessToken: accessToken,
          );
          // Update local status to synced (local retains plaintext)
          await _local.upsertNote(note.copyWith(syncStatus: SyncStatus.synced));
        } else if (item.operation == 'delete') {
          await _remote.deleteRemoteNote(
            url: url,
            anonKey: anonKey,
            id: item.entityId,
            accessToken: accessToken,
          );
        }

        await _queue.markSuccess(item.id!);
      } catch (e) {
        await _queue.markFailed(item.id!, e.toString(), item.attemptCount);
      }
    }
  }

  Future<void> _pullAndMergeRemoteNotes({
    required String url,
    required String anonKey,
    String? accessToken,
  }) async {
    final remoteNotes = await _remote.fetchRemoteNotes(
      url: url,
      anonKey: anonKey,
      accessToken: accessToken,
    );

    final localNotes = await _local.getAllNotes(includeDeleted: true);
    final localMap = {for (var n in localNotes) n.id: n};
    final key = _getKeyBytes?.call();

    for (final remote in remoteNotes) {
      final local = localMap[remote.id];

      if (remote.isDeleted) {
        if (local != null) {
          await _local.deleteNote(remote.id, hardDelete: true);
        }
        continue;
      }

      var content = remote.content;
      // Decrypt if E2E unlocked
      if (_crypto != null && key != null && _crypto!.isEncrypted(content)) {
        try {
          content = await _crypto!.decrypt(key, content);
        } catch (_) {}
      }

      final noteToStore = remote.copyWith(
        content: content,
        syncStatus: SyncStatus.synced,
      );

      if (local == null) {
        // New remote note -> insert locally as synced
        await _local.upsertNote(noteToStore);
      } else {
        // If local is currently dirty (modified offline), protect local draft!
        if (local.syncStatus == SyncStatus.local) {
          continue;
        }

        // If remote is newer, update local
        if (remote.updatedAt.isAfter(local.updatedAt) || remote.updatedAt.isAtSameMomentAs(local.updatedAt)) {
          await _local.upsertNote(noteToStore);
        }
      }
    }
  }

  Future<int> decryptExistingLocalNotes(List<int> keyBytes) async {
    if (_crypto == null) return 0;
    final notes = await _local.getAllNotes();
    var count = 0;
    for (final note in notes) {
      if (_crypto!.isEncrypted(note.content)) {
        try {
          final decrypted = await _crypto!.decrypt(keyBytes, note.content);
          await _local.upsertNote(note.copyWith(content: decrypted));
          count++;
        } catch (_) {}
      }
    }
    return count;
  }

  Future<void> enqueueAndSync({
    required Note note,
    required String operation, // 'create' | 'update' | 'delete'
  }) async {
    // 1. Immediately write to local storage
    if (operation == 'delete') {
      await _local.deleteNote(note.id);
    } else {
      await _local.upsertNote(note.copyWith(syncStatus: SyncStatus.local));
    }

    // 2. Add to mutation queue
    await _queue.enqueue(
      operation: operation,
      entityId: note.id,
      payload: note.toMap(),
    );

    // 3. Trigger async sync if online
    final isOnline = await _connectivity.checkOnline();
    if (isOnline) {
      unawaited(syncAll(silent: true));
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
  }
}
