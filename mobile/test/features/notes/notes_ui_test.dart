import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/features/notes/domain/entities/note.dart';
import 'package:valtera_note/features/notes/presentation/widgets/note_card.dart';

void main() {
  group('NoteCard Widget Tests', () {
    testWidgets('renders title, snippet, pin icon, and handles tap', (tester) async {
      bool tapped = false;
      bool pinToggled = false;

      final note = Note(
        id: 'test-1',
        title: 'Catatan Liburan',
        content: 'Rencana perjalanan ke pantai bersama keluarga.',
        isPinned: true,
        updatedAt: DateTime.utc(2026, 10, 5, 15, 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(
              note: note,
              onTap: () => tapped = true,
              onTogglePin: () => pinToggled = true,
            ),
          ),
        ),
      );

      expect(find.text('Catatan Liburan'), findsOneWidget);
      expect(find.text('Rencana perjalanan ke pantai bersama keluarga.'), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);

      await tester.tap(find.text('Catatan Liburan'));
      expect(tapped, isTrue);

      await tester.tap(find.byIcon(Icons.push_pin_rounded));
      expect(pinToggled, isTrue);
    });
  });
}
