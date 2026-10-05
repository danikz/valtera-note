use tauri::State;
use std::sync::Arc;
use crate::supabase::SupabaseClient;
use crate::db::DatabaseManager;
use crate::models::SupabaseConfigDto;

const SETTING_ACCESS_TOKEN: &str = "supabase_access_token";
const SETTING_REFRESH_TOKEN: &str = "supabase_refresh_token";
const SETTING_TOKEN_EXPIRES_AT: &str = "supabase_token_expires_at";

#[tauri::command]
pub async fn get_supabase_config(
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<SupabaseConfigDto, String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || {
        let url = db.get_setting("supabase_url")?.unwrap_or_default();
        let anon_key = db.get_setting("supabase_anon_key")?.unwrap_or_default();
        let user_email = db.get_setting("supabase_user_email")?;
        let access_token = db.get_setting(SETTING_ACCESS_TOKEN)?;

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
        let old_url = db.get_setting("supabase_url")?.unwrap_or_default();
        db.set_setting("supabase_url", &url)?;
        db.set_setting("supabase_anon_key", &anon_key)?;
        // Ganti project = sesi lama tidak berlaku. Token terbitan project lain
        // dijamin 401 di project baru (iss berbeda), dan refresh-nya juga gagal.
        if !old_url.is_empty() && old_url != url {
            db.delete_setting(SETTING_ACCESS_TOKEN)?;
            db.delete_setting(SETTING_REFRESH_TOKEN)?;
            db.delete_setting(SETTING_TOKEN_EXPIRES_AT)?;
            db.delete_setting("supabase_user_email")?;
        }
        Ok(())
    })
    .await
    .map_err(|e| e.to_string())?
}

