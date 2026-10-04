use std::sync::Arc;
use tauri::State;

use crate::crypto::{self, keystore::KeyManager};
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
        .and_then(|r| r)
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
        .and_then(|r| r)
}

/// Hapus kunci dari keyring device ini (lupakan device).
#[tauri::command]
pub async fn forget_device() -> Result<(), String> {
    tokio::task::spawn_blocking(KeyManager::delete_from_keyring)
        .await
        .map_err(|e| e.to_string())?
}
