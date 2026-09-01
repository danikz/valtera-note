// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    std::panic::set_hook(Box::new(|info| {
        let msg = format!("Valtera Note Panic:\n{:?}", info);
        eprintln!("{}", msg);
        let log_dir = dirs::config_dir()
            .or_else(|| dirs::data_local_dir())
            .unwrap_or_else(|| std::env::temp_dir())
            .join("valtera-note");
        let _ = std::fs::create_dir_all(&log_dir);
        let _ = std::fs::write(log_dir.join("crash.log"), &msg);
    }));

    valtera_note_lib::run();
}
