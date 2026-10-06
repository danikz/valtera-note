import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/features/notes/domain/entities/note.dart';
import 'package:valtera_note/features/notes/presentation/controllers/note_editor_controller.dart';
import 'package:valtera_note/features/notes/presentation/controllers/notes_list_controller.dart';
import 'package:valtera_note/features/notes/presentation/screens/note_editor_screen.dart';

class TestNoteEditorController extends NoteEditorController {
  final Note initialNote;
  TestNoteEditorController(this.initialNote) : super(initialNote.id);

  @override
  NoteEditorState build() {
    return NoteEditorState(note: initialNote);
  }

  @override
  void updateFolder(String? folder) {
    state = state.copyWith(
      note: state.note.copyWith(folder: folder, clearFolder: folder == null),
      isDirty: true,
    );
  }
}

class TestNotesListController extends NotesListController {
  @override
  NotesListState build() {
    return const NotesListState(
      customFolders: ['Personal', 'Work'],
    );
  }
}

void main() {
  testWidgets('NoteEditorScreen displays current folder and allows opening picker', (tester) async {
    final testNote = Note(
      id: 'test-editor-1',
      title: 'Meeting Notes',
      folder: 'Work',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteEditorControllerProvider('test-editor-1').overrideWith(
            () => TestNoteEditorController(testNote),
          ),
          notesListControllerProvider.overrideWith(
            () => TestNotesListController(),
          ),
        ],
        child: const MaterialApp(
          home: NoteEditorScreen(noteId: 'test-editor-1'),
        ),
      ),
    );

    // Folder chip should display 'Work'
    expect(find.text('Work'), findsOneWidget);

    // Tap folder chip
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    // Bottom sheet should open showing 'Pilih Folder' and 'Tanpa Folder'
    expect(find.text('Pilih Folder'), findsOneWidget);
    expect(find.text('Tanpa Folder'), findsOneWidget);
  });

  testWidgets('NoteEditorScreen displays "Pilih Folder" when note has no folder', (tester) async {
    final testNote = Note(
      id: 'test-editor-2',
      title: 'Draft',
      folder: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteEditorControllerProvider('test-editor-2').overrideWith(
            () => TestNoteEditorController(testNote),
          ),
          notesListControllerProvider.overrideWith(
            () => TestNotesListController(),
          ),
        ],
        child: const MaterialApp(
          home: NoteEditorScreen(noteId: 'test-editor-2'),
        ),
      ),
    );

    expect(find.text('Pilih Folder'), findsOneWidget);
  });
}
