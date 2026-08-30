use tauri::State;
use std::sync::Arc;
use crate::supabase::SupabaseClient;
use crate::db::DatabaseManager;
use crate::models::SupabaseConfigDto;

#[tauri::command]
pub async fn get_supabase_config(
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<SupabaseConfigDto, String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || {
        let url = db.get_setting("supabase_url")?.unwrap_or_default();
        let anon_key = db.get_setting("supabase_anon_key")?.unwrap_or_default();
        let user_email = db.get_setting("supabase_user_email")?;
        let access_token = db.get_setting("supabase_access_token")?;

        let is_configured = !url.is_empty() && !anon_key.is_empty();

        Ok(SupabaseConfigDto {
            url,
            anon_key,
            is_configured,
            user_email,
            access_token,
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn save_supabase_config(
    url: String,
    anon_key: String,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<(), String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || {
        db.set_setting("supabase_url", &url)?;
        db.set_setting("supabase_anon_key", &anon_key)?;
        Ok(())
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn test_supabase_connection(
    url: String,
    anon_key: String,
) -> Result<String, String> {
    let client = SupabaseClient::new(url, anon_key);
    client.test_connection().await
}

#[tauri::command]
pub async fn check_supabase_table(
    url: String,
    anon_key: String,
    access_token: Option<String>,
) -> Result<bool, String> {
    let mut client = SupabaseClient::new(url, anon_key);
    if let Some(token) = access_token {
        client.set_access_token(token);
    }
    client.check_table_exists().await
}

#[tauri::command]
pub async fn supabase_register(
    url: String,
    anon_key: String,
    email: String,
    password: String,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<String, String> {
    let client = SupabaseClient::new(url.clone(), anon_key.clone());
    let res = client.register_email(&email, &password).await?;
    
    let token = res.access_token.unwrap_or_default();
    let email_clone = email.clone();
    let db = Arc::clone(&db);

    tokio::task::spawn_blocking(move || {
        db.set_setting("supabase_url", &url)?;
        db.set_setting("supabase_anon_key", &anon_key)?;
        db.set_setting("supabase_user_email", &email_clone)?;
        if !token.is_empty() {
            db.set_setting("supabase_access_token", &token)?;
        }
        Ok::<(), String>(())
    })
    .await
    .map_err(|e| e.to_string())??;

    Ok("Registration successful. Please check email if confirmation is required.".to_string())
}

#[tauri::command]
pub async fn supabase_login(
    url: String,
    anon_key: String,
    email: String,
    password: String,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<String, String> {
    let client = SupabaseClient::new(url.clone(), anon_key.clone());
    let res = client.login_email(&email, &password).await?;
    
    let token = res.access_token.ok_or_else(|| "No access token received".to_string())?;
    let email_clone = email.clone();
    let db = Arc::clone(&db);

    tokio::task::spawn_blocking(move || {
        db.set_setting("supabase_url", &url)?;
        db.set_setting("supabase_anon_key", &anon_key)?;
        db.set_setting("supabase_user_email", &email_clone)?;
        db.set_setting("supabase_access_token", &token)?;
        Ok::<(), String>(())
    })
    .await
    .map_err(|e| e.to_string())??;

    Ok("Login successful".to_string())
}
