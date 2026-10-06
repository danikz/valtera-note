import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/features/notes/domain/entities/note.dart';
import 'package:valtera_note/features/notes/domain/repositories/notes_repository.dart';
import 'package:valtera_note/features/notes/presentation/controllers/note_editor_controller.dart';
import 'package:valtera_note/features/notes/data/repositories/notes_repository_impl.dart';
import 'package:valtera_note/features/sync/domain/sync_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FakeNotesRepository implements NotesRepository {
  Note? savedNote;
  @override
  Future<void> deleteNote(String id) async {}
  @override
  Future<Note?> getNoteById(String id) async => null;
  @override
  Future<List<Note>> getNotes() async => [];
  @override
  Future<void> saveNote(Note note) async {
    savedNote = note;
  }
  @override
  Future<List<Note>> searchNotes(String query) async => [];
  @override
  Future<void> togglePin(String id) async {}
}

class FakeSyncEngine implements SyncEngine {
  @override
  SyncStatusInfo get currentStatus => const SyncStatusInfo();
  @override
  Stream<SyncStatusInfo> get statusStream => const Stream.empty();
  @override
  Future<void> syncAll({bool silent = false}) async {}
  @override
  Future<void> enqueueAndSync({required Note note, required String operation}) async {}
  @override
  Future<int> decryptExistingLocalNotes(List<int> keyBytes) async => 0;
  @override
  void dispose() {}
}

void main() {
  test('Note.copyWith clears folder when clearFolder is true', () {
    final note = Note(id: '1', title: 'Test', folder: 'Work');
    final cleared = note.copyWith(clearFolder: true);
    expect(cleared.folder, isNull);
  });

  test('NoteEditorController.updateFolder updates folder and marks state dirty', () {
    final fakeRepo = FakeNotesRepository();
    final fakeSync = FakeSyncEngine();

    final container = ProviderContainer(
      overrides: [
        notesRepositoryProvider.overrideWithValue(fakeRepo),
        syncEngineProvider.overrideWithValue(fakeSync),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(noteEditorControllerProvider('new').notifier);
    expect(container.read(noteEditorControllerProvider('new')).note.folder, isNull);

    controller.updateFolder('Projects');
    expect(container.read(noteEditorControllerProvider('new')).note.folder, equals('Projects'));
    expect(container.read(noteEditorControllerProvider('new')).isDirty, isTrue);

    controller.updateFolder(null);
    expect(container.read(noteEditorControllerProvider('new')).note.folder, isNull);
  });
}
