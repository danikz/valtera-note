# Dark Mode & Theme Customization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement full system-wide Dark Mode & Light Mode customization with persistent storage, a 1-tap AppBar quick toggle on the main screen, and an appearance selection card in Settings.

**Architecture:** Extend `SecureStorageService` to persist `ThemeMode` (`'dark'`, `'light'`, `'system'`). Create `ThemeController` (`NotifierProvider<ThemeController, ThemeMode>`) defaulting to dark mode. Bind `themeControllerProvider` to `MaterialApp.router` in `lib/main.dart`. Add a quick toggle button to `NotesListScreen`'s AppBar and an appearance options card in `SettingsScreen`.

**Tech Stack:** Flutter 3.x, Dart ^3.9.2, Flutter Riverpod 3.3.2, FlutterSecureStorage.

## Global Constraints
- Use existing `AppTheme.darkTheme` and `AppTheme.lightTheme` definitions.
- Default to `ThemeMode.dark` on fresh launch.
- Persist user preference across app restarts via `SecureStorageService`.
- 100% test pass rate on all existing (58) and new tests.

---

### Task 1: Add Theme Persistence to `SecureStorageService` & Implement `ThemeController`

**Files:**
- Modify: `lib/core/storage/secure_storage_service.dart`
- Create: `lib/core/theme/theme_controller.dart`
- Test: `test/core/theme/theme_controller_test.dart`

**Interfaces:**
- `SecureStorageService`:
  - `Future<void> saveThemeMode(String mode)`
  - `Future<String?> getThemeMode()`
- `ThemeController`:
  - `ThemeMode build()`
  - `Future<void> setThemeMode(ThemeMode mode)`
  - `Future<void> toggleTheme(bool isCurrentlyDark)`

- [ ] **Step 1: Write failing unit test for `ThemeController`**

Create `test/core/theme/theme_controller_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valtera_note/core/storage/secure_storage_service.dart';
import 'package:valtera_note/core/theme/theme_controller.dart';
import 'package:valtera_note/features/setup/data/repositories/setup_repository.dart';

class FakeSecureStorageService extends SecureStorageService {
  String? storedTheme;
  @override
  Future<void> saveThemeMode(String mode) async {
    storedTheme = mode;
  }
  @override
  Future<String?> getThemeMode() async {
    return storedTheme;
  }
}

void main() {
  test('ThemeController defaults to ThemeMode.dark', () {
    final fakeStorage = FakeSecureStorageService();
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(fakeStorage),
      ],
    );
    addTearDown(container.dispose);

    final theme = container.read(themeControllerProvider);
    expect(theme, equals(ThemeMode.dark));
  });

  test('setThemeMode updates state and persists choice', () async {
    final fakeStorage = FakeSecureStorageService();
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(fakeStorage),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(themeControllerProvider.notifier);
    await controller.setThemeMode(ThemeMode.light);

    expect(container.read(themeControllerProvider), equals(ThemeMode.light));
    expect(fakeStorage.storedTheme, equals('light'));
  });

  test('toggleTheme switches between dark and light', () async {
    final fakeStorage = FakeSecureStorageService();
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(fakeStorage),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(themeControllerProvider.notifier);
    await controller.toggleTheme(true); // currently dark -> should switch to light
    expect(container.read(themeControllerProvider), equals(ThemeMode.light));

    await controller.toggleTheme(false); // currently light -> should switch to dark
    expect(container.read(themeControllerProvider), equals(ThemeMode.dark));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/theme_controller_test.dart`
Expected: FAIL due to missing `theme_controller.dart` and storage methods.

- [ ] **Step 3: Implement storage methods and `ThemeController`**

In `lib/core/storage/secure_storage_service.dart`:
- Add `_keyThemeMode = 'app_theme_mode'`.
- Implement `saveThemeMode(String mode)` and `getThemeMode()`.

