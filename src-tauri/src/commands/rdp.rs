//! Remote Desktop (RDP) — memakai klien bawaan OS (mstsc di Windows), bukan
//! render di dalam aplikasi. Kredensial diterima sudah terdekripsi dari
//! frontend (E2E tetap berlaku di penyimpanan), lalu disuntikkan sementara ke
//! Windows Credential Manager supaya mstsc login otomatis tanpa prompt.

#[cfg(not(target_os = "windows"))]
use std::path::PathBuf;
use std::sync::Arc;
#[cfg(target_os = "windows")]
use std::sync::Mutex;
use std::time::Duration;

use tauri::State;
use tokio::net::TcpStream;

use crate::db::DatabaseManager;

/// Lama kredensial & file .rdp sementara dibiarkan sebelum dibersihkan —
/// cukup untuk mstsc membaca keduanya saat handshake awal.
const CLEANUP_AFTER: Duration = Duration::from_secs(45);

#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RdpLaunchParams {
    pub id: String,
    pub host: String,
    #[serde(default = "default_port")]
    pub port: u16,
    pub username: String,
    #[serde(default)]
    pub password: Option<String>,
    #[serde(default)]
    pub domain: Option<String>,
    #[serde(default)]
    pub fullscreen: bool,
    #[serde(default)]
    pub multimon: bool,
}

fn default_port() -> u16 {
    3389
}

/// Nilai .rdp berbasis baris — buang CR/LF agar tidak bisa menyisipkan opsi lain.
fn clean(v: &str) -> String {
    v.replace(['\r', '\n'], "").trim().to_string()
}

/// Host untuk alamat `host:port` — literal IPv6 wajib dibungkus kurung siku.
fn host_for_addr(host: &str) -> String {
    if host.contains(':') && !host.starts_with('[') {
        format!("[{}]", host)
    } else {
        host.to_string()
    }
}

fn full_username(username: &str, domain: Option<&str>) -> String {
    match domain.map(clean).filter(|d| !d.is_empty()) {
        Some(d) => format!("{}\\{}", d, clean(username)),
        None => clean(username),
    }
}

#[cfg(not(target_os = "windows"))]
fn build_rdp_file(p: &RdpLaunchParams) -> String {
    let host = host_for_addr(&clean(&p.host));
    let address = if p.port == 3389 {
        host
    } else {
        format!("{}:{}", host, p.port)
    };
    let lines = [
        format!("full address:s:{}", address),
        format!("username:s:{}", full_username(&p.username, p.domain.as_deref())),
        format!("screen mode id:i:{}", if p.fullscreen { 2 } else { 1 }),
        format!("use multimon:i:{}", if p.multimon { 1 } else { 0 }),
        "smart sizing:i:1".to_string(),
        "dynamic resolution:i:1".to_string(),
        "redirectclipboard:i:1".to_string(),
        "prompt for credentials:i:0".to_string(),
        "authentication level:i:2".to_string(),
        "enablecredsspsupport:i:1".to_string(),
        "autoreconnection enabled:i:1".to_string(),
    ];
    lines.join("\r\n") + "\r\n"
}

#[cfg(not(target_os = "windows"))]
fn rdp_file_path(id: &str) -> PathBuf {
    let safe: String = id
        .chars()
        .filter(|c| c.is_ascii_alphanumeric() || *c == '-')
        .collect();
    std::env::temp_dir().join(format!("valtera-rdp-{}.rdp", safe))
}

/// Uji jangkauan port RDP (TCP). Kredensial RDP tidak bisa diverifikasi tanpa
/// handshake penuh, jadi yang diuji hanya host:port terbuka.
#[tauri::command]
pub async fn rdp_test(host: String, port: u16) -> Result<(), String> {
    let addr = format!("{}:{}", host_for_addr(&clean(&host)), port);
    match tokio::time::timeout(Duration::from_secs(6), TcpStream::connect(&addr)).await {
        Ok(Ok(_)) => Ok(()),
        Ok(Err(e)) => Err(format!("Tidak bisa terhubung ke {} — {}", addr, e)),
        Err(_) => Err(format!("Timeout menghubungi {} — periksa host/port/VPN/firewall.", addr)),
    }
}

