pub mod appwrite;
pub mod commands;
pub mod db;
pub mod models;
pub mod services;

use std::sync::Arc;
use crate::db::DatabaseManager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let db = match DatabaseManager::init() {
        Ok(d) => Arc::new(d),
        Err(e) => {
            eprintln!("Failed to initialize database: {}", e);
            panic!("Database init failed: {}", e);
        }
    };

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .manage(db)
        .invoke_handler(tauri::generate_handler![
            // File operations
            commands::fs::read_file_content,
            commands::fs::write_file_content,
            // Database & session operations
            commands::db::save_tabs_state,
            commands::db::load_session,
            commands::db::get_app_setting,
            commands::db::set_app_setting,
            commands::db::list_snippets,
            // SQL runner operations
            commands::sql::execute_sqlite_query,
            commands::sql::format_sql_query,
            // Appwrite operations
            commands::appwrite::get_appwrite_config,
            commands::appwrite::save_appwrite_config,
            commands::appwrite::test_appwrite_connection,
            commands::appwrite::appwrite_register,
            commands::appwrite::appwrite_login,
        ])
        .run(tauri::generate_context!())
        .expect("error while running valtera-note application");
}
