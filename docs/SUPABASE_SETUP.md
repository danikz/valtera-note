# Supabase Direct API Sync Guide — Valtera Note

Valtera Note dirancang dengan arsitektur **Local-First, Cloud-Synced**. Aplikasi bekerja 100% offline menggunakan SQLite lokal, dan dapat langsung disinkronkan ke **Supabase** secara instan hanya menggunakan **Project URL** dan **API Key (anon public / service role)** tanpa mewajibkan login email/password!

---

## 1. Skrip Pembuatan Tabel di Supabase (PostgreSQL DDL)

Buka [Supabase Dashboard](https://supabase.com/dashboard) ➡️ Pilih Project Anda ➡️ masuk ke menu **SQL Editor**, lalu jalankan skrip berikut:

```sql
-- 1. Buat tabel notes
create table if not exists public.notes (
    id uuid default gen_random_uuid() primary key,
    title text not null default 'Untitled',
    content text not null default '',
    file_extension text not null default 'md',
    is_pinned boolean not null default false,
    is_deleted boolean not null default false,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Buat index performa sinkronisasi
create index if not exists idx_notes_updated_at on public.notes(updated_at desc);

-- 3. Aktifkan Row-Level Security (RLS) dan izinkan akses API Key
alter table public.notes enable row level security;
create policy "Allow API access" on public.notes for all using (true) with check (true);
```

---

## 2. Cara Menghubungkan ke Valtera Note

1. Di Supabase Dashboard, buka **Project Settings** ➡️ **API**.
2. Salin:
   - **Project URL** (contoh: `https://xyzproject.supabase.co`)
   - **anon public key** (`eyJhbGciOiJIUzI1Ni...`)
3. Buka **Valtera Note** ➡️ klik tombol **Sync (☁️)** di pojok kanan atas.
4. Masukkan **Project URL** dan **API Key**, lalu klik **Connect & Sync**.
5. Catatan Anda akan otomatis tersinkronisasi secara real-time ke Supabase!
