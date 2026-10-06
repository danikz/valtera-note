import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/setup_repository.dart';

class SetupState {
  final bool isTesting;
  final bool isSaving;
  final String? urlError;
  final String? anonKeyError;
  final SetupConnectionResult? connectionResult;
  final String? generalError;
  final bool isConfigured;

  const SetupState({
    this.isTesting = false,
    this.isSaving = false,
    this.urlError,
    this.anonKeyError,
    this.connectionResult,
    this.generalError,
    this.isConfigured = false,
  });

  SetupState copyWith({
    bool? isTesting,
    bool? isSaving,
    String? urlError,
    String? anonKeyError,
    SetupConnectionResult? connectionResult,
    String? generalError,
    bool? isConfigured,
  }) {
    return SetupState(
      isTesting: isTesting ?? this.isTesting,
      isSaving: isSaving ?? this.isSaving,
      urlError: urlError,
      anonKeyError: anonKeyError,
      connectionResult: connectionResult ?? this.connectionResult,
      generalError: generalError,
      isConfigured: isConfigured ?? this.isConfigured,
    );
  }
}

final setupControllerProvider =
    NotifierProvider<SetupController, SetupState>(SetupController.new);

class SetupController extends Notifier<SetupState> {
  late final SetupRepository _repo;

  @override
  SetupState build() {
    _repo = ref.watch(setupRepositoryProvider);
    _loadInitial();
    return const SetupState();
  }

  Future<void> _loadInitial() async {
    final config = await _repo.getConfig();
    if (config.isConfigured) {
      state = state.copyWith(isConfigured: true);
    }
  }

  Future<bool> testConnection(String url, String anonKey) async {
    final urlError = _repo.validateUrl(url);
    final keyError = _repo.validateAnonKey(anonKey);

    if (urlError != null || keyError != null) {
      state = state.copyWith(
        urlError: urlError,
        anonKeyError: keyError,
        connectionResult: null,
      );
      return false;
    }

    state = state.copyWith(
      isTesting: true,
      urlError: null,
      anonKeyError: null,
      generalError: null,
    );

    final result = await _repo.testConnection(url: url, anonKey: anonKey);

    state = state.copyWith(
      isTesting: false,
      connectionResult: result,
      generalError: result.isSuccess ? null : result.message,
    );

    return result.isSuccess;
  }

  Future<bool> saveAndConnect(String url, String anonKey) async {
    final urlError = _repo.validateUrl(url);
    final keyError = _repo.validateAnonKey(anonKey);

    if (urlError != null || keyError != null) {
      state = state.copyWith(urlError: urlError, anonKeyError: keyError);
      return false;
    }

    state = state.copyWith(isSaving: true, generalError: null);

    try {
      await _repo.saveConfig(url: url, anonKey: anonKey);
      state = state.copyWith(
        isSaving: false,
        isConfigured: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        generalError: 'Gagal menyimpan konfigurasi: $e',
      );
      return false;
    }
  }

  Future<void> disconnect() async {
    await _repo.disconnect();
    state = const SetupState(isConfigured: false);
  }
}
