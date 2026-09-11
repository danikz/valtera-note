# 📜 Changelog

All notable changes to the **Valtera Note** desktop application will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.8] - 2026-09-11

### 📖 Fitur Baru: Kamus Sintaks & Perintah (Cheatsheet & Knowledge Base)
- **Kamus Sintaks Lengkap (`Ctrl+Shift+T`)**: Menggantikan drawer template standar dengan 27 referensi sintaks siap pakai yang interaktif:
  - **Markdown & GFM**: GitHub Alerts (`> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`), tabel dengan alignment (`:---`, `:---:`), task checklist, blok kode, diagram alur Mermaid (`flowchart TD`), rumus matematika LaTeX/KaTeX, accordion `<details>`, format teks stabilo & `<kbd>`, footnotes, dan template notulensi rapat.
  - **SQL & Database**: Query `SELECT` dengan filter & paginasi, `CREATE TABLE` SQLite, `UPSERT` on conflict, aggregasi `GROUP BY` & `HAVING`, `JOIN`, inspeksi `PRAGMA` SQLite, transaksi ACID, dan CTE (`WITH`).
  - **JSON**: Amplop respons RESTful, aturan wajib JSON murni, konfigurasi `package.json`, dan skema `GeoJSON`.
  - **Regex**: Pola validasi umum (Email, URL, UUID, Slug), kamus arti simbol karakter, dan kuantifier pengulangan.
  - **Git & CLI**: Alur kerja harian Git dan perintah undo/stash.
- **Fitur Interaktif**: Pencarian real-time, filter pill kategori, tombol salin ke clipboard instan, dan tombol sisipkan langsung ke catatan.

### ⚙️ Pengaturan Terpusat (Unified Settings Workspace)
- **Dedicated Settings Page (`Ctrl+,`)**: Halaman pengaturan terpadu dengan sidebar navigasi:
  - **Kredensial Supabase**: URL & Anon Key dengan pengujian koneksi live dan status auto-sync.
  - **Tampilan & Tema**: Preset tema Slate Modern, Obsidian Dark, Dracula, Cyberpunk Neon, GitHub Light, dan Nord Frost, dilengkapi switch Dark / Light mode.
  - **Preferensi Editor**: Ukuran font, tab size, line wrap, dan opsi konfigurasi CodeMirror.
  - **Tentang & Pembaruan**: Informasi versi, spesifikasi teknis (Tauri v2 + Rust), dan tombol cek pembaruan aplikasi.
- **Pembersihan Menu Tools**: Menghilangkan opsi pengaturan dari menu dropdown Tools agar menu Tools 100% fokus untuk developer tools.

### 🪟 Peningkatan Antarmuka & Kontrol Jendela
- **Frameless Windows 11 Controls**: Menonaktifkan titlebar ganda native OS (`decorations: false`) dengan kontrol jendela modern (Minimize, Maximize/Restore dinamis, dan Close).
- **Pembersihan Bar Kanan**: Menghilangkan tombol Tools di sebelah tombol Settings agar quick action bar lebih bersih dan rapi.

---

## [0.1.7] - 2026-09-11

### 🛠️ Fitur Baru: Dedicated Developer Tools Suite & About Modal
- **Full-Page Developer Tools Workspace**: Suite perkakas pengembang lengkap dan terintegrasi yang dapat dibuka via tombol **Tools** di Titlebar, Command Palette (`Ctrl+K`), atau shortcut keyboard langsung:
  - **JSON Formatter, Validator & Tree Inspector** (`Ctrl+Shift+J`):
    - Format (Indented) & Minify JSON instan.
    - Interactive Tree Viewer dengan toggle expand/collapse dan live key-path copying.
    - Ekspor data JSON ke tabel **CSV (RFC 4180)** dan tabel **Markdown (GitHub Flavored)** otomatis.
    - Visual Table Grid dengan pencarian real-time dan pemilihan sumber array objek.
  - **Favicon & Web Icon Package Generator** (`Ctrl+Shift+F`):
    - Generator paket favicon lengkap standar web dari berkas gambar/SVG (drag-and-drop).
    - Menghasilkan `favicon.ico` (multi-resolusi 16x16, 32x32, 48x48), `apple-touch-icon.png`, `android-chrome-192/512`, `manifest.json`, dan `browserconfig.xml`.
    - Unduh seluruh aset terkompresi dalam berkas ZIP sekali klik serta salin snippet tag `<head>` HTML.
  - **MySQL Password Hash Generator** (`Ctrl+Shift+P`):
    - Komputasi hash otentikasi MySQL Native Password (`mysql_native_password` SHA1 double-hash) dan format legacy password untuk administrasi basis data.
  - **Base64 Encoder / Decoder**: Konversi teks dan data biner secara dua arah dengan live character counting dan validasi.
  - **URL Encoder / Decoder & Query Inspector**: URL encoding/decoding instan dengan antarmuka builder query params.
  - **UUID Generator (v4)**: Pembuatan bulk UUID v4 dengan opsi format huruf kapital, tanpa strip (-), dan output format Plain, SQL, JSON, atau CSV.
