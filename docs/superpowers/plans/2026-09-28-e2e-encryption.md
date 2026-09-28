# E2E Encryption Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enkripsi konten catatan end-to-end (SQLite lokal + Supabase cloud) dengan master password (Argon2id + XChaCha20-Poly1305), auto-migrasi data plaintext, auto-unlock via Windows Credential Manager.

**Architecture:** Modul crypto Rust (`src-tauri/src/crypto/`) memegang kunci di memori saja. Enkripsi/decryption terjadi di layer command Tauri: `save_tabs_state` encrypt sebelum tulis DB, `load_session` decrypt setelah baca, sync Supabase encrypt/decrypt via command `encrypt_content`/`decrypt_content` yang dipanggil frontend. Kunci TIDAK PERNAH masuk JS. Format ciphertext: `enc:v1:` + base64(nonce‖ciphertext‖tag).

**Tech Stack:** Rust (tauri 2, rusqlite), crate baru: `argon2 0.5`, `chacha20poly1305 0.10`, `keyring 3`, `base64 0.22`, `zeroize 1`. Frontend: Svelte 5.

**Spec:** `docs/superpowers/specs/2026-09-28-e2e-encryption-design.md`

---

### Task 1: Crypto core module

**Files:**
- Modify: `src-tauri/Cargo.toml`
- Create: `src-tauri/src/crypto/mod.rs`
- Modify: `src-tauri/src/lib.rs:1` (tambah `pub mod crypto;`)

- [ ] **Step 1: Tambah dependensi Cargo**

Di `src-tauri/Cargo.toml`, setelah baris `dirs = "5.0"` tambahkan:

```toml
argon2 = "0.5"
chacha20poly1305 = "0.10"
keyring = "3"
base64 = "0.22"
zeroize = "1"
```

- [ ] **Step 2: Buat file `src-tauri/src/crypto/mod.rs` dengan test dulu**

Buat file berikut (test + implementasi sekaligus; implementasi minimal agar test jalan — TDD penuh sulit untuk file baru kosong karena modul tidak compile tanpa fungsi):

```rust
use argon2::{Algorithm, Argon2, Params, Version};
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use chacha20poly1305::aead::{Aead, AeadCore, KeyInit, OsRng};
use chacha20poly1305::{XChaCha20Poly1305, XNonce};

pub mod keystore;

pub const ENC_PREFIX: &str = "enc:v1:";
pub const SETTING_SALT: &str = "e2e_salt";
pub const SETTING_VERIFIER: &str = "e2e_verifier";
pub const SETTING_DECLINED: &str = "e2e_declined";
pub const VERIFIER_PLAINTEXT: &str = "valtera-e2e-verifier";

const ARGON2_M_KIB: u32 = 19456; // 19 MiB (OWASP)
const ARGON2_T: u32 = 2;
const ARGON2_P: u32 = 1;

pub type Key = [u8; 32];

pub fn is_encrypted(value: &str) -> bool {
    value.starts_with(ENC_PREFIX)
}

pub fn generate_salt() -> [u8; 16] {
    use chacha20poly1305::aead::rand_core::RngCore;
    let mut salt = [0u8; 16];
    OsRng.fill_bytes(&mut salt);
    salt
}

pub fn derive_key(password: &str, salt: &[u8; 16]) -> Result<Key, String> {
    let params = Params::new(ARGON2_M_KIB, ARGON2_T, ARGON2_P, Some(32))
        .map_err(|e| e.to_string())?;
    let argon = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);
    let mut key = [0u8; 32];
    argon
        .hash_password_into(password.as_bytes(), salt, &mut key)
        .map_err(|e| e.to_string())?;
    Ok(key)
}

pub fn encrypt(key: &Key, plaintext: &str) -> Result<String, String> {
    let cipher = XChaCha20Poly1305::new(key.into());
    let nonce = XChaCha20Poly1305::generate_nonce(&mut OsRng);
    let ciphertext = cipher
        .encrypt(&nonce, plaintext.as_bytes())
        .map_err(|e| e.to_string())?;
    let mut buf = Vec::with_capacity(24 + ciphertext.len());
    buf.extend_from_slice(nonce.as_slice());
    buf.extend_from_slice(&ciphertext);
    Ok(format!("{}{}", ENC_PREFIX, B64.encode(buf)))
}

pub fn decrypt(key: &Key, value: &str) -> Result<String, String> {
    let encoded = value
        .strip_prefix(ENC_PREFIX)
        .ok_or_else(|| "not encrypted".to_string())?;
    let raw = B64.decode(encoded).map_err(|_| "ciphertext base64 invalid".to_string())?;
    if raw.len() < 24 {
        return Err("ciphertext too short".to_string());
    }
    let (nonce_bytes, ciphertext) = raw.split_at(24);
    let nonce = XNonce::from_slice(nonce_bytes);
    let cipher = XChaCha20Poly1305::new(key.into());
    let plaintext = cipher
        .decrypt(nonce, ciphertext)
        .map_err(|_| "Decryption failed (password salah atau data korup)".to_string())?;
    String::from_utf8(plaintext).map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip_encrypt_decrypt() {
        let key = derive_key("password123", &[0u8; 16]).unwrap();
        let ct = encrypt(&key, " isi catatan rahasia\nmultiline").unwrap();
        assert!(ct.starts_with("enc:v1:"));
        assert_eq!(decrypt(&key, &ct).unwrap(), " isi catatan rahasia\nmultiline");
    }

    #[test]
    fn derive_key_deterministic() {
        let salt = [7u8; 16];
        assert_eq!(derive_key("abc", &salt).unwrap(), derive_key("abc", &salt).unwrap());
        assert_ne!(derive_key("abc", &salt).unwrap(), derive_key("abd", &salt).unwrap());
    }

    #[test]
    fn tamper_detected() {
        let key = derive_key("password123", &[1u8; 16]).unwrap();
        let ct = encrypt(&key, "rahasia").unwrap();
        // flip satu byte di bagian base64
        let mut chars: Vec<char> = ct.chars().collect();
        let last = chars.len() - 1;
        chars[last] = if chars[last] == 'A' { 'B' } else { 'A' };
        let tampered: String = chars.into_iter().collect();
        assert!(decrypt(&key, &tampered).is_err());
    }

    #[test]
    fn wrong_key_fails() {
        let key1 = derive_key("password123", &[2u8; 16]).unwrap();
        let key2 = derive_key("password456", &[2u8; 16]).unwrap();
        let ct = encrypt(&key1, "rahasia").unwrap();
        assert!(decrypt(&key2, &ct).is_err());
    }

    #[test]
    fn is_encrypted_prefix() {
        assert!(is_encrypted("enc:v1:AAAA"));
        assert!(!is_encrypted("plaintext biasa"));
        assert!(!is_encrypted(""));
    }

    #[test]
    fn decrypt_rejects_plaintext() {
        let key = derive_key("x", &[3u8; 16]).unwrap();
        assert!(decrypt(&key, "bukan ciphertext").is_err());
    }
}
```

