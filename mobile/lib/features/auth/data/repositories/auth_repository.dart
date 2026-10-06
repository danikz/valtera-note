import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/storage/secure_storage_service.dart';
import '../../../setup/data/repositories/setup_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final storageService = ref.watch(secureStorageServiceProvider);
  return AuthRepository(storageService: storageService);
});

class AuthResult {
  final bool isSuccess;
  final String? email;
  final String? errorMessage;
  final bool isConfirmationSent;

  const AuthResult({
    required this.isSuccess,
    this.email,
    this.errorMessage,
    this.isConfirmationSent = false,
  });
}

class AuthRepository {
  final SecureStorageService _storageService;
  final http.Client _httpClient;

  AuthRepository({
    required SecureStorageService storageService,
    http.Client? httpClient,
  })  : _storageService = storageService,
        _httpClient = httpClient ?? http.Client();

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final config = await _storageService.getSupabaseConfig();
    if (!config.isConfigured) {
      return const AuthResult(
        isSuccess: false,
        errorMessage: 'Konfigurasi Supabase URL & Anon Key belum diatur',
      );
    }

    final cleanUrl = config.url!.trim().replaceAll(RegExp(r'/+$'), '');
    final cleanKey = config.anonKey!.trim();

    try {
      final uri = Uri.parse('$cleanUrl/auth/v1/token?grant_type=password');
      final res = await _httpClient.post(
        uri,
        headers: {
          'apikey': cleanKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;
        final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
        final user = data['user'] as Map<String, dynamic>?;
        final userEmail = user?['email'] as String? ?? email.trim();

        if (accessToken != null) {
          final expiresAt = DateTime.now().toUtc().add(Duration(seconds: expiresIn));
          await _storageService.saveAuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userEmail: userEmail,
            expiresAt: expiresAt,
          );

          final metadata = user?['user_metadata'] as Map<String, dynamic>?;
          if (metadata != null) {
            final salt = metadata['e2e_salt'] as String?;
            final verifier = metadata['e2e_verifier'] as String?;
            if (salt != null && verifier != null) {
              await _storageService.saveE2eConfig(salt: salt, verifier: verifier);
            }
          }

          return AuthResult(isSuccess: true, email: userEmail);
        }
      }

      final errorMsg = data['error_description'] ??
          data['msg'] ??
          data['message'] ??
          'Gagal melakukan login (HTTP ${res.statusCode})';

      return AuthResult(isSuccess: false, errorMessage: errorMsg.toString());
    } catch (e) {
      return AuthResult(
        isSuccess: false,
        errorMessage: 'Koneksi gagal atau timeout: $e',
      );
    }
  }

  Future<AuthResult> register({
    required String email,
    required String password,
  }) async {
    final config = await _storageService.getSupabaseConfig();
    if (!config.isConfigured) {
      return const AuthResult(
        isSuccess: false,
        errorMessage: 'Konfigurasi Supabase URL & Anon Key belum diatur',
      );
    }

    final cleanUrl = config.url!.trim().replaceAll(RegExp(r'/+$'), '');
    final cleanKey = config.anonKey!.trim();

    try {
      final uri = Uri.parse('$cleanUrl/auth/v1/signup');
      final res = await _httpClient.post(
        uri,
        headers: {
          'apikey': cleanKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final accessToken = data['access_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;
        final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
        final userEmail = data['email'] as String? ?? email.trim();

        if (accessToken != null) {
          final expiresAt = DateTime.now().toUtc().add(Duration(seconds: expiresIn));
          await _storageService.saveAuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userEmail: userEmail,
            expiresAt: expiresAt,
          );
        }

        final isConfirmationSent = data['confirmation_sent_at'] != null;

        return AuthResult(
          isSuccess: true,
          email: userEmail,
          isConfirmationSent: isConfirmationSent,
        );
      }

      final errorMsg = data['error_description'] ??
          data['msg'] ??
          data['message'] ??
          'Gagal melakukan registrasi (HTTP ${res.statusCode})';

      return AuthResult(isSuccess: false, errorMessage: errorMsg.toString());
    } catch (e) {
      return AuthResult(
        isSuccess: false,
        errorMessage: 'Koneksi gagal atau timeout: $e',
      );
    }
  }

  Future<AuthResult> recoverPassword({required String email}) async {
    final config = await _storageService.getSupabaseConfig();
    if (!config.isConfigured) {
      return const AuthResult(
        isSuccess: false,
        errorMessage: 'Konfigurasi Supabase URL & Anon Key belum diatur',
      );
    }

    final cleanUrl = config.url!.trim().replaceAll(RegExp(r'/+$'), '');
    final cleanKey = config.anonKey!.trim();

    try {
      final uri = Uri.parse('$cleanUrl/auth/v1/recover');
      final res = await _httpClient.post(
        uri,
        headers: {
          'apikey': cleanKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email.trim()}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return const AuthResult(isSuccess: true);
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final msg = data['error_description'] ?? data['msg'] ?? 'Gagal mengirim email reset';
      return AuthResult(isSuccess: false, errorMessage: msg.toString());
    } catch (e) {
      return AuthResult(isSuccess: false, errorMessage: 'Koneksi gagal: $e');
    }
  }

  Future<String?> getEffectiveToken() async {
    final session = await _storageService.getAuthSession();
    if (!session.isLoggedIn) return null;

    // Check if token expires within 2 minutes
    if (session.expiresAt != null && session.refreshToken != null) {
      final threshold = DateTime.now().toUtc().add(const Duration(seconds: 120));
      if (DateTime.now().toUtc().isAfter(session.expiresAt!) ||
          threshold.isAfter(session.expiresAt!)) {
        final refreshed = await refreshToken(session.refreshToken!);
        if (refreshed != null) return refreshed;
      }
    }

    return session.accessToken;
  }

  Future<String?> refreshToken(String refreshToken) async {
    final config = await _storageService.getSupabaseConfig();
    if (!config.isConfigured) return null;

    final cleanUrl = config.url!.trim().replaceAll(RegExp(r'/+$'), '');
    final cleanKey = config.anonKey!.trim();

    try {
      final uri = Uri.parse('$cleanUrl/auth/v1/token?grant_type=refresh_token');
      final res = await _httpClient.post(
        uri,
        headers: {
          'apikey': cleanKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String? ?? refreshToken;
        final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;

        if (newAccessToken != null) {
          final expiresAt = DateTime.now().toUtc().add(Duration(seconds: expiresIn));
          await _storageService.saveAuthSession(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
            expiresAt: expiresAt,
          );
          return newAccessToken;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> fetchUserMetadata() async {
    final config = await _storageService.getSupabaseConfig();
    final token = await getEffectiveToken();
    if (!config.isConfigured || token == null) return null;

    final cleanUrl = config.url!.trim().replaceAll(RegExp(r'/+$'), '');
    final cleanKey = config.anonKey!.trim();

    try {
      final uri = Uri.parse('$cleanUrl/auth/v1/user');
      final res = await _httpClient.get(
        uri,
        headers: {
          'apikey': cleanKey,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final metadata = data['user_metadata'] as Map<String, dynamic>?;
        if (metadata != null) {
          final salt = metadata['e2e_salt'] as String?;
          final verifier = metadata['e2e_verifier'] as String?;
          if (salt != null && verifier != null) {
            await _storageService.saveE2eConfig(salt: salt, verifier: verifier);
          }
        }
        return metadata;
      }
    } catch (_) {}
    return null;
  }

  Future<void> logout() async {
    await _storageService.clearAuthSession();
  }

  Future<AuthSessionData> getSession() async {
    return await _storageService.getAuthSession();
  }
}
