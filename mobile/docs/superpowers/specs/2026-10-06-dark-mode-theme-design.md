# Dark Mode & Theme Customization Design Specification

## Overview
This specification details the design and implementation of system-wide theme customization (Dark Mode, Light Mode, and System Default) for Valtera Note Android (`valtera-note-android`). It introduces persistent storage for the user's theme preference, dynamic reactive theme switching via Riverpod, a 1-tap quick toggle in the main screen's App Bar, and an appearance settings panel in the Settings screen.

---

## Architecture & Data Flow

### 1. Storage & Persistence (`SecureStorageService`)
- **Key:** `app_theme_mode`
- **Values:** `'system'`, `'light'`, `'dark'`
- **Methods:**
  - `Future<void> saveThemeMode(String mode)`: Writes string preference to local storage.
  - `Future<String?> getThemeMode()`: Reads stored preference string, returning null if unset.

### 2. State Management (`ThemeController`)
- **File:** `lib/core/theme/theme_controller.dart`
- **Provider:** `themeControllerProvider` (`NotifierProvider<ThemeController, ThemeMode>`)
- **Default State:** `ThemeMode.dark` (providing the sleek Emerald & Slate dark theme by default).
- **Initialization:** Loads stored preference asynchronously from `SecureStorageService`.
- **Actions:**
  - `Future<void> setThemeMode(ThemeMode mode)`: Updates state and persists the preference string.
  - `Future<void> toggleTheme(bool isCurrentlyDark)`: Quick toggle that switches to `ThemeMode.light` if currently dark, and `ThemeMode.dark` if currently light.

### 3. Application Root (`main.dart`)
- `ValteraNoteApp` listens to `themeControllerProvider`.
- Binds `themeMode: ref.watch(themeControllerProvider)` to `MaterialApp.router`.
- Automatically responds across all screens without reloading.

---

## User Interface & Interactions

### 1. Quick Toggle on Main Screen (`NotesListScreen`)
- **Location:** App Bar actions, positioned alongside the Search and Settings action icons.
- **Icon:**
  - If currently in dark mode: `Icons.light_mode_rounded` (tooltip: *"Beralih ke Mode Terang"*).
  - If currently in light mode: `Icons.dark_mode_rounded` (tooltip: *"Beralih ke Mode Gelap"*).
- **Action:** 1 tap invokes `ref.read(themeControllerProvider.notifier).toggleTheme(isDark)`.

### 2. Appearance Section in Settings (`SettingsScreen`)
- **Section Title:** `TAMPILAN & TEMA`
- **Component:** Elevated container containing a modern segmented button or option tiles:
  - ☀️ **Terang (Light)**
  - 🌙 **Gelap (Dark)**
  - 📱 **Sistem (System Default)**
- **Behavior:** Selection triggers immediate app-wide theme change and saves preference.

---

## Testing & Verification Plan
1. **Unit Tests:**
   - Test `ThemeController`: initialization from storage, `setThemeMode`, `toggleTheme`, and persistence.
2. **Widget Tests:**
   - Test `NotesListScreen` quick toggle changes app theme.
   - Test `SettingsScreen` theme selector triggers `setThemeMode`.
3. **Regression Tests:**
   - Run complete test suite (`flutter test`) ensuring all 58+ existing tests pass without failure.
