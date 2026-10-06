import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/features/notes/domain/entities/note.dart';
import 'package:valtera_note/features/notes/presentation/controllers/notes_list_controller.dart';
import 'package:valtera_note/features/notes/presentation/screens/notes_list_screen.dart';

void main() {
  testWidgets('NotesListScreen displays notes and fab', (tester) async {
    final testNotes = [
      Note(
        id: 'test-1',
        title: 'Catatan Penting',
        content: 'Konten penting',
        isPinned: true,
      ),
      Note(
        id: 'test-2',
        title: 'Catatan Biasa',
        content: 'Konten biasa',
        isPinned: false,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesListControllerProvider.overrideWith(() => FakeNotesListController(testNotes)),
        ],
        child: const MaterialApp(
          home: NotesListScreen(),
        ),
      ),
    );

    expect(find.text('Valtera Note'), findsOneWidget);
    expect(find.text('DISEMATKAN'), findsOneWidget);
    expect(find.text('Catatan Penting'), findsOneWidget);
    expect(find.text('Catatan Biasa'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FloatingActionButton),
        matching: find.byIcon(Icons.add_rounded),
      ),
      findsOneWidget,
    );
  });
}

class FakeNotesListController extends NotesListController {
  final List<Note> initialNotes;

  FakeNotesListController(this.initialNotes);

  @override
  NotesListState build() {
    return NotesListState(isLoading: false, notes: initialNotes);
  }
}
