# Valtera Note Android Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun aplikasi Android native Flutter untuk Valtera Note yang ringan, cepat, *local-first*, memiliki offline mutation queue, dan tersinkronisasi dua arah dengan Supabase database project milik pengguna mengikuti skema `public.notes` existing dan standar UI/UX Pro Max.

**Architecture:** Feature-First Clean Architecture dengan pemisahan Data, Domain, dan Presentation layer. State management & DI menggunakan Flutter Riverpod 2.x, database lokal SQLite (`sqflite`), secure storage untuk kredensial (`flutter_secure_storage`), serta navigasi deklaratif menggunakan GoRouter.

**Tech Stack:** Flutter 3.35.x / Dart 3.9.x, Riverpod 2.6.x, SQFlite 2.4.x, Flutter Secure Storage 9.2.x, Supabase Flutter 2.8.x, GoRouter 14.8.x, Google Fonts (Plus Jakarta Sans), Connectivity Plus 6.1.x, UUID, Intl.

## Global Constraints
- Target platform: Android (minSdkVersion 21+, compileSdkVersion 34+).
- Jangan pernah menggunakan Supabase Service Role Key di aplikasi klien.
- Ikuti 100% kontrak skema tabel Supabase `public.notes` yang telah diaudit di `docs/audit-existing-system.md`.
- Desain UI wajib mematuhi design system di `design-system/valtera-note-android/MASTER.md` (Swiss Minimalism, touch target ≥48dp, Plus Jakarta Sans, nol emoji sebagai kontrol ikon).
- Local-first write: setiap aksi create/update/delete harus tersimpan lokal ke SQFlite dalam <15ms tanpa menunggu jaringan.
- Tidak ada query Supabase langsung di dalam Widget.

---

### Task 1: Scaffolding Proyek Flutter & Setup Dependensi

**Files:**
- Create: `pubspec.yaml`
- Create: `analysis_options.yaml`
- Create: Android project scaffolding via `flutter create`
- Test: `test/widget_test.dart`

**Interfaces:**
- Produces: Proyek Flutter Android yang siap dikompilasi dengan semua dependensi terpasang.

- [ ] **Step 1: Inisialisasi Flutter project di root direktori**
  Jalankan perintah flutter create dengan package name `com.valtera.note`:
  ```bash
  flutter create --org com.valtera --project-name valtera_note --platforms android .
  ```

- [ ] **Step 2: Konfigurasi `pubspec.yaml` dengan dependensi proyek**
  Tambahkan dependensi:
  ```yaml
  dependencies:
    flutter:
      sdk: flutter
    flutter_riverpod: ^2.6.1
    sqflite: ^2.4.1
    path: ^1.9.1
    flutter_secure_storage: ^9.2.4
    connectivity_plus: ^6.1.3
    go_router: ^14.8.1
    supabase_flutter: ^2.8.4
    google_fonts: ^6.2.1
    uuid: ^4.5.1
    intl: ^0.20.2

  dev_dependencies:
    flutter_test:
      sdk: flutter
    flutter_lints: ^5.0.0
  ```

- [ ] **Step 3: Jalankan `flutter pub get`**
  ```bash
  flutter pub get
  ```

- [ ] **Step 4: Verifikasi build dan test awal**
  Jalankan `flutter analyze` untuk memastikan tidak ada lint error.
  ```bash
  flutter analyze
  ```

- [ ] **Step 5: Commit scaffolding**
  ```bash
  git add .
  git commit -m "chore: scaffold flutter android project with dependencies"
  ```

---

### Task 2: Core Theme, Design Tokens & Reusable UI Components (UI/UX Pro Max)

**Files:**
- Create: `lib/core/theme/app_colors.dart`
- Create: `lib/core/theme/app_typography.dart`
- Create: `lib/core/theme/app_theme.dart`
- Create: `lib/core/widgets/valtera_button.dart`
- Create: `lib/core/widgets/valtera_text_field.dart`
- Create: `lib/core/widgets/status_indicator.dart`
- Create: `lib/core/widgets/offline_banner.dart`
- Test: `test/core/widgets/valtera_widgets_test.dart`

