pub mod commands;
pub mod crypto;
pub mod ssh;
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
    let quick_pin_on = db
        .get_setting(commands::crypto::SETTING_QUICK_PIN)
        .map(|v| v.as_deref() == Some("1"))
        .unwrap_or(true); // fail-closed: DB error -> jangan auto-unlock
    if quick_pin_on {
        // Quick PIN aktif = PIN adalah pintunya. Raw key sisa versi lama
        // (sebelum guard "ingat device") akan melewati PIN — hapus.
        if let Err(e) = crypto::keystore::KeyManager::delete_from_keyring() {
            eprintln!("Warning: gagal menghapus raw key keyring: {}", e);
        }
    } else if let Ok(key) = crypto::keystore::KeyManager::load_from_keyring() {
        // Auto-unlock: ambil kunci dari OS keyring, verifikasi terhadap verifier di DB
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
            // Sisa kredensial RDP sementara dari sesi sebelumnya (app ditutup/crash
            // sebelum timer pembersih jalan).
            let db = Arc::clone(app.state::<Arc<DatabaseManager>>().inner());
            std::thread::spawn(move || commands::rdp::cleanup_pending_credentials(&db));
            // Pastikan salt/verifier E2E ada di user_metadata Supabase (pengguna lama
            // yang sudah login sebelum fitur ini) agar aplikasi mobile bisa unlock.
            commands::supabase::publish_e2e_config_background(Arc::clone(
                app.state::<Arc<DatabaseManager>>().inner(),
            ));
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.set_decorations(false);
                let _ = window.set_shadow(true);
            }
            Ok(())
        })
        .manage(db)
        .manage(crate::ssh::SshManager::default())
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
            commands::ssh::ssh_conn_list,
            commands::ssh::ssh_conn_save,
            commands::ssh::ssh_conn_delete,
            commands::ssh::ssh_connect,
            commands::ssh::ssh_write,
            commands::ssh::ssh_replay,
            commands::ssh::ssh_resize,
            commands::ssh::ssh_disconnect,
            commands::ssh::ssh_active_sessions,
            commands::rdp::rdp_test,
            commands::rdp::rdp_launch,
            commands::supabase::test_supabase_connection,
            commands::supabase::check_supabase_table,
            commands::supabase::auto_create_supabase_table,
            commands::supabase::supabase_register,
            commands::supabase::supabase_login,
            commands::supabase::fetch_remote_notes,
            commands::supabase::upsert_remote_note,
            commands::supabase::delete_remote_note,
            commands::supabase::fetch_remote_ssh_connections,
            commands::supabase::upsert_remote_ssh_connection,
            commands::supabase::delete_remote_ssh_connection,
            commands::crypto::quick_pin_status,
            commands::crypto::setup_quick_pin,
            commands::crypto::unlock_with_pin,
            commands::crypto::disable_quick_pin,
        ])
        .build(tauri::generate_context!())
        .expect("error while building valtera-note application")
        .run(|app, event| {
            if let tauri::RunEvent::Exit = event {
                let db = app.state::<Arc<DatabaseManager>>();
                commands::rdp::cleanup_pending_credentials(db.inner());
            }
        });
}
