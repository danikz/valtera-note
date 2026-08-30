use tauri::State;
use std::sync::Arc;
use crate::db::DatabaseManager;
use crate::models::{SessionStateDto, SnippetDto, TabStateDto};

#[tauri::command]
pub async fn save_tabs_state(
    tabs: Vec<TabStateDto>,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<(), String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || db.save_session_tabs(&tabs))
        .await
        .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn load_session(
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<SessionStateDto, String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || db.load_session_tabs())
        .await
        .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn get_app_setting(
    key: String,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<Option<String>, String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || db.get_setting(&key))
        .await
        .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn set_app_setting(
    key: String,
    value: String,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<(), String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || db.set_setting(&key, &value))
        .await
        .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn list_snippets(
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<Vec<SnippetDto>, String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || db.list_snippets())
        .await
        .map_err(|e| e.to_string())?
}
