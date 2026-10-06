# Folder Organization & Filter Chips Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement folder organization, 1-tap horizontal filter chips, folder pills on note cards, and folder selection in the note editor with full Supabase two-way synchronization.

**Architecture:** Extend `NotesListState` and `NotesListController` with folder filtering and custom folder persistence (`SharedPreferences`). Enhance `NoteEditorController` with folder assignment. Update `NotesListScreen`, `NoteCard`, and `NoteEditorScreen` to render modern folder navigation chips, badges, and bottom sheet pickers matching Valtera Note design tokens.

**Tech Stack:** Flutter 3.x, Dart ^3.9.2, Flutter Riverpod 3.3.2, SharedPreferences, SQLite, Supabase.

## Global Constraints
- Must match Valtera Note design tokens (`AppColors.emeraldAccent`, `AppColors.darkSurface`, `AppColors.darkSurfaceVariant`, `AppTypography`).
- Retain existing E2EE crypto and offline-first SQLite sync mechanics.
- Two-way compatibility with desktop `valtera-note` folder naming and `public.notes.folder` Supabase column.
- All existing and new tests must pass (`flutter test`).

---

### Task 1: Extend `NotesListState` & `NotesListController` for Folder Management

**Files:**
- Modify: `lib/features/notes/presentation/controllers/notes_list_controller.dart`
- Test: `test/features/notes/presentation/controllers/notes_list_controller_folder_test.dart`

**Interfaces:**
- Consumes: `Note` entity (`note.folder`), `NotesRepository`, `SharedPreferences`
- Produces:
  - `NotesListState`:
    - `String? selectedFolder`
    - `List<String> customFolders`
    - `List<String> get availableFolders`
    - `List<Note> get filteredNotes`
    - `List<Note> get pinnedFilteredNotes`
    - `List<Note> get otherFilteredNotes`
  - `NotesListController`:
    - `void selectFolder(String? folder)`
    - `Future<void> createFolder(String name)`
    - `Future<void> deleteFolder(String name)`

- [ ] **Step 1: Write unit tests for folder state and controller actions**

Create `test/features/notes/presentation/controllers/notes_list_controller_folder_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valtera_note/features/notes/domain/entities/note.dart';
import 'package:valtera_note/features/notes/domain/repositories/notes_repository.dart';
import 'package:valtera_note/features/notes/presentation/controllers/notes_list_controller.dart';
import 'package:valtera_note/features/sync/domain/sync_engine.dart';
import 'package:mocktail/mocktail.dart';

class MockNotesRepository extends Mock implements NotesRepository {}
class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('availableFolders includes defaults and notes folders', () {
    final note1 = Note(id: '1', title: 'A', folder: 'Work');
    final note2 = Note(id: '2', title: 'B', folder: 'Finance');
    final state = NotesListState(
      notes: [note1, note2],
      customFolders: ['Personal'],
    );

    expect(state.availableFolders.contains('Personal'), isTrue);
    expect(state.availableFolders.contains('Work'), isTrue);
    expect(state.availableFolders.contains('Finance'), isTrue);
    expect(state.availableFolders.contains('Projects'), isTrue);
  });

  test('filteredNotes returns only notes in selectedFolder', () {
    final note1 = Note(id: '1', title: 'A', folder: 'Work', isPinned: true);
    final note2 = Note(id: '2', title: 'B', folder: 'Personal', isPinned: false);
    final note3 = Note(id: '3', title: 'C', folder: null);

    final state = NotesListState(
      notes: [note1, note2, note3],
      selectedFolder: 'Work',
    );

    expect(state.filteredNotes.length, equals(1));
    expect(state.filteredNotes.first.id, equals('1'));
    expect(state.pinnedFilteredNotes.length, equals(1));
    expect(state.otherFilteredNotes.length, equals(0));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/presentation/controllers/notes_list_controller_folder_test.dart`
Expected: FAIL due to missing `customFolders`, `availableFolders`, `pinnedFilteredNotes`, etc.

- [ ] **Step 3: Implement folder logic in `NotesListState` & `NotesListController`**

