# Supabase Cloud Sync Guide — Valtera Note

Valtera Note is designed as **Local-First, Cloud-Synced**: the app works 100% offline on a local SQLite database, and can sync to **Supabase** for multi-device access.

Sync uses **strict Row Level Security (RLS)** — only your logged-in account can read & write your notes table. The anon key serves merely as a project identifier, never as a door to your data.

---

## 1. Setup Order (Follow In Order)

### Step 1 — Project Credentials

1. Open the [Supabase Dashboard](https://supabase.com/dashboard) ➡️ pick your Project ➡️ **Project Settings → API**.
2. Copy the **Project URL** (e.g. `https://xyzproject.supabase.co`) and the **anon public key** (`eyJhbGciOiJIUzI1Ni...`).
3. Open **Valtera Note** ➡️ **Settings → Supabase Cloud** (or the ☁️ button in the titlebar) ➡️ enter both ➡️ **Connect & Sync**.

### Step 2 — Prepare the `notes` Table

Still in the Supabase Dashboard, open the **SQL Editor** and run the official script below (the same script is available in the app via **Sync Modal → Copy SQL Script**):

```sql
-- 1. Create the notes table (with user_id for per-user Row Level Security)
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

-- 2. Migrate tables created by older app versions
alter table public.notes add column if not exists folder text;
alter table public.notes add column if not exists user_id uuid default auth.uid();

-- 3. Index for sync queries
create index if not exists idx_notes_updated_at on public.notes(updated_at desc);

-- 4. Lock the table to the logged-in owner only.
--    You MUST sign in inside the app after this — without a session, sync cannot write.
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

> This script **revokes all anonymous access** — anyone holding just the anon key cannot read or write your table. Legacy rows with a NULL `user_id` can still be updated by the account owner after login.

### Step 3 — Sign Up / Sign In

1. In **Valtera Note**, open **Settings → Supabase Cloud → Supabase Account**.
2. Click **Register New Account** (create a new password, min. 8 characters) or **Sign In** if you already registered.
3. If email confirmation is required, open your inbox and click the confirmation link — or disable *Confirm email* under **Authentication → Sign In / Providers → Email** to get a session instantly.
4. The status changes to **"Signed in: your@email"** — the session is kept alive with a refresh token.

Once all three steps are done, notes sync **automatically**: 1.5s after typing (debounce) plus a 30s background pull. Old notes that previously failed to push heal themselves within one sync cycle.

---

## 2. How Sync Works

| Mechanism | Description |
| :--- | :--- |
| Per-note push (1.5s debounce) | Every edited note is pushed (upsert) immediately, with E2E-encrypted content (`enc:v1:...`). |
| Full sync every 30s | Pulls notes from the cloud + pushes local notes missing from the cloud (self-healing). |
| Deletion | Local tombstones (`deleted_note_ids`) + remote hard delete; deleted notes are never resurrected. |
| Conflicts | Content is always E2E-encrypted (`enc:v1:...`) — the server only stores ciphertext. |

---

## 3. Troubleshooting

| Problem | Cause & Fix |
| :--- | :--- |
| `Invalid login credentials` on Sign In | Email not confirmed (click the inbox link) or wrong password. Fast path: disable *Confirm email*, delete the user in the dashboard, then **Register New Account** from the app. |
| `permission denied for table notes` / sync can't write | The strict SQL script ran but the app **isn't signed in** — complete Step 3. |
| `new row violates row-level security` | You're signed in with a different account than the one that created the rows — keep logins consistent across devices. |
| Notes exist in the app but not in the cloud (≤ v0.1.12) | Fixed in v0.1.13+: local notes whose IDs are missing from the cloud are pushed automatically within 30s. |
| Dashboard shows a different row count | The Supabase Table Editor doesn't auto-refresh — click its refresh button. Also make sure the open project matches the one configured in the app. |
| Switching Supabase projects | Since v0.1.14 the old session is cleared automatically when the URL changes — just sign in to the new project. |

---

## 4. Security Notes

- **Never use the `service_role` key** in a client application — it bypasses RLS entirely.
- Note contents are stored in the cloud as **E2E ciphertext** (`enc:v1:...`); your Supabase server cannot read them. Note titles are stored as-is.
- The strict script (Step 2) is mandatory — older versions of this documentation shipped a permissive `using (true)` policy that opened the table to anyone holding the anon key.
