import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/storage/secure_storage_service.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return const SecureStorageService();
});

final setupRepositoryProvider = Provider<SetupRepository>((ref) {
  final storageService = ref.watch(secureStorageServiceProvider);
  return SetupRepository(storageService: storageService);
});

class SetupConnectionResult {
  final bool isSuccess;
  final bool isTableReady;
  final String message;

  const SetupConnectionResult({
    required this.isSuccess,
    required this.isTableReady,
    required this.message,
  });
}

class SetupRepository {
  final SecureStorageService _storageService;
  final http.Client _httpClient;

  SetupRepository({
    required SecureStorageService storageService,
    http.Client? httpClient,
  })  : _storageService = storageService,
        _httpClient = httpClient ?? http.Client();

  String? validateUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return 'Supabase URL wajib diisi';
    }
    final trimmed = url.trim();
    if (!trimmed.startsWith('https://')) {
      return 'URL harus menggunakan HTTPS';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority || !uri.host.contains('.')) {
      return 'Format URL Supabase tidak valid';
    }
    return null;
  }

  String? validateAnonKey(String? key) {
    if (key == null || key.trim().isEmpty) {
      return 'Anon key wajib diisi';
    }
    final trimmed = key.trim();

    // Check if key is a JWT with service_role
    try {
      final parts = trimmed.split('.');
      if (parts.length == 3) {
        String normalized = parts[1];
        while (normalized.length % 4 != 0) {
          normalized += '=';
        }
        final decoded = utf8.decode(base64Url.decode(normalized));
        if (decoded.contains('"role":"service_role"') ||
            decoded.contains('"role": "service_role"')) {
          return 'Service Role Key tidak boleh digunakan demi keamanan. Gunakan anon public key.';
        }
      }
    } catch (_) {
      // In case key format is not standard JWT, continue with normal validation
    }
    return null;
  }

  Future<SetupConnectionResult> testConnection({
    required String url,
    required String anonKey,
  }) async {
    final cleanUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final cleanKey = anonKey.trim();

    try {
      // 1. Health check auth endpoint
      final healthUri = Uri.parse('$cleanUrl/auth/v1/health');
      final healthRes = await _httpClient.get(
        healthUri,
        headers: {'apikey': cleanKey},
      ).timeout(const Duration(seconds: 10));

      if (healthRes.statusCode != 200) {
        return SetupConnectionResult(
          isSuccess: false,
          isTableReady: false,
          message: 'Gagal terhubung ke Supabase Auth (HTTP ${healthRes.statusCode}). Pastikan URL dan Anon Key benar.',
        );
      }

      // 2. Query table notes
      final notesUri = Uri.parse('$cleanUrl/rest/v1/notes?select=id&limit=1');
      final notesRes = await _httpClient.get(
        notesUri,
        headers: {
          'apikey': cleanKey,
          'Authorization': 'Bearer $cleanKey',
        },
      ).timeout(const Duration(seconds: 10));

      if (notesRes.statusCode >= 200 && notesRes.statusCode < 300) {
        return const SetupConnectionResult(
          isSuccess: true,
          isTableReady: true,
          message: 'Koneksi ke Supabase berhasil terhubung dan tabel notes siap!',
        );
      } else {
        final body = notesRes.body;
        if (body.contains('42P01') ||
            body.contains('does not exist') ||
            body.contains('PGRST204') ||
            body.contains('PGRST205')) {
          return const SetupConnectionResult(
            isSuccess: true,
            isTableReady: false,
            message: "Koneksi ke Supabase berhasil! (Tabel 'notes' belum dibuat di SQL Editor).",
          );
        } else {
          return SetupConnectionResult(
            isSuccess: true,
            isTableReady: true,
            message: 'Koneksi ke Supabase berhasil terhubung!',
          );
        }
      }
    } catch (e) {
      return SetupConnectionResult(
        isSuccess: false,
        isTableReady: false,
        message: 'Tidak dapat menghubungi server Supabase: $e',
      );
    }
  }

  Future<void> saveConfig({
    required String url,
    required String anonKey,
  }) async {
    await _storageService.saveSupabaseConfig(
      url: url.trim().replaceAll(RegExp(r'/+$'), ''),
      anonKey: anonKey.trim(),
    );
  }

  Future<SupabaseConfigData> getConfig() async {
    return await _storageService.getSupabaseConfig();
  }

  Future<void> disconnect() async {
    await _storageService.clearSupabaseConfig();
  }
}
