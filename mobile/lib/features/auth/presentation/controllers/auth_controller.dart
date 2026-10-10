import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/crypto/e2e_controller.dart';
import '../../../notes/data/repositories/notes_repository_impl.dart';
import '../../../notes/presentation/controllers/notes_list_controller.dart';
import '../../../setup/data/repositories/setup_repository.dart';
import '../../../sync/domain/sync_engine.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/models/auth_state.dart';

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  late final AuthRepository _repo;

  @override
  AuthState build() {
    _repo = ref.watch(authRepositoryProvider);
    _restoreSession();
    return const AuthState();
  }

  Future<void> _restoreSession() async {
    final session = await _repo.getSession();
    if (session.isLoggedIn) {
      state = state.copyWith(
        isLoggedIn: true,
        userEmail: session.userEmail,
      );
    }
  }

  Future<bool> login(String email, String password) async {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Email dan password tidak boleh kosong');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);

    final result = await _repo.login(email: email, password: password);

    state = state.copyWith(
      isLoading: false,
      isLoggedIn: result.isSuccess,
      userEmail: result.email,
      errorMessage: result.isSuccess ? null : result.errorMessage,
    );

    return result.isSuccess;
  }

  Future<bool> register(String email, String password, String confirmPassword) async {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Email dan password tidak boleh kosong');
      return false;
    }

    if (password != confirmPassword) {
      state = state.copyWith(errorMessage: 'Konfirmasi password tidak cocok');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);

    final result = await _repo.register(email: email, password: password);

    state = state.copyWith(
      isLoading: false,
      isLoggedIn: result.isSuccess && !result.isConfirmationSent,
      userEmail: result.email,
      errorMessage: result.isSuccess ? null : result.errorMessage,
      isEmailConfirmationRequired: result.isConfirmationSent,
      successMessage: result.isConfirmationSent
          ? 'Registrasi berhasil! Silakan periksa email Anda untuk verifikasi.'
          : null,
    );

    return result.isSuccess;
  }

  Future<bool> recoverPassword(String email) async {
    if (email.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Email wajib diisi');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);

    final result = await _repo.recoverPassword(email: email);

    state = state.copyWith(
      isLoading: false,
      errorMessage: result.isSuccess ? null : result.errorMessage,
      successMessage: result.isSuccess
          ? 'Tautan reset kata sandi telah dikirim ke email Anda.'
          : null,
    );

    return result.isSuccess;
  }

  Future<void> logout() async {
    await _repo.logout();

    // Hapus semua data milik akun ini dari device: catatan lokal (plaintext),
    // antrean sync, folder, serta konfigurasi & kunci E2E. Tanpa ini catatan
    // akun lama ikut ter-sync ke akun yang login berikutnya, dan kunci E2E
    // akun lama dipakai untuk mengenkripsi data akun baru.
    final storage = ref.read(secureStorageServiceProvider);
    await ref.read(syncQueueDataSourceProvider).clearQueue();
    await ref.read(notesLocalDataSourceProvider).clearAll();
    await storage.saveCustomFolders(const []);
    await storage.clearAllE2e();
    await ref.read(e2eControllerProvider.notifier).refreshConfig();
    ref.invalidate(notesListControllerProvider);

    state = const AuthState(isLoggedIn: false);
  }

  /// Jumlah perubahan lokal yang belum terkirim (hilang bila logout).
  Future<int> pendingChangesCount() async {
    final items = await ref.read(syncQueueDataSourceProvider).getPendingItems();
    return items.length;
  }
}
