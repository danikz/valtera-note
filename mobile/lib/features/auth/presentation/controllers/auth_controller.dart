import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    state = const AuthState(isLoggedIn: false);
  }
}
