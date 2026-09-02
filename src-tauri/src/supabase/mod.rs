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

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RemoteNote {
    pub id: Option<String>,
    pub title: String,
    pub content: String,
    pub file_extension: String,
    #[serde(default)]
    pub folder: Option<String>,
    #[serde(default)]
    pub is_pinned: bool,
    #[serde(default)]
    pub is_deleted: bool,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
}

impl SupabaseClient {
    pub fn new(url: String, anon_key: String) -> Self {
        let client = Client::builder()
            .timeout(Duration::from_secs(12))
            .danger_accept_invalid_certs(true) // For local Docker / self-hosted Supabase instances
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

    pub async fn check_table_exists(&self) -> Result<bool, String> {
        let url = format!("{}/rest/v1/notes?select=id&limit=1", self.url);
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

    pub async fn fetch_notes(&self) -> Result<Vec<RemoteNote>, String> {
        let url = format!("{}/rest/v1/notes?select=*&is_deleted=eq.false&order=updated_at.desc", self.url);
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
        let url = format!("{}/rest/v1/notes?on_conflict=id", self.url);
        let mut req = self.client.post(&url)
            .header("apikey", &self.anon_key)
            .header("Prefer", "resolution=merge-duplicates,return=representation")
            .header("Content-Type", "application/json");

        if let Some(token) = &self.access_token {
            req = req.header("Authorization", format!("Bearer {}", token));
        } else {
            req = req.header("Authorization", format!("Bearer {}", self.anon_key));
        }

        let mut note_val = serde_json::to_value(note)
            .map_err(|e| format!("Serialization error: {}", e))?;
        
        // Remove empty id if null/None so database defaults gen_random_uuid()
        if let Some(obj) = note_val.as_object_mut() {
            if obj.get("id").map_or(true, |v| v.is_null()) {
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

        Ok(note.clone())
    }

    pub async fn delete_note(&self, id: &str) -> Result<(), String> {
        let url = format!("{}/rest/v1/notes?id=eq.{}", self.url, id);
        let mut req = self.client.delete(&url).header("apikey", &self.anon_key);
        if let Some(token) = &self.access_token {
            req = req.header("Authorization", format!("Bearer {}", token));
        } else {
            req = req.header("Authorization", format!("Bearer {}", self.anon_key));
        }

        let res = req.send().await;
        if let Ok(response) = res {
            if response.status().is_success() {
                return Ok(());
            }
        }

        // Fallback: Soft delete by setting is_deleted = true in case hard DELETE RLS policy is restricted
        let patch_url = format!("{}/rest/v1/notes?id=eq.{}", self.url, id);
        let mut patch_req = self.client.patch(&patch_url)
            .header("apikey", &self.anon_key)
            .header("Content-Type", "application/json");
        
        if let Some(token) = &self.access_token {
            patch_req = patch_req.header("Authorization", format!("Bearer {}", token));
        } else {
            patch_req = patch_req.header("Authorization", format!("Bearer {}", self.anon_key));
        }

        let _ = patch_req.json(&serde_json::json!({
            "is_deleted": true,
            "updated_at": chrono_iso_now()
        })).send().await;

        Ok(())
    }
}

fn chrono_iso_now() -> String {
    // Generate ISO 8601 UTC timestamp
    let now = std::time::SystemTime::now();
    let datetime: chrono::DateTime<chrono::Utc> = now.into();
    datetime.to_rfc3339()
}
