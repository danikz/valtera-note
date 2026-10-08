use std::sync::Arc;
use tauri::State;

use crate::crypto::{self, keystore::KeyManager, Key};
use crate::crypto::{SETTING_DECLINED, SETTING_SALT, SETTING_VERIFIER, VERIFIER_PLAINTEXT};
use crate::db::DatabaseManager;
use crate::supabase::SupabaseClient;

fn b64_encode(data: &[u8]) -> String {
    use base64::{engine::general_purpose::STANDARD as B64, Engine};
    B64.encode(data)
}

fn b64_decode16(value: &str) -> Result<[u8; 16], String> {
    use base64::{engine::general_purpose::STANDARD as B64, Engine};
    let raw = B64.decode(value).map_err(|_| "salt base64 invalid".to_string())?;
    raw.try_into().map_err(|_| "salt length invalid".to_string())
}

fn b64_decode(value: &str) -> Result<Vec<u8>, String> {
    use base64::{engine::general_purpose::STANDARD as B64, Engine};
    B64.decode(value).map_err(|_| "base64 invalid".to_string())
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
        // Idempoten: jika master password sudah diatur, validasi password ini
        // terhadap verifier lama. Valid = sukses tanpa mengubah apa pun;
        // tidak valid = error. Mencegah setup ulang dengan salt baru yang
        // membuat data lama tidak terbaca (jika keyring gagal lalu user retry).
        if let Some(salt_b64) = db.get_setting(SETTING_SALT)? {
            let salt = b64_decode16(&salt_b64)?;
            let verifier = db
                .get_setting(SETTING_VERIFIER)?
                .ok_or_else(|| "Verifier E2E tidak ditemukan".to_string())?;
            let key = crypto::derive_key(&password, &salt)?;
            let plain = crypto::decrypt(&key, &verifier)?;
            if plain != VERIFIER_PLAINTEXT {
                return Err("Master password sudah diatur - password tidak cocok".to_string());
            }
            if remember_device {
                if let Err(e) = KeyManager::save_to_keyring(&key) {
                    eprintln!("Warning: gagal menyimpan kunci ke keyring: {}", e);
                }
            }
            return Ok::<_, String>(key);
        }

        let salt = crypto::generate_salt();
        let key = crypto::derive_key(&password, &salt)?;
        let verifier = crypto::encrypt(&key, VERIFIER_PLAINTEXT)?;

        // Migrasi otomatis (re-encrypt semua plaintext lokal) + simpan salt/verifier
        // dalam SATU transaksi — gagal di tengah jalan tidak meninggalkan state campuran.
        let counts =
            db.migrate_content(|pt| crypto::encrypt(&key, pt), &b64_encode(&salt), &verifier)?;
        eprintln!(
            "E2E migration complete: {} tabs, {} snippets encrypted",
            counts.0, counts.1
        );
        db.set_setting(SETTING_DECLINED, "0")?;

        // Keyring best-effort: gagal keyring tidak membatalkan setup —
        // fallback sesuai spec: prompt password tiap launch.
        if remember_device {
            if let Err(e) = KeyManager::save_to_keyring(&key) {
                eprintln!("Warning: gagal menyimpan kunci ke keyring: {}", e);
            }
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
    remember_device: Option<bool>,
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

    // "Ingat device" bisa diaktifkan belakangan dari layar terkunci.
    if remember_device.unwrap_or(false) {
        if let Err(e) = KeyManager::save_to_keyring(&key) {
            eprintln!("Warning: gagal menyimpan kunci ke keyring: {}", e);
        }
    }

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
    let db_blocking = Arc::clone(&db);
    let (old_key, new_key) = tokio::task::spawn_blocking(move || {
        // 1. Validasi password lama
        let salt_b64 = db_blocking
            .get_setting(SETTING_SALT)?
            .ok_or_else(|| "Master password belum diatur".to_string())?;
        let salt = b64_decode16(&salt_b64)?;
        let verifier = db_blocking
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

        // 3. Re-encrypt semua data lama->baru + simpan salt/verifier baru
        //    dalam SATU transaksi (rollback penuh saat gagal di tengah jalan).
        let counts = db_blocking.reencrypt_all(
            |ct| crypto::decrypt(&old_key, ct),
            |pt| crypto::encrypt(&new_key, pt),
            &b64_encode(&new_salt),
            &new_verifier,
        )?;
        eprintln!(
            "E2E re-encryption complete: {} tabs, {} snippets",
            counts.0, counts.1
        );

        if remember_device {
            if let Err(e) = KeyManager::save_to_keyring(&new_key) {
                eprintln!("Warning: gagal menyimpan kunci baru ke keyring: {}", e);
            }
        } else {
            let _ = KeyManager::delete_from_keyring();
        }

        // Quick PIN membungkus kunci LAMA — setelah re-encryption dia basi.
        // Matikan; user bisa mengaktifkan ulang dengan PIN yang sama.
        let _ = KeyManager::delete_quickpin();
        let _ = db_blocking.set_setting(SETTING_QUICK_PIN, "0");
        Ok::<_, String>((old_key, new_key))
    })
    .await
    .map_err(|e| e.to_string())??;

    keys.set_key(new_key);

    // 4. Rotasi ciphertext cloud (kunci lama -> baru). Gagal dikembalikan sebagai
    //    error agar user tahu cloud masih pakai kunci lama; catatan lokal sudah
    //    aman (transaksi lokal sudah commit sebelum langkah ini).
    if let Err(e) = rotate_cloud_notes(Arc::clone(&db), &old_key, &new_key).await {
        return Err(format!(
            "Password diganti secara lokal, TAPI re-enkripsi cloud gagal: {}. Catatan cloud masih terenkripsi dengan kunci lama.",
            e
        ));
    }
    Ok(())
}

/// Re-encrypt semua note cloud dengan kunci baru. Note yang tidak bisa didekripsi
/// dengan kunci lama (mis. dienkripsi device lain dengan salt berbeda) dilewati
/// dan dilaporkan lewat log.
async fn rotate_cloud_notes(
    db: Arc<DatabaseManager>,
    old_key: &Key,
    new_key: &Key,
) -> Result<(), String> {
    let url = db.get_setting("supabase_url")?.unwrap_or_default();
    let anon_key = db.get_setting("supabase_anon_key")?.unwrap_or_default();
    if url.is_empty() || anon_key.is_empty() {
        return Ok(());
    }

    let mut client = SupabaseClient::new(url, anon_key);
    if let Some(token) = crate::commands::supabase::effective_access_token(db).await {
        client.set_access_token(token);
    }

    let notes = client
        .fetch_notes()
        .await
        .map_err(|e| format!("gagal menarik note cloud: {}", e))?;

    let mut rotated = 0usize;
    let mut skipped = 0usize;
    for note in notes {
        if note.is_deleted || note.id.is_none() {
            continue;
        }
        let new_content = if crypto::is_encrypted(&note.content) {
            match crypto::decrypt(old_key, &note.content) {
                Ok(plain) => crypto::encrypt(new_key, &plain)?,
                Err(_) => {
                    skipped += 1;
                    continue;
                }
            }
        } else if !note.content.is_empty() {
            // Note cloud masih plaintext (migrasi setup belum menyentuhnya) —
            // sekalian dienkripsi dengan kunci baru.
            crypto::encrypt(new_key, &note.content)?
        } else {
            continue;
        };
        let updated = crate::supabase::RemoteNote {
            content: new_content,
            ..note
        };
        client
            .upsert_note(&updated)
            .await
            .map_err(|e| format!("gagal menulis ulang note cloud: {}", e))?;
        rotated += 1;
    }
    eprintln!(
        "E2E cloud rotation: {} notes rotated, {} skipped",
        rotated, skipped
    );
    Ok(())
}

/// Enkripsi konten untuk sync cloud. Plaintext passthrough jika sudah terenkripsi.
///
/// Mode: master password di-set -> wajib kunci dari KeyManager (error saat
/// terkunci). User yang secara eksplisit menolak E2E (e2e_declined=1) ->
/// passthrough plaintext sesuai pilihannya. Sebelum memilih (setup awal) ->
/// fail-closed agar plaintext tidak bocor sebelum keputusan.
#[tauri::command]
pub async fn encrypt_content(
    content: String,
    keys: State<'_, KeyManager>,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<String, String> {
    if crypto::is_encrypted(&content) {
        return Ok(content);
    }

    let db_has_master = Arc::clone(&db);
    let has_master = tokio::task::spawn_blocking(move || {
        Ok::<_, String>(db_has_master.get_setting(SETTING_SALT)?.is_some())
    })
    .await
    .map_err(|e| e.to_string())??;

    if has_master {
        return keys
            .with_key(|k| crypto::encrypt(k, &content))
            .ok_or_else(|| "App terkunci - tidak bisa mengenkripsi".to_string())
            .and_then(|r| r);
    }

    let db_declined = Arc::clone(&db);
    let declined = tokio::task::spawn_blocking(move || {
        Ok::<_, String>(db_declined.get_setting(SETTING_DECLINED)?.as_deref() == Some("1"))
    })
    .await
    .map_err(|e| e.to_string())??;

    if declined {
        return Ok(content);
    }

    Err("Enkripsi belum dikonfigurasi - selesaikan setup keamanan terlebih dahulu".to_string())
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

// ===== Quick PIN 6 digit =====
// Kunci E2E dibungkus (dienkripsi) dengan kunci turunan PIN lalu disimpan di
// OS keychain — bukan di database. PIN bukan pengganti master password:
// hanya pintu cepat di device ini. 5x salah -> fitur PIN dimatikan otomatis
// dan kembali ke master password (membatasi brute force offline).

pub const SETTING_QUICK_PIN: &str = "e2e_quickpin";
const QUICK_PIN_MAX_ATTEMPTS: u32 = 5;

fn validate_pin(pin: &str) -> Result<(), String> {
    if pin.len() != 6 || !pin.chars().all(|c| c.is_ascii_digit()) {
        return Err("PIN harus tepat 6 digit angka".to_string());
    }
    Ok(())
}

#[tauri::command]
pub async fn quick_pin_status(db: State<'_, Arc<DatabaseManager>>) -> Result<bool, String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || {
        Ok::<_, String>(db.get_setting(SETTING_QUICK_PIN)?.as_deref() == Some("1"))
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn setup_quick_pin(
    pin: String,
    keys: State<'_, KeyManager>,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<(), String> {
    validate_pin(&pin)?;

    let key = keys
        .with_key(|k| *k)
        .ok_or_else(|| "App terkunci — buka kunci dengan master password dulu".to_string())?;

    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || {
        let pin_salt = crypto::generate_salt();
        let wrapper = crypto::derive_key(&pin, &pin_salt)?;

        // Blob: salt PIN di luar ciphertext (dibutuhkan untuk derive wrapper),
        // kunci E2E di dalamnya. Verifikasi tetap lewat verifier DB saat unlock.
        let blob = serde_json::json!({
            "v": 1,
            "s": b64_encode(&pin_salt),
            "ct": crypto::encrypt(&wrapper, &b64_encode(&key))?,
        })
        .to_string();

        KeyManager::save_quickpin_blob(&blob)?;
        // Raw key tidak boleh tersisa di keyring — kalau ada, auto-unlock
        // akan melewati PIN. PIN kini menjadi pintunya.
        if let Err(e) = KeyManager::delete_from_keyring() {
            eprintln!("Warning: gagal menghapus raw key keyring: {}", e);
        }
        db.set_setting(SETTING_QUICK_PIN, "1")?;
        Ok::<_, String>(())
    })
    .await
    .map_err(|e| e.to_string())?;

    keys.reset_pin_attempts();
    Ok(())
}

#[tauri::command]
pub async fn unlock_with_pin(
    pin: String,
    keys: State<'_, KeyManager>,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<(), String> {
    validate_pin(&pin)?;

    let db = Arc::clone(&db);
    let db_cleanup = Arc::clone(&db);
    let key = tokio::task::spawn_blocking(move || {
        let blob = KeyManager::load_quickpin_blob()
            .map_err(|_| "PIN cepat tidak aktif di device ini".to_string())?;
        let parsed: serde_json::Value =
            serde_json::from_str(&blob).map_err(|_| "Blob PIN korup".to_string())?;
        let salt_b64 = parsed["s"]
            .as_str()
            .ok_or_else(|| "Blob PIN korup (salt)".to_string())?;
        let ct = parsed["ct"]
            .as_str()
            .ok_or_else(|| "Blob PIN korup (ct)".to_string())?;

        let pin_salt = b64_decode16(salt_b64)?;
        let wrapper = crypto::derive_key(&pin, &pin_salt)?;
        let key_b64 = crypto::decrypt(&wrapper, ct)?;

        // Kunci hasil unwrap wajib lolos verifier DB — menangkap PIN salah
        // maupun kunci basi setelah ganti master password.
        let raw = b64_decode(&key_b64)?;
        let key: Key = raw
            .try_into()
            .map_err(|_| "Blob PIN korup (panjang kunci)".to_string())?;

        let salt_b64 = db
            .get_setting(SETTING_SALT)?
            .ok_or_else(|| "Master password belum diatur".to_string())?;
        let verifier = db
            .get_setting(SETTING_VERIFIER)?
            .ok_or_else(|| "Verifier E2E tidak ditemukan".to_string())?;
        let plain = crypto::decrypt(&key, &verifier)?;
        if plain != VERIFIER_PLAINTEXT {
            // Kunci basi (master password pernah diganti) — buang fitur PIN.
            let _ = KeyManager::delete_quickpin();
            let _ = db.set_setting(SETTING_QUICK_PIN, "0");
            return Err("Kunci PIN sudah basi — silakan set ulang PIN setelah unlock".to_string());
        }
        Ok::<_, String>(key)
    })
    .await
    .map_err(|e| e.to_string())?;

    match key {
        Ok(key) => {
            keys.reset_pin_attempts();
            keys.set_key(key);
            Ok(())
        }
        Err(e) => {
            let attempts = keys.fail_pin();
            if attempts >= QUICK_PIN_MAX_ATTEMPTS {
                // Brute-force brake: matikan PIN, kembali ke master password.
                let db2 = db_cleanup;
                let _ = tokio::task::spawn_blocking(move || {
                    let _ = KeyManager::delete_quickpin();
                    let _ = db2.set_setting(SETTING_QUICK_PIN, "0");
                })
                .await;
                keys.reset_pin_attempts();
                return Err(format!(
                    "{} — PIN salah {}x, fitur PIN dimatikan. Gunakan master password.",
                    e, attempts
                ));
            }
            Err(format!(
                "{} (PIN salah {}x dari {})",
                e, attempts, QUICK_PIN_MAX_ATTEMPTS
            ))
        }
    }
}

#[tauri::command]
pub async fn disable_quick_pin(db: State<'_, Arc<DatabaseManager>>) -> Result<(), String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || {
        KeyManager::delete_quickpin()?;
        db.set_setting(SETTING_QUICK_PIN, "0")?;
        Ok::<_, String>(())
    })
    .await
    .map_err(|e| e.to_string())?
}