Catatan: file berisi `pub mod keystore;` tapi Task 1 belum buat file itu — buat placeholder `src-tauri/src/crypto/keystore.rs` berisi satu baris `// diisi Task 2` agar compile.

- [ ] **Step 3: Daftarkan modul di `src-tauri/src/lib.rs`**

Baris 1-5 sekarang:

```rust
pub mod commands;
pub mod db;
pub mod models;
pub mod services;
pub mod supabase;
```

Ubah jadi:

```rust
pub mod commands;
pub mod crypto;
pub mod db;
pub mod models;
pub mod services;
pub mod supabase;
```

- [ ] **Step 4: Run test**

Run (workdir `src-tauri`): `cargo test`
Expected: semua 6 test crypto PASS. Argon2id dengan 19 MiB agak lambat (~0.1-1s per panggilan) — normal.

- [ ] **Step 5: Commit**

```bash
git add src-tauri/Cargo.toml src-tauri/Cargo.lock src-tauri/src/crypto/ src-tauri/src/lib.rs
git commit -m "feat(crypto): add Argon2id + XChaCha20-Poly1305 core module"
```

---

### Task 2: KeyManager + keyring

**Files:**
- Modify: `src-tauri/src/crypto/keystore.rs` (ganti placeholder)

- [ ] **Step 1: Implementasi KeyManager**

Ganti seluruh isi `src-tauri/src/crypto/keystore.rs`:

```rust
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use std::sync::Mutex;
use zeroize::Zeroizing;

use crate::crypto::Key;

const KEYRING_SERVICE: &str = "valtera-note";
const KEYRING_ACCOUNT: &str = "e2e-key";

pub struct KeyManager {
    key: Mutex<Option<Zeroizing<Key>>>,
}

impl Default for KeyManager {
    fn default() -> Self {
        Self::new()
    }
}

impl KeyManager {
    pub fn new() -> Self {
        Self {
            key: Mutex::new(None),
        }
    }

    pub fn set_key(&self, key: Key) {
        *self.key.lock().unwrap() = Some(Zeroizing::new(key));
    }

    pub fn clear(&self) {
        *self.key.lock().unwrap() = None;
    }

    pub fn is_unlocked(&self) -> bool {
        self.key.lock().unwrap().is_some()
    }

    /// Jalankan closure dengan kunci. None jika terkunci.
    pub fn with_key<R>(&self, f: impl FnOnce(&Key) -> R) -> Option<R> {
        let guard = self.key.lock().unwrap();
        guard.as_ref().map(|k| f(&**k))
    }

    pub fn save_to_keyring(key: &Key) -> Result<(), String> {
        let entry =
            keyring::Entry::new(KEYRING_SERVICE, KEYRING_ACCOUNT).map_err(|e| e.to_string())?;
        entry.set_password(&B64.encode(key)).map_err(|e| e.to_string())
    }

    pub fn load_from_keyring() -> Result<Key, String> {
        let entry =
            keyring::Entry::new(KEYRING_SERVICE, KEYRING_ACCOUNT).map_err(|e| e.to_string())?;
        let b64 = entry.get_password().map_err(|e| e.to_string())?;
        let raw = B64.decode(b64).map_err(|_| "keyring entry corrupt".to_string())?;
        raw.try_into()
            .map_err(|_| "keyring key length invalid".to_string())
    }

    pub fn delete_from_keyring() -> Result<(), String> {
        let entry =
            keyring::Entry::new(KEYRING_SERVICE, KEYRING_ACCOUNT).map_err(|e| e.to_string())?;
        match entry.delete_credential() {
            Ok(()) | Err(keyring::Error::NoEntry) => Ok(()),
            Err(e) => Err(e.to_string()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn set_clear_is_unlocked() {
        let km = KeyManager::new();
        assert!(!km.is_unlocked());
        km.set_key([9u8; 32]);
        assert!(km.is_unlocked());
        km.clear();
        assert!(!km.is_unlocked());
    }

    #[test]
    fn with_key_returns_none_when_locked() {
        let km = KeyManager::new();
        assert!(km.with_key(|k| *k).is_none());
        km.set_key([5u8; 32]);
        assert_eq!(km.with_key(|k| *k), Some([5u8; 32]));
    }
}
```

- [ ] **Step 2: Run test**

Run (workdir `src-tauri`): `cargo test keystore`
Expected: 2 test PASS.

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/crypto/keystore.rs
git commit -m "feat(crypto): add KeyManager with in-memory key and OS keyring storage"
```

---

### Task 3: DB migration methods

**Files:**
- Modify: `src-tauri/src/db/mod.rs` (tambah 2 method di akhir `impl DatabaseManager`, sebelum `}` penutup impl di line 313)

- [ ] **Step 1: Tambah method `migrate_content` dan `reencrypt_all`**

Setelah method `list_snippets` (line 312 `}` penutup list_snippets), sebelum `}` penutup `impl DatabaseManager` (line 313), tambahkan:

```rust
    /// Enkripsi semua content plaintext (tanpa prefix enc:v1:) di tabs_state & snippets.
    /// Idempoten: baris yang sudah terenkripsi dilewati. Dipakai saat set_master_password.
    pub fn migrate_content<F>(&self, encrypt: F) -> Result<(usize, usize), String>
    where
        F: Fn(&str) -> Result<String, String>,
    {
        let mut conn = self.conn.lock().map_err(|e| e.to_string())?;
        let mut tabs_done = 0usize;

        {
            let mut stmt = conn
                .prepare(
                    "SELECT id, content FROM tabs_state
                     WHERE content IS NOT NULL AND content NOT LIKE 'enc:v1:%'",
                )
                .map_err(|e| e.to_string())?;
            let rows: Vec<(i64, String)> = stmt
                .query_map([], |row| Ok((row.get(0)?, row.get(1)?)))
                .map_err(|e| e.to_string())?
                .filter_map(|r| r.ok())
                .collect();
            drop(stmt);
            for (id, content) in rows {
                let enc = encrypt(&content)?;
                conn.execute(
                    "UPDATE tabs_state SET content = ?1 WHERE id = ?2",
                    params![enc, id],
                )
                .map_err(|e| e.to_string())?;
                tabs_done += 1;
            }
        }

        let mut snippets_done = 0usize;
        {
            let mut stmt = conn
                .prepare(
                    "SELECT id, content FROM snippets
                     WHERE content IS NOT NULL AND content NOT LIKE 'enc:v1:%' AND is_deleted = 0",
                )
                .map_err(|e| e.to_string())?;
            let rows: Vec<(i64, String)> = stmt
                .query_map([], |row| Ok((row.get(0)?, row.get(1)?)))
                .map_err(|e| e.to_string())?
                .filter_map(|r| r.ok())
                .collect();
            drop(stmt);
            for (id, content) in rows {
                let enc = encrypt(&content)?;
                conn.execute(
                    "UPDATE snippets SET content = ?1 WHERE id = ?2",
                    params![enc, id],
                )
                .map_err(|e| e.to_string())?;
                snippets_done += 1;
            }
        }

        Ok((tabs_done, snippets_done))
    }

    /// Decrypt dengan kunci lama lalu re-encrypt dengan kunci baru (semua baris terenkripsi).
    /// Dipakai saat change_password.
    pub fn reencrypt_all<D, E>(&self, decrypt: D, encrypt: E) -> Result<(usize, usize), String>
    where
        D: Fn(&str) -> Result<String, String>,
        E: Fn(&str) -> Result<String, String>,
    {
        let mut conn = self.conn.lock().map_err(|e| e.to_string())?;
        let mut tabs_done = 0usize;

        {
            let mut stmt = conn
                .prepare(
                    "SELECT id, content FROM tabs_state
                     WHERE content IS NOT NULL AND content LIKE 'enc:v1:%'",
                )
                .map_err(|e| e.to_string())?;
            let rows: Vec<(i64, String)> = stmt
                .query_map([], |row| Ok((row.get(0)?, row.get(1)?)))
                .map_err(|e| e.to_string())?
                .filter_map(|r| r.ok())
                .collect();
            drop(stmt);
            for (id, content) in rows {
                let plain = decrypt(&content)?;
                let enc = encrypt(&plain)?;
                conn.execute(
                    "UPDATE tabs_state SET content = ?1 WHERE id = ?2",
                    params![enc, id],
                )
                .map_err(|e| e.to_string())?;
                tabs_done += 1;
            }
        }

        let mut snippets_done = 0usize;
        {
            let mut stmt = conn
                .prepare(
                    "SELECT id, content FROM snippets
                     WHERE content IS NOT NULL AND content LIKE 'enc:v1:%' AND is_deleted = 0",
                )
                .map_err(|e| e.to_string())?;
            let rows: Vec<(i64, String)> = stmt
                .query_map([], |row| Ok((row.get(0)?, row.get(1)?)))
                .map_err(|e| e.to_string())?
                .filter_map(|r| r.ok())
                .collect();
            drop(stmt);
            for (id, content) in rows {
                let plain = decrypt(&content)?;
                let enc = encrypt(&plain)?;
                conn.execute(
                    "UPDATE snippets SET content = ?1 WHERE id = ?2",
                    params![enc, id],
                )
                .map_err(|e| e.to_string())?;
                snippets_done += 1;
            }
        }

        Ok((tabs_done, snippets_done))
    }
