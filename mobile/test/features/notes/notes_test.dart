import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valtera_note/features/notes/domain/entities/note.dart';
import 'package:valtera_note/features/notes/data/remote/notes_remote_data_source.dart';

void main() {
  group('Note Entity Serialization Tests', () {
    final now = DateTime.utc(2026, 10, 5, 12, 0, 0);
    final note = Note(
      id: 'uuid-1234',
      userId: 'user-9999',
      title: 'Catatan Rapat',
      content: 'Isi ringkasan rapat penting',
      fileExtension: 'md',
      folder: 'Kerja',
      isPinned: true,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
    );

    test('toMap and fromMap preserves all fields for SQLite', () {
      final map = note.toMap();
      expect(map['id'], 'uuid-1234');
      expect(map['user_id'], 'user-9999');
      expect(map['title'], 'Catatan Rapat');
      expect(map['is_pinned'], 1);
      expect(map['is_deleted'], 0);
      expect(map['sync_status'], 'synced');

      final reconstructed = Note.fromMap(map);
      expect(reconstructed.id, note.id);
      expect(reconstructed.title, note.title);
      expect(reconstructed.content, note.content);
      expect(reconstructed.isPinned, isTrue);
      expect(reconstructed.isDeleted, isFalse);
      expect(reconstructed.syncStatus, SyncStatus.synced);
    });

    test('toPostgresJson formats valid Supabase PostgREST payload', () {
      final json = note.toPostgresJson();
      expect(json['id'], 'uuid-1234');
      expect(json['title'], 'Catatan Rapat');
      expect(json['content'], 'Isi ringkasan rapat penting');
      expect(json['file_extension'], 'md');
      expect(json['folder'], 'Kerja');
      expect(json['is_pinned'], true);
      expect(json['is_deleted'], false);
      expect(json.containsKey('user_id'), isFalse); // user_id is assigned by Postgres auth.uid()
      expect(json['updated_at'], now.toUtc().toIso8601String());
    });

    test('fromPostgresJson handles null folder and missing defaults', () {
      final remoteJson = {
        'id': 'uuid-remote-555',
        'user_id': 'user-123',
        'title': 'Remote Title',
        'content': 'Remote Content',
        'file_extension': 'txt',
        'folder': null,
        'is_pinned': false,
        'is_deleted': false,
        'created_at': '2026-10-05T10:00:00.000Z',
        'updated_at': '2026-10-05T11:00:00.000Z',
      };

      final parsed = Note.fromPostgresJson(remoteJson);
      expect(parsed.id, 'uuid-remote-555');
      expect(parsed.title, 'Remote Title');
      expect(parsed.folder, isNull);
      expect(parsed.fileExtension, 'txt');
      expect(parsed.syncStatus, SyncStatus.synced);
    });
  });

  group('NotesRemoteDataSource Tests', () {
    test('fetchRemoteNotes parses array of remote notes', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/rest/v1/notes')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'note-1',
                'title': 'Catatan 1',
                'content': 'Isi 1',
                'file_extension': 'md',
                'folder': null,
                'is_pinned': false,
                'is_deleted': false,
                'created_at': '2026-10-05T10:00:00Z',
                'updated_at': '2026-10-05T10:00:00Z',
              }
            ]),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final dataSource = NotesRemoteDataSource(httpClient: mockClient);
      final list = await dataSource.fetchRemoteNotes(
        url: 'https://test.supabase.co',
        anonKey: 'anon-key',
        accessToken: 'access-token',
      );

      expect(list.length, 1);
      expect(list.first.id, 'note-1');
      expect(list.first.title, 'Catatan 1');
    });

    test('upsertRemoteNote sends valid payload and returns saved note', () async {
      final note = Note(
        id: 'note-new',
        title: 'New Note',
        content: 'New Content',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final mockClient = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.contains('/rest/v1/notes')) {
          expect(request.headers['Prefer'], contains('resolution=merge-duplicates'));
          return http.Response(
            jsonEncode([
              {
                'id': 'note-new',
                'title': 'New Note',
                'content': 'New Content',
                'file_extension': 'md',
                'folder': null,
                'is_pinned': false,
                'is_deleted': false,
                'created_at': '2026-10-05T10:00:00Z',
                'updated_at': '2026-10-05T10:00:00Z',
              }
            ]),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final dataSource = NotesRemoteDataSource(httpClient: mockClient);
      final saved = await dataSource.upsertRemoteNote(
        url: 'https://test.supabase.co',
        anonKey: 'anon-key',
        note: note,
        accessToken: 'access-token',
      );

      expect(saved.id, 'note-new');
      expect(saved.title, 'New Note');
    });
  });
}