Update `lib/features/notes/presentation/controllers/notes_list_controller.dart`:
- Define default folders: `['Personal', 'Work', 'Projects', 'SQL Queries']`.
- Add `selectedFolder` and `customFolders` in `NotesListState`.
- Add getters `availableFolders`, `filteredNotes`, `pinnedFilteredNotes`, `otherFilteredNotes`.
- Load custom folders from `SharedPreferences` in `NotesListController.build()` and provide `selectFolder`, `createFolder`, and `deleteFolder`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/presentation/controllers/notes_list_controller_folder_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/presentation/controllers/notes_list_controller.dart test/features/notes/presentation/controllers/notes_list_controller_folder_test.dart
git commit -m "feat(notes): add folder filtering and custom folder management to NotesListController"
```

---

### Task 2: Add Folder Support to `NoteEditorController`

**Files:**
- Modify: `lib/features/notes/presentation/controllers/note_editor_controller.dart`
- Test: `test/features/notes/presentation/controllers/note_editor_controller_folder_test.dart`

**Interfaces:**
- Consumes: `Note`
- Produces: `NoteEditorController.updateFolder(String? folder)`

- [ ] **Step 1: Write failing test for `updateFolder`**

Create `test/features/notes/presentation/controllers/note_editor_controller_folder_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:valtera_note/features/notes/domain/entities/note.dart';
import 'package:valtera_note/features/notes/domain/repositories/notes_repository.dart';
import 'package:valtera_note/features/notes/presentation/controllers/note_editor_controller.dart';
import 'package:valtera_note/features/sync/domain/sync_engine.dart';

class MockNotesRepository extends Mock implements NotesRepository {}
class MockSyncEngine extends Mock implements SyncEngine {}

