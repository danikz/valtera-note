import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/notes_repository.dart';
import '../local/notes_local_data_source.dart';
import '../remote/notes_remote_data_source.dart';

final notesLocalDataSourceProvider = Provider<NotesLocalDataSource>((ref) {
  return NotesLocalDataSource();
});

final notesRemoteDataSourceProvider = Provider<NotesRemoteDataSource>((ref) {
  return NotesRemoteDataSource();
});

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final local = ref.watch(notesLocalDataSourceProvider);
  final remote = ref.watch(notesRemoteDataSourceProvider);
  return NotesRepositoryImpl(localDataSource: local, remoteDataSource: remote);
});

class NotesRepositoryImpl implements NotesRepository {
  final NotesLocalDataSource _local;
  final NotesRemoteDataSource _remote;

  NotesRepositoryImpl({
    required NotesLocalDataSource localDataSource,
    required NotesRemoteDataSource remoteDataSource,
  })  : _local = localDataSource,
        _remote = remoteDataSource;

  NotesRemoteDataSource get remoteDataSource => _remote;

  @override
  Future<List<Note>> getNotes() async {
    return await _local.getAllNotes();
  }

  @override
  Future<Note?> getNoteById(String id) async {
    return await _local.getNoteById(id);
  }

  @override
  Future<void> saveNote(Note note) async {
    // Local-first: write immediately into SQLite
    await _local.upsertNote(note);
  }

  @override
  Future<void> deleteNote(String id) async {
    await _local.deleteNote(id);
  }

  @override
  Future<void> togglePin(String id) async {
    await _local.togglePin(id);
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    return await _local.searchNotes(query);
  }
}
