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
    // Fail-closed di Rust: jika master password aktif tapi app terkunci, tolak tulisan.
    // Tanpa ini, save saat terkunci menghapus semua baris tabs_state
    // (save_session_tabs delete-all-then-insert) lalu menulis data kosong.
    let db_guard = Arc::clone(&db);
    let has_e2e = tokio::task::spawn_blocking(move || db_guard.has_setting(crypto::SETTING_SALT))
        .await
        .map_err(|e| e.to_string())?;
    if has_e2e && !keys.is_unlocked() {
        return Err("App terkunci - tidak bisa menyimpan catatan".to_string());
    }

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
    let db_load = Arc::clone(&db);
    let mut session = tokio::task::spawn_blocking(move || db_load.load_session_tabs())
        .await
        .map_err(|e| e.to_string())??;

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

/// Setting yang hanya boleh diubah backend: material kripto (salt, verifier,
/// flag quick PIN) dan state internal RDP. Menimpa salt/verifier dari frontend
/// akan membuat seluruh catatan tidak bisa didekripsi.
fn is_protected_setting(key: &str) -> bool {
    (key.starts_with("e2e_") && key != crypto::SETTING_DECLINED) || key.starts_with("rdp_")
}

#[tauri::command]
pub async fn set_app_setting(
    key: String,
    value: String,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<(), String> {
    if is_protected_setting(&key) {
        return Err(format!("Setting '{}' tidak boleh diubah dari UI", key));
    }
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
        .map_err(|e| e.to_string())??;

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

#[cfg(test)]
mod tests {
    use super::is_protected_setting;

    #[test]
    fn crypto_and_rdp_settings_are_protected() {
        assert!(is_protected_setting("e2e_salt"));
        assert!(is_protected_setting("e2e_verifier"));
        assert!(is_protected_setting("e2e_quickpin"));
        assert!(is_protected_setting("rdp_pending_creds"));
        assert!(!is_protected_setting("e2e_declined"));
        assert!(!is_protected_setting("theme_mode"));
    }
}
