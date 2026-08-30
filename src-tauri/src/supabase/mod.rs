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

#[derive(Debug, Serialize, Deserialize)]
pub struct RemoteNote {
    pub id: Option<String>,
    pub title: String,
    pub content: String,
    pub file_extension: String,
    pub is_pinned: bool,
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
        let url = format!("{}/rest/v1/", self.url);
        let res = self.client.get(&url)
            .header("apikey", &self.anon_key)
            .header("Authorization", format!("Bearer {}", self.anon_key))
            .send()
            .await
            .map_err(|e| format!("Cannot reach Supabase server at {}: {}", self.url, e))?;

        let status = res.status();
        if status.is_success() {
            Ok("Connection to Supabase REST API successful!".to_string())
        } else {
            let err_text = res.text().await.unwrap_or_default();
            Err(format!("Supabase error (HTTP {}): {}", status.as_u16(), err_text))
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
}
