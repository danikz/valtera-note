use crate::models::{FilePayloadDto, FileSaveResultDto};
use crate::services::FsService;

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
