# Design: Enkripsi End-to-End valtera-note

Tanggal: 2026-09-28
Status: Disetujui user

## Problem Statement

valtera-note sudah production. Semua data tersimpan plaintext: konten catatan di SQLite lokal (`tabs_state.content`, `snippets.content`), data sinkron ke Supabase cloud, dan fallback `localStorage`. Siapa pun yang mendapatkan file DB, akses akun Supabase, atau backup dapat membaca seluruh isi catatan. User butuh enkripsi yang aman agar data tidak mudah dibobol.

## Keputusan User

| Keputusan | Pilihan |
|---|---|
| Scope | Konten catatan di DB lokal + data cloud Supabase |
| Skema kunci | Master password end-to-end (mirip Proton Mail / Standard Notes) |
| Metadata | Isi catatan terenkripsi; judul, folder, tanggal tetap plaintext (search sidebar tetap jalan) |
| Migrasi data lama | Auto-migrate saat password pertama di-set |
| UX unlock | Ingat password/kunci di device via Windows Credential Manager |

## Pendekatan

**Dipilih: enkripsi di Rust backend (Tauri).**

- KDF: Argon2id (crate `argon2`), parameter OWASP: m=19456 KiB, t=2, p=1. Salt 16-byte acak per user.
- Cipher: XChaCha20-Poly1305 (crate `chacha20poly1305`), nonce 24-byte acak per operasi.
- Format ciphertext: string `enc:v1:` + base64(nonce ‖ ciphertext ‖ tag). Prefix jadi penanda "sudah terenkripsi" dan versi format.
- Kunci 32-byte hidup hanya di memori Rust (`Mutex<Option<EncryptionKey>>` di app state), di-wipe dengan `zeroize` saat lock/exit.
- Keyring: crate `keyring` (Windows Credential Manager) menyimpan kunci turunan (bukan password) agar password tidak pernah at-rest.

Ditolak:
- Frontend WebCrypto — PBKDF2 lebih lemah dari Argon2id; kunci bocor ke devtools.
- SQLCipher — tidak menyentuh data cloud; butuh dua sistem kunci.

## Komponen

### 1. Crypto core — `src-tauri/src/crypto/mod.rs` (baru)

- `derive_key(password, salt) -> [u8; 32]` — Argon2id.
- `encrypt(key, plaintext) -> String` — XChaCha20-Poly1305, output `enc:v1:...`.
- `decrypt(key, ciphertext) -> Result<String>` — gagal jelas saat auth tag tidak cocok (data dimanipulasi/korup).
- `is_encrypted(value) -> bool` — deteksi prefix `enc:v1:`.
- Semua struct yang pegang key material implement `Zeroize`/`Drop`.

### 2. Key lifecycle — command Tauri baru

- `set_master_password(password, remember_device)`:
  1. Generate salt 16-byte.
  2. Derive key via Argon2id.
  3. Simpan salt + verifier (teks known yang dienkripsi) ke `app_settings`.
  4. Migrasi: re-encrypt semua data plaintext (lokal + cloud).
  5. Kalau `remember_device`: simpan kunci base64 ke keyring `valtera-note/e2e-key`.
  6. Simpan kunci di app state.
- `unlock(password) -> bool` — baca salt + verifier dari `app_settings`, derive, verifikasi. Salah → error "Password salah".
- `is_unlocked() -> bool` — untuk UI menentukan lock screen vs editor.
- `lock()` — wipe kunci dari memori.
- `change_password(old, new)` — validasi lama, salt+key baru, re-encrypt semua, update keyring.
- `disable_remember_device()` — hapus entri keyring.

### 3. Aliran data

**SQLite lokal:**
- `save_session_tabs` menyimpan `content` sebagai `enc:v1:...` saat kunci aktif.
- `load_session_tabs` decrypt transparan (baris plaintext tanpa prefix diteruskan apa adanya — defensive untuk data yang belum termigrasi).
- Berlaku juga untuk `snippets.content`.

**Supabase cloud (sync dari frontend via fetch):**
- Command `encrypt_content(content) -> String` dan `decrypt_content(cipher) -> String`.
- `editorStore.syncSingleTab` panggil `encrypt_content` sebelum `upsertRemoteNote`.
- `fetchRemoteNotes` → frontend panggil `decrypt_content` per note.
- Plaintext melewati memori JS sesaat; kunci tidak pernah keluar dari proses Rust.

**Metadata:** judul, folder, tanggal, ID tetap plaintext di SQLite dan Supabase.

### 4. Migrasi otomatis

Berjalan sekali di dalam `set_master_password` setelah kunci aktif:
1. UPDATE semua baris `tabs_state` & `snippets` yang `content` belum berprefix `enc:v1:` → terenkripsi.
2. Tarik semua remote notes → upsert ulang dengan `encrypt_content`.
3. Transaksional untuk DB lokal; idempoten (prefix check mencegah double-encrypt).

### 5. Error handling

| Kasus | Perilaku |
|---|---|
| Password salah saat unlock | Error "Password salah" (verifier mismatch), tidak crash |
| Data terenkripsi, kunci tidak ada | UI lock screen muncul |
| Ciphertext korup | Tab menampilkan `[Gagal decrypt]`, app tetap jalan |
| Keyring tidak tersedia/gagal | Fallback: prompt password tiap launch |
| Kunci hilang (password lupa) | Data tidak bisa dipulihkan — ditampilkan peringatan saat set password |

### 6. UI (Svelte)

- Komponen lock screen: muncul saat `is_unlocked() == false` dan ada data terenkripsi.
- Setup wizard pertama: buat master password (input 2x, meter kekuatan, peringatan "lupa password = data hilang permanen"), checkbox "Ingat di device ini".
- Pengaturan: tombol Lock, ganti password, hapus ingat-device.

## Testing

- Unit test Rust: roundtrip encrypt/decrypt, determinisme KDF (salt sama → kunci sama), deteksi tamper (flip byte → error), deteksi prefix, migrasi DB sample in-memory, unlock salah password.
- Manual E2E: set password → restart → auto-unlock via keyring → lock → wrong password ditolak → Supabase dashboard menampilkan ciphertext pada kolom content → device kedua login password sama → decrypt sukses.

## Dependensi baru (Cargo)

`argon2`, `chacha20poly1305`, `keyring`, `rand`, `base64`, `zeroize`

## Batasan & Risiko

- Lupa master password = data hilang permanen (sifat E2E, tanpa escrow).
- Metadata plaintext: pihak dengan akses Supabase bisa lihat judul/folder/tanggal — keputusan sadar user demi search sidebar.
- Plaintext sempat ada di memori JS saat decrypt untuk render — risiko diterima; kunci tetap di Rust.
- Brute-force tetap mungkin secara teori; Argon2id dengan parameter OWASP membuatnya mahal.