- **About Modal**:
  - Modal informasi aplikasi resmi Valtera Note lengkap dengan nomor versi, lisensi, informasi pengembang, dan tombol periksa pembaruan manual.
- **Peningkatan Titlebar & Navigasi**:
  - Tombol akses cepat Developer Tools pada Titlebar dengan penanda status aktif.
  - Integrasi perintah developer tools langsung ke dalam Command Palette.

---

## [0.1.6] - 2026-09-10

### ✨ Fitur Baru: Dukungan Icon & Emoji Saat Menulis & Manajemen Multi-Tab
- **Inline Emoji & Icon Autocomplete**: Mengetik `:` langsung di editor CodeMirror memicu autocomplete cerdas (cth: `:rocket:`, `:fire:`, `:star:`, `:check:`, `:warn:`, `:db:`, `:sql:`, `:koding:`, dll) dengan dukungan alias bahasa Indonesia dan Inggris. Menekan `Enter` atau `Tab` langsung mengganti tag menjadi karakter emoji asli.
- **Visual Emoji & Icon Picker Modal**: Popup visual pencarian icon lengkap dengan filter kategori (*Dev & DB*, *Status & Task*, *Dokumen*, *Simbol & Panah*, *Ekspresi*), preview hover, salin karakter, serta tombol sisipkan langsung ke kursor aktif. Dapat dibuka via tombol Titlebar, Command Palette, atau shortcut `Ctrl+Shift+E`.
- **Fitur Tutup Semua Tab (Close All Tabs)**:
  - Menutup seluruh tab terbuka sekaligus tanpa perlu mengklik silang satu per satu via shortcut `Ctrl+Shift+W` atau tombol dedicated **Tutup Semua** di TabBar saat tab > 1.
  - Aman dan non-destruktif: catatan yang telah tersimpan tetap utuh di Sidebar dan Supabase Cloud, hanya tab scratchpad kosong yang dibersihkan.
- **Tab Right-Click Context Menu**: Klik kanan pada sembarang tab kini menampilkan menu konteks profesional:
  - 📌 **Tutup Tab Ini** (`Ctrl+W`)
  - 🗂️ **Tutup Tab Lainnya**
  - ❌ **Tutup Semua Tab** (`Ctrl+Shift+W`)
  - 💾 **Simpan Catatan** (`Ctrl+S`)
- **Pintasan Keyboard & Command Palette**: Menambahkan perintah dan shortcut `Ctrl+W` (tutup tab aktif), `Ctrl+Shift+W` (tutup semua tab), dan `Ctrl+Shift+E` (picker emoji).

---

## [0.1.5] - 2026-09-10

### ☁️ Supabase Cloud Sync & CI Build Pipeline Optimization
- **Local-to-Cloud Sync Fix**: Resolved issue where locally saved notes failed to sync to Supabase Cloud due to PostgREST `on_conflict=id` requirement when notes lacked assigned remote IDs.
- **Dynamic Upserting**: New notes are now posted cleanly to `/rest/v1/notes` or provisioned with a client UUID, returning the generated record and setting `tab.supabase_id` seamlessly.
- **Visual Cloud Indicators**: Added clear emerald `<Cloud>` status badges and 1-click cloud sync buttons on unsynced notes in both tab bar and sidebar.
- **Accurate Error Reporting**: Fixed false positive "Sync Succeeded" notification when remote upsert encounters permission or network issues.
- **CI Build Speedup (80-90% faster)**: Integrated `swatinem/rust-cache@v2` and `pnpm` store caching into GitHub Actions cross-platform workflow, eliminating redundant full recompilations.

