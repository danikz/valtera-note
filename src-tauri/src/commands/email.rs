use std::sync::Arc;

use serde::Serialize;
use tauri::State;

use crate::crypto::{self, keystore::KeyManager};
use crate::db::DatabaseManager;
use crate::mail::{self, DeleteResult, InboxPage, MailCredentials, MailManager, MailMessage};

// ===== Akun email tersimpan (E2E: payload dienkripsi frontend) =====
// Tiap akun berdiri sendiri (domain berbeda boleh) — tidak ada inbox gabungan.

#[derive(Serialize)]
pub struct EmailAccountRow {
    pub id: String,
    pub label: String,
    pub payload: String, // ciphertext enc:v1:...
    pub updated_at: String,
}

#[tauri::command]
pub async fn email_account_list(
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<Vec<EmailAccountRow>, String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || {
        let conn = db.get_conn();
        let mut stmt = conn
            .prepare("SELECT id, label, payload, updated_at FROM email_accounts ORDER BY label")
            .map_err(|e| e.to_string())?;
        let rows = stmt
            .query_map([], |r| {
                Ok(EmailAccountRow {
                    id: r.get(0)?,
                    label: r.get(1)?,
                    payload: r.get(2)?,
                    updated_at: r.get(3)?,
                })
            })
            .map_err(|e| e.to_string())?;
        let mut out = Vec::new();
        for row in rows {
            out.push(row.map_err(|e| e.to_string())?);
        }
        Ok(out)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn email_account_save(
    id: String,
    label: String,
    payload: String,
    db: State<'_, Arc<DatabaseManager>>,
    mail: State<'_, MailManager>,
) -> Result<(), String> {
    // Password email tidak boleh tersimpan polos.
    if !crypto::is_encrypted(&payload) {
        return Err("Kredensial email harus terenkripsi — atur master password dulu".to_string());
    }
    let db = Arc::clone(&db);
    let row_id = id.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.get_conn();
        conn.execute(
            "INSERT INTO email_accounts (id, label, payload, updated_at)
             VALUES (?1, ?2, ?3, CURRENT_TIMESTAMP)
             ON CONFLICT(id) DO UPDATE SET label = ?2, payload = ?3, updated_at = CURRENT_TIMESTAMP",
            rusqlite::params![row_id, label, payload],
        )
        .map_err(|e| e.to_string())?;
        Ok::<_, String>(())
    })
    .await
    .map_err(|e| e.to_string())??;
    // Sesi lama memakai kredensial lama.
    mail.forget(&id).await;
    Ok(())
}

#[tauri::command]
pub async fn email_account_delete(
    id: String,
    db: State<'_, Arc<DatabaseManager>>,
    mail: State<'_, MailManager>,
) -> Result<(), String> {
    let db = Arc::clone(&db);
    let row_id = id.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.get_conn();
        conn.execute("DELETE FROM email_accounts WHERE id = ?1", rusqlite::params![row_id])
            .map_err(|e| e.to_string())?;
        Ok::<_, String>(())
    })
    .await
    .map_err(|e| e.to_string())??;
    mail.forget(&id).await;
    Ok(())
}

/// Uji login sebelum akun disimpan; hasilnya jumlah email di INBOX.
#[tauri::command]
pub async fn email_test(
    email: String,
    password: String,
    host: String,
    port: u16,
) -> Result<u32, String> {
    mail::test_login(&MailCredentials { email, password, host, port }).await
}

/// Satu halaman INBOX (terbaru dulu). `before_uid` = UID terakhir halaman sebelumnya.
#[tauri::command]
pub async fn email_inbox(
    account_id: String,
    before_uid: Option<u32>,
    limit: Option<u32>,
    db: State<'_, Arc<DatabaseManager>>,
    keys: State<'_, KeyManager>,
    mail: State<'_, MailManager>,
) -> Result<InboxPage, String> {
    let creds = load_credentials(Arc::clone(&db), &keys, &account_id).await?;
    mail.inbox(&account_id, &creds, before_uid, limit.unwrap_or(50) as usize).await
}

/// Isi lengkap satu email (tidak menandai email sebagai sudah dibaca di server).
#[tauri::command]
pub async fn email_message(
    account_id: String,
    uid: u32,
    db: State<'_, Arc<DatabaseManager>>,
    keys: State<'_, KeyManager>,
    mail: State<'_, MailManager>,
) -> Result<MailMessage, String> {
    let creds = load_credentials(Arc::clone(&db), &keys, &account_id).await?;
    mail.message(&account_id, &creds, uid).await
}

/// Hapus email: dipindah ke folder Sampah, atau permanen bila `permanent`.
#[tauri::command]
pub async fn email_delete(
    account_id: String,
    uids: Vec<u32>,
    permanent: bool,
    db: State<'_, Arc<DatabaseManager>>,
    keys: State<'_, KeyManager>,
    mail: State<'_, MailManager>,
) -> Result<DeleteResult, String> {
    let creds = load_credentials(Arc::clone(&db), &keys, &account_id).await?;
    mail.delete(&account_id, &creds, &uids, permanent).await
}

// Kredensial didekripsi di Rust per permintaan — password tidak perlu
// melewati frontend saat membaca inbox, dan app terkunci = inbox tertutup.
async fn load_credentials(
    db: Arc<DatabaseManager>,
    keys: &KeyManager,
    id: &str,
) -> Result<MailCredentials, String> {
    let row_id = id.to_string();
    let payload: String = tokio::task::spawn_blocking(move || {
        let conn = db.get_conn();
        conn.query_row(
            "SELECT payload FROM email_accounts WHERE id = ?1",
            rusqlite::params![row_id],
            |r| r.get(0),
        )
        .map_err(|_| "Akun email tidak ditemukan".to_string())
    })
    .await
    .map_err(|e| e.to_string())??;
    let plain = keys
        .with_key(|k| crypto::decrypt(k, &payload))
        .ok_or_else(|| "Aplikasi terkunci — buka kunci untuk membaca email".to_string())??;
    serde_json::from_str(&plain).map_err(|_| "Data akun email rusak".to_string())
}
