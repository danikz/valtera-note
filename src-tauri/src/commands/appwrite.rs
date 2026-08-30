use tauri::State;
use std::sync::Arc;
use crate::appwrite::AppwriteClient;
use crate::db::DatabaseManager;
use crate::models::AppwriteConfigDto;

#[tauri::command]
pub async fn get_appwrite_config(
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<AppwriteConfigDto, String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || {
        let endpoint = db.get_setting("appwrite_endpoint")?.unwrap_or_default();
        let project_id = db.get_setting("appwrite_project_id")?.unwrap_or_default();
        let database_id = db.get_setting("appwrite_database_id")?.unwrap_or_else(|| "valtera_note_db".to_string());
        let user_email = db.get_setting("appwrite_user_email")?;
        let user_name = db.get_setting("appwrite_user_name")?;

        let is_configured = !endpoint.is_empty() && !project_id.is_empty();

        Ok(AppwriteConfigDto {
            endpoint,
            project_id,
            database_id,
            is_configured,
            user_email,
            user_name,
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn save_appwrite_config(
    endpoint: String,
    project_id: String,
    database_id: String,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<(), String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || {
        db.set_setting("appwrite_endpoint", &endpoint)?;
        db.set_setting("appwrite_project_id", &project_id)?;
        db.set_setting("appwrite_database_id", &database_id)?;
        Ok(())
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn test_appwrite_connection(
    endpoint: String,
    project_id: String,
) -> Result<String, String> {
    let client = AppwriteClient::new(endpoint, project_id);
    client.test_connection().await
}

#[tauri::command]
pub async fn appwrite_register(
    endpoint: String,
    project_id: String,
    email: String,
    password: String,
    name: String,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<String, String> {
    let client = AppwriteClient::new(endpoint.clone(), project_id.clone());
    client.register_email(&email, &password, &name).await?;
    
    // Automatically log in after register
    let res = client.login_email(&email, &password).await?;
    let user_id = res.get("userId").and_then(|u| u.as_str()).unwrap_or("").to_string();

    let db = Arc::clone(&db);
    let email_clone = email.clone();
    let name_clone = name.clone();
    tokio::task::spawn_blocking(move || {
        db.set_setting("appwrite_endpoint", &endpoint)?;
        db.set_setting("appwrite_project_id", &project_id)?;
        db.set_setting("appwrite_user_email", &email_clone)?;
        db.set_setting("appwrite_user_name", &name_clone)?;
        db.set_setting("appwrite_user_id", &user_id)?;
        Ok::<(), String>(())
    })
    .await
    .map_err(|e| e.to_string())??;

    Ok("Registration & login successful".to_string())
}

#[tauri::command]
pub async fn appwrite_login(
    endpoint: String,
    project_id: String,
    email: String,
    password: String,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<String, String> {
    let client = AppwriteClient::new(endpoint.clone(), project_id.clone());
    let res = client.login_email(&email, &password).await?;
    
    let user_id = res.get("userId").and_then(|u| u.as_str()).unwrap_or("").to_string();
    
    let db = Arc::clone(&db);
    let email_clone = email.clone();
    tokio::task::spawn_blocking(move || {
        db.set_setting("appwrite_endpoint", &endpoint)?;
        db.set_setting("appwrite_project_id", &project_id)?;
        db.set_setting("appwrite_user_email", &email_clone)?;
        db.set_setting("appwrite_user_id", &user_id)?;
        Ok::<(), String>(())
    })
    .await
    .map_err(|e| e.to_string())??;

    Ok("Login successful".to_string())
}
