import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/features/notes/domain/entities/note.dart';
import 'package:valtera_note/features/notes/presentation/controllers/notes_list_controller.dart';
import 'package:valtera_note/features/notes/presentation/screens/notes_list_screen.dart';

class TestNotesListController extends NotesListController {
  final List<Note> initialNotes;
  final List<String> initialCustomFolders;

  TestNotesListController(this.initialNotes, {this.initialCustomFolders = const []});

  @override
  NotesListState build() {
    return NotesListState(
      isLoading: false,
      notes: initialNotes,
      customFolders: initialCustomFolders,
    );
  }

  @override
  void selectFolder(String? folder) {
    state = state.copyWith(
      selectedFolder: folder,
      clearSelectedFolder: folder == null,
    );
  }
}

void main() {
  testWidgets('NotesListScreen displays folder chips and filters notes when tapped', (tester) async {
    final notes = [
      Note(id: '1', title: 'Work Memo', folder: 'Work'),
      Note(id: '2', title: 'Personal Diary', folder: 'Personal'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesListControllerProvider.overrideWith(
            () => TestNotesListController(notes),
          ),
        ],
        child: const MaterialApp(
          home: NotesListScreen(),
        ),
      ),
    );

    // Filter bar should contain 'Semua' and folders
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Work'), findsWidgets); // chip + badge in card
    expect(find.text('Personal'), findsWidgets); // chip + badge in card

    // Both notes should be visible initially
    expect(find.text('Work Memo'), findsOneWidget);
    expect(find.text('Personal Diary'), findsOneWidget);

    // Tap on 'Work' folder chip
    await tester.tap(find.widgetWithText(InkWell, 'Work').first);
    await tester.pumpAndSettle();

    // Now only Work Memo should be visible
    expect(find.text('Work Memo'), findsOneWidget);
    expect(find.text('Personal Diary'), findsNothing);

    // Tap back on 'Semua' chip
    await tester.tap(find.widgetWithText(InkWell, 'Semua'));
    await tester.pumpAndSettle();

    // Both visible again
    expect(find.text('Work Memo'), findsOneWidget);
    expect(find.text('Personal Diary'), findsOneWidget);
  });
}
