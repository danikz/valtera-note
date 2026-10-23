import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/crypto/e2e_controller.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../setup/data/repositories/setup_repository.dart';
import '../domain/ssh_host.dart';
import 'ssh_local_data_source.dart';
import 'ssh_remote_data_source.dart';

final sshLocalDataSourceProvider = Provider<SshLocalDataSource>((ref) {
  return SshLocalDataSource();
});

final sshRemoteDataSourceProvider = Provider<SshRemoteDataSource>((ref) {
  return SshRemoteDataSource();
});

final sshRepositoryProvider = Provider<SshRepository>((ref) {
  return SshRepository(
    local: ref.watch(sshLocalDataSourceProvider),
    remote: ref.watch(sshRemoteDataSourceProvider),
    storage: ref.watch(secureStorageServiceProvider),
    authRepository: ref.watch(authRepositoryProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    crypto: ref.watch(cryptoServiceProvider),
    getKeyBytes: () => ref.read(e2eControllerProvider).keyBytes,
    // Fail-closed: selama status E2E belum diketahui (loading) anggap aktif.
    isE2eConfigured: () {
      final e2e = ref.read(e2eControllerProvider);
      return e2e.isConfigured || e2e.isLoading;
    },
  );
});

class SshLockedException implements Exception {
  @override
  String toString() => 'Buka kunci E2E (Master Password) dulu untuk mengubah koneksi.';
}

class SshRepository {
  final SshLocalDataSource _local;
  final SshRemoteDataSource _remote;
  final SecureStorageService _storage;
  final AuthRepository _authRepository;
  final ConnectivityService _connectivity;
  final CryptoService _crypto;
  final List<int>? Function() _getKeyBytes;
  final bool Function() _isE2eConfigured;

  bool _isSyncing = false;

  SshRepository({
    required SshLocalDataSource local,
    required SshRemoteDataSource remote,
    required SecureStorageService storage,
    required AuthRepository authRepository,
    required ConnectivityService connectivity,
    required CryptoService crypto,
    required List<int>? Function() getKeyBytes,
    required bool Function() isE2eConfigured,
  })  : _local = local,
        _remote = remote,
        _storage = storage,
        _authRepository = authRepository,
        _connectivity = connectivity,
        _crypto = crypto,
        _getKeyBytes = getKeyBytes,
        _isE2eConfigured = isE2eConfigured;

  Future<List<SshConnectionRecord>> listRecords() => _local.getAll();

  /// null = payload terenkripsi tapi E2E masih terkunci (atau kunci tidak cocok).
  Future<SshHost?> decode(SshConnectionRecord record) async {
    var json = record.payload;
    if (_crypto.isEncrypted(json)) {
      final key = _getKeyBytes();
      if (key == null) return null;
      try {
        json = await _crypto.decrypt(key, json);
      } catch (_) {
        return null;
      }
    }
    try {
      return SshHost.fromPayload(id: record.id, label: record.label, payloadJson: json);
    } catch (_) {
      return null;
    }
  }

  Future<String> _encodePayload(SshHost host) async {
    final json = host.toPayloadJson();
    final key = _getKeyBytes();
    if (key != null) return _crypto.encrypt(key, json);
    if (_isE2eConfigured()) throw SshLockedException();
    return json;
  }

  Future<SshConnectionRecord> save(SshHost host) async {
    final id = host.id.isEmpty || host.id.startsWith('quick:') ? const Uuid().v4() : host.id;
    final label = host.label.trim().isEmpty ? host.address : host.label.trim();
    final record = SshConnectionRecord(
      id: id,
      label: label,
      payload: await _encodePayload(host),
      updatedAt: DateTime.now().toUtc(),
      dirty: true,
    );
    await _local.upsert(record);
    return record;
  }

  /// Tandai hapus — tombstone dikirim ke cloud saat sync berikutnya.
  Future<void> delete(String id) async {
    final existing = await _local.getById(id);
    if (existing == null) return;
    await _local.upsert(SshConnectionRecord(
      id: existing.id,
      label: existing.label,
      payload: existing.payload,
      updatedAt: DateTime.now().toUtc(),
      isDeleted: true,
      dirty: true,
    ));
  }

  Future<void> clearLocal() => _local.clearAll();

  /// Pull (merge) + push + heal tombstone — pola sama dengan desktop.
  /// Mengembalikan ringkasan untuk ditampilkan, null bila dilewati.
  Future<String?> sync() async {
    if (_isSyncing) return null;

    final config = await _storage.getSupabaseConfig();
    if (!config.isConfigured) return null;
    if (!await _connectivity.checkOnline()) return 'Offline — koneksi tersimpan di perangkat';

    final token = await _authRepository.getEffectiveToken();
    if (token == null) return 'Login untuk menyinkronkan koneksi SSH';

    _isSyncing = true;
    try {
      final url = config.url!;
      final anonKey = config.anonKey!;
      var pulled = 0, pushed = 0, removed = 0, skipped = 0;

      final remote = await _remote.fetchAll(url: url, anonKey: anonKey, accessToken: token);
      final remoteById = {for (final r in remote) r.id: r};
      final localById = {for (final l in await _local.getAll(includeDeleted: true)) l.id: l};

      // 1. Pull + heal tombstone.
      for (final r in remote) {
        final l = localById[r.id];
        if (r.isDeleted) {
          if (l != null) {
            await _local.hardDelete(r.id);
            removed++;
          }
          continue;
        }
        if (l == null) {
          await _local.upsert(_clean(r));
          pulled++;
          continue;
        }
        if (l.isDeleted) continue; // dihapus di sini, tombstone dikirim di tahap push
        if (l.payload == r.payload && l.label == r.label) {
          if (l.dirty) await _local.upsert(_clean(l));
          continue;
        }
        // Konflik konten: versi yang lebih baru menang.
        if (l.dirty && !r.updatedAt.isAfter(l.updatedAt)) continue;
        await _local.upsert(_clean(r));
        pulled++;
      }

      // 2. Push perubahan lokal & kirim tombstone.
      for (final l in await _local.getAll(includeDeleted: true)) {
        final r = remoteById[l.id];
        if (l.isDeleted) {
          if (r != null && !r.isDeleted) {
            await _remote.softDelete(url: url, anonKey: anonKey, id: l.id, accessToken: token);
          }
          await _local.hardDelete(l.id);
          continue;
        }
        if (!l.dirty && r != null && !r.isDeleted) continue;

        var record = l;
        if (!_crypto.isEncrypted(record.payload)) {
          // Kredensial plaintext tidak pernah dikirim ke cloud.
          final key = _getKeyBytes();
          if (key == null) {
            skipped++;
            continue;
          }
          record = SshConnectionRecord(
            id: l.id,
            label: l.label,
            payload: await _crypto.encrypt(key, l.payload),
            updatedAt: l.updatedAt,
            dirty: true,
          );
          await _local.upsert(record);
        }

        await _remote.upsert(url: url, anonKey: anonKey, record: record, accessToken: token);
        // Jangan bersihkan flag dirty bila koneksi diubah lagi selama upload.
        final current = await _local.getById(record.id);
        if (current != null && !current.updatedAt.isAfter(record.updatedAt)) {
          await _local.upsert(_clean(current));
        }
        pushed++;
      }

      final parts = <String>[
        if (pulled > 0) '$pulled ditarik',
        if (pushed > 0) '$pushed dikirim',
        if (removed > 0) '$removed dihapus',
        if (skipped > 0) '$skipped hanya lokal (aktifkan E2E untuk sinkron)',
      ];
      return parts.isEmpty ? 'Sinkron — sudah sama semua' : 'Sinkron — ${parts.join(', ')}';
    } finally {
      _isSyncing = false;
    }
  }

  SshConnectionRecord _clean(SshConnectionRecord r) => SshConnectionRecord(
        id: r.id,
        label: r.label,
        payload: r.payload,
        updatedAt: r.updatedAt,
      );
}