---

## [0.1.4] - 2026-09-09

### 🛠️ SQLite Migration & Supabase Configuration Persistence Fix
- **Automatic SQLite Migration**: Added automatic migration in Rust database engine to fix legacy `app_settings` table constraint (`NOT NULL constraint failed: app_settings.value_json`), resolving issue where Supabase URL and API Key were lost after restart.
- **IPC Self-Healing**: Enhanced IPC Supabase configuration loader with automatic recovery from local storage cache to SQLite.
- **Auto-Persist Sync Settings**: Supabase credentials are now automatically saved upon successful connection tests and on closing the sync configuration modal.

---

## [0.1.3] - 2026-09-02

### 🔄 In-App Auto-Updater Artifacts Fix
- **Enabled Updater Bundles**: Configured `createUpdaterArtifacts: true` in Tauri v2 bundle configuration to automatically generate cryptographic signature `.sig` files and `latest.json` manifests during GitHub Actions builds.
- **Direct 1-Click Update**: Enabled automatic update notifications and 1-click in-app update for all installed desktop clients.

---

## [0.1.2] - 2026-09-02

### 🛠️ Fixes & Supabase Connection Test
- **Supabase Connection Ping**: Updated test ping endpoint to use `/auth/v1/health` and `/rest/v1/notes` instead of root schema endpoint, resolving `HTTP 401 Only the service_role API key can be used for this endpoint`.
- **Seamless Anon Key Authentication**: Enabled instant validation with standard Supabase `anon_key`.

---

## [0.1.1] - 2026-09-02

### 🔄 Supabase Cloud Sync & Auto-Updater Enhancement
- **Full Schema Sync**: Added `folder` column support in Supabase `notes` table and migration script.
- **Enhanced RLS Security Policy**: Comprehensive CRUD permission configuration for seamless `anon_key` and authenticated sync.
- **Auto-Updater Integration**: Configured dedicated Minisign cryptographic keys for in-app 1-click updates.

---

## [0.1.0] - 2026-09-01

### 🚀 Initial Production Release

#### ✨ Core Editor & Workspace
- **Ultra-Lightweight Rust Engine**: Cold boot in `< 250ms` and `< 40MB` idle RAM usage powered by Tauri v2.
- **CodeMirror 6 Virtualized Buffer**: High performance with syntax highlighting for Markdown, SQL, JSON, CSV, Rust, TypeScript, and Plain Text.
- **Multi-Tab & Split Views**: Support for side-by-side editing, live markdown sync-scroll, and full reader mode.
- **Organized Folders & Sidebar**: Automatic initial note creation when making new folders, inline folder collapsing, and custom tagging.

#### 🗄️ SQL Scratchpad & JSON Visualizer
- **SQLite Query Runner**: Direct `.db` / `.sqlite` execution with tabbed data grid viewer, sorting, and row counting.
- **Collapsible JSON Tree Viewer**: Interactive node expansion, path copying (`parent.child[0]`), and format beautifier.
- **Quick Snippets & Templates**: Instant code snippets drawer accessible via `Ctrl+Shift+S`.

#### ☁️ Supabase Cloud Sync & Security
- **Local-First Offline Architecture**: Embedded SQLite 3 cache with WAL mode ensuring zero data loss during network drops.
- **Background Sync**: Non-blocking asynchronous Supabase sync using native Rust threads (`tokio`).
- **Tombstone Sync Safety**: Clear distinction between closing a tab view and permanent note deletion.

#### 🔄 Automatic In-App Updates
- **Tauri v2 Auto-Updater**: Instant in-app update checks connected to GitHub Releases.
- **Mandatory Bugfix Alerts**: Interactive update modal with live download progress tracking and seamless automatic restart.
- **Digital Code Signing**: Ed25519 cryptographic signatures on all release packages (`latest.json`).

#### 🪟 Windows System Integration
- **Shell Context Menu**: Built-in 1-click registration for *"Open with Valtera Note"* in Windows File Explorer.
- **Single-Instance Enforcement**: Smoothly routes newly clicked files into existing application tabs.
- **Packaging**: Dual distribution via WiX MSI (`.msi`) and NSIS Setup (`.exe`).

---

<sub>Maintained by <b>PT Valtera Teknologi Digital</b></sub>