**Interfaces:**
- Produces: `AppColors`, `AppTypography`, `AppTheme.light`, `AppTheme.dark`, `ValteraButton`, `ValteraTextField`, `StatusIndicator`, `OfflineBanner`.

- [ ] **Step 1: Tulis unit/widget test untuk token & widgets**
  Buat `test/core/widgets/valtera_widgets_test.dart` yang memvalidasi rendering `ValteraButton`, `ValteraTextField`, dan touch target minimum 48dp.

- [ ] **Step 2: Jalankan test untuk memastikan failing**
  ```bash
  flutter test test/core/widgets/valtera_widgets_test.dart
  ```

- [ ] **Step 3: Implementasikan theme tokens dan reusable widgets**
  - Implementasi `AppColors` (Slate 950, Slate 900, Slate 800, Slate 50, Teal 600, Emerald 500, Red 500).
  - Implementasi `AppTypography` dengan GoogleFonts `plusJakartaSans`.
  - Implementasi `AppTheme` dengan tema terang dan tema gelap.
  - Implementasi `ValteraButton` (hit area ≥48x48 dp, loading spinner, ripple effect).
  - Implementasi `ValteraTextField` (focus border emerald/teal, error label, clear button).
  - Implementasi `StatusIndicator` (dot + text badge: Synced, Local, Syncing, Error).
  - Implementasi `OfflineBanner` (warning banner saat koneksi offline).

- [ ] **Step 4: Jalankan test dan pastikan passing**
  ```bash
  flutter test test/core/widgets/valtera_widgets_test.dart
  ```

- [ ] **Step 5: Commit**
  ```bash
  git add lib/core/theme lib/core/widgets test/core/widgets
  git commit -m "feat(core): add UI/UX Pro Max theme tokens and reusable widgets"
  ```

---

### Task 3: Secure Storage & Database Lokal SQFlite

**Files:**
- Create: `lib/core/storage/secure_storage_service.dart`
- Create: `lib/core/database/app_database.dart`
- Create: `lib/core/errors/app_failures.dart`
- Test: `test/core/storage/secure_storage_test.dart`
- Test: `test/core/database/app_database_test.dart`

**Interfaces:**
- Produces:
  - `SecureStorageService`: `saveSupabaseConfig`, `getSupabaseConfig`, `clearSupabaseConfig`, `saveAuthSession`, `getAuthSession`, `clearAuthSession`.
  - `AppDatabase`: Singleton SQFlite instance dengan tabel `local_notes` dan `sync_queue`.
  - `AppFailure`: `NetworkFailure`, `AuthFailure`, `DatabaseFailure`, `ValidationFailure`.

- [ ] **Step 1: Tulis test untuk SecureStorageService dan AppDatabase**
  Buat unit test yang memvalidasi operasi penyimpan kredensial dan pembuatan skema SQLite (`local_notes` dan `sync_queue`).

- [ ] **Step 2: Jalankan test (failing)**
  ```bash
  flutter test test/core/storage/secure_storage_test.dart test/core/database/app_database_test.dart
  ```

- [ ] **Step 3: Implementasi SecureStorageService, AppDatabase, dan AppFailures**
  - `SecureStorageService` menyimpan `supabase_url`, `supabase_anon_key`, `access_token`, `refresh_token`, `expires_at`, `user_email`.
  - `AppDatabase` membuat tabel `local_notes` dan `sync_queue` dengan index pada `updated_at` dan `is_pinned`.
  - `AppFailures` memetakan exception teknis ke pesan ramah pengguna.

- [ ] **Step 4: Jalankan test (passing)**
  ```bash
  flutter test test/core/storage/secure_storage_test.dart test/core/database/app_database_test.dart
  ```