In `lib/core/theme/theme_controller.dart`:
- Implement `ThemeController extends Notifier<ThemeMode>`.
- Export `themeControllerProvider`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/theme_controller_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/storage/secure_storage_service.dart lib/core/theme/theme_controller.dart test/core/theme/theme_controller_test.dart
git commit -m "feat(theme): implement ThemeController and persistent theme storage"
```

---

### Task 2: Connect `ThemeController` to `ValteraNoteApp` in `lib/main.dart`

**Files:**
- Modify: `lib/main.dart`
- Test: `test/features/setup/setup_screen_test.dart`

**Interfaces:**
- Consumes: `themeControllerProvider`
- Produces: `MaterialApp.router(themeMode: ref.watch(themeControllerProvider))`

- [ ] **Step 1: Check existing main.dart usage**

Verify `lib/main.dart` connects `ref.watch(themeControllerProvider)` to `MaterialApp.router`.

- [ ] **Step 2: Update `lib/main.dart`**

Modify `lib/main.dart`:
```dart
import 'core/theme/theme_controller.dart';
...
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeControllerProvider);

    return MaterialApp.router(
      title: 'Valtera Note',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
```

- [ ] **Step 3: Run existing app startup tests to verify it passes**

Run: `flutter test test/features/setup/setup_screen_test.dart`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat(theme): connect themeControllerProvider to MaterialApp in main.dart"
```

---

### Task 3: Add Quick Theme Toggle Icon to `NotesListScreen` AppBar

**Files:**
- Modify: `lib/features/notes/presentation/screens/notes_list_screen.dart`
- Test: `test/features/notes/presentation/screens/notes_list_screen_theme_test.dart`

**Interfaces:**
- Consumes: `themeControllerProvider`, `isDark`
- Produces: Quick toggle `IconButton` in AppBar actions

- [ ] **Step 1: Write failing widget test for quick theme toggle**

Create `test/features/notes/presentation/screens/notes_list_screen_theme_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/core/theme/theme_controller.dart';
import 'package:valtera_note/features/notes/domain/entities/note.dart';
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
        child: const MaterialApp(
          home: NotesListScreen(),
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/presentation/screens/notes_list_screen_theme_test.dart`
Expected: FAIL because theme toggle button doesn't exist yet in AppBar.

- [ ] **Step 3: Implement Quick Toggle in `NotesListScreen` AppBar**

In `lib/features/notes/presentation/screens/notes_list_screen.dart`:
Add `IconButton` in `AppBar.actions`:
```dart
IconButton(
  icon: Icon(
    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
  ),
  tooltip: isDark ? 'Beralih ke Mode Terang' : 'Beralih ke Mode Gelap',
  onPressed: () {
    ref.read(themeControllerProvider.notifier).toggleTheme(isDark);
  },
),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/presentation/screens/notes_list_screen_theme_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/notes/presentation/screens/notes_list_screen.dart test/features/notes/presentation/screens/notes_list_screen_theme_test.dart
git commit -m "feat(ui): add quick theme toggle button to NotesListScreen AppBar"
```

---

### Task 4: Add Appearance Section (`TAMPILAN & TEMA`) to `SettingsScreen`

**Files:**
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`
- Test: `test/features/settings/settings_screen_theme_test.dart`

**Interfaces:**
- Consumes: `themeControllerProvider`
- Produces: Theme selector card in Settings

- [ ] **Step 1: Write failing test for SettingsScreen theme section**

Create `test/features/settings/settings_screen_theme_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/core/theme/theme_controller.dart';
import 'package:valtera_note/features/settings/presentation/screens/settings_screen.dart';

class MockThemeController extends ThemeController {
  ThemeMode current = ThemeMode.dark;
  @override
  ThemeMode build() => current;
  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    current = mode;
    state = mode;
  }
}

void main() {
  testWidgets('SettingsScreen displays theme options', (tester) async {
    final mockTheme = MockThemeController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeControllerProvider.overrideWith(() => mockTheme),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    expect(find.text('TAMPILAN & TEMA'), findsOneWidget);
    expect(find.text('Terang'), findsOneWidget);
    expect(find.text('Gelap'), findsOneWidget);
    expect(find.text('Ikuti Sistem'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/settings_screen_theme_test.dart`
Expected: FAIL because 'TAMPILAN & TEMA' section does not exist yet.

- [ ] **Step 3: Implement Appearance Section in `SettingsScreen`**

In `lib/features/settings/presentation/screens/settings_screen.dart`:
Add section `_buildThemeSection(isDark, themeMode)` with 3 selectable options (Terang, Gelap, Ikuti Sistem) connecting to `ref.read(themeControllerProvider.notifier).setThemeMode(mode)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/settings_screen_theme_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/screens/settings_screen.dart test/features/settings/settings_screen_theme_test.dart
git commit -m "feat(settings): add appearance and theme selection card in SettingsScreen"
```

---

### Task 5: Full Verification & Integration Test

**Files:**
- Run complete test suite: `flutter test`

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: 100% tests passing (all 60+ tests green).

- [ ] **Step 2: Final commit**

```bash
git commit -m "feat: complete dark mode and theme customization support"
```
