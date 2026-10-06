pub mod commands;
pub mod crypto;
pub mod db;
pub mod models;
pub mod services;
pub mod supabase;

use std::sync::Arc;
use tauri::{Emitter, Manager};
use crate::db::DatabaseManager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let db = match DatabaseManager::init() {
        Ok(d) => Arc::new(d),
        Err(e) => {
            eprintln!("Warning: Failed to initialize database: {}, using fallback", e);
            Arc::new(DatabaseManager::init_fallback())
        }
    };

    let keys = crypto::keystore::KeyManager::new();
    // Auto-unlock: ambil kunci dari OS keyring, verifikasi terhadap verifier di DB
    if let Ok(key) = crypto::keystore::KeyManager::load_from_keyring() {
        let verifier_ok = db
            .get_setting(crypto::SETTING_VERIFIER)
            .ok()
            .flatten()
            .and_then(|v| crypto::decrypt(&key, &v).ok())
            .map(|p| p == crypto::VERIFIER_PLAINTEXT)
            .unwrap_or(false);
        if verifier_ok {
            keys.set_key(key);
        }
    }

    tauri::Builder::default()
        .plugin(tauri_plugin_single_instance::init(|app, args, _cwd| {
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.show();
                let _ = window.unminimize();
                let _ = window.set_focus();

                for arg in args.iter().skip(1) {
                    if !arg.starts_with('-') && std::path::Path::new(arg).exists() {
                        let _ = app.emit("open-file-path", arg.clone());
                    }
                }
            }
        }))
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_window_state::Builder::default().build())
        .plugin(tauri_plugin_clipboard_manager::init())
        .setup(|app| {
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.set_decorations(false);
                let _ = window.set_shadow(true);
            }
            Ok(())
        })
        .manage(db)
        .manage(keys)
        .invoke_handler(tauri::generate_handler![
            // File operations
            commands::fs::read_file_content,
            commands::fs::write_file_content,
            commands::fs::get_cli_open_file,
            commands::fs::register_windows_context_menu,
            // Database & session operations
            commands::db::save_tabs_state,
            commands::db::load_session,
            commands::db::get_app_setting,
            commands::db::set_app_setting,
            commands::db::list_snippets,
            // E2E encryption
            commands::crypto::e2e_status,
            commands::crypto::has_master_password,
            commands::crypto::set_master_password,
            commands::crypto::unlock,
            commands::crypto::lock,
            commands::crypto::is_unlocked,
            commands::crypto::change_password,
            commands::crypto::encrypt_content,
            commands::crypto::decrypt_content,
            commands::crypto::forget_device,
            // SQL runner operations
            commands::sql::execute_sqlite_query,
            commands::sql::format_sql_query,
            commands::sql::inspect_sqlite_tables,
            commands::sql::get_internal_db_path,
            // Supabase operations
            commands::supabase::get_supabase_config,
            commands::supabase::save_supabase_config,
            commands::supabase::supabase_logout,
            commands::ai::ai_get_config,
            commands::ai::ai_save_config,
            commands::ai::ai_complete,
            commands::ai::ai_test_connection,
            commands::ai::ai_list_models,
            commands::supabase::test_supabase_connection,
            commands::supabase::check_supabase_table,
            commands::supabase::auto_create_supabase_table,
            commands::supabase::supabase_register,
            commands::supabase::supabase_login,
            commands::supabase::fetch_remote_notes,
            commands::supabase::upsert_remote_note,
            commands::supabase::delete_remote_note,
        ])
        .run(tauri::generate_context!())
        .expect("error while running valtera-note application");
}
