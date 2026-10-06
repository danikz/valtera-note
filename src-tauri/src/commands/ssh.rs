use std::sync::Arc;

use serde::Serialize;
use tauri::{AppHandle, State};

use crate::db::DatabaseManager;
use crate::ssh::{disconnect_session, open_session, resize_session, write_to_session, SshConnectParams, SshManager};

// ===== Manajemen kredensial tersimpan (E2E: payload dienkripsi frontend) =====

#[derive(Serialize)]
pub struct SshConnectionRow {
    pub id: String,
    pub label: String,
    pub payload: String, // ciphertext enc:v1:...
    pub updated_at: String,
}

#[tauri::command]
pub async fn ssh_conn_list(
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<Vec<SshConnectionRow>, String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || {
        let conn = db.get_conn();
        let mut stmt = conn
            .prepare("SELECT id, label, payload, updated_at FROM ssh_connections ORDER BY label")
            .map_err(|e| e.to_string())?;
        let rows = stmt
            .query_map([], |r| {
                Ok(SshConnectionRow {
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
pub async fn ssh_conn_save(
    id: String,
    label: String,
    payload: String,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<(), String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || {
        let conn = db.get_conn();
        conn.execute(
            "INSERT INTO ssh_connections (id, label, payload, updated_at)
             VALUES (?1, ?2, ?3, CURRENT_TIMESTAMP)
             ON CONFLICT(id) DO UPDATE SET label = ?2, payload = ?3, updated_at = CURRENT_TIMESTAMP",
            rusqlite::params![id, label, payload],
        )
        .map_err(|e| e.to_string())?;
        Ok(())
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn ssh_conn_delete(id: String, db: State<'_, Arc<DatabaseManager>>) -> Result<(), String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || {
        let conn = db.get_conn();
        conn.execute("DELETE FROM ssh_connections WHERE id = ?1", rusqlite::params![id])
            .map_err(|e| e.to_string())?;
        Ok(())
    })
    .await
    .map_err(|e| e.to_string())?
}

// ===== Sesi interaktif =====

#[tauri::command]
pub async fn ssh_connect(
    app: AppHandle,
    params: SshConnectParams,
    manager: State<'_, SshManager>,
) -> Result<String, String> {
    open_session(app, &manager, params).await
}

#[tauri::command]
pub async fn ssh_write(
    id: String,
    data: String,
    manager: State<'_, SshManager>,
) -> Result<(), String> {
    write_to_session(&manager, &id, &data).await
}

#[tauri::command]
pub async fn ssh_resize(
    id: String,
    cols: u32,
    rows: u32,
    manager: State<'_, SshManager>,
) -> Result<(), String> {
    resize_session(&manager, &id, cols, rows).await
}

#[tauri::command]
pub async fn ssh_disconnect(
    app: AppHandle,
    id: String,
    manager: State<'_, SshManager>,
) -> Result<(), String> {
    disconnect_session(app, &manager, &id).await
}

/// Daftar sesi yang sedang hidup (untuk chips re-attach).
#[tauri::command]
pub async fn ssh_active_sessions(manager: State<'_, SshManager>) -> Result<Vec<String>, String> {
    let sessions = manager.sessions.lock().await;
    Ok(sessions.keys().cloned().collect())
}
