pub mod commands;
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
        .manage(db)
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
            // SQL runner operations
            commands::sql::execute_sqlite_query,
            commands::sql::format_sql_query,
            // Supabase operations
            commands::supabase::get_supabase_config,
            commands::supabase::save_supabase_config,
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
