import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/note.dart';

class NotesRemoteDataSource {
  final http.Client _httpClient;

  NotesRemoteDataSource({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Map<String, String> _buildHeaders(String anonKey, String? accessToken, {bool isUpsert = false}) {
    final token = (accessToken != null && accessToken.isNotEmpty) ? accessToken : anonKey;
    final headers = {
      'apikey': anonKey,
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    if (isUpsert) {
      headers['Prefer'] = 'resolution=merge-duplicates,return=representation';
    }
    return headers;
  }

  Future<List<Note>> fetchRemoteNotes({
    required String url,
    required String anonKey,
    String? accessToken,
  }) async {
    final cleanUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$cleanUrl/rest/v1/notes?select=*&order=updated_at.desc');

    final res = await _httpClient.get(
      uri,
      headers: _buildHeaders(anonKey, accessToken),
    ).timeout(const Duration(seconds: 12));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List<dynamic>;
      return list.map((item) => Note.fromPostgresJson(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Fetch remote notes failed (HTTP ${res.statusCode}): ${res.body}');
    }
  }

  Future<Note> upsertRemoteNote({
    required String url,
    required String anonKey,
    required Note note,
    String? accessToken,
  }) async {
    final cleanUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$cleanUrl/rest/v1/notes?on_conflict=id');

    final payload = note.toPostgresJson();
    // Always refresh updated_at on remote write
    payload['updated_at'] = DateTime.now().toUtc().toIso8601String();

    final res = await _httpClient.post(
      uri,
      headers: _buildHeaders(anonKey, accessToken, isUpsert: true),
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 12));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body);
      if (body is List && body.isNotEmpty) {
        return Note.fromPostgresJson(body.first as Map<String, dynamic>);
      } else if (body is Map<String, dynamic>) {
        return Note.fromPostgresJson(body);
      }
      return note.copyWith(syncStatus: SyncStatus.synced);
    } else {
      throw Exception('Upsert remote note failed (HTTP ${res.statusCode}): ${res.body}');
    }
  }

  Future<void> deleteRemoteNote({
    required String url,
    required String anonKey,
    required String id,
    String? accessToken,
  }) async {
    final cleanUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$cleanUrl/rest/v1/notes?id=eq.$id');

    // 1. Try hard delete first
    final deleteRes = await _httpClient.delete(
      uri,
      headers: _buildHeaders(anonKey, accessToken),
    ).timeout(const Duration(seconds: 10));

    if (deleteRes.statusCode >= 200 && deleteRes.statusCode < 300) {
      return;
    }

    // 2. Fallback: Soft delete by setting is_deleted = true if DELETE restricted by RLS
    final patchRes = await _httpClient.patch(
      uri,
      headers: _buildHeaders(anonKey, accessToken),
      body: jsonEncode({
        'is_deleted': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }),
    ).timeout(const Duration(seconds: 10));

    if (patchRes.statusCode < 200 || patchRes.statusCode >= 300) {
      throw Exception('Delete remote note failed (HTTP ${patchRes.statusCode}): ${patchRes.body}');
    }
  }
}
