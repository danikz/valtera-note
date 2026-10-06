import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SupabaseConfigData {
  final String? url;
  final String? anonKey;

  const SupabaseConfigData({this.url, this.anonKey});

  bool get isConfigured =>
      url != null &&
      url!.trim().isNotEmpty &&
      anonKey != null &&
      anonKey!.trim().isNotEmpty;
}

class AuthSessionData {
  final String? accessToken;
  final String? refreshToken;
  final String? userEmail;
  final DateTime? expiresAt;

  const AuthSessionData({
    this.accessToken,
    this.refreshToken,
    this.userEmail,
    this.expiresAt,
  });

  bool get isLoggedIn =>
      accessToken != null && accessToken!.trim().isNotEmpty;
}

class SecureStorageService {
  final FlutterSecureStorage _storage;

  static const _keyUrl = 'supabase_url';
  static const _keyAnonKey = 'supabase_anon_key';
  static const _keyAccessToken = 'supabase_access_token';
  static const _keyRefreshToken = 'supabase_refresh_token';
  static const _keyUserEmail = 'supabase_user_email';
  static const _keyExpiresAt = 'supabase_token_expires_at';
  static const _keyE2eSalt = 'e2e_salt';
  static const _keyE2eVerifier = 'e2e_verifier';
  static const _keyE2eKey = 'e2e_key';
  static const _keyE2eRemember = 'e2e_remember_device';
  static const _keyCustomFolders = 'custom_folders';
  static const _keyThemeMode = 'app_theme_mode';

  const SecureStorageService({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  Future<void> saveThemeMode(String mode) async {
    await _storage.write(key: _keyThemeMode, value: mode.trim());
  }

  Future<String?> getThemeMode() async {
    final mode = await _storage.read(key: _keyThemeMode);
    return mode?.trim();
  }

  Future<void> saveCustomFolders(List<String> folders) async {
    await _storage.write(key: _keyCustomFolders, value: jsonEncode(folders));
  }

  Future<List<String>> getCustomFolders() async {
    final raw = await _storage.read(key: _keyCustomFolders);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> saveSupabaseConfig({
    required String url,
    required String anonKey,
  }) async {
    await _storage.write(key: _keyUrl, value: url.trim());
    await _storage.write(key: _keyAnonKey, value: anonKey.trim());
  }

  Future<SupabaseConfigData> getSupabaseConfig() async {
    final url = await _storage.read(key: _keyUrl);
    final anonKey = await _storage.read(key: _keyAnonKey);
    return SupabaseConfigData(url: url, anonKey: anonKey);
  }

  Future<void> clearSupabaseConfig() async {
    await _storage.delete(key: _keyUrl);
    await _storage.delete(key: _keyAnonKey);
    await clearAuthSession();
  }

  Future<void> saveAuthSession({
    required String accessToken,
    String? refreshToken,
    String? userEmail,
    DateTime? expiresAt,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken.trim());
    if (refreshToken != null) {
      await _storage.write(key: _keyRefreshToken, value: refreshToken.trim());
    }
    if (userEmail != null) {
      await _storage.write(key: _keyUserEmail, value: userEmail.trim());
    }
    if (expiresAt != null) {
      await _storage.write(
        key: _keyExpiresAt,
        value: expiresAt.toUtc().toIso8601String(),
      );
    }
  }

  Future<AuthSessionData> getAuthSession() async {
    final accessToken = await _storage.read(key: _keyAccessToken);
    final refreshToken = await _storage.read(key: _keyRefreshToken);
    final userEmail = await _storage.read(key: _keyUserEmail);
    final expiresAtStr = await _storage.read(key: _keyExpiresAt);

    DateTime? expiresAt;
    if (expiresAtStr != null && expiresAtStr.isNotEmpty) {
      expiresAt = DateTime.tryParse(expiresAtStr);
    }

    return AuthSessionData(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userEmail: userEmail,
      expiresAt: expiresAt,
    );
  }

  Future<void> clearAuthSession() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserEmail);
    await _storage.delete(key: _keyExpiresAt);
  }

  Future<void> saveE2eConfig({
    required String salt,
    required String verifier,
  }) async {
    await _storage.write(key: _keyE2eSalt, value: salt);
    await _storage.write(key: _keyE2eVerifier, value: verifier);
  }

  Future<E2eConfigData> getE2eConfig() async {
    final salt = await _storage.read(key: _keyE2eSalt);
    final verifier = await _storage.read(key: _keyE2eVerifier);
    final key = await _storage.read(key: _keyE2eKey);
    final rememberStr = await _storage.read(key: _keyE2eRemember);
    return E2eConfigData(
      salt: salt,
      verifier: verifier,
      savedKeyBase64: key,
      rememberDevice: rememberStr == 'true',
    );
  }

  Future<void> saveE2eKey({
    required String keyBase64,
    required bool rememberDevice,
  }) async {
    await _storage.write(key: _keyE2eRemember, value: rememberDevice.toString());
    if (rememberDevice) {
      await _storage.write(key: _keyE2eKey, value: keyBase64);
    } else {
      await _storage.delete(key: _keyE2eKey);
    }
  }

  Future<void> clearE2eKey() async {
    await _storage.delete(key: _keyE2eKey);
    await _storage.delete(key: _keyE2eRemember);
  }

  Future<void> clearAllE2e() async {
    await _storage.delete(key: _keyE2eSalt);
    await _storage.delete(key: _keyE2eVerifier);
    await clearE2eKey();
  }
}

class E2eConfigData {
  final String? salt;
  final String? verifier;
  final String? savedKeyBase64;
  final bool rememberDevice;

  const E2eConfigData({
    this.salt,
    this.verifier,
    this.savedKeyBase64,
    this.rememberDevice = false,
  });

  bool get isConfigured =>
      salt != null && salt!.trim().isNotEmpty && verifier != null && verifier!.trim().isNotEmpty;
}