/// Hapus seluruh sesi auth Supabase (token + identitas email) dari settings DB.
/// Logout yang hanya membersihkan state frontend membuat sync berikutnya tetap
/// memakai token lama dari DB.
#[tauri::command]
pub async fn supabase_logout(db: State<'_, Arc<DatabaseManager>>) -> Result<(), String> {
    let db = Arc::clone(&db);
    tokio::task::spawn_blocking(move || {
        db.delete_setting(SETTING_ACCESS_TOKEN)?;
        db.delete_setting(SETTING_REFRESH_TOKEN)?;
        db.delete_setting(SETTING_TOKEN_EXPIRES_AT)?;
        db.delete_setting("supabase_user_email")?;
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
pub async fn auto_create_supabase_table(
    url: String,
    anon_key: String,
    token: String,
) -> Result<String, String> {
    let client = SupabaseClient::new(url.clone(), anon_key);

    // Extract project ref from URL (e.g. https://xyz.supabase.co -> xyz)
    let project_ref = if let Ok(parsed) = reqwest::Url::parse(&url) {
        parsed.host_str().unwrap_or("").split('.').next().unwrap_or("").to_string()
    } else {
        url.trim_start_matches("https://").trim_start_matches("http://").split('.').next().unwrap_or("").to_string()
    };

    if project_ref.is_empty() {
        return Err("URL Supabase tidak valid".to_string());
    }

    let sql = "
        create table if not exists public.notes (
            id uuid default gen_random_uuid() primary key,
            user_id uuid default auth.uid(),
            title text not null default 'Untitled',
            content text not null default '',
            file_extension text not null default 'md',
            folder text,
            is_pinned boolean not null default false,
            is_deleted boolean not null default false,
            created_at timestamp with time zone default timezone('utc'::text, now()) not null,
            updated_at timestamp with time zone default timezone('utc'::text, now()) not null
        );

        alter table public.notes add column if not exists folder text;
        alter table public.notes add column if not exists user_id uuid default auth.uid();

        create index if not exists idx_notes_updated_at on public.notes(updated_at desc);

        alter table public.notes enable row level security;

        revoke all on public.notes from anon;

        drop policy if exists \"Allow API access\" on public.notes;
        drop policy if exists \"Allow all for anon and authenticated\" on public.notes;
        drop policy if exists \"Enable read access for all users\" on public.notes;
        drop policy if exists \"Owner full access\" on public.notes;

        create policy \"Owner full access\"
        on public.notes
        for all
        to authenticated
        using (auth.uid() = user_id or user_id is null)
        with check (auth.uid() = user_id or user_id is null);
    ";

    client.execute_sql_management(&project_ref, &token, sql).await
}

fn unix_now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

fn is_auth_error(err: &str) -> bool {
    err.contains("HTTP 401") || err.contains("JWT expired") || err.contains("JWS signature")
}

/// Simpan sesi auth (access/refresh/expiry) ke settings DB.
fn persist_auth_session(
    db: &DatabaseManager,
    access_token: &str,
    refresh_token: Option<&str>,
    expires_in: u64,
) -> Result<(), String> {
    db.set_setting(SETTING_ACCESS_TOKEN, access_token)?;
    if let Some(r) = refresh_token {
        let r = r.trim();
        if !r.is_empty() {
            db.set_setting(SETTING_REFRESH_TOKEN, r)?;
        }
    }
    db.set_setting(
        SETTING_TOKEN_EXPIRES_AT,
        &(unix_now() + expires_in as i64).to_string(),
    )?;
    Ok(())
}

/// Perbarui access token memakai refresh_token tersimpan, lalu simpan sesi baru.
pub async fn refresh_stored_token(db: &DatabaseManager) -> Result<String, String> {
    let url = db.get_setting("supabase_url")?.unwrap_or_default();
    let anon_key = db.get_setting("supabase_anon_key")?.unwrap_or_default();
    let refresh = db.get_setting(SETTING_REFRESH_TOKEN)?.unwrap_or_default();
    if url.is_empty() || anon_key.is_empty() || refresh.is_empty() {
        return Err("Tidak ada sesi login Supabase tersimpan".to_string());
    }

    let client = SupabaseClient::new(url, anon_key);
    let res = client.refresh_token(&refresh).await?;
    let token = res
        .access_token
        .ok_or_else(|| "Refresh response tidak memuat access_token".to_string())?;
    let expires_in = res.expires_in.unwrap_or(3600);
    let new_refresh = res.refresh_token.unwrap_or(refresh);
    persist_auth_session(db, &token, Some(&new_refresh), expires_in)?;
    Ok(token)
}

/// Token efektif untuk request sync: token dari DB, di-refresh proaktif bila
/// mendekati kadaluarsa. None bila user belum pernah login (fallback anon key).
pub async fn effective_access_token(db: Arc<DatabaseManager>) -> Option<String> {
    let db_read = Arc::clone(&db);
    let (token, refresh, expires_at) = tokio::task::spawn_blocking(move || {
        let token = db_read
            .get_setting(SETTING_ACCESS_TOKEN)
            .ok()
            .flatten()
            .filter(|s| !s.is_empty());
        let refresh = db_read
            .get_setting(SETTING_REFRESH_TOKEN)
            .ok()
            .flatten()
            .filter(|s| !s.is_empty());
        let expires_at = db_read
            .get_setting(SETTING_TOKEN_EXPIRES_AT)
            .ok()
            .flatten()
            .and_then(|s| s.parse::<i64>().ok());
        (token, refresh, expires_at)
    })
    .await
    .ok()?;

    if refresh.is_none() {
        return token;
    }

    // Tanpa expires_at (login versi lama) token dipakai apa adanya;
    // retry 401 pada command sync yang menyelamatkan.
    let needs_refresh = expires_at.map_or(false, |t| unix_now() >= t - 120);
    if !needs_refresh {
        return token;
    }

    refresh_stored_token(&db).await.ok().or(token)
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

    let token = res.access_token.clone().unwrap_or_default();
    let refresh_token = res.refresh_token.clone();
    let expires_in = res.expires_in.unwrap_or(3600);
    let email_clone = email.clone();
    let db = Arc::clone(&db);

    tokio::task::spawn_blocking(move || {
        db.set_setting("supabase_url", &url)?;
        db.set_setting("supabase_anon_key", &anon_key)?;
        db.set_setting("supabase_user_email", &email_clone)?;
        if !token.is_empty() {
            persist_auth_session(&db, &token, refresh_token.as_deref(), expires_in)?;
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
    let refresh_token = res.refresh_token;
    let expires_in = res.expires_in.unwrap_or(3600);
    let email_clone = email.clone();
    let db = Arc::clone(&db);

    tokio::task::spawn_blocking(move || {
        db.set_setting("supabase_url", &url)?;
        db.set_setting("supabase_anon_key", &anon_key)?;
        db.set_setting("supabase_user_email", &email_clone)?;
        persist_auth_session(&db, &token, refresh_token.as_deref(), expires_in)?;
        Ok::<(), String>(())
    })
    .await
    .map_err(|e| e.to_string())??;

    Ok("Login successful".to_string())
}

#[tauri::command]
pub async fn fetch_remote_notes(
    url: String,
    anon_key: String,
    access_token: Option<String>,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<Vec<crate::supabase::RemoteNote>, String> {
    let mut client = SupabaseClient::new(url, anon_key);
    let token = effective_access_token(Arc::clone(&db))
        .await
        .or(access_token)
        .filter(|s| !s.is_empty());
    if let Some(token) = token {
        client.set_access_token(token);
    }

    match client.fetch_notes().await {
        Ok(notes) => Ok(notes),
        Err(e) if is_auth_error(&e) => match refresh_stored_token(&db).await {
            Ok(token) => {
                client.set_access_token(token);
                client.fetch_notes().await
            }
            Err(_) => Err(e),
        },
        Err(e) => Err(e),
    }
}

#[tauri::command]
pub async fn upsert_remote_note(
    url: String,
    anon_key: String,
    note: crate::supabase::RemoteNote,
    access_token: Option<String>,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<crate::supabase::RemoteNote, String> {
    let mut client = SupabaseClient::new(url, anon_key);
    let token = effective_access_token(Arc::clone(&db))
        .await
        .or(access_token)
        .filter(|s| !s.is_empty());
    if let Some(token) = token {
        client.set_access_token(token);
    }

    match client.upsert_note(&note).await {
        Ok(saved) => Ok(saved),
        Err(e) if is_auth_error(&e) => match refresh_stored_token(&db).await {
            Ok(token) => {
                client.set_access_token(token);
                client.upsert_note(&note).await
            }
            Err(_) => Err(e),
        },
        Err(e) => Err(e),
    }
}

#[tauri::command]
pub async fn delete_remote_note(
    url: String,
    anon_key: String,
    id: String,
    access_token: Option<String>,
    db: State<'_, Arc<DatabaseManager>>,
) -> Result<(), String> {
    let mut client = SupabaseClient::new(url, anon_key);
    let token = effective_access_token(Arc::clone(&db))
        .await
        .or(access_token)
        .filter(|s| !s.is_empty());
    if let Some(token) = token {
        client.set_access_token(token);
    }

    match client.delete_note(&id).await {
        Ok(()) => Ok(()),
        Err(e) if is_auth_error(&e) => match refresh_stored_token(&db).await {
            Ok(token) => {
                client.set_access_token(token);
                client.delete_note(&id).await
            }
            Err(_) => Err(e),
        },
        Err(e) => Err(e),
    }
}
