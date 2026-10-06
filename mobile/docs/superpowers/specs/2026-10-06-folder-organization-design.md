# Folder Organization & Filter Chips Design Specification

## Overview
This specification details the design and implementation of the Folder Organization & Navigation feature for the Valtera Note Android application (`valtera-note-android`). It aligns the mobile app with the desktop client (`valtera-note`), allowing users to categorize, filter, and manage notes by folder while maintaining two-way synchronization via Supabase.

---

## Architecture & Data Model

### 1. Folder Data Source & Persistence
- **Default Folders:** Identical to the desktop defaults: `['Personal', 'Work', 'Projects', 'SQL Queries']`.
- **Dynamic Folders:** Extracted automatically from existing local and synced `Note.folder` values.
- **Custom Folders Persistence:** Managed via `SharedPreferences` (key: `custom_folders`), ensuring folders without notes do not disappear across app restarts.
- **Entity Compatibility:** The `Note` entity already includes `final String? folder;`, which maps to SQLite column `folder` and PostgreSQL column `folder`. No database schema migration is required.

### 2. State Management

#### `NotesListState`
- `selectedFolder`: `String?`
  - `null`: "Semua" (All notes displayed).
  - Non-null `String`: Filters notes where `note.folder == selectedFolder`.
- `customFolders`: `List<String>`
- `availableFolders`: `List<String>` (Sorted, deduplicated combination of default, custom, and note folders).
- `filteredNotes`: `List<Note>` (Filtered by `selectedFolder` and search query if applicable).
- `pinnedFilteredNotes`: `List<Note>` (Pinned subset of filtered notes).
- `otherFilteredNotes`: `List<Note>` (Unpinned subset of filtered notes).

#### `NotesListController`
- `selectFolder(String? folder)`: Sets the active filter.
- `createFolder(String name)`: Validates name, adds to custom folders in `SharedPreferences`, and notifies state.
- `deleteFolder(String name)`: Removes folder from custom folders and updates all notes in that folder to `folder: null`, enqueuing sync updates.

#### `NoteEditorController`
- `updateFolder(String? folder)`: Updates the current note's folder, marks editor state as dirty, and schedules auto-save/sync.

---

## User Interface & Interactions

### 1. Main Screen (`NotesListScreen`)
- **Horizontal Filter Chip Bar:**
  - Located directly beneath the App Bar / E2E Lock Banner.
  - Horizontally scrollable row with smooth physics.
  - Chips:
    - `Semua` with badge count `state.notes.length`.
    - Each folder: `📁 {folderName}` with badge count for notes in that folder.
    - End action: `+ Folder` chip/button opening a quick folder creation dialog.
  - **Visual Styles:**
    - Active Chip: `AppColors.emeraldAccent` background (dark mode) or `AppColors.primary` (light mode) with bold label.
    - Inactive Chip: Surface background with subtle border.
  - **Long-Press Action:** Long-pressing a custom folder chip opens a bottom sheet or dialog to rename or delete the folder.
  - **Empty State:** If the selected folder has no notes, display an empty illustration message: *"Belum ada catatan di folder [Folder]"* with a button to *"Buat Catatan Baru"*.

### 2. Note Card (`NoteCard`)
- When `note.folder != null && note.folder!.isNotEmpty`:
  - Display a subtle pill badge (e.g. `📁 Work`) next to the date stamp.
  - Compact typography (11sp) with rounded border and low-opacity container.

### 3. Note Editor (`NoteEditorScreen`)
- **Folder Picker Header:**
  - Displayed prominently in the editor (AppBar action or sub-header): `[📁 {Folder Name} ▼]` or `[📁 Pilih Folder]` if unfiled.
  - Tapping opens the **Folder Selector Bottom Sheet**:
    - Option: *Tanpa Folder* (Uncategorized / null).
    - List of available folders with radio/check indicator for the current folder.
    - Option: *+ Buat Folder Baru* with inline text field to immediately create and assign a new folder.

---

## Two-Way Cloud Synchronization
- Folder changes on Android update `note.folder` and mark `syncStatus = SyncStatus.local`.
- `SyncEngine.enqueueAndSync` pushes changes to Supabase (`public.notes.folder` column).
- Desktop app (`valtera-note`) pulls notes from Supabase, detecting `tab.folder` automatically.
- Notes organized into folders on desktop automatically appear under the corresponding folder chips on Android.

---

## Testing & Verification Plan
1. **Unit Tests:**
   - Test `NotesListController`: folder selection, filtering logic, folder creation, folder deletion.
   - Test `NoteEditorController`: folder updating and persistence.
2. **Widget Tests:**
   - Verify filter chips render with proper counts.
   - Verify selecting a folder filters the visible list of notes.
   - Verify `NoteCard` renders folder pill badge when folder is present.
   - Verify folder picker bottom sheet in `NoteEditorScreen`.
3. **Regression Tests:**
   - Run full existing test suite (`flutter test`) ensuring 0 failures.