```

- [ ] **Step 2: Pastikan compile**

Run (workdir `src-tauri`): `cargo check`
Expected: tidak ada error.

- [ ] **Step 3: Commit**

```bash
git add src-tauri/src/db/mod.rs
git commit -m "feat(db): add content migration and re-encrypt methods for E2E encryption"
```

---

### Task 4: Tauri crypto commands + registrasi + auto-unlock startup

**Files:**
- Create: `src-tauri/src/commands/crypto.rs`
- Modify: `src-tauri/src/commands/mod.rs`
- Modify: `src-tauri/src/lib.rs`

- [ ] **Step 1: Buat `src-tauri/src/commands/crypto.rs`**

```rust
use std::sync::Arc;
use tauri::State;

use crate::crypto::{self, keystore::KeyManager, Key};
use crate::crypto::{SETTING_DECLINED, SETTING_SALT, SETTING_VERIFIER, VERIFIER_PLAINTEXT};
use crate::db::DatabaseManager;

fn b64_encode(data: &[u8]) -> String {
    use base64::{engine::general_purpose::STANDARD as B64, Engine};
    B64.encode(data)
}

fn b64_decode16(value: &str) -> Result<[u8; 16], String> {
    use base64::{engine::general_purpose::STANDARD as B64, Engine};
    let raw = B64.decode(value).map_err(|_| "salt base64 invalid".to_string())?;
    raw.try_into().map_err(|_| "salt length invalid".to_string())
}

/// Status E2E untuk frontend: "none" (belum diatur), "locked", "ready".
#[tauri::command]
pub async fn e2e_status(
    keys: State<'_, KeyManager>,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<String, String> {
    let db = Arc::clone(&db);
    let has = tokio::task::spawn_blocking(move || {
        let salt = db.get_setting(SETTING_SALT)?;
        Ok::<_, String>(salt.is_some())
    })
    .await
    .map_err(|e| e.to_string())??;

    if !has {
        Ok("none".to_string())
    } else if keys.is_unlocked() {
        Ok("ready".to_string())
    } else {
        Ok("locked".to_string())
    }
}

