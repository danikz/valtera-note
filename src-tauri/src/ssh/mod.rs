//! SSH engine — sesi interaktif per koneksi, output di-stream ke frontend
//! lewat Tauri events. Satu sesi = satu koneksi (MVP); kredensial diterima
//! sudah terdekripsi di sisi frontend (E2E tetap berlaku di penyimpanan).

use std::collections::HashMap;
use std::sync::{Arc, Mutex as StdMutex};

use russh::client::{self, Handle};
use tauri::{AppHandle, Emitter};
use tokio::sync::Mutex;

/// Ring buffer output terakhir per sesi (raw PTY bytes, termasuk escape
/// sequence). Dipakai untuk mengembalikan isi layar saat terminal di-attach
/// ulang — mis. setelah halaman SSH ditinggalkan dan dibuka lagi — karena
/// shell tidak mengirim ulang prompt/layar dengan sendirinya.
pub struct ReplayBuffer {
    data: StdMutex<Vec<u8>>,
    cap: usize,
}

impl ReplayBuffer {
    fn new(cap: usize) -> Self {
        Self {
            data: StdMutex::new(Vec::with_capacity(4096)),
            cap,
        }
    }

    fn push(&self, bytes: &[u8]) {
        if bytes.is_empty() {
            return;
        }
        let mut buf = self.data.lock().unwrap();
        buf.extend_from_slice(bytes);
        if buf.len() > self.cap {
            let excess = buf.len() - self.cap;
            buf.drain(..excess);
        }
    }

    fn snapshot(&self) -> Vec<u8> {
        self.data.lock().unwrap().clone()
    }
}

pub struct ClientHandler {
    app: AppHandle,
    session_id: String,
    replay: Arc<ReplayBuffer>,
}

#[async_trait::async_trait]
impl client::Handler for ClientHandler {
    type Error = russh::Error;

    async fn check_server_key(
        &mut self,
        _server_public_key: &russh::keys::key::PublicKey,
    ) -> Result<bool, Self::Error> {
        // Trust-on-first-use sederhana: fingerprint diverifikasi oleh UI
        // melalui event ssh-hostkey pada iterasi berikutnya.
        Ok(true)
    }

    async fn data(
        &mut self,
        _channel: russh::ChannelId,
        data: &[u8],
        _session: &mut client::Session,
    ) -> Result<(), Self::Error> {
        self.replay.push(data);
        let _ = self.app.emit(
            "ssh-data",
            serde_json::json!({ "id": self.session_id, "data": String::from_utf8_lossy(data) }),
        );
        Ok(())
    }

    async fn extended_data(
        &mut self,
        _channel: russh::ChannelId,
        _ext: u32,
        data: &[u8],
        _session: &mut client::Session,
    ) -> Result<(), Self::Error> {
        self.replay.push(data);
        let _ = self.app.emit(
            "ssh-data",
            serde_json::json!({ "id": self.session_id, "data": String::from_utf8_lossy(data) }),
        );
        Ok(())
    }

    async fn channel_close(
        &mut self,
        _channel: russh::ChannelId,
        _session: &mut client::Session,
    ) -> Result<(), Self::Error> {
        let _ = self.app.emit(
            "ssh-status",
            serde_json::json!({ "id": self.session_id, "status": "closed" }),
        );
        Ok(())
    }
}

pub struct ActiveSession {
    pub handle: Handle<ClientHandler>,
    pub channel: russh::Channel<russh::client::Msg>,
    pub label: String,
    pub replay: Arc<ReplayBuffer>,
}

#[derive(Default)]
pub struct SshManager {
    pub sessions: Mutex<HashMap<String, ActiveSession>>,
}

#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SshConnectParams {
    pub id: String,
    pub label: String,
    pub host: String,
    #[serde(default = "default_port")]
    pub port: u16,
    pub username: String,
    pub auth_type: String, // "password" | "key"
    #[serde(default)]
    pub password: Option<String>,
    #[serde(default)]
    pub private_key: Option<String>,
    #[serde(default)]
    pub passphrase: Option<String>,
    #[serde(default = "default_cols")]
    pub cols: u32,
    #[serde(default = "default_rows")]
    pub rows: u32,
}

fn default_port() -> u16 {
    22
}
fn default_cols() -> u32 {
    80
}
fn default_rows() -> u32 {
    24
}

