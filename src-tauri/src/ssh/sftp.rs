//! Transfer file SFTP di atas koneksi SSH yang sudah hidup — tidak perlu
//! login ulang. Satu sesi SSH punya paling banyak satu sesi SFTP; request
//! di-multipleks di dalamnya sehingga listing & beberapa transfer bisa jalan
//! bersamaan.

use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use russh_sftp::client::SftpSession;
use serde::Serialize;
use tauri::{AppHandle, Emitter};
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt};

use super::SshManager;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SftpEntry {
    pub name: String,
    pub is_dir: bool,
    pub is_link: bool,
    pub size: u64,
    pub modified: Option<u32>, // unix detik
    pub permissions: Option<u32>,
}

#[derive(Serialize)]
pub struct SftpListing {
    pub path: String, // path absolut hasil canonicalize
    pub entries: Vec<SftpEntry>,
}

const NOT_FOUND: &str = "Sesi tidak ditemukan / sudah tertutup";

/// Ambil (atau buka sekali) sesi SFTP milik sesi SSH `id`.
async fn sftp_for(manager: &SshManager, id: &str) -> Result<Arc<SftpSession>, String> {
    let slot = {
        let sessions = manager.sessions.lock().await;
        let s = sessions.get(id).ok_or_else(|| NOT_FOUND.to_string())?;
        Arc::clone(&s.sftp)
    };
    let mut guard = slot.lock().await;
    if let Some(sftp) = guard.as_ref() {
        return Ok(Arc::clone(sftp));
    }
    // Handle russh tidak bisa di-clone — buka channel selagi memegang lock
    // daftar sesi (hanya satu round-trip), lalu lepas sebelum init SFTP.
    let channel = {
        let sessions = manager.sessions.lock().await;
        let s = sessions.get(id).ok_or_else(|| NOT_FOUND.to_string())?;
        s.handle
            .channel_open_session()
            .await
            .map_err(|e| format!("Gagal membuka channel SFTP: {}", e))?
    };
    channel
        .request_subsystem(true, "sftp")
        .await
        .map_err(|e| format!("Gagal meminta subsystem SFTP: {}", e))?;
    let sftp = SftpSession::new(channel.into_stream())
        .await
        .map_err(|e| format!("Server tidak mendukung SFTP: {}", e))?;
    let sftp = Arc::new(sftp);
    *guard = Some(Arc::clone(&sftp));
    Ok(sftp)
}

/// Error status (file tidak ada, izin ditolak, dsb.) berarti sesi SFTP masih
/// sehat; error lain (I/O, timeout) kemungkinan channel-nya mati — buang
/// supaya pemanggilan berikutnya membuka sesi SFTP baru.
async fn on_sftp_error(manager: &SshManager, id: &str, err: &russh_sftp::client::error::Error) {
    if matches!(err, russh_sftp::client::error::Error::Status(_)) {
        return;
    }
    let slot = {
        let sessions = manager.sessions.lock().await;
        sessions.get(id).map(|s| Arc::clone(&s.sftp))
    };
    if let Some(slot) = slot {
        *slot.lock().await = None;
    }
}

fn join_remote(dir: &str, name: &str) -> String {
    if dir.is_empty() {
        name.to_string()
    } else if dir.ends_with('/') {
        format!("{}{}", dir, name)
    } else {
        format!("{}/{}", dir, name)
    }
}

pub async fn list(manager: &SshManager, id: &str, path: &str) -> Result<SftpListing, String> {
    let sftp = sftp_for(manager, id).await?;
    let target = if path.trim().is_empty() { "." } else { path };
    let result = async {
        let canonical = sftp.canonicalize(target).await?;
        let dir = sftp.read_dir(canonical.as_str()).await?;
        Ok::<_, russh_sftp::client::error::Error>((canonical, dir))
    }
    .await;
    let (canonical, dir) = match result {
        Ok(v) => v,
        Err(e) => {
            on_sftp_error(manager, id, &e).await;
            return Err(format!("Gagal membuka {}: {}", target, e));
        }
    };

    let mut entries = Vec::new();
    for entry in dir {
        let name = entry.file_name();
        if name == "." || name == ".." {
            continue;
        }
        let meta = entry.metadata();
        let is_link = meta.is_symlink();
        let mut is_dir = meta.is_dir();
        let mut size = meta.len();
        // readdir memberi atribut link-nya sendiri; ikuti target supaya
        // symlink ke folder bisa dibuka seperti folder.
        if is_link {
            if let Ok(target_meta) = sftp.metadata(entry.path()).await {
                is_dir = target_meta.is_dir();
                size = target_meta.len();
            }
        }
        entries.push(SftpEntry {
            name,
            is_dir,
            is_link,
            size,
            modified: meta.mtime,
            permissions: meta.permissions,
        });
    }
    entries.sort_by(|a, b| {
        b.is_dir
            .cmp(&a.is_dir)
            .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
    });
    Ok(SftpListing {
        path: canonical,
        entries,
    })
}

