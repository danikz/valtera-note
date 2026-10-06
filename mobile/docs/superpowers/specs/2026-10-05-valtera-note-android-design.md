# Design Specification: Valtera Note Android

**Tanggal:** 05 Oktober 2026  
**Status:** Approved by User  
**Target Platform:** Android (Flutter 3.35.x / Dart 3.9.x)  
**Backend:** Supabase milik pengguna (Self-hosted / Cloud)  
**Web Counterpart:** `valtera-note` (Svelte 5 + Tauri v2)

---

## 1. Ringkasan Eksekutif & Tujuan Produk

Valtera Note Android adalah aplikasi catatan mobile *local-first*, cepat, dan minimalis yang menjadi pendamping resmi dari project web/desktop `valtera-note`. 

### Prinsip Utama
- **Local-First & Fast-First:** Membaca dan menulis ke database lokal SQLite (`sqflite`) seketika (<10ms). Pengguna dapat langsung mengetik tanpa diblokir oleh jaringan.
- **Contract-First:** Mengikuti skema tabel PostgreSQL `public.notes` dan kebijakan Row-Level Security (RLS) yang sudah ada di Supabase pengguna tanpa membuat modifikasi yang merusak sinkronisasi desktop.
- **Secure:** Hanya menggunakan Supabase `anon_key` dan JWT token authenticated. Kunci sensitif disimpan pada `flutter_secure_storage` (Android Keystore / EncryptedSharedPreferences). Service role key dilarang keras.
- **Low Visual Noise:** Mengadopsi prinsip desain Swiss Minimalism dari *UI/UX Pro Max*, mengutamakan tipografi yang nyaman dibaca, kontras tinggi, dan antarmuka tanpa dekorasi berlebihan.

---

## 2. Arsitektur Aplikasi (Feature-First Clean Architecture)

Aplikasi dibangun menggunakan pola **Feature-First** dengan pemisahan lapisan data, domain, dan presentasi menggunakan **Flutter Riverpod (v2.x)**:

```
lib/
├── core/
│   ├── database/
│   │   ├── app_database.dart         # SQFlite database singleton & migrasi tabel
│   │   └── tables/                   # DDL skema local_notes & sync_queue
│   ├── storage/
│   │   └── secure_storage_service.dart # Wrapper flutter_secure_storage (URL, anon key, tokens)
│   ├── network/
│   │   └── connectivity_service.dart # Stream listener status internet (connectivity_plus)
│   ├── theme/
│   │   ├── app_colors.dart           # Semantic color tokens (Slate 950 / Emerald)
│   │   ├── app_typography.dart       # Plus Jakarta Sans text styles
│   │   └── app_theme.dart            # ThemeData Light & Dark (System adaptive)
│   ├── router/
│   │   └── app_router.dart           # GoRouter konfigurasi (redirect guards & routes)
│   ├── errors/
│   │   └── app_failures.dart         # Custom Failure classes & error mapping
│   └── widgets/
│       ├── valtera_button.dart       # Primary & secondary button dengan hit-area 48dp
│       ├── valtera_text_field.dart   # Input dengan visual focus ring & error label
│       ├── status_indicator.dart     # Badge indikator status sync
│       ├── offline_banner.dart       # Banner koneksi offline
│       └── confirmation_dialog.dart  # Modal konfirmasi aksi destruktif
├── features/
│   ├── setup/
│   │   ├── data/repositories/setup_repository.dart
│   │   └── presentation/screens/setup_screen.dart
│   ├── auth/
│   │   ├── data/repositories/auth_repository.dart
│   │   ├── domain/models/auth_state.dart
│   │   └── presentation/screens/
│   │       ├── login_screen.dart
│   │       ├── register_screen.dart
│   │       └── forgot_password_screen.dart
│   ├── notes/
│   │   ├── data/
│   │   │   ├── local/notes_local_data_source.dart
│   │   │   ├── remote/notes_remote_data_source.dart
│   │   │   └── repositories/notes_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/note.dart
│   │   │   └── repositories/notes_repository.dart
│   │   └── presentation/
│   │       ├── controllers/notes_list_controller.dart
│   │       ├── controllers/note_editor_controller.dart
│   │       ├── screens/notes_list_screen.dart
│   │       ├── screens/note_editor_screen.dart
│   │       ├── screens/search_screen.dart
│   │       └── widgets/note_card.dart
│   ├── settings/
│   │   └── presentation/screens/settings_screen.dart
│   └── sync/
│       ├── data/local/sync_queue_data_source.dart
│       ├── domain/sync_engine.dart
│       └── domain/models/sync_queue_item.dart
└── main.dart
```

---

## 3. UI/UX Pro Max Design Tokens

