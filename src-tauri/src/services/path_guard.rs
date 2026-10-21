//! Allowlist path lokal untuk command IPC.
//!
//! Webview tidak boleh bisa membaca/menulis file sembarang hanya dengan
//! mengirim string path (mis. lewat XSS di Markdown). Sumber kebenaran adalah
//! fs scope milik `tauri-plugin-fs`, yang hanya bertambah lewat jalur yang
//! dipicu pengguna:
//!   - dialog open/save/folder (`tauri-plugin-dialog` memanggil `allow_file`
//!     / `allow_directory` saat dialog kembali),
//!   - drag-drop file/folder ke jendela (`tauri-plugin-fs`),
//!   - argumen baris perintah / single-instance dan file hasil unduhan SFTP
//!     (di-grant dari Rust lewat [`grant_file`]).
//!
//! Setiap grant direkam ke tabel `granted_paths` (hanya ditulis dari sini,
//! tidak ada command IPC yang menulisnya) supaya tab sesi tetap bisa disimpan
//! setelah aplikasi dibuka ulang. Saat start, file di tabel di-grant ulang ke
//! fs scope; folder hanya dipakai sebagai tujuan unduhan dan tidak membuka
//! akses baca ke isinya.

use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use rusqlite::params;
use tauri::scope::fs::Event;
use tauri::{AppHandle, Manager, Runtime};
use tauri_plugin_fs::FsExt;

use crate::db::DatabaseManager;

const MAX_FILES: i64 = 500;
const MAX_DIRS: i64 = 50;
const DENIED: &str =
    "Akses ditolak: path ini belum dipilih lewat dialog, drag-drop, atau \"Open with\". Buka/simpan ulang lewat dialog.";

/// Folder tujuan yang pernah dipilih pengguna (dipulihkan dari DB).
#[derive(Default)]
pub struct GrantedDirs(Mutex<HashSet<PathBuf>>);

fn normalize(path: &Path) -> PathBuf {
    dunce::canonicalize(path).unwrap_or_else(|_| path.components().collect())
}

/// Pulihkan grant tersimpan lalu rekam setiap grant baru. Dipanggil sekali di
/// `setup`, setelah plugin fs & dialog terpasang.
pub fn init<R: Runtime>(app: &AppHandle<R>, db: Arc<DatabaseManager>) {
    let scope = app.fs_scope();
    let dirs = GrantedDirs::default();

    let rows: Vec<(String, String)> = {
        let conn = db.get_conn();
        let existed: bool = conn
            .query_row(
                "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'granted_paths'",
                [],
                |_| Ok(()),
            )
            .is_ok();
        let _ = conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS granted_paths (
                path TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );",
        );
        if !existed {
            // Migrasi satu kali dari versi tanpa allowlist: file yang sedang
            // terbuka di sesi tetap bisa disimpan setelah update.
            let _ = conn.execute(
                "INSERT OR IGNORE INTO granted_paths (path, kind)
                 SELECT DISTINCT file_path, 'file' FROM tabs_state
                 WHERE file_path IS NOT NULL AND file_path != ''",
                [],
            );
        }
        conn.prepare("SELECT path, kind FROM granted_paths")
            .and_then(|mut stmt| {
                stmt.query_map([], |r| Ok((r.get(0)?, r.get(1)?)))?
                    .collect::<Result<Vec<_>, _>>()
            })
            .unwrap_or_default()
    };

    {
        let mut set = dirs.0.lock().unwrap();
        for (path, kind) in rows {
            if kind == "dir" {
                set.insert(normalize(Path::new(&path)));
            } else {
                let _ = scope.allow_file(&path);
            }
        }
    }
    app.manage(dirs);

    // Didaftarkan setelah pemulihan agar grant lama tidak ditulis ulang.
    let handle = app.clone();
    scope.listen(move |event| {
        if let Event::PathAllowed(path) = event {
            record(&handle, &db, path);
        }
    });
}

fn record<R: Runtime>(app: &AppHandle<R>, db: &DatabaseManager, path: &Path) {
    let is_dir = path.is_dir();
    let kind = if is_dir { "dir" } else { "file" };
    let stored = normalize(path);
    if is_dir {
        app.state::<GrantedDirs>().0.lock().unwrap().insert(stored.clone());
    }
    let conn = db.get_conn();
    let _ = conn.execute(
        "INSERT INTO granted_paths (path, kind, updated_at) VALUES (?1, ?2, CURRENT_TIMESTAMP)
         ON CONFLICT(path) DO UPDATE SET kind = ?2, updated_at = CURRENT_TIMESTAMP",
        params![stored.to_string_lossy(), kind],
    );
    let cap = if is_dir { MAX_DIRS } else { MAX_FILES };
    let _ = conn.execute(
        "DELETE FROM granted_paths WHERE kind = ?1 AND path NOT IN (
            SELECT path FROM granted_paths WHERE kind = ?1 ORDER BY updated_at DESC LIMIT ?2
         )",
        params![kind, cap],
    );
}

/// Izinkan file yang berasal dari jalur tepercaya (argumen CLI, hasil unduhan).
pub fn grant_file<R: Runtime>(app: &AppHandle<R>, path: &Path) {
    let _ = app.fs_scope().allow_file(path);
}

/// File (baca/tulis) harus sudah di-grant.
pub fn ensure_file<R: Runtime>(app: &AppHandle<R>, path: &str) -> Result<(), String> {
    if !path.trim().is_empty() && app.fs_scope().is_allowed(path) {
        Ok(())
    } else {
        Err(DENIED.to_string())
    }
}

/// Folder tujuan tulis: di-grant di sesi ini, atau pernah dipilih sebelumnya.
pub fn ensure_dir<R: Runtime>(app: &AppHandle<R>, dir: &str) -> Result<(), String> {
    if dir.trim().is_empty() {
        return Err(DENIED.to_string());
    }
    let path = Path::new(dir);
    if app.fs_scope().is_allowed(path)
        || app
            .state::<GrantedDirs>()
            .0
            .lock()
            .unwrap()
            .contains(&normalize(path))
    {
        Ok(())
    } else {
        Err(DENIED.to_string())
    }
}