void main() {
  test('updateFolder sets note folder and marks state dirty', () {
    final note = Note(id: 'test-1', title: 'Hello', folder: null);
    final state = NoteEditorState(note: note);
    expect(state.note.folder, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify failure / initial state**

Run: `flutter test test/features/notes/presentation/controllers/note_editor_controller_folder_test.dart`

- [ ] **Step 3: Implement `updateFolder(String? folder)` in `NoteEditorController`**

In `lib/features/notes/presentation/controllers/note_editor_controller.dart`:
```dart
void updateFolder(String? folder) {
  final updated = state.note.copyWith(
    folder: folder,
    updatedAt: DateTime.now().toUtc(),
    syncStatus: SyncStatus.local,
  );
  state = state.copyWith(note: updated, isDirty: true);
  _scheduleAutoSave();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/presentation/controllers/note_editor_controller_folder_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/presentation/controllers/note_editor_controller.dart test/features/notes/presentation/controllers/note_editor_controller_folder_test.dart
git commit -m "feat(editor): support updating note folder in NoteEditorController"
```

---

### Task 3: Display Folder Pill Badge on `NoteCard`

**Files:**
- Modify: `lib/features/notes/presentation/widgets/note_card.dart`
- Test: `test/features/notes/presentation/widgets/note_card_folder_test.dart`

**Interfaces:**
- Consumes: `note.folder`
- Produces: Pill badge widget rendered with folder icon and text when folder is present

- [ ] **Step 1: Write failing widget test for NoteCard folder badge**

Create `test/features/notes/presentation/widgets/note_card_folder_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/features/notes/domain/entities/note.dart';
import 'package:valtera_note/features/notes/presentation/widgets/note_card.dart';

void main() {
  testWidgets('NoteCard shows folder pill badge when folder is set', (tester) async {
    final note = Note(
      id: '1',
      title: 'Testing Folder',
      content: 'Sample content',
      folder: 'Work',
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

    expect(find.text('Work'), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/presentation/widgets/note_card_folder_test.dart`
Expected: FAIL because folder pill badge does not exist yet.

- [ ] **Step 3: Implement folder pill badge in `NoteCard`**

In `lib/features/notes/presentation/widgets/note_card.dart`:
Near the bottom row (alongside formatted date and sync dot), if `note.folder != null && note.folder!.isNotEmpty`, display:
```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(
    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightMuted,
    borderRadius: BorderRadius.circular(6),
    border: Border.all(
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      width: 0.5,
    ),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.folder_outlined,
        size: 11,
        color: isDark ? AppColors.emeraldAccent : AppColors.primary,
      ),
      const SizedBox(width: 3),
      Text(
        note.folder!,
        style: AppTypography.bodySmall(
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ).copyWith(fontSize: 10, fontWeight: FontWeight.w500),
      ),
    ],
  ),
)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/presentation/widgets/note_card_folder_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/presentation/widgets/note_card.dart test/features/notes/presentation/widgets/note_card_folder_test.dart
git commit -m "feat(ui): display folder pill badge on NoteCard"
```

---

### Task 4: Add Folder Filter Chips & New Folder Dialog to `NotesListScreen`

**Files:**
- Modify: `lib/features/notes/presentation/screens/notes_list_screen.dart`
- Test: `test/features/notes/presentation/screens/notes_list_screen_folder_test.dart`

**Interfaces:**
- Consumes: `notesListControllerProvider`, `state.availableFolders`, `state.selectedFolder`, `state.pinnedFilteredNotes`, `state.otherFilteredNotes`
- Produces:
  - Horizontal scrollable chip bar
  - New Folder dialog
  - Folder long-press deletion/manage dialog
  - Empty state when folder has 0 notes

- [ ] **Step 1: Write widget test for horizontal folder chip bar**

Create `test/features/notes/presentation/screens/notes_list_screen_folder_test.dart`:
Verify that chips for "Semua" and available folders render, and tapping a folder triggers `selectFolder`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/presentation/screens/notes_list_screen_folder_test.dart`

- [ ] **Step 3: Implement Horizontal Filter Chips & Folder Dialogs in `NotesListScreen`**

In `lib/features/notes/presentation/screens/notes_list_screen.dart`:
- Add `_buildFolderFilterBar(BuildContext context, WidgetRef ref, NotesListState state, bool isDark)`.
- Use `SingleChildScrollView(scrollDirection: Axis.horizontal, ...)`:
  - "Semua" chip with total note count badge.
  - Per-folder chips with note count badge for that folder.
  - "+ Folder" action chip at the end opening `_showNewFolderDialog`.
  - Handle chip selection via `ref.read(notesListControllerProvider.notifier).selectFolder(...)`.
  - Handle long-press on custom folder chip via `_showFolderOptionsDialog` (Rename / Hapus Folder).
- Update `_buildBody` to use `state.pinnedFilteredNotes` and `state.otherFilteredNotes`.
- If filtered notes are empty but `state.selectedFolder != null`, display a folder-specific empty view with a button to create a note inside this folder.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/presentation/screens/notes_list_screen_folder_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/presentation/screens/notes_list_screen.dart test/features/notes/presentation/screens/notes_list_screen_folder_test.dart
git commit -m "feat(ui): add horizontal folder filter chips and folder dialogs to NotesListScreen"
```

---

### Task 5: Add Folder Selector & Bottom Sheet to `NoteEditorScreen`

**Files:**
- Modify: `lib/features/notes/presentation/screens/note_editor_screen.dart`
- Test: `test/features/notes/presentation/screens/note_editor_screen_folder_test.dart`

**Interfaces:**
- Consumes: `noteEditorControllerProvider(noteId)`, `notesListControllerProvider`
- Produces: Folder picker button in editor + bottom sheet modal to choose or create a folder.

- [ ] **Step 1: Write test for editor folder picker**

Create `test/features/notes/presentation/screens/note_editor_screen_folder_test.dart`:
Verify folder selector chip appears and tapping it shows the folder list.

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/features/notes/presentation/screens/note_editor_screen_folder_test.dart`

- [ ] **Step 3: Implement Folder Selector & Bottom Sheet in `NoteEditorScreen`**

In `lib/features/notes/presentation/screens/note_editor_screen.dart`:
- Add a folder chip button right above the title or in the AppBar:
  - If `note.folder != null`: `[📁 {note.folder} ▼]`
  - If `note.folder == null`: `[📁 Pilih Folder ▼]`
- On tap, open `_showFolderPickerBottomSheet(context, ref, currentFolder)`:
  - Option "Tanpa Folder"
  - List of available folders from `notesListControllerProvider` with radio / check icon.
  - "+ Buat Folder Baru" text field / button to add on the fly and immediately select.
- When selected: call `ref.read(noteEditorControllerProvider(widget.noteId).notifier).updateFolder(selected)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/presentation/screens/note_editor_screen_folder_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/presentation/screens/note_editor_screen.dart test/features/notes/presentation/screens/note_editor_screen_folder_test.dart
git commit -m "feat(editor): add folder picker bottom sheet to NoteEditorScreen"
```

---

### Task 6: Full Verification & Integration Test

**Files:**
- Run full test suite: `flutter test`
- Verify existing 47+ tests still pass alongside all new folder tests.

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: 100% tests passing (0 failures).

- [ ] **Step 2: Final commit**

```bash
git commit -m "feat: complete folder organization and filtering support"
```