Mengacu pada [`design-system/valtera-note-android/MASTER.md`](file:///D:/Tools%20Kerja/Valtera%20Teknologi%20Digital/valtera-note-android/design-system/valtera-note-android/MASTER.md):

### 3.1. Color Tokens
| Semantic Token | Light Mode | Dark Mode | Fungsi |
|---|---|---|---|
| `background` | `#F8FAFC` (Slate 50) | `#020617` (Slate 950) | Background halaman |
| `surface` | `#FFFFFF` | `#0F172A` (Slate 900) | Background card / editor / modal |
| `surfaceBorder` | `#E2E8F0` | `#1E293B` (Slate 800) | Garis tepi komponen (1px) |
| `primary` | `#0D9488` (Teal 600) | `#10B981` (Emerald 500) | Aksen utama & tombol CTA |
| `textPrimary` | `#0F172A` (Slate 900) | `#F8FAFC` (Slate 50) | Teks utama |
| `textSecondary` | `#64748B` (Slate 500) | `#94A3B8` (Slate 400) | Teks pendukung & waktu |
| `destructive` | `#DC2626` (Red 600) | `#EF4444` (Red 500) | Hapus & error |
| `syncSynced` | `#10B981` | `#10B981` | Status sinkronisasi berhasil |
| `syncPending` | `#F59E0B` | `#F59E0B` | Status perubahan lokal |

### 3.2. Tipografi
- **Family:** `Plus Jakarta Sans` (Google Fonts).
- **H1 (Header/Title):** 22sp, SemiBold.
- **Card Title:** 16sp, Medium.
- **Body Note:** 15sp, Regular, height 1.5.
- **Metadata:** 12sp, Regular.

### 3.3. Interaksi & Aksesibilitas
- Touch targets ≥ 48x48 dp.
- Animasi smooth (150–250ms) dengan Material 3 InkWell ink-splash.
- Debounce auto-save: 1500 ms.
- Safe-area compliance: padding sistem bebas tumpang tindih dengan keyboard dan status bar.

---

## 4. Skema Database Lokal & Model Data

### 4.1. Entity Dart (`Note`)
```dart
enum SyncStatus { local, syncing, synced, error }

class Note {
  final String id;              // UUID
  final String? userId;         // UUID pemilik akun
  final String title;           // Judul catatan (default: 'Untitled')
  final String content;         // Konten teks
  final String fileExtension;   // Default: 'md'
  final String? folder;         // Folder/label (opsional)
  final bool isPinned;          // Status sematan
  final bool isDeleted;         // Tombstone soft delete
  final DateTime createdAt;     // UTC
  final DateTime updatedAt;     // UTC
  final SyncStatus syncStatus;  // Status sync lokal
}
```

### 4.2. Skema SQLite (`sqflite`)
```sql
CREATE TABLE local_notes (
    id TEXT PRIMARY KEY,
    user_id TEXT,
    title TEXT NOT NULL DEFAULT 'Untitled',
    content TEXT NOT NULL DEFAULT '',
    file_extension TEXT NOT NULL DEFAULT 'md',
    folder TEXT,
    is_pinned INTEGER NOT NULL DEFAULT 0,
    is_deleted INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    sync_status TEXT NOT NULL DEFAULT 'synced'
);

CREATE INDEX idx_local_notes_updated_at ON local_notes(updated_at DESC);
CREATE INDEX idx_local_notes_pinned ON local_notes(is_pinned DESC);

CREATE TABLE sync_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    payload TEXT NOT NULL,
    created_at TEXT NOT NULL,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    status TEXT NOT NULL DEFAULT 'pending'
);
```

---

## 5. Alur Sinkronisasi & Offline Mutation Engine

```
[UI Editor / List]
       │
       ▼ (Instant <10ms)
[SQFlite: local_notes] ◄─── (Optimistic UI Update: syncStatus = 'local')
       │
       ▼ (Debounce 1.5s / App Background / Connectivity Online)
[SyncEngine]
       ├── Apakah Online?
       │     ├── YA ──► Kirim ke Supabase REST API (POST /rest/v1/notes?on_conflict=id)
       │     │           ├── Sukses ──► Tandai local_notes (syncStatus = 'synced')
       │     │           └── Gagal  ──► Masukkan ke tabel `sync_queue` (status = 'pending')
       │     └── TIDAK ─► Masukkan ke tabel `sync_queue` (status = 'pending')
       │
       └── Two-Way Pull (Pull-to-refresh & Polling):
             Ambil remote notes (order=updated_at.desc)
             Bandingkan dengan local_notes:
               - Jika remote lebih baru & lokal tidak dirty: update record lokal
               - Jika remote is_deleted: hapus dari local_notes
               - Jika lokal sedang dirty (syncStatus == local): lindungi draft lokal
```

---

## 6. Autentikasi & Navigasi

### State Navigasi (GoRouter):
1. **Belum Konfigurasi Supabase:** Arahkan ke `/setup` (Input URL & Anon Key).
2. **Sudah Konfigurasi, Belum Login:** Arahkan ke `/login` (Email/Password, opsi daftar & lupa kata sandi).
3. **Sudah Login & Sesi Valid:** Arahkan ke `/notes` (Daftar catatan utama).
4. **Editor:** Arahkan ke `/notes/:id` (buka catatan existing) atau `/notes/new` (buat catatan baru).
5. **Pengaturan:** Arahkan ke `/settings` (Informasi akun, status sinkronisasi, disconnect project).

---

## 7. Rencana Pengujian

1. **Unit Test:**
   - URL & API Key validator.
   - Note entity mapper & PostgREST JSON serializer.
   - SQFlite local data source CRUD & filter pencarian.
   - SyncQueue enqueue/dequeue & retry policy.
2. **Widget Test:**
   - SetupScreen input handling & connection testing state.
   - LoginScreen & RegisterScreen validation.
   - NotesListScreen (Empty, Loading, Error, Loaded state).
   - NoteEditorScreen input text & back navigation.
3. **Analisis Kode:**
   - `flutter analyze` 0 issue.