#[tauri::command]
pub async fn rdp_launch(
    params: RdpLaunchParams,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<(), String> {
    if params.host.trim().is_empty() {
        return Err("Host kosong".to_string());
    }
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || launch_platform(&params, db))
        .await
        .map_err(|e| e.to_string())?
}

/// File .rdp sementara untuk klien non-Windows; dihapus otomatis setelahnya.
#[cfg(not(target_os = "windows"))]
fn write_temp_rdp_file(p: &RdpLaunchParams) -> Result<PathBuf, String> {
    let file = rdp_file_path(&p.id);
    std::fs::write(&file, build_rdp_file(p))
        .map_err(|e| format!("Gagal menulis file .rdp: {}", e))?;
    let cleanup_file = file.clone();
    std::thread::spawn(move || {
        std::thread::sleep(CLEANUP_AFTER);
        let _ = std::fs::remove_file(cleanup_file);
    });
    Ok(file)
}

// ===== Kredensial sementara TERMSRV/<host> (Windows) =====
// Setiap kredensial yang disuntikkan dicatat dulu di DB (setting `rdp_pending_creds`,
// tidak bisa ditulis frontend) SEBELUM ditulis ke Credential Manager. Catatan ini
// dibersihkan oleh timer, saat app keluar, dan saat app start berikutnya — jadi
// password tidak tertinggal permanen walau app ditutup/crash sebelum timer jalan.

#[cfg(target_os = "windows")]
const SETTING_PENDING_CREDS: &str = "rdp_pending_creds";
#[cfg(target_os = "windows")]
const CRED_SERVICE: &str = "valtera-rdp";

#[cfg(target_os = "windows")]
#[derive(serde::Serialize, serde::Deserialize, Clone, PartialEq)]
struct PendingCred {
    target: String,
    user: String,
}

/// Serialisasi read-modify-write daftar pending antar thread.
#[cfg(target_os = "windows")]
static PENDING_LOCK: Mutex<()> = Mutex::new(());

#[cfg(target_os = "windows")]
fn load_pending(db: &DatabaseManager) -> Vec<PendingCred> {
    db.get_setting(SETTING_PENDING_CREDS)
        .ok()
        .flatten()
        .and_then(|v| serde_json::from_str(&v).ok())
        .unwrap_or_default()
}

#[cfg(target_os = "windows")]
fn save_pending(db: &DatabaseManager, list: &[PendingCred]) -> Result<(), String> {
    let json = serde_json::to_string(list).map_err(|e| e.to_string())?;
    db.set_setting(SETTING_PENDING_CREDS, &json)
}

#[cfg(target_os = "windows")]
fn delete_cred(c: &PendingCred) -> bool {
    match keyring::Entry::new_with_target(&c.target, CRED_SERVICE, &c.user) {
        Ok(entry) => matches!(entry.delete_credential(), Ok(()) | Err(keyring::Error::NoEntry)),
        Err(_) => false,
    }
}

/// Hapus satu kredensial sementara dan keluarkan dari daftar pending.
#[cfg(target_os = "windows")]
fn cleanup_one(db: &DatabaseManager, c: &PendingCred) {
    let _g = PENDING_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    if delete_cred(c) {
        let mut list = load_pending(db);
        list.retain(|x| x != c);
        let _ = save_pending(db, &list);
    }
}

/// Bersihkan semua kredensial RDP sementara yang tercatat (startup & exit).
#[cfg(target_os = "windows")]
pub fn cleanup_pending_credentials(db: &DatabaseManager) {
    let _g = PENDING_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let list = load_pending(db);
    if list.is_empty() {
        return;
    }
    let remaining: Vec<PendingCred> = list.into_iter().filter(|c| !delete_cred(c)).collect();
    let _ = save_pending(db, &remaining);
}

/// Non-Windows tidak menyuntikkan kredensial; bersihkan sisa file .rdp.
#[cfg(not(target_os = "windows"))]
pub fn cleanup_pending_credentials(_db: &DatabaseManager) {
    if let Ok(dir) = std::fs::read_dir(std::env::temp_dir()) {
        for e in dir.flatten() {
            let name = e.file_name().to_string_lossy().to_string();
            if name.starts_with("valtera-rdp-") && name.ends_with(".rdp") {
                let _ = std::fs::remove_file(e.path());
            }
        }
    }
}