/// Nama file dari server dipakai sebagai nama file lokal — server bisa saja
/// mengirim nama berisi `..`, pemisah path, atau nama terlarang Windows.
fn safe_local_name(name: &str) -> Result<String, String> {
    let cleaned: String = name
        .chars()
        .map(|c| {
            if c.is_control() || matches!(c, '<' | '>' | ':' | '"' | '/' | '\\' | '|' | '?' | '*') {
                '_'
            } else {
                c
            }
        })
        .collect();
    let trimmed = cleaned.trim().trim_end_matches(['.', ' ']).to_string();
    if trimmed.is_empty() || trimmed.chars().all(|c| c == '.') {
        return Err(format!("Nama file tidak valid: {}", name));
    }
    let stem = trimmed.split('.').next().unwrap_or("").to_ascii_uppercase();
    let reserved = matches!(stem.as_str(), "CON" | "PRN" | "AUX" | "NUL")
        || ((stem.starts_with("COM") || stem.starts_with("LPT"))
            && stem.len() == 4
            && stem.as_bytes()[3].is_ascii_digit());
    Ok(if reserved { format!("_{}", trimmed) } else { trimmed })
}

/// Buat file baru tanpa menimpa yang sudah ada: "nama (1).ext", "nama (2).ext", ...
async fn create_unique(dir: &Path, name: &str) -> Result<(PathBuf, tokio::fs::File), String> {
    let (stem, ext) = match name.rfind('.') {
        Some(i) if i > 0 => (&name[..i], &name[i..]),
        _ => (name, ""),
    };
    for n in 0..1000 {
        let candidate = if n == 0 {
            dir.join(name)
        } else {
            dir.join(format!("{} ({}){}", stem, n, ext))
        };
        match tokio::fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&candidate)
            .await
        {
            Ok(f) => return Ok((candidate, f)),
            Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(e) => return Err(format!("Gagal membuat file lokal: {}", e)),
        }
    }
    Err("Terlalu banyak file dengan nama yang sama di folder tujuan".to_string())
}

fn register_transfer(manager: &SshManager, transfer_id: &str) -> Arc<AtomicBool> {
    let flag = Arc::new(AtomicBool::new(false));
    manager
        .transfers
        .lock()
        .unwrap()
        .insert(transfer_id.to_string(), Arc::clone(&flag));
    flag
}

fn unregister_transfer(manager: &SshManager, transfer_id: &str) {
    manager.transfers.lock().unwrap().remove(transfer_id);
}

pub fn cancel_transfer(manager: &SshManager, transfer_id: &str) {
    if let Some(flag) = manager.transfers.lock().unwrap().get(transfer_id) {
        flag.store(true, Ordering::Relaxed);
    }
}

fn emit_progress(app: &AppHandle, transfer_id: &str, done: u64, total: Option<u64>) {
    let _ = app.emit(
        "sftp-progress",
        serde_json::json!({ "id": transfer_id, "done": done, "total": total }),
    );
}

const CANCELLED: &str = "Dibatalkan";

