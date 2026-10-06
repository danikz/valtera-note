# Audit Sistem Existing: Valtera Note (Web/Desktop)

**Tanggal Audit:** 05 Oktober 2026  
**Target:** Sinkronisasi & Kompatibilitas dengan `valtera-note-android`  
**Sumber Kode:** `D:\Tools Kerja\Valtera Teknologi Digital\valtera-note`

---

## 1. Ikhtisar Arsitektur Web/Desktop
- **Frontend Framework:** Svelte 5 + Vite + Tailwind CSS v4 + TypeScript
- **Desktop Shell:** Tauri v2 (Rust backend untuk IO, local SQLite, & Supabase HTTP client)
- **Local Storage:** SQLite (`rusqlite`) dengan mode WAL untuk desktop, fallback in-memory jika disk gagal.
- **Prinsip Utama:** *Local-First, Cloud-Synced*. Catatan tersimpan di lokal terlebih dahulu dan otomatis disinkronkan ke Supabase project milik pengguna saat tersambung.

---

## 2. Inisialisasi & Konfigurasi Supabase
- **Penyimpanan Kredensial:** Disimpan dinamis di SQLite settings:
  - `supabase_url`: URL project Supabase pengguna (contoh: `https://xyzproject.supabase.co`)
  - `supabase_anon_key`: Anon/public API key pengguna
  - `supabase_access_token`: Access token JWT dari sesi login pengguna
  - `supabase_refresh_token`: Refresh token untuk auto-refresh sesi
  - `supabase_token_expires_at`: Timestamp Unix kedaluwarsa token
  - `supabase_user_email`: Email pengguna yang sedang login
- **Keamanan:**
  - Aplikasi klien hanya menggunakan `anon_key` dan JWT token `authenticated`.
  - Service role key **dilarang keras** dipakai di aplikasi Android.

---

## 3. Skema & Struktur Database Supabase

### Tabel: `public.notes`
| Nama Kolom | Tipe Data PostgreSQL | Nullable | Default | Keterangan |
|---|---|---|---|---|
| `id` | `uuid` | NO | `gen_random_uuid()` | Primary Key UUID |
| `user_id` | `uuid` | YES | `auth.uid()` | ID pemilik akun (dari Supabase Auth) |
| `title` | `text` | NO | `'Untitled'` | Judul catatan |
| `content` | `text` | NO | `''` | Isi catatan (plaintext / markdown) |
| `file_extension` | `text` | NO | `'md'` | Ekstensi file ('md', 'txt', dll.) |
| `folder` | `text` | YES | `NULL` | Kategori / folder catatan |
| `is_pinned` | `boolean` | NO | `false` | Status disematkan |
| `is_deleted` | `boolean` | NO | `false` | Soft delete / tombstone |
| `created_at` | `timestamptz` | NO | `timezone('utc'::text, now())` | Waktu dibuat (UTC) |
| `updated_at` | `timestamptz` | NO | `timezone('utc'::text, now())` | Waktu diperbarui (UTC) |

> **Catatan Penting:** 
> - Kolom `is_archived` **TIDAK ADA** pada skema database existing `public.notes`. Pengelompokan dilakukan menggunakan kolom `folder`.
> - Format waktu menggunakan format ISO 8601 UTC string (RFC 3339).

### Index Sinkronisasi
```sql
create index if not exists idx_notes_updated_at on public.notes(updated_at desc);
```

### Row Level Security (RLS) Policy
```sql
alter table public.notes enable row level security;
revoke all on public.notes from anon;

create policy "Owner full access"
on public.notes
for all
to authenticated
using (auth.uid() = user_id or user_id is null)
with check (auth.uid() = user_id or user_id is null);
```

---

## 4. Query & Mutasi Data

### 4.1. Test Koneksi
- Health check: `GET {url}/auth/v1/health` dengan header `apikey: {anon_key}`
- REST check: `GET {url}/rest/v1/notes?select=id&limit=1` dengan header `apikey: {anon_key}` dan `Authorization: Bearer {anon_key}`