pub async fn open_session(
    app: AppHandle,
    manager: &SshManager,
    p: SshConnectParams,
) -> Result<String, String> {
    {
        let sessions = manager.sessions.lock().await;
        if sessions.contains_key(&p.id) {
            return Ok(p.id); // sesi sudah hidup — re-attach
        }
    }

    let config = Arc::new(client::Config::default());
    let addr = (p.host.clone(), p.port);
    let replay = Arc::new(ReplayBuffer::new(128 * 1024));
    let handler = ClientHandler {
        app: app.clone(),
        session_id: p.id.clone(),
        replay: Arc::clone(&replay),
    };

    let mut handle: Handle<ClientHandler> =
        client::connect(config, addr, handler)
            .await
            .map_err(|e| format!("Gagal terhubung ke {}:{} — {}", p.host, p.port, e))?;

    let auth_ok = match p.auth_type.as_str() {
        "key" => {
            let key = p
                .private_key
                .clone()
                .ok_or_else(|| "Private key kosong".to_string())?;
            let secret = russh::keys::decode_secret_key(&key, p.passphrase.as_deref())
                .map_err(|e| format!("Private key tidak valid: {}", e))?;
            handle
                .authenticate_publickey(p.username.trim(), Arc::new(secret))
                .await
                .map_err(|e| format!("Autentikasi public key gagal: {}", e))?
        }
        _ => handle
            .authenticate_password(p.username.trim(), p.password.as_deref().unwrap_or(""))
            .await
            .map_err(|e| format!("Autentikasi password gagal: {}", e))?,
    };
    if !auth_ok {
        let _ = handle
            .disconnect(russh::Disconnect::ByApplication, "auth failed", "en")
            .await;
        return Err("Autentikasi ditolak server — periksa user/password/key.".to_string());
    }

    let channel = handle
        .channel_open_session()
        .await
        .map_err(|e| format!("Gagal membuka channel: {}", e))?;
    channel
        .request_pty(true, "xterm-256color", p.cols, p.rows, 0, 0, &[])
        .await
        .map_err(|e| format!("Gagal meminta PTY: {}", e))?;
    channel
        .request_shell(true)
        .await
        .map_err(|e| format!("Gagal meminta shell: {}", e))?;

    let mut sessions = manager.sessions.lock().await;
    sessions.insert(
        p.id.clone(),
        ActiveSession {
            handle,
            channel,
            label: p.label.clone(),
            replay,
        },
    );
    let _ = app.emit(
        "ssh-status",
        serde_json::json!({ "id": p.id, "status": "connected" }),
    );
    Ok(p.id)
}

pub async fn write_to_session(manager: &SshManager, id: &str, data: &str) -> Result<(), String> {
    let sessions = manager.sessions.lock().await;
    let session = sessions
        .get(id)
        .ok_or_else(|| "Sesi tidak ditemukan / sudah tertutup".to_string())?;
    session
        .channel
        .data(data.as_bytes())
        .await
        .map_err(|e| format!("Gagal mengirim data: {}", e))
}

pub async fn resize_session(
    manager: &SshManager,
    id: &str,
    cols: u32,
    rows: u32,
) -> Result<(), String> {
    let sessions = manager.sessions.lock().await;
    let session = sessions
        .get(id)
        .ok_or_else(|| "Sesi tidak ditemukan / sudah tertutup".to_string())?;
    session
        .channel
        .window_change(cols, rows, 0, 0)
        .await
        .map_err(|e| format!("Gagal resize: {}", e))
}

/// Isi layar terakhir sesi (hasil replay buffer) untuk di-write ke terminal
/// yang baru di-attach. String lossy konsisten dengan jalur event ssh-data.
pub async fn replay_session(manager: &SshManager, id: &str) -> Result<String, String> {
    let sessions = manager.sessions.lock().await;
    let session = sessions
        .get(id)
        .ok_or_else(|| "Sesi tidak ditemukan / sudah tertutup".to_string())?;
    Ok(String::from_utf8_lossy(&session.replay.snapshot()).into_owned())
}

pub async fn disconnect_session(
    app: AppHandle,
    manager: &SshManager,
    id: &str,
) -> Result<(), String> {
    let removed = {
        let mut sessions = manager.sessions.lock().await;
        sessions.remove(id)
    };
    if let Some(session) = removed {
        let _ = session
            .handle
            .disconnect(russh::Disconnect::ByApplication, "user quit", "en")
            .await;
        let _ = app.emit(
            "ssh-status",
            serde_json::json!({ "id": id, "status": "disconnected" }),
        );
    }
    Ok(())
}

/// Decode kunci PEM private yang disimpan plaintext (hasil dekripsi E2E).
#[allow(dead_code)]
pub fn validate_key(pem: &str, passphrase: Option<&str>) -> Result<(), String> {
    russh::keys::decode_secret_key(pem, passphrase)
        .map(|_| ())
        .map_err(|e| format!("Private key tidak valid: {}", e))
}