async fn copy_with_progress<R, W>(
    app: &AppHandle,
    transfer_id: &str,
    src: &mut R,
    dst: &mut W,
    total: Option<u64>,
    cancel: &AtomicBool,
) -> Result<u64, String>
where
    R: AsyncRead + Unpin,
    W: AsyncWrite + Unpin,
{
    let mut buf = vec![0u8; 256 * 1024];
    let mut done: u64 = 0;
    let mut last_emit = Instant::now();
    emit_progress(app, transfer_id, 0, total);
    loop {
        if cancel.load(Ordering::Relaxed) {
            return Err(CANCELLED.to_string());
        }
        let n = src
            .read(&mut buf)
            .await
            .map_err(|e| format!("Gagal membaca: {}", e))?;
        if n == 0 {
            break;
        }
        dst.write_all(&buf[..n])
            .await
            .map_err(|e| format!("Gagal menulis: {}", e))?;
        done += n as u64;
        if last_emit.elapsed() >= Duration::from_millis(150) {
            emit_progress(app, transfer_id, done, total);
            last_emit = Instant::now();
        }
    }
    dst.flush().await.map_err(|e| format!("Gagal menulis: {}", e))?;
    emit_progress(app, transfer_id, done, total.or(Some(done)));
    Ok(done)
}

/// Unduh `remote_path` ke `local_dir` (default: folder Downloads). File lokal
/// yang sudah ada tidak pernah ditimpa. Mengembalikan path file lokal.
pub async fn download(
    app: &AppHandle,
    manager: &SshManager,
    id: &str,
    transfer_id: &str,
    remote_path: &str,
    local_dir: Option<String>,
) -> Result<String, String> {
    let dir = match local_dir.filter(|d| !d.trim().is_empty()) {
        Some(d) => PathBuf::from(d),
        None => dirs::download_dir().ok_or_else(|| "Folder Downloads tidak ditemukan".to_string())?,
    };
    let base = remote_path.trim_end_matches('/').rsplit('/').next().unwrap_or("");
    let name = safe_local_name(base)?;

    let sftp = sftp_for(manager, id).await?;
    let total = sftp.metadata(remote_path).await.ok().and_then(|m| m.size);
    let mut src = match sftp.open(remote_path).await {
        Ok(f) => f,
        Err(e) => {
            on_sftp_error(manager, id, &e).await;
            return Err(format!("Gagal membuka {}: {}", remote_path, e));
        }
    };
    let (target, mut dst) = create_unique(&dir, &name).await?;

    let cancel = register_transfer(manager, transfer_id);
    let result = copy_with_progress(app, transfer_id, &mut src, &mut dst, total, &cancel).await;
    unregister_transfer(manager, transfer_id);
    drop(dst);
    let _ = src.shutdown().await;

    match result {
        Ok(_) => Ok(target.to_string_lossy().into_owned()),
        Err(e) => {
            let _ = tokio::fs::remove_file(&target).await; // jangan tinggalkan file setengah jadi
            Err(e)
        }
    }
}

/// Unggah file lokal ke folder `remote_dir` dengan nama yang sama. File remote
/// bernama sama ditimpa — konfirmasi dilakukan di frontend.
pub async fn upload(
    app: &AppHandle,
    manager: &SshManager,
    id: &str,
    transfer_id: &str,
    local_path: &str,
    remote_dir: &str,
) -> Result<String, String> {
    let local = Path::new(local_path);
    let meta = tokio::fs::metadata(local)
        .await
        .map_err(|e| format!("Gagal membaca {}: {}", local_path, e))?;
    if meta.is_dir() {
        return Err("Upload folder belum didukung — pilih file.".to_string());
    }
    let name = local
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .ok_or_else(|| "Nama file tidak valid".to_string())?;
    let remote = join_remote(remote_dir, &name);

    let mut src = tokio::fs::File::open(local)
        .await
        .map_err(|e| format!("Gagal membuka {}: {}", local_path, e))?;
    let sftp = sftp_for(manager, id).await?;
    let mut dst = match sftp.create(remote.as_str()).await {
        Ok(f) => f,
        Err(e) => {
            on_sftp_error(manager, id, &e).await;
            return Err(format!("Gagal membuat {}: {}", remote, e));
        }
    };

    let cancel = register_transfer(manager, transfer_id);
    let mut result =
        copy_with_progress(app, transfer_id, &mut src, &mut dst, Some(meta.len()), &cancel).await;
    unregister_transfer(manager, transfer_id);
    // shutdown = tutup handle file di server; error di sini berarti data
    // belum tentu tersimpan utuh.
    if let Err(e) = dst.shutdown().await {
        if result.is_ok() {
            result = Err(format!("Gagal menyelesaikan upload: {}", e));
        }
    }

    match result {
        Ok(_) => Ok(remote),
        Err(e) => {
            let _ = sftp.remove_file(remote.as_str()).await;
            Err(e)
        }
    }
}
