use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::time::Duration;

#[derive(Clone)]
pub struct AppwriteClient {
    client: Client,
    endpoint: String,
    project_id: String,
    session_id: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct AppwriteErrorResponse {
    pub message: Option<String>,
    pub code: Option<u16>,
    #[serde(rename = "type")]
    pub error_type: Option<String>,
}

impl AppwriteClient {
    pub fn new(endpoint: String, project_id: String) -> Self {
        let client = Client::builder()
            .timeout(Duration::from_secs(12))
            .danger_accept_invalid_certs(true) // Support self-hosted instances with local/self-signed SSL
            .build()
            .unwrap_or_default();

        Self {
            client,
            endpoint: endpoint.trim_end_matches('/').to_string(),
            project_id: project_id.trim().to_string(),
            session_id: None,
        }
    }

    pub async fn test_connection(&self) -> Result<String, String> {
        let url = format!("{}/locale", self.endpoint);
        let res = self.client.get(&url)
            .header("X-Appwrite-Project", &self.project_id)
            .send()
            .await
            .map_err(|e| format!("Cannot reach Appwrite server at {}: {}", self.endpoint, e))?;

        let status = res.status();
        if status.is_success() {
            Ok("Connection to Appwrite server successful!".to_string())
        } else {
            let err_text = res.text().await.unwrap_or_default();
            if let Ok(err_json) = serde_json::from_str::<AppwriteErrorResponse>(&err_text) {
                if let Some(msg) = err_json.message {
                    return Err(format!("Appwrite Error ({}): {}", status.as_u16(), msg));
                }
            }
            Err(format!("Appwrite responded with HTTP {}: {}", status.as_u16(), err_text))
        }
    }

    pub async fn register_email(&self, email: &str, password: &str, name: &str) -> Result<serde_json::Value, String> {
        let url = format!("{}/account", self.endpoint);
        let body = serde_json::json!({
            "userId": "unique()",
            "email": email.trim(),
            "password": password,
            "name": if name.trim().is_empty() { "Valtera User" } else { name.trim() },
        });

        let res = self.client.post(&url)
            .header("X-Appwrite-Project", &self.project_id)
            .json(&body)
            .send()
            .await
            .map_err(|e| format!("Network request failed: {}", e))?;

        let status = res.status();
        if !status.is_success() {
            let err_text = res.text().await.unwrap_or_default();
            if let Ok(err_json) = serde_json::from_str::<AppwriteErrorResponse>(&err_text) {
                if let Some(msg) = err_json.message {
                    return Err(msg);
                }
            }
            return Err(format!("Registration failed (HTTP {}): {}", status.as_u16(), err_text));
        }

        let json = res.json::<serde_json::Value>().await.map_err(|e| e.to_string())?;
        Ok(json)
    }

    pub async fn login_email(&self, email: &str, password: &str) -> Result<serde_json::Value, String> {
        let url = format!("{}/account/sessions/email", self.endpoint);
        let body = serde_json::json!({
            "email": email.trim(),
            "password": password,
        });

        let res = self.client.post(&url)
            .header("X-Appwrite-Project", &self.project_id)
            .json(&body)
            .send()
            .await
            .map_err(|e| format!("Network request failed: {}", e))?;

        let status = res.status();
        if !status.is_success() {
            let err_text = res.text().await.unwrap_or_default();
            if let Ok(err_json) = serde_json::from_str::<AppwriteErrorResponse>(&err_text) {
                if let Some(msg) = err_json.message {
                    return Err(msg);
                }
            }
            return Err(format!("Login failed (HTTP {}): {}", status.as_u16(), err_text));
        }

        let json = res.json::<serde_json::Value>().await.map_err(|e| e.to_string())?;
        Ok(json)
    }
}
