use crate::models::{FilePayloadDto, FileSaveResultDto};
use crate::services::FsService;
use std::path::Path;

#[tauri::command]
pub async fn read_file_content(path: String) -> Result<FilePayloadDto, String> {
    tokio::task::spawn_blocking(move || FsService::read_file(&path))
        .await
        .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn write_file_content(
    path: String,
    content: String,
    line_ending: Option<String>,
) -> Result<FileSaveResultDto, String> {
    tokio::task::spawn_blocking(move || FsService::write_file(&path, &content, line_ending))
        .await
        .map_err(|e| e.to_string())?
}

#[tauri::command]
pub fn get_cli_open_file() -> Option<String> {
    let args: Vec<String> = std::env::args().collect();
    for arg in args.iter().skip(1) {
        if !arg.starts_with('-') && Path::new(arg).exists() {
            return Some(arg.clone());
        }
    }
    None
}

#[tauri::command]
pub fn register_windows_context_menu() -> Result<String, String> {
    #[cfg(target_os = "windows")]
    {
        use std::os::windows::process::CommandExt;
        let current_exe = std::env::current_exe().map_err(|e| e.to_string())?;
        let exe_path = current_exe.to_str().ok_or("Invalid executable path")?;

        let reg_shell_key = r"HKCU\Software\Classes\*\shell\ValteraNote";
        let reg_cmd_key = r"HKCU\Software\Classes\*\shell\ValteraNote\command";
        let icon_val = format!("\"{}\",0", exe_path);
        let cmd_val = format!("\"{}\" \"%1\"", exe_path);

        const CREATE_NO_WINDOW: u32 = 0x08000000;

        let _ = std::process::Command::new("reg")
            .args(&["add", reg_shell_key, "/ve", "/d", "Open with Valtera Note", "/f"])
            .creation_flags(CREATE_NO_WINDOW)
            .output();

        let _ = std::process::Command::new("reg")
            .args(&["add", reg_shell_key, "/v", "Icon", "/d", &icon_val, "/f"])
            .creation_flags(CREATE_NO_WINDOW)
            .output();

        let output = std::process::Command::new("reg")
            .args(&["add", reg_cmd_key, "/ve", "/d", &cmd_val, "/f"])
            .creation_flags(CREATE_NO_WINDOW)
            .output()
            .map_err(|e| format!("Failed to register context menu: {}", e))?;

        if output.status.success() {
            Ok("Menu 'Open with Valtera Note' berhasil didaftarkan ke Windows!".to_string())
        } else {
            let err = String::from_utf8_lossy(&output.stderr);
            Err(format!("Gagal mendaftarkan registry: {}", err))
        }
    }
    #[cfg(not(target_os = "windows"))]
    {
        Ok("File association ready".to_string())
    }
}
