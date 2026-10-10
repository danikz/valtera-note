//! Remote Desktop (RDP) — memakai klien bawaan OS (mstsc di Windows), bukan
//! render di dalam aplikasi. Kredensial diterima sudah terdekripsi dari
//! frontend (E2E tetap berlaku di penyimpanan), lalu disuntikkan sementara ke
//! Windows Credential Manager supaya mstsc login otomatis tanpa prompt.

#[cfg(not(target_os = "windows"))]
use std::path::PathBuf;
use std::time::Duration;

use tokio::net::TcpStream;

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

fn full_username(username: &str, domain: Option<&str>) -> String {
    match domain.map(clean).filter(|d| !d.is_empty()) {
        Some(d) => format!("{}\\{}", d, clean(username)),
        None => clean(username),
    }
}

#[cfg(not(target_os = "windows"))]
fn build_rdp_file(p: &RdpLaunchParams) -> String {
    let host = clean(&p.host);
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
    let host = clean(&host);
    let addr = format!("{}:{}", host, port);
    match tokio::time::timeout(Duration::from_secs(6), TcpStream::connect(&addr)).await {
        Ok(Ok(_)) => Ok(()),
        Ok(Err(e)) => Err(format!("Tidak bisa terhubung ke {} — {}", addr, e)),
        Err(_) => Err(format!("Timeout menghubungi {} — periksa host/port/VPN/firewall.", addr)),
    }
}

#[tauri::command]
pub async fn rdp_launch(params: RdpLaunchParams) -> Result<(), String> {
    if params.host.trim().is_empty() {
        return Err("Host kosong".to_string());
    }
    launch_platform(&params)
}

/// File .rdp sementara untuk klien non-Windows; dihapus otomatis setelahnya.
#[cfg(not(target_os = "windows"))]
fn write_temp_rdp_file(p: &RdpLaunchParams) -> Result<PathBuf, String> {
    let file = rdp_file_path(&p.id);
    std::fs::write(&file, build_rdp_file(p))
        .map_err(|e| format!("Gagal menulis file .rdp: {}", e))?;
    let cleanup_file = file.clone();
    tokio::spawn(async move {
        tokio::time::sleep(CLEANUP_AFTER).await;
        let _ = std::fs::remove_file(cleanup_file);
    });
    Ok(file)
}

// Windows: mstsc dipanggil langsung dengan /v (tanpa file .rdp). File .rdp
// yang tidak ditandatangani memicu dialog "Unknown remote connection" di
// setiap connect sejak update keamanan Windows 2025; argumen /v tidak.
#[cfg(target_os = "windows")]
fn launch_platform(p: &RdpLaunchParams) -> Result<(), String> {
    // Kredensial generic "TERMSRV/<host>" dibaca mstsc untuk login otomatis.
    // Bila user sudah punya entri sendiri untuk host ini, entri itu tidak
    // dihapus setelahnya (hanya ditimpa dengan kredensial tersimpan).
    let host = clean(&p.host);
    let user = full_username(&p.username, p.domain.as_deref());
    let target = format!("TERMSRV/{}", host);
    if let Some(pass) = p.password.as_deref().filter(|s| !s.is_empty()) {
        let entry = keyring::Entry::new_with_target(&target, "valtera-rdp", &user)
            .map_err(|e| format!("Gagal menyiapkan kredensial RDP: {}", e))?;
        let pre_existing = entry.get_password().is_ok();
        entry
            .set_password(pass)
            .map_err(|e| format!("Gagal menyimpan kredensial RDP sementara: {}", e))?;
        if !pre_existing {
            tokio::spawn(async move {
                tokio::time::sleep(CLEANUP_AFTER).await;
                let _ = entry.delete_credential();
            });
        }
    }

    let mut cmd = std::process::Command::new("mstsc.exe");
    cmd.arg(format!("/v:{}:{}", host, p.port));
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
fn launch_platform(p: &RdpLaunchParams) -> Result<(), String> {
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
fn launch_platform(p: &RdpLaunchParams) -> Result<(), String> {
    let file = write_temp_rdp_file(p)?;
    std::process::Command::new("xdg-open")
        .arg(file)
        .spawn()
        .map_err(|e| format!("Gagal membuka file .rdp (pasang Remmina/FreeRDP): {}", e))?;
    Ok(())
}
