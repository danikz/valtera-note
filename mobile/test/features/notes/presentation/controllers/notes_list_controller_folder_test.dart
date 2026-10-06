import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/features/notes/domain/entities/note.dart';
import 'package:valtera_note/features/notes/presentation/controllers/notes_list_controller.dart';

void main() {
  group('NotesListState Folder Tests', () {
    test('availableFolders includes default folders, custom folders, and folders from notes', () {
      final note1 = Note(id: '1', title: 'Work Note', folder: 'Work');
      final note2 = Note(id: '2', title: 'Finance Note', folder: 'Finance');
      final note3 = Note(id: '3', title: 'No Folder Note', folder: null);

      final state = NotesListState(
        notes: [note1, note2, note3],
        customFolders: const ['Client ABC'],
      );

      final folders = state.availableFolders;

      // Default folders
      expect(folders.contains('Personal'), isTrue);
      expect(folders.contains('Work'), isTrue);
      expect(folders.contains('Projects'), isTrue);
      expect(folders.contains('SQL Queries'), isTrue);

      // Custom folders & note folders
      expect(folders.contains('Finance'), isTrue);
      expect(folders.contains('Client ABC'), isTrue);
    });

    test('filteredNotes returns only notes matching selectedFolder', () {
      final note1 = Note(id: '1', title: 'A', folder: 'Work', isPinned: true);
      final note2 = Note(id: '2', title: 'B', folder: 'Personal', isPinned: false);
      final note3 = Note(id: '3', title: 'C', folder: null, isPinned: false);

      final state = NotesListState(
        notes: [note1, note2, note3],
        selectedFolder: 'Work',
      );

      expect(state.filteredNotes.length, equals(1));
      expect(state.filteredNotes.first.id, equals('1'));
      expect(state.pinnedFilteredNotes.length, equals(1));
      expect(state.otherFilteredNotes.length, equals(0));
    });

    test('filteredNotes returns all notes when selectedFolder is null', () {
      final note1 = Note(id: '1', title: 'A', folder: 'Work', isPinned: true);
      final note2 = Note(id: '2', title: 'B', folder: 'Personal', isPinned: false);

      final state = NotesListState(
        notes: [note1, note2],
        selectedFolder: null,
      );

      expect(state.filteredNotes.length, equals(2));
      expect(state.pinnedFilteredNotes.length, equals(1));
      expect(state.otherFilteredNotes.length, equals(1));
    });

    test('countForFolder calculates accurate count', () {
      final note1 = Note(id: '1', title: 'A', folder: 'Work');
      final note2 = Note(id: '2', title: 'B', folder: 'Work');
      final note3 = Note(id: '3', title: 'C', folder: 'Personal');

      final state = NotesListState(
        notes: [note1, note2, note3],
      );

      expect(state.countForFolder(null), equals(3));
      expect(state.countForFolder('Work'), equals(2));
      expect(state.countForFolder('Personal'), equals(1));
      expect(state.countForFolder('EmptyFolder'), equals(0));
    });
  });
}