- [ ] **Step 5: Commit**
  ```bash
  git add lib/core/storage lib/core/database lib/core/errors test/core/
  git commit -m "feat(core): implement secure storage, sqflite database, and error failures"
  ```

---

### Task 4: Fitur Setup Supabase (Onboarding URL & Anon Key)

**Files:**
- Create: `lib/features/setup/data/repositories/setup_repository.dart`
- Create: `lib/features/setup/presentation/controllers/setup_controller.dart`
- Create: `lib/features/setup/presentation/screens/setup_screen.dart`
- Test: `test/features/setup/setup_screen_test.dart`

**Interfaces:**
- Consumes: `SecureStorageService`, `AppDatabase`, `ValteraButton`, `ValteraTextField`.
- Produces: `SetupScreen` (validasi URL HTTPS, Anon Key, Test Connection, simpan konfigurasi).

- [ ] **Step 1: Tulis unit & widget test untuk Setup Feature**
  Test validasi URL (menolak HTTP atau format salah), penolakan service role key, dan pemanggilan test connection.

- [ ] **Step 2: Jalankan test (failing)**
  ```bash
  flutter test test/features/setup/setup_screen_test.dart
  ```

- [ ] **Step 3: Implementasikan SetupRepository, SetupController, dan SetupScreen**
  - Validasi HTTPS dan regex URL Supabase.
  - Pengecekan HTTP endpoint `/auth/v1/health` dan REST endpoint `/rest/v1/notes?select=id&limit=1`.
  - Simpan konfigurasi ke `SecureStorageService`.
  - UI responsif dengan field URL, Anon Key (dengan toggle mata), status banner, dan tombol Test Connection.

- [ ] **Step 4: Jalankan test (passing)**
  ```bash
  flutter test test/features/setup/setup_screen_test.dart
  ```

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/setup test/features/setup
  git commit -m "feat(setup): add supabase setup and connection testing screen"
  ```

---

### Task 5: Fitur Autentikasi (Login, Register & Session Persistence)

**Files:**
- Create: `lib/features/auth/data/repositories/auth_repository.dart`
- Create: `lib/features/auth/domain/models/auth_state.dart`
- Create: `lib/features/auth/presentation/controllers/auth_controller.dart`
- Create: `lib/features/auth/presentation/screens/login_screen.dart`
- Create: `lib/features/auth/presentation/screens/register_screen.dart`
- Create: `lib/features/auth/presentation/screens/forgot_password_screen.dart`
- Test: `test/features/auth/auth_test.dart`

**Interfaces:**
- Consumes: `SecureStorageService`, `SetupRepository`.
- Produces: `AuthRepository` (login, register, logout, refreshToken), `LoginScreen`, `RegisterScreen`, `ForgotPasswordScreen`.

- [ ] **Step 1: Tulis unit test untuk auth repository & controller**
  Test login success, invalid credentials handling, auto-refresh token logic, dan logout.

- [ ] **Step 2: Jalankan test (failing)**
  ```bash
  flutter test test/features/auth/auth_test.dart
  ```

- [ ] **Step 3: Implementasikan AuthRepository, AuthController, dan Layar Auth**
  - Autentikasi menggunakan Supabase Auth endpoint (atau SupabaseClient terinisialisasi).
  - Simpan session JWT ke `SecureStorageService`.
  - Handle refresh token otomatis saat mendekati masa kedaluwarsa.
  - UI bersih dengan form email, password, konfirmasi password, inline validation error.

- [ ] **Step 4: Jalankan test (passing)**
  ```bash
  flutter test test/features/auth/auth_test.dart
  ```

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/auth test/features/auth
  git commit -m "feat(auth): implement login, register, forgot password, and session persistence"
  ```

---

### Task 6: Notes Entity, Local DataSource & Remote PostgREST DataSource

**Files:**
- Create: `lib/features/notes/domain/entities/note.dart`
- Create: `lib/features/notes/data/local/notes_local_data_source.dart`
- Create: `lib/features/notes/data/remote/notes_remote_data_source.dart`
- Create: `lib/features/notes/data/repositories/notes_repository_impl.dart`
- Test: `test/features/notes/notes_data_source_test.dart`

