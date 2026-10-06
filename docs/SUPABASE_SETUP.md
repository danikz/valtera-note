# Supabase Cloud Sync Guide — Valtera Note

Valtera Note dirancang dengan arsitektur **Local-First, Cloud-Synced**: aplikasi bekerja 100% offline menggunakan SQLite lokal, dan dapat disinkronkan ke **Supabase** untuk akses multi-perangkat.

Sinkronisasi menggunakan **Row Level Security (RLS) ketat** — hanya akun yang login yang bisa membaca & menulis tabel catatanmu. Anon key hanya dipakai sebagai penanda project, bukan pintu akses data.

---

## 1. Urutan Setup (Ikuti Berurutan)

### Langkah 1 — Kredensial Project

1. Buka [Supabase Dashboard](https://supabase.com/dashboard) ➡️ pilih Project ➡️ **Project Settings → API**.
2. Salin **Project URL** (contoh: `https://xyzproject.supabase.co`) dan **anon public key** (`eyJhbGciOiJIUzI1Ni...`).
3. Buka **Valtera Note** ➡️ **Pengaturan → Supabase Cloud** (atau tombol ☁️ di titlebar) ➡️ masukkan keduanya ➡️ **Connect & Sync**.

### Langkah 2 — Siapkan Tabel `notes`

Masih di Supabase Dashboard, buka **SQL Editor**, jalankan skrip resmi berikut (skrip yang sama tersedia di app melalui **SyncModal → Copy Skrip SQL**):

```sql
-- 1. Buat tabel notes (dengan user_id untuk per-user Row Level Security)
create table if not exists public.notes (
    id uuid default gen_random_uuid() primary key,
    user_id uuid default auth.uid(),
    title text not null default 'Untitled',
    content text not null default '',
    file_extension text not null default 'md',
    folder text,
    is_pinned boolean not null default false,
    is_deleted boolean not null default false,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Migrasi tabel dari versi app lama
alter table public.notes add column if not exists folder text;
alter table public.notes add column if not exists user_id uuid default auth.uid();

-- 3. Index untuk query sinkronisasi
create index if not exists idx_notes_updated_at on public.notes(updated_at desc);

-- 4. Kunci tabel hanya untuk pemilik akun yang login.
--    WAJIB login di app setelah ini — tanpa sesi login, sync tidak bisa menulis.
alter table public.notes enable row level security;

revoke all on public.notes from anon;

drop policy if exists "Allow API access" on public.notes;
drop policy if exists "Allow all for anon and authenticated" on public.notes;
drop policy if exists "Enable read access for all users" on public.notes;
drop policy if exists "Owner full access" on public.notes;

create policy "Owner full access"
on public.notes
for all
to authenticated
using (auth.uid() = user_id or user_id is null)
with check (auth.uid() = user_id or user_id is null);
```

> Skrip ini **mencabut semua akses anon** — siapa pun yang hanya memegang anon key tidak bisa membaca atau menulis tabelmu. Baris lama ber-`user_id` NULL tetap dapat diperbarui oleh pemilik akun setelah login.

### Langkah 3 — Masuk / Daftar Akun

1. Di **Valtera Note**, buka **Pengaturan → Supabase Cloud → Akun Supabase**.
2. Klik **Daftar Akun Baru** (buat password baru, minimal 8 karakter) atau **Masuk** bila sudah pernah daftar.
3. Jika diminta konfirmasi email, buka inbox dan klik tautan konfirmasi — atau matikan *Confirm email* di **Authentication → Sign In / Providers → Email** agar langsung dapat sesi.
4. Status berubah menjadi **"Masuk: emailmu"** — sesi ditahan otomatis dengan refresh token.

Setelah ketiga langkah selesai, semua catatan tersinkron **otomatis**: 1,5 detik setelah mengetik (debounce) + pull berkala tiap 30 detik. Note lama yang pernah gagal ter-push akan pulih sendiri dalam satu siklus sync.

---

## 2. Cara Kerja Sinkronisasi

| Mekanisme | Keterangan |
| :--- | :--- |
| Push per-note (debounce 1,5 detik) | Setiap catatan yang diedit langsung dikirim (upsert) dengan konten terenkripsi E2E (`enc:v1:...`). |
| Sync penuh tiap 30 detik | Pull catatan dari cloud + push catatan lokal yang belum ada di cloud (self-healing). |
| Hapus | Tombstone lokal (`deleted_note_ids`) + hard-delete remote; note yang dihapus tidak akan dihidupkan kembali. |
| Konflik | konten selalu E2E-encrypted (`enc:v1:...`) — server hanya menyimpan ciphertext. |

---

## 3. Troubleshooting

| Masalah | Penyebab & Solusi |
| :--- | :--- |
| `Invalid login credentials` saat Masuk | Email belum dikonfirmasi (klik tautan dari inbox) atau password salah. Jalur cepat: matikan *Confirm email*, hapus user di dashboard, lalu **Daftar Akun Baru** dari app. |
| `permission denied for table notes` / sync gagal menulis | Skrip SQL ketat sudah dijalankan tapi app **belum login** — selesaikan Langkah 3. |
| `new row violates row-level security` | Kamu login dengan akun berbeda dari yang membuat baris — pastikan login konsisten di semua perangkat. |
| Catatan ada di app tapi tidak di cloud (v0.1.12 ke bawah) | Bug sudah diperbaiki di v0.1.13+: note lokal yang ID-nya belum ada di cloud di-push otomatis dalam ≤30 detik. |
| Dashboard menampilkan jumlah baris berbeda | Table Editor Supabase tidak auto-refresh — klik tombol refresh. Pastikan juga project yang dibuka sama dengan yang tercantum di app. |
| Ganti project Supabase | Sejak v0.1.14 sesi lama otomatis dibersihkan saat URL berubah — cukup login ulang ke project baru. |

---

## 4. Catatan Keamanan

- **Jangan pakai `service_role` key** di aplikasi client — key itu melewati RLS sepenuhnya.
- Isi catatan tersimpan di cloud sebagai **ciphertext E2E** (`enc:v1:...`); server Supabase-mu tidak bisa membacanya. Judul catatan tersimpan apa adanya.
- Skrip ketat (Langkah 2) wajib dijalankan — versi lama dokumentasi pernah menyertakan policy permisif `using (true)` yang membuka tabel ke siapa pun dengan anon key.