### 4.2. List Catatan (Fetch Notes)
- Endpoint: `GET {url}/rest/v1/notes?select=*&order=updated_at.desc`
- Headers:
  - `apikey: {anon_key}`
  - `Authorization: Bearer {access_token}` (atau fallback `{anon_key}` jika belum login)
- Catatan: Fetch mengambil semua catatan termasuk yang `is_deleted = true` agar sinkronisasi dapat menghapus salinan lokal yang dihapus di perangkat lain (tombstone pattern).

### 4.3. Create / Update Catatan (Upsert)
- Endpoint:
  - Dengan ID: `POST {url}/rest/v1/notes?on_conflict=id` dengan header `Prefer: resolution=merge-duplicates,return=representation`
  - Tanpa ID: `POST {url}/rest/v1/notes` dengan header `Prefer: return=representation`
- Header Auth: `apikey` dan `Authorization: Bearer {token}`
- Payload:
  ```json
  {
    "id": "<uuid>",
    "title": "Judul",
    "content": "Isi catatan",
    "file_extension": "md",
    "folder": null,
    "is_pinned": false,
    "is_deleted": false,
    "updated_at": "2026-10-05T15:20:00.000Z"
  }
  ```
  *(Catatan: `user_id` tidak dikirim dari UI payload melainkan otomatis diisi oleh default PostgreSQL `auth.uid()`)*

### 4.4. Delete Catatan
- Prioritas: Hard delete via `DELETE {url}/rest/v1/notes?id=eq.{id}`
- Fallback jika RLS membatasi hard delete: Soft delete via `PATCH {url}/rest/v1/notes?id=eq.{id}` dengan body `{"is_deleted": true, "updated_at": "<utc_iso>"}`.

---

## 5. Alur Autentikasi (Supabase Auth)
- **Registrasi:** `POST {url}/auth/v1/signup` dengan `{ "email": email, "password": password }`
- **Login:** `POST {url}/auth/v1/token?grant_type=password` dengan `{ "email": email, "password": password }`
- **Refresh Token:** `POST {url}/auth/v1/token?grant_type=refresh_token` dengan `{ "refresh_token": refresh_token }`
- **Session Lifecycle:**
  - Token di-refresh secara proaktif jika `now >= expires_at - 120 detik`.
  - Jika mendapat respon HTTP 401 atau JWT expired, sistem mencoba `refresh_token`. Jika gagal, sesi dibersihkan dan pengguna diarahkan login kembali.
  - Logout menghapus seluruh token dari secure storage lokal.

---

## 6. Sinkronisasi & Penanganan Konflik
1. **Debounce Auto-sync:** Penyimpanan lokal dilakukan instan, pengiriman ke cloud di-debounce 1.5 detik.
2. **Offline Mutation Queue:** Operasi saat offline dicatat di antrean lokal (create, update, delete) dan diproses berurutan saat koneksi internet kembali pulih (`connectivity_plus`).
3. **Penyelesaian Konflik:**
   - Deteksi berbasis perbandingan `updated_at`.
   - Data lokal yang sedang disunting (`is_dirty`) tidak ditimpa diam-diam oleh update remote.

---

## 7. Rekomendasi Teknologi untuk `valtera-note-android` (Flutter)
1. **State Management:** `flutter_riverpod` (v2) — deklaratif, kuat, type-safe, dan mudah di-test.
2. **Database Lokal (Cache & Queue):** `drift` (SQLite) / `shared_preferences` untuk metadata, atau `sqflite` — 100% kompatibel dengan relational model `public.notes` dan mutation queue.
3. **Kredensial Aman:** `flutter_secure_storage` (untuk `supabase_url`, `anon_key`, `access_token`, `refresh_token`).
4. **Supabase SDK / HTTP:** `supabase_flutter` atau direct Supabase client via REST/Auth API.
5. **Konektivitas:** `connectivity_plus` untuk deteksi status online/offline.
6. **Routing:** `go_router` untuk navigasi deklaratif (Splash -> Setup -> Auth -> Notes List -> Editor).