**Interfaces:**
- Produces:
  - `Note`: entity domain dengan method `toMap()`, `fromMap()`, `toPostgresJson()`, `fromPostgresJson()`.
  - `NotesLocalDataSource`: `getAllNotes()`, `getNoteById()`, `insertNote()`, `updateNote()`, `deleteNote()`, `searchNotes()`.
  - `NotesRemoteDataSource`: `fetchRemoteNotes()`, `upsertRemoteNote()`, `deleteRemoteNote()`.
  - `NotesRepository`: Local-first repository mediator.

- [ ] **Step 1: Tulis test untuk serialization dan CRUD local/remote data source**
  Verifikasi pemetaan kolom: `id`, `user_id`, `title`, `content`, `file_extension`, `folder`, `is_pinned`, `is_deleted`, `created_at`, `updated_at`.

- [ ] **Step 2: Jalankan test (failing)**
  ```bash
  flutter test test/features/notes/notes_data_source_test.dart
  ```

- [ ] **Step 3: Implementasikan Note Entity dan Data Sources**
  - SQFlite query builder untuk filter soft-delete (`is_deleted = 0`) dan sorting pinned pertama + `updated_at DESC`.
  - PostgREST request builder dengan header `apikey` dan `Authorization: Bearer <token>`.
  - Fallback soft delete jika hard delete dibatasi oleh RLS policy.

- [ ] **Step 4: Jalankan test (passing)**
  ```bash
  flutter test test/features/notes/notes_data_source_test.dart
  ```

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/notes/domain lib/features/notes/data test/features/notes
  git commit -m "feat(notes): implement note entity, sqflite local data source, and remote postgrest source"
  ```

---

### Task 7: Offline Mutation Queue & Background Sync Engine

**Files:**
- Create: `lib/features/sync/domain/models/sync_queue_item.dart`
- Create: `lib/features/sync/data/local/sync_queue_data_source.dart`
- Create: `lib/features/sync/domain/sync_engine.dart`
- Create: `lib/core/network/connectivity_service.dart`
- Test: `test/features/sync/sync_engine_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `NotesLocalDataSource`, `NotesRemoteDataSource`, `ConnectivityService`.
- Produces: `SyncEngine` (`syncAll()`, `enqueueMutation()`, `drainQueue()`, `streamStatus`).

- [ ] **Step 1: Tulis test untuk SyncEngine dan SyncQueueDataSource**
  Test antrean FIFO mutasi (create, update, delete), penanganan kegagalan koneksi, dan pemrosesan ulang saat online kembali.

- [ ] **Step 2: Jalankan test (failing)**
  ```bash
  flutter test test/features/sync/sync_engine_test.dart
  ```

- [ ] **Step 3: Implementasikan SyncEngine dan SyncQueueDataSource**
  - Tabel `sync_queue`: `enqueue`, `peekNext`, `markProcessing`, `markSuccess`, `markFailedWithRetry`.
  - `SyncEngine`:
    - Mengamati `ConnectivityService`.
    - Auto-drain antrean saat kembali online.
    - Two-way pull merge: bandingkan `updated_at`, lindungi draf lokal yang kotor (`sync_status == 'local'`), perbarui cache lokal jika remote lebih baru.
    - Debounced push untuk mutasi baru.

