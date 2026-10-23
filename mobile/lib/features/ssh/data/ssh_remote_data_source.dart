import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/ssh_host.dart';

/// REST Supabase untuk tabel `ssh_connections` — payload yang dikirim selalu
/// apa adanya dari lokal (ciphertext E2E), server tidak melihat kredensial.
class SshRemoteDataSource {
  final http.Client _httpClient;

  SshRemoteDataSource({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Map<String, String> _headers(String anonKey, String? accessToken, {bool isUpsert = false}) {
    final token = (accessToken != null && accessToken.isNotEmpty) ? accessToken : anonKey;
    return {
      'apikey': anonKey,
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      if (isUpsert) 'Prefer': 'resolution=merge-duplicates,return=representation',
    };
  }

  String _clean(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');

  /// Termasuk tombstone (is_deleted) agar hapus di satu perangkat ikut ke semua.
  Future<List<SshConnectionRecord>> fetchAll({
    required String url,
    required String anonKey,
    String? accessToken,
  }) async {
    final uri = Uri.parse('${_clean(url)}/rest/v1/ssh_connections?select=*&order=updated_at.desc');
    final res = await _httpClient
        .get(uri, headers: _headers(anonKey, accessToken))
        .timeout(const Duration(seconds: 12));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Fetch ssh_connections gagal (HTTP ${res.statusCode}): ${res.body}');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => SshConnectionRecord.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<SshConnectionRecord> upsert({
    required String url,
    required String anonKey,
    required SshConnectionRecord record,
    String? accessToken,
  }) async {
    final uri = Uri.parse('${_clean(url)}/rest/v1/ssh_connections?on_conflict=id');
    final res = await _httpClient
        .post(
          uri,
          headers: _headers(anonKey, accessToken, isUpsert: true),
          body: jsonEncode({
            'id': record.id,
            'label': record.label,
            'payload': record.payload,
            'is_deleted': false,
            'updated_at': record.updatedAt.toUtc().toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Upsert ssh_connections gagal (HTTP ${res.statusCode}): ${res.body}');
    }
    final body = jsonDecode(res.body);
    if (body is List && body.isNotEmpty) {
      return SshConnectionRecord.fromMap(body.first as Map<String, dynamic>);
    }
    return record;
  }

  Future<void> softDelete({
    required String url,
    required String anonKey,
    required String id,
    String? accessToken,
  }) async {
    final uri = Uri.parse(
        '${_clean(url)}/rest/v1/ssh_connections?id=eq.${Uri.encodeQueryComponent(id)}');
    final res = await _httpClient
        .patch(
          uri,
          headers: _headers(anonKey, accessToken),
          body: jsonEncode({
            'is_deleted': true,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Hapus ssh_connections gagal (HTTP ${res.statusCode}): ${res.body}');
    }
  }
}
