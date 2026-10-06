import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/core/theme/theme_controller.dart';
import 'package:valtera_note/features/notes/presentation/controllers/notes_list_controller.dart';
import 'package:valtera_note/features/notes/presentation/screens/notes_list_screen.dart';

class MockThemeController extends ThemeController {
  ThemeMode current = ThemeMode.dark;
  @override
  ThemeMode build() => current;
  @override
  Future<void> toggleTheme(bool isCurrentlyDark) async {
    current = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
    state = current;
  }
}

class FakeNotesListController extends NotesListController {
  @override
  NotesListState build() => const NotesListState();
}

void main() {
  testWidgets('NotesListScreen has quick theme toggle button in AppBar', (tester) async {
    final mockTheme = MockThemeController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeControllerProvider.overrideWith(() => mockTheme),
          notesListControllerProvider.overrideWith(() => FakeNotesListController()),
        ],
        child: MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: ThemeMode.dark,
          home: const NotesListScreen(),
        ),
      ),
    );

    // In dark mode, toggle button shows light_mode icon to switch to light
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.light_mode_rounded));
    await tester.pumpAndSettle();

    expect(mockTheme.current, equals(ThemeMode.light));
  });
}