- [ ] **Step 4: Jalankan test (passing)**
  ```bash
  flutter test test/features/sync/sync_engine_test.dart
  ```

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/sync lib/core/network test/features/sync
  git commit -m "feat(sync): implement offline mutation queue and background sync engine"
  ```

---

### Task 8: Notes List, Search, Editor & Settings UI (UI/UX Pro Max)

**Files:**
- Create: `lib/features/notes/presentation/controllers/notes_list_controller.dart`
- Create: `lib/features/notes/presentation/controllers/note_editor_controller.dart`
- Create: `lib/features/notes/presentation/screens/notes_list_screen.dart`
- Create: `lib/features/notes/presentation/screens/note_editor_screen.dart`
- Create: `lib/features/notes/presentation/screens/search_screen.dart`
- Create: `lib/features/notes/presentation/widgets/note_card.dart`
- Create: `lib/features/settings/presentation/screens/settings_screen.dart`
- Create: `lib/core/router/app_router.dart`
- Modify: `lib/main.dart`
- Test: `test/features/notes/notes_ui_test.dart`

**Interfaces:**
- Consumes: Semua layer sebelumnya.
- Produces: Seluruh aplikasi yang dapat dijalankan secara utuh dari onboarding hingga CRUD catatan dan sinkronisasi.

- [ ] **Step 1: Tulis widget test untuk Notes List, Editor, dan Search**
  Verifikasi:
  - Empty state menampilkan ilustrasi dan ajakan membuat catatan.
  - Floating Action Button membuka editor.
  - Mengetik judul dan isi otomatis menyimpan ke draf lokal (auto-save).
  - Search menyaring catatan secara instan.

- [ ] **Step 2: Jalankan test (failing)**
  ```bash
  flutter test test/features/notes/notes_ui_test.dart
  ```

- [ ] **Step 3: Implementasikan Controller dan Layar-Layar UI**
  - `NotesListScreen`: Appbar minimalis, search trigger, status bar sync, list/staggered grid card catatan, pin grouping, pull-to-refresh.
  - `NoteCard`: Judul tebal, cuplikan isi, waktu update, status pin badge, ink-well ripple feedback.
  - `NoteEditorScreen`: Zen mode tanpa distraksi, safe-area keyboard avoidance, auto-save debounce 1.5s, tombol hapus dengan konfirmasi dialog.
  - `SearchScreen`: Input autofocus dengan tombol clear, real-time query highlight, empty state pencarian.
  - `SettingsScreen`: Informasi akun login, project URL tersambung, tombol Force Sync, tombol Disconnect dengan dialog konfirmasi.
  - `AppRouter`: GoRouter dengan auth redirect guard (`/setup` -> `/login` -> `/notes`).
  - `main.dart`: Inisialisasi Riverpod `ProviderScope` dan aplikasi Flutter.

- [ ] **Step 4: Jalankan test (passing)**
  ```bash
  flutter test test/features/notes/notes_ui_test.dart
  ```

- [ ] **Step 5: Commit**
  ```bash
  git add lib/features/notes/presentation lib/features/settings lib/core/router lib/main.dart test/features/notes
  git commit -m "feat(ui): implement notes list, editor, search, settings, and routing"
  ```

---

### Task 9: Pengujian Menyeluruh, Analisis Kode & Verifikasi Akhir

**Files:**
- Modify/Add: `test/integration/app_flow_test.dart`
- Run: `flutter analyze`
- Run: `flutter test`

**Interfaces:**
- Produces: Laporan verifikasi bebas error, test suite 100% passing, sesuai Definition of Done (PRD Section 20).

- [ ] **Step 1: Jalankan analisis statis Dart**
  ```bash
  flutter analyze
  ```
  Harus menghasilkan: `No issues found!`.

- [ ] **Step 2: Jalankan seluruh test suite**
  ```bash
  flutter test
  ```
  Harus PASS seluruh unit, widget, dan integration test.

- [ ] **Step 3: Verifikasi Checklist UI/UX Pro Max Pre-Delivery**
  - [x] Zero emoji sebagai ikon navigasi
  - [x] Touch target minimal 48dp
  - [x] Kontras teks ≥ 4.5:1 untuk mode terang dan gelap
  - [x] Keyboard handling aman tanpa visual jitter
  - [x] Offline banner dan sync indicator informatif

- [ ] **Step 4: Commit dan dokumentasikan rilis MVP**
  ```bash
  git add .
  git commit -m "chore: complete quality assurance and verification passes"
  ```