#[tauri::command]
pub async fn has_master_password(
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<bool, String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || {
        let salt = db.get_setting(SETTING_SALT)?;
        Ok::<_, String>(salt.is_some())
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn set_master_password(
    password: String,
    remember_device: bool,
    keys: State<'_, KeyManager>,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<(), String> {
    if password.len() < 8 {
        return Err("Password minimal 8 karakter".to_string());
    }

    let db = Arc::clone(&db);
    let key = tokio::task::spawn_blocking(move || {
        let salt = crypto::generate_salt();
        let key = crypto::derive_key(&password, &salt)?;
        let verifier = crypto::encrypt(&key, VERIFIER_PLAINTEXT)?;
        db.set_setting(SETTING_SALT, &b64_encode(&salt))?;
        db.set_setting(SETTING_VERIFIER, &verifier)?;
        db.set_setting(SETTING_DECLINED, "0")?;

        // Migrasi otomatis: re-encrypt semua plaintext lokal
        let counts = db.migrate_content(|pt| crypto::encrypt(&key, pt))?;
        eprintln!(
            "E2E migration complete: {} tabs, {} snippets encrypted",
            counts.0, counts.1
        );

        if remember_device {
            KeyManager::save_to_keyring(&key)?;
        } else {
            let _ = KeyManager::delete_from_keyring();
        }
        Ok::<_, String>(key)
    })
    .await
    .map_err(|e| e.to_string())??;

    keys.set_key(key);
    Ok(())
}

#[tauri::command]
pub async fn unlock(
    password: String,
    keys: State<'_, KeyManager>,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<(), String> {
    let db = Arc::clone(&db);
    let key = tokio::task::spawn_blocking(move || {
        let salt_b64 = db
            .get_setting(SETTING_SALT)?
            .ok_or_else(|| "Master password belum diatur".to_string())?;
        let salt = b64_decode16(&salt_b64)?;
        let verifier = db
            .get_setting(SETTING_VERIFIER)?
            .ok_or_else(|| "Verifier E2E tidak ditemukan".to_string())?;
        let key = crypto::derive_key(&password, &salt)?;
        let plain = crypto::decrypt(&key, &verifier)?;
        if plain != VERIFIER_PLAINTEXT {
            return Err("Password salah".to_string());
        }
        Ok::<_, String>(key)
    })
    .await
    .map_err(|e| e.to_string())??;

    keys.set_key(key);
    Ok(())
}

#[tauri::command]
pub fn lock(keys: State<'_, KeyManager>) {
    keys.clear();
}

#[tauri::command]
pub fn is_unlocked(keys: State<'_, KeyManager>) -> bool {
    keys.is_unlocked()
}

#[tauri::command]
pub async fn change_password(
    old_password: String,
    new_password: String,
    remember_device: bool,
    keys: State<'_, KeyManager>,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<(), String> {
    if new_password.len() < 8 {
        return Err("Password baru minimal 8 karakter".to_string());
    }

    let db = Arc::clone(&db);
    let new_key = tokio::task::spawn_blocking(move || {
        // 1. Validasi password lama
        let salt_b64 = db
            .get_setting(SETTING_SALT)?
            .ok_or_else(|| "Master password belum diatur".to_string())?;
        let salt = b64_decode16(&salt_b64)?;
        let verifier = db
            .get_setting(SETTING_VERIFIER)?
            .ok_or_else(|| "Verifier E2E tidak ditemukan".to_string())?;
        let old_key = crypto::derive_key(&old_password, &salt)?;
        let plain = crypto::decrypt(&old_key, &verifier)?;
        if plain != VERIFIER_PLAINTEXT {
            return Err("Password lama salah".to_string());
        }

        // 2. Kunci baru + salt baru
        let new_salt = crypto::generate_salt();
        let new_key = crypto::derive_key(&new_password, &new_salt)?;
        let new_verifier = crypto::encrypt(&new_key, VERIFIER_PLAINTEXT)?;

        // 3. Re-encrypt semua data lama->baru
        let counts = db.reencrypt_all(
            |ct| crypto::decrypt(&old_key, ct),
            |pt| crypto::encrypt(&new_key, pt),
        )?;
        eprintln!(
            "E2E re-encryption complete: {} tabs, {} snippets",
            counts.0, counts.1
        );

        // 4. Simpan salt + verifier baru
        db.set_setting(SETTING_SALT, &b64_encode(&new_salt))?;
        db.set_setting(SETTING_VERIFIER, &new_verifier)?;

        if remember_device {
            KeyManager::save_to_keyring(&new_key)?;
        } else {
            let _ = KeyManager::delete_from_keyring();
        }
        Ok::<_, String>(new_key)
    })
    .await
    .map_err(|e| e.to_string())??;

    keys.set_key(new_key);
    Ok(())
}

/// Enkripsi konten untuk sync cloud. Plaintext passthrough jika sudah terenkripsi.
#[tauri::command]
pub async fn encrypt_content(
    content: String,
    keys: State<'_, KeyManager>,
) -> Result<String, String> {
    if crypto::is_encrypted(&content) {
        return Ok(content);
    }
    keys.with_key(|k| crypto::encrypt(k, &content))
        .ok_or_else(|| "App terkunci - tidak bisa mengenkripsi".to_string())
}

/// Decrypt konten dari cloud. Ciphertext passthrough jika belum terenkripsi.
#[tauri::command]
pub async fn decrypt_content(
    content: String,
    keys: State<'_, KeyManager>,
) -> Result<String, String> {
    if !crypto::is_encrypted(&content) {
        return Ok(content);
    }
    keys.with_key(|k| crypto::decrypt(k, &content))
        .ok_or_else(|| "App terkunci - tidak bisa mendekripsi".to_string())
}

/// Hapus kunci dari keyring device ini (lupakan device).
#[tauri::command]
pub async fn forget_device() -> Result<(), String> {
    tokio::task::spawn_blocking(KeyManager::delete_from_keyring)
        .await
        .map_err(|e| e.to_string())?
}
```

- [ ] **Step 2: Daftarkan modul commands**

`src-tauri/src/commands/mod.rs` — tambah `pub mod crypto;` dan `pub use crypto::*;`:

```rust
pub mod crypto;
pub mod db;
pub mod fs;
pub mod sql;
pub mod supabase;

pub use crypto::*;
pub use db::*;
pub use fs::*;
pub use sql::*;
pub use supabase::*;
```

- [ ] **Step 3: Wire di `src-tauri/src/lib.rs` — state KeyManager, auto-unlock startup, registrasi command**

Setelah blok `let db = ...;` (line 19), tambahkan auto-unlock dari keyring:

```rust
    let keys = crypto::keystore::KeyManager::new();
    // Auto-unlock: ambil kunci dari OS keyring, verifikasi terhadap verifier di DB
    if let Ok(key) = crypto::keystore::KeyManager::load_from_keyring() {
        let verifier_ok = db
            .get_setting(crypto::SETTING_VERIFIER)
            .ok()
            .flatten()
            .and_then(|v| crypto::decrypt(&key, &v).ok())
            .map(|p| p == crypto::VERIFIER_PLAINTEXT)
            .unwrap_or(false);
        if verifier_ok {
            keys.set_key(key);
        }
    }
```

Tambahkan `.manage(keys)` setelah `.manage(db)` (line 48), dan daftarkan command di `invoke_handler` (setelah blok `// Database & session operations`):

```rust
            // E2E encryption
            commands::crypto::e2e_status,
            commands::crypto::has_master_password,
            commands::crypto::set_master_password,
            commands::crypto::unlock,
            commands::crypto::lock,
            commands::crypto::is_unlocked,
            commands::crypto::change_password,
            commands::crypto::encrypt_content,
            commands::crypto::decrypt_content,
            commands::crypto::forget_device,
```

- [ ] **Step 4: Pastikan compile**

Run (workdir `src-tauri`): `cargo check`
Expected: tidak ada error.

- [ ] **Step 5: Commit**

```bash
git add src-tauri/src/commands/crypto.rs src-tauri/src/commands/mod.rs src-tauri/src/lib.rs
git commit -m "feat(crypto): add E2E master password commands with keyring auto-unlock"
```

---

### Task 5: Enkripsi transparan di save/load DB command layer

**Files:**
- Modify: `src-tauri/src/commands/db.rs`

- [ ] **Step 1: Ubah `save_tabs_state`, `load_session`, `list_snippets`**

Ganti seluruh isi `src-tauri/src/commands/db.rs`:

```rust
use tauri::State;
use std::sync::Arc;
use crate::crypto;
use crate::crypto::keystore::KeyManager;
use crate::db::DatabaseManager;
use crate::models::{SessionStateDto, SnippetDto, TabStateDto};

#[tauri::command]
pub async fn save_tabs_state(
    tabs: Vec<TabStateDto>,
    db: State<'_, Arc<DatabaseManager>>,
    keys: State<'_, KeyManager>,
) -> Result<(), String> {
    let mut tabs = tabs;

    // Enkripsi konten sebelum tulis ke DB (jika unlocked)
    if keys.is_unlocked() {
        let key: crypto::Key = keys
            .with_key(|k| *k)
            .ok_or_else(|| "App terkunci".to_string())?;
        for tab in tabs.iter_mut() {
            if !tab.content.is_empty() && !crypto::is_encrypted(&tab.content) {
                tab.content = crypto::encrypt(&key, &tab.content)?;
            }
        }
    }

    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || db.save_session_tabs(&tabs))
        .await
        .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn load_session(
    db: State<'_, Arc<DatabaseManager>>,
    keys: State<'_, KeyManager>,
) -> Result<SessionStateDto, String> {
    let db = Arc::clone(&db);
    let mut session = tokio::task::spawn_blocking(move || db.load_session_tabs())
        .await
        .map_err(|e| e.to_string())?;

    // Terkunci + master password aktif: jangan kirim ciphertext/plaintext ke UI.
    // UI akan reload session setelah unlock.
    let db_has_e2e = {
        let db2 = Arc::clone(&db);
        tokio::task::spawn_blocking(move || {
            db2.get_setting(crypto::SETTING_SALT).map(|s| s.is_some())
        })
        .await
        .map_err(|e| e.to_string())?
        .unwrap_or(false)
    };

    if db_has_e2e && !keys.is_unlocked() {
        return Ok(SessionStateDto {
            tabs: Vec::new(),
            active_tab_index: 0,
        });
    }

    if keys.is_unlocked() {
        let key: crypto::Key = keys
            .with_key(|k| *k)
            .ok_or_else(|| "App terkunci".to_string())?;
        for tab in session.tabs.iter_mut() {
            if crypto::is_encrypted(&tab.content) {
                tab.content = crypto::decrypt(&key, &tab.content)
                    .unwrap_or_else(|_| "[Gagal decrypt]".to_string());
            }
        }
    }

    Ok(session)
}

#[tauri::command]
pub async fn get_app_setting(
    key: String,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<Option<String>, String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || db.get_setting(&key))
        .await
        .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn set_app_setting(
    key: String,
    value: String,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<(), String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || db.set_setting(&key, &value))
        .await
        .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn list_snippets(
    db: State<'_, Arc<DatabaseManager>>,
    keys: State<'_, KeyManager>,
) -> Result<Vec<SnippetDto>, String> {
    let db = Arc::clone(&db);
    let mut snippets = tokio::task::spawn_blocking(move || db.list_snippets())
        .await
        .map_err(|e| e.to_string())?;

    if keys.is_unlocked() {
        let key: crypto::Key = keys
            .with_key(|k| *k)
            .ok_or_else(|| "App terkunci".to_string())?;
        for s in snippets.iter_mut() {
            if crypto::is_encrypted(&s.content) {
                s.content = crypto::decrypt(&key, &s.content)
                    .unwrap_or_else(|_| "[Gagal decrypt]".to_string());
            }
        }
    }

    Ok(snippets)
}
```

- [ ] **Step 2: Pastikan compile**

Run (workdir `src-tauri`): `cargo check`
Expected: tidak ada error.

- [ ] **Step 3: Run semua test Rust**

Run (workdir `src-tauri`): `cargo test`
Expected: semua PASS (8 test).

- [ ] **Step 4: Commit**

```bash
git add src-tauri/src/commands/db.rs
git commit -m "feat(crypto): transparent encrypt/decrypt in tabs and snippets DB commands"
```

---

### Task 6: Frontend IPC wrappers

**Files:**
- Modify: `src/services/ipc.ts` (tambah method di objek `ipc`, setelah method `getAppSetting`)

- [ ] **Step 1: Tambah method E2E ke objek `ipc`**

Cari method `async getAppSetting(key: string)` di `src/services/ipc.ts`, tambahkan setelah penutup method itu:

```typescript
  async hasMasterPassword(): Promise<boolean> {
    if (isTauri) {
      try {
        return await invoke<boolean>('has_master_password');
      } catch (err) {
        console.warn('IPC hasMasterPassword error:', err);
      }
    }
    return false;
  },

  async e2eStatus(): Promise<'none' | 'locked' | 'ready'> {
    if (isTauri) {
      try {
        return await invoke<'none' | 'locked' | 'ready'>('e2e_status');
      } catch (err) {
        console.warn('IPC e2eStatus error:', err);
      }
    }
    return 'none';
  },

  async setMasterPassword(password: string, rememberDevice: boolean): Promise<void> {
    if (isTauri) {
      await invoke<void>('set_master_password', {
        password,
        rememberDevice
      });
      return;
    }
    throw new Error('Enkripsi hanya tersedia di aplikasi desktop');
  },

  async unlockMasterPassword(password: string): Promise<void> {
    if (isTauri) {
      await invoke<void>('unlock', { password });
      return;
    }
    throw new Error('Enkripsi hanya tersedia di aplikasi desktop');
  },

  async lockApp(): Promise<void> {
    if (isTauri) {
      await invoke<void>('lock');
    }
  },

  async changeMasterPassword(oldPassword: string, newPassword: string, rememberDevice: boolean): Promise<void> {
    if (isTauri) {
      await invoke<void>('change_password', {
        oldPassword,
        old_password: oldPassword,
        newPassword,
        new_password: newPassword,
        rememberDevice
      });
      return;
    }
    throw new Error('Enkripsi hanya tersedia di aplikasi desktop');
  },

  async forgetDevice(): Promise<void> {
    if (isTauri) {
      await invoke<void>('forget_device');
    }
  },

  async encryptContent(content: string): Promise<string> {
    if (isTauri) {
      try {
        return await invoke<string>('encrypt_content', { content });
      } catch (err) {
        console.warn('IPC encryptContent error:', err);
        return content;
      }
    }
    return content;
  },

  async decryptContent(content: string): Promise<string> {
    if (isTauri) {
      try {
        return await invoke<string>('decrypt_content', { content });
      } catch (err) {
        console.warn('IPC decryptContent error:', err);
        return content;
      }
    }
    return content;
  },
```

- [ ] **Step 2: Typecheck**

Run (root): `npm run check`
Expected: tidak ada error baru.

- [ ] **Step 3: Commit**

```bash
git add src/services/ipc.ts
git commit -m "feat(ipc): add E2E encryption IPC wrappers"
```

---

### Task 7: editorStore — guard persist, cloud encrypt/decrypt, reload session

**Files:**
- Modify: `src/stores/editorStore.svelte.ts`

- [ ] **Step 1: Guard `persistTabs` — jangan tulis DB saat terkunci**

Di method `persistTabs` (line 910), ganti isi menjadi:

```typescript
  private async persistTabs() {
    try {
      // Guard: jangan tulis plaintext ke DB saat E2E aktif dan app terkunci
      const status = await ipc.e2eStatus();
      if (status === 'locked') {
        console.warn('persistTabs skipped: app is locked');
        return;
      }

      const snapshot = this.tabs.map((t, idx) => ({
        ...t,
        is_active: idx === this.activeTabIndex
      }));
      await ipc.saveTabsState(snapshot);
    } catch (e) {
      console.error('Failed to persist tabs:', e);
    }
  }
```

- [ ] **Step 2: Faktor session load jadi `reloadSession`**

Ubah awal `init()` (line 80-88, blok `const session = await ipc.loadSession(); ... }`):

```typescript
  async init() {
    try {
      await this.reloadSession();
```

dan hapus blok session asli dari `init()` (baris `const session = ...` sampai `}` penutup assignment `activeTabIndex`), lalu tambahkan method baru setelah `init()`:

```typescript
  async reloadSession() {
    const session = await ipc.loadSession();
    if (session && Array.isArray(session.tabs)) {
      this.tabs = session.tabs;
      this.activeTabIndex = session.tabs.length > 0
        ? Math.max(0, Math.min(session.active_tab_index, session.tabs.length - 1))
        : 0;
    }
  }
```

- [ ] **Step 3: Enkripsi di `syncSingleTab`**

Di `syncSingleTab` (line 713), ganti pembuatan `remotePayload`:

```typescript
      const remotePayload: RemoteNote = {
        id: tab.supabase_id || undefined,
        title: tab.title || 'Untitled',
        content: await ipc.encryptContent(tab.content || ''),
        file_extension: tab.file_extension || 'txt',
        folder: tab.folder || undefined,
        is_pinned: false,
        is_deleted: false
      };
```

- [ ] **Step 4: Decrypt + encrypt di `autoSyncAll`**

Di `autoSyncAll` (line 769), setelah `const remoteNotes = await ipc.fetchRemoteNotes(...)` (line 777-781), tambahkan decrypt:

```typescript
      // Decrypt konten remote (passthrough jika belum terenkripsi)
      if (Array.isArray(remoteNotes)) {
        for (const remote of remoteNotes) {
          if (remote.content) {
            remote.content = await ipc.decryptContent(remote.content);
          }
        }
      }
```

Dan di loop push (line 847-890), ganti payload `upsertRemoteNote` (line 862-870):

```typescript
            const res = await ipc.upsertRemoteNote(
              this.supabaseConfig.url,
              this.supabaseConfig.anon_key,
              {
                id: tab.supabase_id || undefined,
                title: tab.title,
                content: await ipc.encryptContent(tab.content || ''),
                file_extension: tab.file_extension || 'txt',
                folder: tab.folder || undefined,
                is_pinned: false,
                is_deleted: false
              },
              this.supabaseConfig.access_token || undefined
            );
```

- [ ] **Step 5: Tambah `migrateCloudNotes`**

Tambahkan method baru setelah `autoSyncAll`:

```typescript
  /**
   * One-time cloud migration: re-encrypt semua remote notes yang masih plaintext.
   * Dipanggil setelah set_master_password sukses.
   */
  async migrateCloudNotes() {
    if (!this.supabaseConfig.is_configured) return;
    try {
      const remoteNotes = await ipc.fetchRemoteNotes(
        this.supabaseConfig.url,
        this.supabaseConfig.anon_key,
        this.supabaseConfig.access_token || undefined
      );
      if (!Array.isArray(remoteNotes)) return;
      for (const note of remoteNotes) {
        if (!note.id || note.is_deleted) continue;
        if (note.content && !note.content.startsWith('enc:v1:')) {
          await ipc.upsertRemoteNote(
            this.supabaseConfig.url,
            this.supabaseConfig.anon_key,
            {
              ...note,
              content: await ipc.encryptContent(note.content)
            },
            this.supabaseConfig.access_token || undefined
          );
        }
      }
    } catch (e) {
      console.warn('Cloud E2E migration failed:', e);
    }
  }
```

- [ ] **Step 6: Typecheck**

Run (root): `npm run check`
Expected: tidak ada error baru.

- [ ] **Step 7: Commit**

```bash
git add src/stores/editorStore.svelte.ts
git commit -m "feat(store): E2E encrypt on sync, decrypt on pull, persist guard, session reload"
```

---

### Task 8: LockScreen component + App wiring

**Files:**
- Create: `src/components/Auth/LockScreen.svelte`
- Modify: `src/App.svelte`

- [ ] **Step 1: Buat `src/components/Auth/LockScreen.svelte`**

```svelte
<script lang="ts">
  import { Lock, ShieldCheck, Loader2, Eye, EyeOff, AlertTriangle } from 'lucide-svelte';
  import { ipc } from '../../services/ipc';
  import { editorStore } from '../../stores/editorStore.svelte';

  let { mode, onDone }: { mode: 'setup' | 'locked'; onDone: () => void } = $props();

  let password = $state('');
  let confirmPassword = $state('');
  let rememberDevice = $state(true);
  let showPassword = $state(false);
  let isWorking = $state(false);
  let error = $state('');
  let isMigrating = $state(false);

  async function handleSetup() {
    error = '';
    if (password.length < 8) {
      error = 'Password minimal 8 karakter';
      return;
    }
    if (password !== confirmPassword) {
      error = 'Konfirmasi password tidak cocok';
      return;
    }
    isWorking = true;
    try {
      await ipc.setMasterPassword(password, rememberDevice);
      isMigrating = true;
      await editorStore.migrateCloudNotes();
      onDone();
    } catch (e: any) {
      error = typeof e === 'string' ? e : e?.message || 'Gagal mengatur password';
    } finally {
      isWorking = false;
      isMigrating = false;
    }
  }

  async function handleUnlock() {
    error = '';
    isWorking = true;
    try {
      await ipc.unlockMasterPassword(password);
      await editorStore.reloadSession();
      onDone();
    } catch (e: any) {
      error = typeof e === 'string' ? e : e?.message || 'Password salah';
    } finally {
      isWorking = false;
    }
  }

  function handleSkip() {
    ipc.setAppSetting('e2e_declined', '1');
    onDone();
  }
</script>

<div class="fixed inset-0 z-[9999] flex items-center justify-center bg-slate-950/95 backdrop-blur-sm">
  <div class="w-full max-w-md rounded-2xl border border-slate-800 bg-slate-900 p-8 shadow-2xl">
    <div class="mb-6 flex flex-col items-center gap-3 text-center">
      {#if mode === 'setup'}
        <div class="rounded-xl bg-emerald-600/20 p-3">
          <ShieldCheck class="h-8 w-8 text-emerald-400" />
        </div>
        <h2 class="text-lg font-semibold text-slate-100">Aktifkan Enkripsi End-to-End</h2>
        <p class="text-xs leading-relaxed text-slate-400">
          Catatan Anda akan dienkripsi dengan XChaCha20-Poly1305 sebelum disimpan ke database lokal
          dan cloud. Hanya Anda yang bisa membacanya.
        </p>
      {:else}
        <div class="rounded-xl bg-blue-600/20 p-3">
          <Lock class="h-8 w-8 text-blue-400" />
        </div>
        <h2 class="text-lg font-semibold text-slate-100">App Terkunci</h2>
        <p class="text-xs text-slate-400">Masukkan master password untuk membuka catatan Anda.</p>
      {/if}
    </div>

    {#if mode === 'setup'}
      <div class="mb-4 flex items-start gap-2 rounded-lg border border-amber-700/50 bg-amber-900/20 p-3">
        <AlertTriangle class="mt-0.5 h-4 w-4 shrink-0 text-amber-400" />
        <p class="text-[11px] leading-relaxed text-amber-200">
          Lupa password = data tidak bisa dipulihkan. Tidak ada reset. Simpan password baik-baik.
        </p>
      </div>
    {/if}

    <form
      class="space-y-4"
      onsubmit={(e) => { e.preventDefault(); mode === 'setup' ? handleSetup() : handleUnlock(); }}
    >
      <div class="relative">
        <input
          type={showPassword ? 'text' : 'password'}
          bind:value={password}
          placeholder="Master password"
          autofocus
          class="w-full rounded-xl border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-slate-100 placeholder:text-slate-500 focus:border-blue-500 focus:outline-none"
        />
        <button
          type="button"
          onclick={() => (showPassword = !showPassword)}
          class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-500 hover:text-slate-300"
        >
          {#if showPassword}<EyeOff class="h-4 w-4" />{:else}<Eye class="h-4 w-4" />{/if}
        </button>
      </div>

      {#if mode === 'setup'}
        <input
          type={showPassword ? 'text' : 'password'}
          bind:value={confirmPassword}
          placeholder="Ulangi password"
          class="w-full rounded-xl border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-slate-100 placeholder:text-slate-500 focus:border-blue-500 focus:outline-none"
        />

        <label class="flex cursor-pointer items-center gap-2 text-xs text-slate-300">
          <input type="checkbox" bind:checked={rememberDevice} class="accent-blue-600" />
          Ingat password di device ini (Windows Credential Manager)
        </label>
      {/if}

      {#if error}
        <p class="rounded-lg border border-red-800/50 bg-red-900/20 px-3 py-2 text-xs text-red-300">
          {error}
        </p>
      {/if}

      <button
        type="submit"
        disabled={isWorking || isMigrating || !password}
        class="flex w-full items-center justify-center gap-2 rounded-xl bg-blue-600 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-blue-500 disabled:cursor-not-allowed disabled:opacity-50"
      >
        {#if isWorking || isMigrating}
          <Loader2 class="h-4 w-4 animate-spin" />
          {isMigrating ? 'Mengenkripsi data...' : 'Memproses...'}
        {:else}
          {mode === 'setup' ? 'Aktifkan Enkripsi' : 'Buka Kunci'}
        {/if}
      </button>
    </form>

    {#if mode === 'setup'}
      <button
        onclick={handleSkip}
        class="mt-4 w-full text-center text-xs text-slate-500 transition-colors hover:text-slate-300"
      >
        Lewati untuk sekarang
      </button>
    {/if}
  </div>
</div>
```

- [ ] **Step 2: Wire di `src/App.svelte`**

Tambahkan import (setelah import `SettingsWorkspace`, line 33):

```typescript
  import LockScreen from './components/Auth/LockScreen.svelte';
```

Tambahkan state (setelah `let sqlViewerRef = ...`, line 47):

```typescript
  let lockState = $state<'checking' | 'setup' | 'locked' | 'unlocked'>('checking');
```

Tambahkan init di `onMount` yang sudah ada (atau tambahkan blok `onMount` baru jika perlu) — di awal onMount existing, tambahkan:

```typescript
    const hasE2E = await ipc.hasMasterPassword();
    if (!hasE2E) {
      const declined = await ipc.getAppSetting('e2e_declined');
      lockState = declined === '1' ? 'unlocked' : 'setup';
    } else {
      const status = await ipc.e2eStatus();
      lockState = status === 'ready' ? 'unlocked' : 'locked';
    }
```

Di template, paling atas setelah tag pembuka root layout, render overlay:

```svelte
  {#if lockState === 'setup' || lockState === 'locked'}
    <LockScreen
      mode={lockState === 'setup' ? 'setup' : 'locked'}
      onDone={async () => {
        lockState = 'unlocked';
        await editorStore.reloadSession();
      }}
    />
  {/if}
```

Jika `App.svelte` belum punya `onMount` async, bungkus dengan `onMount(async () => { ... })`.

- [ ] **Step 3: Typecheck**

Run (root): `npm run check`
Expected: tidak ada error baru.

- [ ] **Step 4: Commit**

```bash
git add src/components/Auth/LockScreen.svelte src/App.svelte
git commit -m "feat(ui): add lock screen with setup wizard and unlock flow"
```

---

### Task 9: Tab Security di Settings

**Files:**
- Create: `src/components/Settings/SecuritySettings.svelte`
- Modify: `src/components/Settings/SettingsWorkspace.svelte`

- [ ] **Step 1: Buat `src/components/Settings/SecuritySettings.svelte`**

```svelte
<script lang="ts">
  import { Lock, Loader2, ShieldCheck, ShieldOff, KeyRound, MonitorSmartphone } from 'lucide-svelte';
  import { ipc } from '../../services/ipc';
  import { editorStore } from '../../stores/editorStore.svelte';

  let status = $state<'none' | 'locked' | 'ready' | 'unknown'>('unknown');
  let oldPassword = $state('');
  let newPassword = $state('');
  let confirmPassword = $state('');
  let isWorking = $state(false);
  let message = $state<{ text: string; type: 'success' | 'error' } | null>(null);

  async function refreshStatus() {
    status = await ipc.e2eStatus();
  }

  refreshStatus();

  async function handleChangePassword() {
    message = null;
    if (newPassword.length < 8) {
      message = { text: 'Password baru minimal 8 karakter', type: 'error' };
      return;
    }
    if (newPassword !== confirmPassword) {
      message = { text: 'Konfirmasi password tidak cocok', type: 'error' };
      return;
    }
    isWorking = true;
    try {
      await ipc.changeMasterPassword(oldPassword, newPassword, true);
      message = { text: 'Password berhasil diganti. Semua data dienkripsi ulang.', type: 'success' };
      oldPassword = newPassword = confirmPassword = '';
    } catch (e: any) {
      message = { text: typeof e === 'string' ? e : e?.message || 'Gagal ganti password', type: 'error' };
    } finally {
      isWorking = false;
    }
  }

  async function handleLockNow() {
    await ipc.lockApp();
    window.location.reload();
  }

  async function handleForgetDevice() {
    await ipc.forgetDevice();
    await ipc.lockApp();
    window.location.reload();
  }
</script>

<div class="space-y-6">
  <div class="flex items-center gap-3">
    {#if status === 'ready'}
      <div class="rounded-xl bg-emerald-600/20 p-2.5">
        <ShieldCheck class="h-5 w-5 text-emerald-400" />
      </div>
      <div>
        <h3 class="text-sm font-semibold text-slate-100">Enkripsi End-to-End Aktif</h3>
        <p class="text-xs text-slate-400">Catatan dienkripsi sebelum disimpan lokal & cloud.</p>
      </div>
    {:else}
      <div class="rounded-xl bg-slate-700/40 p-2.5">
        <ShieldOff class="h-5 w-5 text-slate-400" />
      </div>
      <div>
        <h3 class="text-sm font-semibold text-slate-100">Enkripsi Belum Aktif</h3>
        <p class="text-xs text-slate-400">Aktifkan via layar setup saat app dibuka.</p>
      </div>
    {/if}
  </div>

  {#if status === 'ready'}
    <div class="space-y-3 rounded-xl border border-slate-700/60 bg-slate-800/40 p-4">
      <h4 class="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-slate-300">
        <KeyRound class="h-4 w-4" /> Ganti Master Password
      </h4>
      <form class="space-y-3" onsubmit={(e) => { e.preventDefault(); handleChangePassword(); }}>
        <input
          type="password"
          bind:value={oldPassword}
          placeholder="Password lama"
          class="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-100 placeholder:text-slate-500 focus:border-blue-500 focus:outline-none"
        />
        <input
          type="password"
          bind:value={newPassword}
          placeholder="Password baru (min. 8 karakter)"
          class="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-100 placeholder:text-slate-500 focus:border-blue-500 focus:outline-none"
        />
        <input
          type="password"
          bind:value={confirmPassword}
          placeholder="Ulangi password baru"
          class="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-100 placeholder:text-slate-500 focus:border-blue-500 focus:outline-none"
        />
        {#if message}
          <p class="text-xs {message.type === 'success' ? 'text-emerald-400' : 'text-red-400'}">
            {message.text}
          </p>
        {/if}
        <button
          type="submit"
          disabled={isWorking || !oldPassword || !newPassword}
          class="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-xs font-medium text-white hover:bg-blue-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {#if isWorking}<Loader2 class="h-4 w-4 animate-spin" />{/if}
          Ganti Password
        </button>
      </form>
      <p class="text-[11px] text-slate-500">
        Semua catatan lokal akan dienkripsi ulang dengan kunci baru.
      </p>
    </div>

    <div class="space-y-2 rounded-xl border border-slate-700/60 bg-slate-800/40 p-4">
      <h4 class="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-slate-300">
        <Lock class="h-4 w-4" /> Kunci & Device
      </h4>
      <div class="flex flex-wrap gap-2">
        <button
          onclick={handleLockNow}
          class="flex items-center gap-2 rounded-lg bg-slate-700 px-4 py-2 text-xs font-medium text-slate-100 hover:bg-slate-600"
        >
          <Lock class="h-4 w-4" /> Kunci Sekarang
        </button>
        <button
          onclick={handleForgetDevice}
          class="flex items-center gap-2 rounded-lg bg-red-900/40 px-4 py-2 text-xs font-medium text-red-300 hover:bg-red-900/60"
        >
          <MonitorSmartphone class="h-4 w-4" /> Lupakan Password di Device Ini
        </button>
      </div>
      <p class="text-[11px] text-slate-500">
        "Lupakan Device" menghapus kunci tersimpan — app akan minta password setiap dibuka.
      </p>
    </div>
  {/if}
</div>
```

- [ ] **Step 2: Tambah tab `security` di `SettingsWorkspace.svelte`**

1. Line 44: ganti type jadi:

```typescript
  export type SettingsTab = 'supabase' | 'security' | 'appearance' | 'editor' | 'about';
```

2. Tambah import (setelah line 42 import `ipc`):

```typescript
  import SecuritySettings from './SecuritySettings.svelte';
```

3. Di sidebar nav, setelah tombol tab `supabase` (sekitar line 388-396, blok dengan `onclick={() => setTab('supabase')}`), tambahkan tombol security dengan pola sama:

```svelte
        <button
          onclick={() => setTab('security')}
          class="w-full flex items-center justify-between px-3 py-2.5 rounded-xl text-xs font-medium transition-all cursor-pointer {currentTab === 'security' ? 'bg-blue-600 text-white shadow-sm font-semibold' : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'}"
        >
          <span class="flex items-center gap-2">
            <ShieldCheck class="w-4 h-4 {currentTab === 'security' ? 'text-white' : 'text-emerald-400'}" />
            Keamanan
          </span>
        </button>
```

4. Di area konten, setelah `{#if currentTab === 'supabase'}` block (line 461) dan sebelum `{:else if currentTab === 'appearance'}` (line 661), tambahkan:

```svelte
        {:else if currentTab === 'security'}
          <SecuritySettings />
```

- [ ] **Step 3: Typecheck**

Run (root): `npm run check`
Expected: tidak ada error baru.

- [ ] **Step 4: Commit**

```bash
git add src/components/Settings/SecuritySettings.svelte src/components/Settings/SettingsWorkspace.svelte
git commit -m "feat(settings): add security tab with password change, lock, forget device"
```

---

### Task 10: Verifikasi akhir

- [ ] **Step 1: Semua test Rust**

Run (workdir `src-tauri`): `cargo test`
Expected: semua PASS.

- [ ] **Step 2: Build Rust**

Run (workdir `src-tauri`): `cargo check`
Expected: tidak ada error/warning baru terkait crypto.

- [ ] **Step 3: Frontend check**

Run (root): `npm run check`
Expected: tidak ada error.

- [ ] **Step 4: Manual E2E smoke test (dev)**

Run (root): `npm run tauri dev`, lalu:

1. App buka → layar setup enkripsi muncul → set password (contoh `rahasiakuat123`) + centang ingat device.
2. Buat catatan berisi teks unik `TESTMARKER123` → tunggu persist (±5s).
3. Buka file DB (`%APPDATA%\valtera-note\valtera_note.db`) dengan SQLite viewer → kolom `tabs_state.content` berisi `enc:v1:...`, TIDAK berisi `TESTMARKER123`.
4. Buka Supabase dashboard → table `notes` → kolom `content` berisi `enc:v1:...`.
5. Restart app → auto-unlock (langsung masuk, catatan terbaca normal).
6. Settings → Keamanan → "Lupakan Password di Device Ini" → restart → layar unlock muncul → password salah ditolak → password benar → catatan terbaca.
7. Catatan lama yang ada sebelumnya (plaintext) terbaca normal (sudah termigrasi).

- [ ] **Step 5: Commit final jika ada perbaikan**

```bash
git add -A
git commit -m "chore: E2E encryption final fixes"
```

---

## Catatan penting untuk eksekutor

- **Jangan pernah log plaintext atau key** — hanya log count/progress.
- Prefix `enc:v1:` adalah kontrak format — jangan ubah tanpa bump versi prefix.
- `load_session` mengembalikan session kosong saat locked — bukan bug, itu guard.
- `encrypt_content`/`decrypt_content` passthrough jika format tidak cocok — idempoten untuk migrasi.
- Snippets tidak punya command write di Rust; enkripsi snippets hanya via migrasi Task 3 dan command `list_snippets` decrypt.
