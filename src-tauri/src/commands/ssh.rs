use std::sync::Arc;

use serde::Serialize;
use tauri::{AppHandle, State};

use crate::db::DatabaseManager;
use crate::ssh::sftp::{self, SftpListing};
use crate::ssh::{
    disconnect_session, open_session, replay_session, resize_session, write_to_session,
    SshConnectParams, SshManager,
};

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

/// Isi layar terakhir sesi untuk terminal yang baru di-attach ulang.
#[tauri::command]
pub async fn ssh_replay(id: String, manager: State<'_, SshManager>) -> Result<String, String> {
    replay_session(&manager, &id).await
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

// ===== Transfer file (SFTP di atas sesi yang sama) =====

/// Isi folder remote; `path` kosong = folder home user.
#[tauri::command]
pub async fn sftp_list(
    id: String,
    path: String,
    manager: State<'_, SshManager>,
) -> Result<SftpListing, String> {
    sftp::list(&manager, &id, &path).await
}

/// Unduh file remote ke `local_dir` (null = folder Downloads); hasilnya path
/// file lokal. Progres dikirim lewat event `sftp-progress`.
#[tauri::command]
pub async fn sftp_download(
    app: AppHandle,
    id: String,
    transfer_id: String,
    remote_path: String,
    local_dir: Option<String>,
    manager: State<'_, SshManager>,
) -> Result<String, String> {
    sftp::download(&app, &manager, &id, &transfer_id, &remote_path, local_dir).await
}

/// Unggah file lokal ke folder remote; hasilnya path file remote.
#[tauri::command]
pub async fn sftp_upload(
    app: AppHandle,
    id: String,
    transfer_id: String,
    local_path: String,
    remote_dir: String,
    manager: State<'_, SshManager>,
) -> Result<String, String> {
    sftp::upload(&app, &manager, &id, &transfer_id, &local_path, &remote_dir).await
}

#[tauri::command]
pub fn sftp_cancel(transfer_id: String, manager: State<'_, SshManager>) {
    sftp::cancel_transfer(&manager, &transfer_id);
}

/// Folder Downloads default (ditampilkan di panel file).
#[tauri::command]
pub fn sftp_default_download_dir() -> Option<String> {
    dirs::download_dir().map(|p| p.to_string_lossy().into_owned())
}

/// Tampilkan file hasil unduhan di file manager OS.
#[tauri::command]
pub fn reveal_in_folder(path: String) -> Result<(), String> {
    let p = std::path::Path::new(&path);
    if !p.exists() {
        return Err("File tidak ditemukan".to_string());
    }
    #[cfg(target_os = "windows")]
    {
        use std::os::windows::process::CommandExt;
        std::process::Command::new("explorer")
            .raw_arg(format!("/select,\"{}\"", path.replace('"', "")))
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    #[cfg(target_os = "macos")]
    {
        std::process::Command::new("open")
            .arg("-R")
            .arg(&path)
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    #[cfg(all(unix, not(target_os = "macos")))]
    {
        let dir = p.parent().unwrap_or(p);
        std::process::Command::new("xdg-open")
            .arg(dir)
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    Ok(())
}