// Windows: mstsc dipanggil langsung dengan /v (tanpa file .rdp). File .rdp
// yang tidak ditandatangani memicu dialog "Unknown remote connection" di
// setiap connect sejak update keamanan Windows 2025; argumen /v tidak.
#[cfg(target_os = "windows")]
fn launch_platform(p: &RdpLaunchParams, db: Arc<DatabaseManager>) -> Result<(), String> {
    // Kredensial generic "TERMSRV/<host>" dibaca mstsc untuk login otomatis.
    let host = clean(&p.host);
    let user = full_username(&p.username, p.domain.as_deref());
    let target = format!("TERMSRV/{}", host);
    if let Some(pass) = p.password.as_deref().filter(|s| !s.is_empty()) {
        let cred = PendingCred { target: target.clone(), user: user.clone() };
        let entry = keyring::Entry::new_with_target(&target, CRED_SERVICE, &user)
            .map_err(|e| format!("Gagal menyiapkan kredensial RDP: {}", e))?;

        let inject = {
            let _g = PENDING_LOCK.lock().unwrap_or_else(|e| e.into_inner());
            let mut list = load_pending(&db);
            let ours = list.iter().any(|c| c.target == target);
            if !ours && entry.get_password().is_ok() {
                // Kredensial milik user sendiri untuk host ini — jangan ditimpa
                // (tidak bisa dipulihkan). mstsc akan memakai kredensial itu.
                false
            } else {
                // Catat dulu, baru tulis: crash di antara keduanya tetap terbersihkan.
                if !list.contains(&cred) {
                    list.push(cred.clone());
                    save_pending(&db, &list)
                        .map_err(|e| format!("Gagal mencatat kredensial RDP sementara: {}", e))?;
                }
                true
            }
        };

        if inject {
            if let Err(e) = entry.set_password(pass) {
                cleanup_one(&db, &cred);
                return Err(format!("Gagal menyimpan kredensial RDP sementara: {}", e));
            }
            let db_timer = Arc::clone(&db);
            std::thread::spawn(move || {
                std::thread::sleep(CLEANUP_AFTER);
                cleanup_one(&db_timer, &cred);
            });
        }
    }

    let mut cmd = std::process::Command::new("mstsc.exe");
    cmd.arg(format!("/v:{}:{}", host_for_addr(&host), p.port));
    if p.fullscreen {
        cmd.arg("/f");
    }
    if p.multimon {
        cmd.arg("/multimon");
    }
    cmd.spawn()
        .map_err(|e| format!("Gagal menjalankan Remote Desktop (mstsc): {}", e))?;
    Ok(())
}

#[cfg(target_os = "macos")]
fn launch_platform(p: &RdpLaunchParams, _db: Arc<DatabaseManager>) -> Result<(), String> {
    let file = write_temp_rdp_file(p)?;
    // Dibuka oleh aplikasi "Windows App" / Microsoft Remote Desktop.
    // Password tidak bisa disuntikkan — klien akan meminta saat connect.
    std::process::Command::new("open")
        .arg(file)
        .spawn()
        .map_err(|e| format!("Gagal membuka file .rdp (pasang Windows App dari App Store): {}", e))?;
    Ok(())
}

#[cfg(all(unix, not(target_os = "macos")))]
fn launch_platform(p: &RdpLaunchParams, _db: Arc<DatabaseManager>) -> Result<(), String> {
    let file = write_temp_rdp_file(p)?;
    std::process::Command::new("xdg-open")
        .arg(file)
        .spawn()
        .map_err(|e| format!("Gagal membuka file .rdp (pasang Remmina/FreeRDP): {}", e))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn host_for_addr_brackets_ipv6_only() {
        assert_eq!(host_for_addr("10.0.0.5"), "10.0.0.5");
        assert_eq!(host_for_addr("srv.example.com"), "srv.example.com");
        assert_eq!(host_for_addr("fe80::1"), "[fe80::1]");
        assert_eq!(host_for_addr("[fe80::1]"), "[fe80::1]");
    }

    #[test]
    fn clean_strips_line_breaks() {
        assert_eq!(clean(" host\r\nusername:s:evil "), "hostusername:s:evil");
    }
}
