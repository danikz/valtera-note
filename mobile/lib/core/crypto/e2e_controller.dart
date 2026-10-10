import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage_service.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/setup/data/repositories/setup_repository.dart';
import 'crypto_service.dart';

enum E2eStatus {
  notConfigured,
  locked,
  unlocked,
}

class E2eState {
  final E2eStatus status;
  final String? salt;
  final String? verifier;
  final List<int>? keyBytes;
  final bool isLoading;
  final String? errorMessage;

  const E2eState({
    this.status = E2eStatus.notConfigured,
    this.salt,
    this.verifier,
    this.keyBytes,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isUnlocked => status == E2eStatus.unlocked && keyBytes != null;
  bool get isLocked => status == E2eStatus.locked;
  bool get isConfigured => status != E2eStatus.notConfigured;

  E2eState copyWith({
    E2eStatus? status,
    String? salt,
    String? verifier,
    List<int>? keyBytes,
    bool? isLoading,
    String? errorMessage,
  }) {
    return E2eState(
      status: status ?? this.status,
      salt: salt ?? this.salt,
      verifier: verifier ?? this.verifier,
      keyBytes: keyBytes ?? this.keyBytes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptoService();
});

final e2eControllerProvider =
    NotifierProvider<E2eController, E2eState>(E2eController.new);

class E2eController extends Notifier<E2eState> {
  late final SecureStorageService _storage;
  late final CryptoService _crypto;
  late final AuthRepository _authRepo;

  @override
  E2eState build() {
    _storage = ref.watch(secureStorageServiceProvider);
    _crypto = ref.watch(cryptoServiceProvider);
    _authRepo = ref.watch(authRepositoryProvider);

    Future.microtask(_init);
    return const E2eState(isLoading: true);
  }

  Future<void> _init() async {
    final local = await _loadConfig();
    // Di latar belakang: cocokkan dengan user_metadata Supabase.
    unawaited(_syncRemoteConfig(local));
  }

  /// Master password bisa diganti dari desktop (salt + verifier baru). Salinan
  /// lokal yang basi membuat catatan baru tak terbaca dan editan mobile
  /// terenkripsi dengan kunci lama — jadi selalu cocokkan dengan server.
  Future<void> _syncRemoteConfig(E2eConfigData local) async {
    try {
      final metadata = await _authRepo.fetchUserMetadata();
      if (metadata == null) return; // offline / belum login
      final remote = await _storage.getE2eConfig();
      if (!remote.isConfigured) return;
      if (remote.salt == local.salt && remote.verifier == local.verifier) return;

      // Kunci yang diingat diturunkan dari salt lama -> basi, wajib unlock ulang.
      await _storage.clearE2eKey();
      state = E2eState(
        status: E2eStatus.locked,
        salt: remote.salt,
        verifier: remote.verifier,
      );
    } catch (_) {}
  }

  Future<E2eConfigData> _loadConfig() async {
    state = state.copyWith(isLoading: true);

    // 1. Check local storage for E2E config
    var config = await _storage.getE2eConfig();

    // 2. If not stored locally, check remote user metadata
    if (!config.isConfigured) {
      await _authRepo.fetchUserMetadata();
      config = await _storage.getE2eConfig();
    }

    if (!config.isConfigured) {
      state = const E2eState(status: E2eStatus.notConfigured);
      return config;
    }

    final salt = config.salt!;
    final verifier = config.verifier!;

    // 3. Check if key is remembered on this device
    if (config.rememberDevice && config.savedKeyBase64 != null) {
      try {
        final keyBytes = base64Decode(config.savedKeyBase64!);
        final isValid = await _crypto.verifyMasterPassword(
          keyBytes: keyBytes,
          verifierCiphertext: verifier,
        );
        if (isValid) {
          state = E2eState(
            status: E2eStatus.unlocked,
            salt: salt,
            verifier: verifier,
            keyBytes: keyBytes,
          );
          return config;
        }
      } catch (_) {}
    }

    // 4. Fallback: locked, waiting for user password
    state = E2eState(
      status: E2eStatus.locked,
      salt: salt,
      verifier: verifier,
    );
    return config;
  }

  Future<bool> unlock(String password, {bool rememberDevice = true}) async {
    final salt = state.salt;
    final verifier = state.verifier;

    if (salt == null || verifier == null) {
      state = state.copyWith(errorMessage: 'Konfigurasi E2E tidak ditemukan');
      return false;
    }

    if (password.length < 8) {
      state = state.copyWith(errorMessage: 'Master password minimal 8 karakter');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final saltBytes = base64Decode(salt);
      final derivedKey = await _crypto.deriveKey(password, saltBytes);

      final isValid = await _crypto.verifyMasterPassword(
        keyBytes: derivedKey,
        verifierCiphertext: verifier,
      );

      if (!isValid) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Master password salah',
        );
        return false;
      }

      if (rememberDevice) {
        await _storage.saveE2eKey(
          keyBase64: base64Encode(derivedKey),
          rememberDevice: true,
        );
      } else {
        await _storage.clearE2eKey();
      }

      state = E2eState(
        status: E2eStatus.unlocked,
        salt: salt,
        verifier: verifier,
        keyBytes: derivedKey,
        isLoading: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal membuka kunci: $e',
      );
      return false;
    }
  }

  void lock() {
    state = E2eState(
      status: E2eStatus.locked,
      salt: state.salt,
      verifier: state.verifier,
    );
  }

  Future<void> forgetDevice() async {
    await _storage.clearE2eKey();
    lock();
  }

  Future<void> refreshConfig() async {
    await _init();
  }
}
