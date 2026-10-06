import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/features/notes/domain/entities/note.dart';
import 'package:valtera_note/features/notes/presentation/widgets/note_card.dart';

void main() {
  testWidgets('NoteCard displays folder badge with icon when folder is provided', (tester) async {
    final note = Note(
      id: 'note-folder-1',
      title: 'Finance Report',
      content: 'Important financial figures',
      folder: 'Finance',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteCard(
            note: note,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Finance'), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
  });

  testWidgets('NoteCard does NOT display folder badge when folder is null', (tester) async {
    final note = Note(
      id: 'note-folder-2',
      title: 'Quick Note',
      content: 'No folder here',
      folder: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteCard(
            note: note,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.folder_outlined), findsNothing);
  });
}
