import '../entities/note.dart';

abstract class NotesRepository {
  Future<List<Note>> getNotes();
  Future<Note?> getNoteById(String id);
  Future<void> saveNote(Note note);
  Future<void> deleteNote(String id);
  Future<void> togglePin(String id);
  Future<List<Note>> searchNotes(String query);
}
