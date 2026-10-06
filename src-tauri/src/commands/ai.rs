use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tauri::State;

use crate::db::DatabaseManager;

const KEY_KIND: &str = "ai_provider_kind"; // "openai" | "anthropic"
const KEY_BASE_URL: &str = "ai_base_url";
const KEY_API_KEY: &str = "ai_api_key";
const KEY_MODEL: &str = "ai_model";

#[derive(Serialize)]
pub struct AiConfig {
    pub kind: String,
    pub base_url: String,
    pub has_api_key: bool,
    pub model: String,
}

fn read_config(db: &DatabaseManager) -> (String, String, String, String) {
    let kind = db
        .get_setting(KEY_KIND)
        .ok()
        .flatten()
        .unwrap_or_else(|| "openai".to_string());
    let base_url = db.get_setting(KEY_BASE_URL).ok().flatten().unwrap_or_default();
    let api_key = db.get_setting(KEY_API_KEY).ok().flatten().unwrap_or_default();
    let model = db.get_setting(KEY_MODEL).ok().flatten().unwrap_or_default();
    (kind, base_url, api_key, model)
}

#[tauri::command]
pub async fn ai_get_config(db: State<'_, Arc<DatabaseManager>>) -> Result<AiConfig, String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || {
        let (kind, base_url, api_key, model) = read_config(&db);
        Ok(AiConfig {
            kind,
            base_url,
            has_api_key: !api_key.is_empty(),
            model,
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

/// api_key None/berisi spasi = tidak mengubah key tersimpan (mencegah key
/// terhapus tak sengaja saat user hanya mengubah model).
#[tauri::command]
pub async fn ai_save_config(
    kind: String,
    base_url: String,
    api_key: Option<String>,
    model: String,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<(), String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || {
        let kind = if kind == "anthropic" { "anthropic" } else { "openai" };
        db.set_setting(KEY_KIND, kind)?;
        db.set_setting(KEY_BASE_URL, base_url.trim().trim_end_matches('/'))?;
        if let Some(k) = api_key {
            let k = k.trim();
            if !k.is_empty() {
                db.set_setting(KEY_API_KEY, k)?;
            }
        }
        db.set_setting(KEY_MODEL, model.trim())?;
        Ok(())
    })
    .await
    .map_err(|e| e.to_string())?
}

#[derive(Deserialize)]
pub struct AiMessage {
    pub role: String,
    pub content: String,
}

#[derive(Deserialize)]
pub struct AiRequest {
    pub system: String,
    pub user: String,
    #[serde(default)]
    pub max_tokens: Option<u32>,
    /// Riwayat giliran sebelumnya (tanpa pesan user terbaru) untuk chat multi-turn.
    #[serde(default)]
    pub history: Vec<AiMessage>,
}

async fn call_ai(
    kind: &str,
    base_url: &str,
    api_key: &str,
    model: &str,
    system: &str,
    user: &str,
    max_tokens: u32,
    history: &[AiMessage],
) -> Result<String, String> {
    if api_key.trim().is_empty() {
        return Err("API key AI belum diatur (Pengaturan → AI Assistant)".to_string());
    }
    if base_url.trim().is_empty() {
        return Err("Base URL AI belum diatur (Pengaturan → AI Assistant)".to_string());
    }
    if model.trim().is_empty() {
        return Err("Model AI belum diatur (Pengaturan → AI Assistant)".to_string());
    }

    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(120))
        .build()
        .map_err(|e| format!("Gagal membuat HTTP client: {}", e))?;
    let base = base_url.trim().trim_end_matches('/');

    let res = match kind {
        "anthropic" => {
            let url = format!("{}/v1/messages", base);
            let mut msgs: Vec<serde_json::Value> = history
                .iter()
                .map(|m| serde_json::json!({ "role": m.role, "content": m.content }))
                .collect();
            msgs.push(serde_json::json!({ "role": "user", "content": user }));
            let body = serde_json::json!({
                "model": model,
                "max_tokens": max_tokens,
                "system": system,
                "messages": msgs
            });
            client
                .post(&url)
                .header("x-api-key", api_key.trim())
                .header("anthropic-version", "2023-06-01")
                .header("content-type", "application/json")
                .json(&body)
                .send()
                .await
                .map_err(|e| format!("Request gagal: {}", e))?
        }
        _ => {
            // OpenAI-compatible: OpenAI, OpenRouter, Groq, Ollama (/v1), dll.
            let url = format!("{}/chat/completions", base);
            let mut messages = vec![serde_json::json!({ "role": "system", "content": system })];
            for m in history {
                messages.push(serde_json::json!({ "role": m.role, "content": m.content }));
            }
            messages.push(serde_json::json!({ "role": "user", "content": user }));
            let body = serde_json::json!({
                "model": model,
                "messages": messages
            });
            client
                .post(&url)
                .header("Authorization", format!("Bearer {}", api_key.trim()))
                .header("content-type", "application/json")
                .json(&body)
                .send()
                .await
                .map_err(|e| format!("Request gagal: {}", e))?
        }
    };

    let status = res.status();
    let text = res.text().await.unwrap_or_default();
    if !status.is_success() {
        return Err(format!("HTTP {}: {}", status.as_u16(), text));
    }

    let v: serde_json::Value =
        serde_json::from_str(&text).map_err(|e| format!("Respon tidak valid: {} — {}", e, text))?;

    match kind {
        "anthropic" => {
            let out = v["content"]
                .as_array()
                .map(|arr| {
                    arr.iter()
                        .filter_map(|c| c["text"].as_str())
                        .collect::<Vec<&str>>()
                        .join("")
                })
                .unwrap_or_default();
            if out.is_empty() {
                return Err(format!("Respon Anthropic tidak berisi teks: {}", text));
            }
            Ok(out)
        }
        _ => {
            let out = v["choices"][0]["message"]["content"]
                .as_str()
                .unwrap_or_default();
            if out.is_empty() {
                return Err(format!("Respon tidak berisi teks: {}", text));
            }
            Ok(out.to_string())
        }
    }
}

#[tauri::command]
pub async fn ai_complete(
    request: AiRequest,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<String, String> {
    let db = Arc::clone(&db);
    let (kind, base_url, api_key, model) =
        tokio::task::spawn_blocking(move || read_config(&db))
            .await
            .map_err(|e| e.to_string())?;
    let max_tokens = request.max_tokens.unwrap_or(2048);
    call_ai(
        &kind,
        &base_url,
        &api_key,
        &model,
        &request.system,
        &request.user,
        max_tokens,
        &request.history,
    )
    .await
}

#[tauri::command]
pub async fn ai_test_connection(db: State<'_, Arc<DatabaseManager>>) -> Result<String, String> {
    let db = Arc::clone(&db);
    let (kind, base_url, api_key, model) =
        tokio::task::spawn_blocking(move || read_config(&db))
            .await
            .map_err(|e| e.to_string())?;
    call_ai(
        &kind,
        &base_url,
        &api_key,
        &model,
        "You are a connectivity test. Reply with exactly: OK",
        "ping",
        32,
        &[],
    )
    .await
}

/// Ambil daftar model dari provider: OpenAI-compatible pakai GET /models,
/// Anthropic pakai GET /v1/models. Dikembalikan terurut.
#[tauri::command]
pub async fn ai_list_models(db: State<'_, Arc<DatabaseManager>>) -> Result<Vec<String>, String> {
    let db = Arc::clone(&db);
    let (kind, base_url, api_key, _model) =
        tokio::task::spawn_blocking(move || read_config(&db))
            .await
            .map_err(|e| e.to_string())?;

    if api_key.trim().is_empty() {
        return Err("API key AI belum diatur (Pengaturan → AI Assistant)".to_string());
    }
    if base_url.trim().is_empty() {
        return Err("Base URL AI belum diatur (Pengaturan → AI Assistant)".to_string());
    }

    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(30))
        .build()
        .map_err(|e| format!("Gagal membuat HTTP client: {}", e))?;
    let base = base_url.trim().trim_end_matches('/');

    let res = match kind.as_str() {
        "anthropic" => client
            .get(format!("{}/v1/models", base))
            .header("x-api-key", api_key.trim())
            .header("anthropic-version", "2023-06-01")
            .send()
            .await
            .map_err(|e| format!("Request gagal: {}", e))?,
        _ => client
            .get(format!("{}/models", base))
            .header("Authorization", format!("Bearer {}", api_key.trim()))
            .send()
            .await
            .map_err(|e| format!("Request gagal: {}", e))?,
    };

    let status = res.status();
    let text = res.text().await.unwrap_or_default();
    if !status.is_success() {
        return Err(format!("HTTP {}: {}", status.as_u16(), text));
    }

    let v: serde_json::Value =
        serde_json::from_str(&text).map_err(|e| format!("Respon tidak valid: {}", e))?;
    let mut models: Vec<String> = v["data"]
        .as_array()
        .map(|arr| {
            arr.iter()
                .filter_map(|m| m["id"].as_str())
                .map(|s| s.to_string())
                .collect()
        })
        .unwrap_or_default();
    if models.is_empty() {
        return Err(format!("Provider tidak mengembalikan daftar model: {}", text));
    }
    models.sort();
    Ok(models)
}
