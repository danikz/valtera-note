use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::time::Duration;

#[derive(Clone)]
pub struct SupabaseClient {
    client: Client,
    url: String,
    anon_key: String,
    access_token: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SupabaseAuthResponse {
    pub access_token: Option<String>,
    pub token_type: Option<String>,
    pub expires_in: Option<u64>,
    pub refresh_token: Option<String>,
    pub user: Option<SupabaseUser>,
    pub msg: Option<String>,
    pub error_description: Option<String>,
    pub message: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SupabaseUser {
    pub id: String,
    pub email: Option<String>,
}

fn default_untitled() -> String {
    "Untitled".to_string()
}

fn default_ext() -> String {
    "txt".to_string()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RemoteNote {
    #[serde(default)]
    pub id: Option<String>,
    #[serde(default = "default_untitled")]
    pub title: String,
    #[serde(default)]
    pub content: String,
    #[serde(default = "default_ext")]
    pub file_extension: String,
    #[serde(default)]
    pub folder: Option<String>,
    /// None = jangan kirim kolom ini saat upsert (desktop tidak punya konsep pin),
    /// sehingga pin yang diatur di aplikasi mobile tidak tertimpa `false`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub is_pinned: Option<bool>,
    #[serde(default)]
    pub is_deleted: bool,
    #[serde(default)]
    pub created_at: Option<String>,
    #[serde(default)]
    pub updated_at: Option<String>,
}

/// Satu baris tabel `ssh_connections` di cloud. `payload` selalu ciphertext
/// E2E — server tidak pernah melihat kredensial plaintext.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RemoteSshConnection {
    #[serde(default)]
    pub id: Option<String>,
    #[serde(default)]
    pub label: String,
    #[serde(default)]
    pub payload: String,
    #[serde(default)]
    pub is_deleted: bool,
    #[serde(default)]
    pub created_at: Option<String>,
    #[serde(default)]
    pub updated_at: Option<String>,
}

/// true bila URL mengarah ke mesin lokal (localhost / 127.x / ::1 / *.localhost).
fn is_loopback_url(url: &str) -> bool {
    let Ok(parsed) = reqwest::Url::parse(url.trim()) else {
        return false;
    };
    let Some(host) = parsed.host_str() else {
        return false;
    };
    let host = host.trim_start_matches('[').trim_end_matches(']').to_ascii_lowercase();
    if let Ok(ip) = host.parse::<std::net::IpAddr>() {
        return ip.is_loopback();
    }
    host == "localhost" || host.ends_with(".localhost")
}

impl SupabaseClient {
    pub fn new(url: String, anon_key: String) -> Self {
        let client = Client::builder()
            .timeout(Duration::from_secs(12))
            // Sertifikat self-signed hanya ditoleransi untuk instance lokal
            // (Docker di mesin sendiri). Host lain WAJIB TLS valid — tanpa ini
            // token login & data bisa disadap lewat MITM.
            .danger_accept_invalid_certs(is_loopback_url(&url))
            .build()
            .unwrap_or_default();

        Self {
            client,
            url: url.trim_end_matches('/').to_string(),
            anon_key: anon_key.trim().to_string(),
            access_token: None,
        }
    }

    pub fn set_access_token(&mut self, token: String) {
        self.access_token = Some(token);
    }

    pub async fn test_connection(&self) -> Result<String, String> {
        // 1. Try Supabase Auth Health endpoint first (always permits anon key)
        let health_url = format!("{}/auth/v1/health", self.url);
        if let Ok(res) = self.client.get(&health_url).header("apikey", &self.anon_key).send().await {
            if res.status().is_success() {
                return Ok("Koneksi ke Supabase API berhasil terhubung!".to_string());
            }
        }

        // 2. Query /rest/v1/notes to verify REST API & anon key
        let url = format!("{}/rest/v1/notes?select=id&limit=1", self.url);
        let res = self.client.get(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", self.anon_key))
            .send()
            .await
            .map_err(|e| format!("Tidak dapat menghubungi server Supabase di {}: {}", self.url, e))?;

        let status = res.status();
        if status.is_success() {
            Ok("Koneksi ke Supabase REST API berhasil!".to_string())
        } else {
            let err_text = res.text().await.unwrap_or_default();
            if err_text.contains("42P01") || err_text.contains("does not exist") || err_text.contains("PGRST204") || err_text.contains("PGRST205") {
                Ok("Koneksi ke Supabase berhasil! (Tabel 'notes' belum dibuat, silakan jalankan SQL migration)".to_string())
            } else {
                Err(format!("Supabase error (HTTP {}): {}", status.as_u16(), err_text))
            }
        }
    }

    /// "Ready" berarti skema lengkap: tabel notes DAN ssh_connections.
    /// Kalau notes ada tapi ssh_connections belum, user perlu jalankan
    /// auto-create lagi (SQL-nya idempotent).
    pub async fn check_table_exists(&self) -> Result<bool, String> {
        let notes_ok = self.table_probe("notes").await?;
        let ssh_ok = self.table_probe("ssh_connections").await?;
        Ok(notes_ok && ssh_ok)
    }

    async fn table_probe(&self, table: &str) -> Result<bool, String> {
        let url = format!("{}/rest/v1/{}?select=id&limit=1", self.url, table);
        let mut req = self.client.get(&url)
            .header("apikey", &self.anon_key);

        if let Some(token) = &self.access_token {
            req = req.header("Authorization", format!("Bearer {}", token));
        } else {
            req = req.header("Authorization", format!("Bearer {}", self.anon_key));
        }

        let res = req.send().await.map_err(|e| format!("Request failed: {}", e))?;
        let status = res.status();

        if status.is_success() {
            Ok(true)
        } else {
            let text = res.text().await.unwrap_or_default();
            if text.contains("42P01") || text.contains("does not exist") || text.contains("PGRST204") || text.contains("PGRST205") {
                Ok(false)
            } else if status.as_u16() == 401 || status.as_u16() == 403 {
                // RLS protected table exists
                Ok(true)
            } else {
                Ok(false)
            }
        }
    }

    pub async fn execute_sql_management(&self, project_ref: &str, token: &str, sql: &str) -> Result<String, String> {
        let endpoint = format!("https://api.supabase.com/v1/projects/{}/database/query", project_ref);
        let body = serde_json::json!({
            "query": sql
        });

        let res = self.client.post(&endpoint)
            .header("Authorization", format!("Bearer {}", token.trim()))
            .header("Content-Type", "application/json")
            .json(&body)
            .send()
            .await
            .map_err(|e| format!("Gagal memanggil Supabase Management API: {}", e))?;

        let status = res.status();
        let text = res.text().await.unwrap_or_default();

        if status.is_success() {
            Ok("Tabel 'notes' dan RLS policy berhasil dibuat secara otomatis!".to_string())
        } else {
            Err(format!("Supabase API error (HTTP {}): {}", status.as_u16(), text))
        }
    }

    pub async fn register_email(&self, email: &str, password: &str) -> Result<SupabaseAuthResponse, String> {
        let url = format!("{}/auth/v1/signup", self.url);
        let body = serde_json::json!({
            "email": email.trim(),
            "password": password,
        });

        let res = self.client.post(&url)
            .header("apikey", &self.anon_key)
            .header("Content-Type", "application/json")
            .json(&body)
            .send()
            .await
            .map_err(|e| format!("Network request failed: {}", e))?;

        let status = res.status();
        let text = res.text().await.unwrap_or_default();

        if !status.is_success() {
            if let Ok(err_json) = serde_json::from_str::<SupabaseAuthResponse>(&text) {
                if let Some(msg) = err_json.error_description.or(err_json.msg).or(err_json.message) {
                    return Err(msg);
                }
            }
            return Err(format!("Registration failed (HTTP {}): {}", status.as_u16(), text));
        }

        let auth_res: SupabaseAuthResponse = serde_json::from_str(&text)
            .map_err(|e| format!("Failed to parse response: {}", e))?;
        Ok(auth_res)
    }

    pub async fn login_email(&self, email: &str, password: &str) -> Result<SupabaseAuthResponse, String> {
        let url = format!("{}/auth/v1/token?grant_type=password", self.url);
        let body = serde_json::json!({
            "email": email.trim(),
            "password": password,
        });

        let res = self.client.post(&url)
            .header("apikey", &self.anon_key)
            .header("Content-Type", "application/json")
            .json(&body)
            .send()
            .await
            .map_err(|e| format!("Network request failed: {}", e))?;

        let status = res.status();
        let text = res.text().await.unwrap_or_default();

        if !status.is_success() {
            if let Ok(err_json) = serde_json::from_str::<SupabaseAuthResponse>(&text) {
                if let Some(msg) = err_json.error_description.or(err_json.msg).or(err_json.message) {
                    return Err(msg);
                }
            }
            return Err(format!("Login failed (HTTP {}): {}", status.as_u16(), text));
        }

        let auth_res: SupabaseAuthResponse = serde_json::from_str(&text)
            .map_err(|e| format!("Failed to parse auth token: {}", e))?;
        Ok(auth_res)
    }

    /// Gabungkan `data` ke `user_metadata` user yang sedang login (PUT /auth/v1/user).
    pub async fn update_user_metadata(&self, data: serde_json::Value) -> Result<(), String> {
        let token = self
            .access_token
            .as_deref()
            .ok_or_else(|| "Belum login Supabase".to_string())?;
        let url = format!("{}/auth/v1/user", self.url);
        let res = self.client.put(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", token))
            .header("Content-Type", "application/json")
            .json(&serde_json::json!({ "data": data }))
            .send()
            .await
            .map_err(|e| format!("Network request failed: {}", e))?;

        let status = res.status();
        if status.is_success() {
            return Ok(());
        }
        let text = res.text().await.unwrap_or_default();
        Err(format!("Update user metadata failed (HTTP {}): {}", status.as_u16(), text))
    }

    pub async fn refresh_token(&self, refresh_token: &str) -> Result<SupabaseAuthResponse, String> {
        let url = format!("{}/auth/v1/token?grant_type=refresh_token", self.url);
        let body = serde_json::json!({
            "refresh_token": refresh_token.trim(),
        });

        let res = self.client.post(&url)
            .header("apikey", &self.anon_key)
            .header("Content-Type", "application/json")
            .json(&body)
            .send()
            .await
            .map_err(|e| format!("Network request failed: {}", e))?;

        let status = res.status();
        let text = res.text().await.unwrap_or_default();

        if !status.is_success() {
            if let Ok(err_json) = serde_json::from_str::<SupabaseAuthResponse>(&text) {
                if let Some(msg) = err_json.error_description.or(err_json.msg).or(err_json.message) {
                    return Err(msg);
                }
            }
            return Err(format!("Token refresh failed (HTTP {}): {}", status.as_u16(), text));
        }

        serde_json::from_str(&text)
            .map_err(|e| format!("Failed to parse refresh response: {}", e))
    }

    pub async fn fetch_notes(&self) -> Result<Vec<RemoteNote>, String> {
        // Tanpa filter is_deleted: frontend perlu melihat tombstone remote agar
        // note yang sudah dihapus tidak di-push ulang oleh heal logic.
        let url = format!("{}/rest/v1/notes?select=*&order=updated_at.desc", self.url);
        let mut req = self.client.get(&url).header("apikey", &self.anon_key);
        if let Some(token) = &self.access_token {
            req = req.header("Authorization", format!("Bearer {}", token));
        } else {
            req = req.header("Authorization", format!("Bearer {}", self.anon_key));
        }

        let res = req.send().await.map_err(|e| format!("Failed to fetch notes: {}", e))?;
        let status = res.status();
        let text = res.text().await.unwrap_or_default();

        if !status.is_success() {
            return Err(format!("Fetch notes failed (HTTP {}): {}", status.as_u16(), text));
        }

        let notes: Vec<RemoteNote> = serde_json::from_str(&text)
            .map_err(|e| format!("Failed to parse notes list: {} (Response: {})", e, text))?;
        Ok(notes)
    }

    pub async fn upsert_note(&self, note: &RemoteNote) -> Result<RemoteNote, String> {
        let has_id = note.id.as_ref().map_or(false, |s| !s.trim().is_empty());

        let url = if has_id {
            format!("{}/rest/v1/notes?on_conflict=id", self.url)
        } else {
            format!("{}/rest/v1/notes", self.url)
        };

        let mut req = self.client.post(&url)
            .header("apikey", &self.anon_key)
            .header("Content-Type", "application/json");

        if has_id {
            req = req.header("Prefer", "resolution=merge-duplicates,return=representation");
        } else {
            req = req.header("Prefer", "return=representation");
        }

        if let Some(token) = &self.access_token {
            req = req.header("Authorization", format!("Bearer {}", token));
        } else {
            req = req.header("Authorization", format!("Bearer {}", self.anon_key));
        }

        let mut note_val = serde_json::to_value(note)
            .map_err(|e| format!("Serialization error: {}", e))?;
        
        if let Some(obj) = note_val.as_object_mut() {
            if !has_id {
                obj.remove("id");
            }
            if obj.get("created_at").map_or(true, |v| v.is_null()) {
                obj.remove("created_at");
            }
            // Always set updated_at to now on update
            obj.insert("updated_at".to_string(), serde_json::Value::String(chrono_iso_now()));
        }

        let res = req.json(&note_val).send().await.map_err(|e| format!("Failed to upsert note: {}", e))?;
        let status = res.status();
        let text = res.text().await.unwrap_or_default();

        if !status.is_success() {
            return Err(format!("Upsert note failed (HTTP {}): {}", status.as_u16(), text));
        }

        // PostgREST return=representation returns an array of records
        if let Ok(records) = serde_json::from_str::<Vec<RemoteNote>>(&text) {
            if let Some(first) = records.into_iter().next() {
                return Ok(first);
            }
        }

        if let Ok(single) = serde_json::from_str::<RemoteNote>(&text) {
            return Ok(single);
        }

        // Fallback: parse as generic JSON array / object in case schema has minor deviations
        if let Ok(val) = serde_json::from_str::<serde_json::Value>(&text) {
            if let Some(arr) = val.as_array() {
                if let Some(first_obj) = arr.first().and_then(|v| v.as_object()) {
                    let mut updated_note = note.clone();
                    if let Some(id_val) = first_obj.get("id").and_then(|v| v.as_str()) {
                        updated_note.id = Some(id_val.to_string());
                    }
                    if let Some(t_val) = first_obj.get("title").and_then(|v| v.as_str()) {
                        updated_note.title = t_val.to_string();
                    }
                    if let Some(c_val) = first_obj.get("content").and_then(|v| v.as_str()) {
                        updated_note.content = c_val.to_string();
                    }
                    if let Some(ext_val) = first_obj.get("file_extension").and_then(|v| v.as_str()) {
                        updated_note.file_extension = ext_val.to_string();
                    }
                    if let Some(f_val) = first_obj.get("folder").and_then(|v| v.as_str()) {
                        updated_note.folder = Some(f_val.to_string());
                    }
                    return Ok(updated_note);
                }
            } else if let Some(first_obj) = val.as_object() {
                let mut updated_note = note.clone();
                if let Some(id_val) = first_obj.get("id").and_then(|v| v.as_str()) {
                    updated_note.id = Some(id_val.to_string());
                }
                return Ok(updated_note);
            }
        }

        Ok(note.clone())
    }

    /// Fetch semua baris ssh_connections (termasuk tombstone is_deleted agar
    /// penghapusan di perangkat lain tetap terlihat dan bisa di-heal).
    pub async fn fetch_ssh_connections(&self) -> Result<Vec<RemoteSshConnection>, String> {
        let url = format!("{}/rest/v1/ssh_connections?select=*&order=updated_at.desc", self.url);
        let mut req = self.client.get(&url).header("apikey", &self.anon_key);
        if let Some(token) = &self.access_token {
            req = req.header("Authorization", format!("Bearer {}", token));
        } else {
            req = req.header("Authorization", format!("Bearer {}", self.anon_key));
        }

        let res = req.send().await.map_err(|e| format!("Failed to fetch ssh connections: {}", e))?;
        let status = res.status();
        let text = res.text().await.unwrap_or_default();

        if !status.is_success() {
            return Err(format!("Fetch ssh_connections failed (HTTP {}): {}", status.as_u16(), text));
        }

        let rows: Vec<RemoteSshConnection> = serde_json::from_str(&text)
            .map_err(|e| format!("Failed to parse ssh_connections: {} (Response: {})", e, text))?;
        Ok(rows)
    }

    pub async fn upsert_ssh_connection(&self, conn: &RemoteSshConnection) -> Result<RemoteSshConnection, String> {
        let has_id = conn.id.as_ref().map_or(false, |s| !s.trim().is_empty());

        let url = if has_id {
            format!("{}/rest/v1/ssh_connections?on_conflict=id", self.url)
        } else {
            format!("{}/rest/v1/ssh_connections", self.url)
        };

        let mut req = self.client.post(&url)
            .header("apikey", &self.anon_key)
            .header("Content-Type", "application/json");

        if has_id {
            req = req.header("Prefer", "resolution=merge-duplicates,return=representation");
        } else {
            req = req.header("Prefer", "return=representation");
        }

        if let Some(token) = &self.access_token {
            req = req.header("Authorization", format!("Bearer {}", token));
        } else {
            req = req.header("Authorization", format!("Bearer {}", self.anon_key));
        }

        let mut conn_val = serde_json::to_value(conn)
            .map_err(|e| format!("Serialization error: {}", e))?;

        if let Some(obj) = conn_val.as_object_mut() {
            if !has_id {
                obj.remove("id");
            }
            if obj.get("created_at").map_or(true, |v| v.is_null()) {
                obj.remove("created_at");
            }
            obj.insert("updated_at".to_string(), serde_json::Value::String(chrono_iso_now()));
        }

        let res = req.json(&conn_val).send().await.map_err(|e| format!("Failed to upsert ssh connection: {}", e))?;
        let status = res.status();
        let text = res.text().await.unwrap_or_default();

        if !status.is_success() {
            return Err(format!("Upsert ssh_connection failed (HTTP {}): {}", status.as_u16(), text));
        }

        if let Ok(records) = serde_json::from_str::<Vec<RemoteSshConnection>>(&text) {
            if let Some(first) = records.into_iter().next() {
                return Ok(first);
            }
        }
        Ok(conn.clone())
    }

    /// Penghapusan memakai soft delete (tombstone) agar perangkat lain ikut
    /// menghapus salinannya saat pull — hard delete akan membuat salinan
    /// di perangkat lain ter-push ulang (zombie).
    pub async fn delete_ssh_connection(&self, id: &str) -> Result<(), String> {
        let url = format!("{}/rest/v1/ssh_connections?id=eq.{}", self.url, id);
        let mut req = self.client.patch(&url)
            .header("apikey", &self.anon_key)
            .header("Content-Type", "application/json");

        if let Some(token) = &self.access_token {
            req = req.header("Authorization", format!("Bearer {}", token));
        } else {
            req = req.header("Authorization", format!("Bearer {}", self.anon_key));
        }

        let res = req
            .json(&serde_json::json!({
                "is_deleted": true,
                "updated_at": chrono_iso_now()
            }))
            .send()
            .await
            .map_err(|e| format!("Delete ssh_connection failed: {}", e))?;

        let status = res.status();
        if status.is_success() {
            return Ok(());
        }
        let text = res.text().await.unwrap_or_default();
        Err(format!("Delete ssh_connection failed (HTTP {}): {}", status.as_u16(), text))
    }

    /// Soft delete (tombstone), sama seperti ssh_connections & aplikasi mobile:
    /// device lain melihat is_deleted lalu ikut menghapus salinannya. Hard delete
    /// membuat device lain tidak pernah tahu note dihapus (atau meng-upload ulang).
    pub async fn delete_note(&self, id: &str) -> Result<(), String> {
        let url = format!("{}/rest/v1/notes?id=eq.{}", self.url, id);
        let mut req = self.client.patch(&url)
            .header("apikey", &self.anon_key)
            .header("Content-Type", "application/json");

        if let Some(token) = &self.access_token {
            req = req.header("Authorization", format!("Bearer {}", token));
        } else {
            req = req.header("Authorization", format!("Bearer {}", self.anon_key));
        }

        match req.json(&serde_json::json!({
            "is_deleted": true,
            "updated_at": chrono_iso_now()
        })).send().await {
            Ok(response) if response.status().is_success() => Ok(()),
            Ok(response) => {
                let status = response.status().as_u16();
                let text = response.text().await.unwrap_or_default();
                Err(format!("Delete note failed (HTTP {}): {}", status, text))
            }
            Err(e) => Err(format!("Delete note failed: {}", e)),
        }
    }
}

fn chrono_iso_now() -> String {
    // Generate ISO 8601 UTC timestamp
    let now = std::time::SystemTime::now();
    let datetime: chrono::DateTime<chrono::Utc> = now.into();
    datetime.to_rfc3339()
}

#[cfg(test)]
mod tls_tests {
    use super::is_loopback_url;

    #[test]
    fn only_local_hosts_skip_tls_validation() {
        assert!(is_loopback_url("https://localhost:8000"));
        assert!(is_loopback_url("https://127.0.0.1:54321"));
        assert!(is_loopback_url("https://[::1]:8000"));
        assert!(is_loopback_url("https://api.localhost"));
        assert!(!is_loopback_url("https://xyz.supabase.co"));
        assert!(!is_loopback_url("https://localhost.evil.com"));
        assert!(!is_loopback_url("https://192.168.1.10"));
        assert!(!is_loopback_url("bukan url"));
    }
}
