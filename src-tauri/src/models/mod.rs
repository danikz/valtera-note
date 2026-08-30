use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FilePayloadDto {
    pub file_path: Option<String>,
    pub file_name: String,
    pub file_extension: String,
    pub content: String,
    pub encoding: String,
    pub line_ending: String,
    pub file_size: u64,
    pub is_readonly: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileSaveResultDto {
    pub success: bool,
    pub file_path: String,
    pub file_hash: String,
    pub saved_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TabStateDto {
    pub id: Option<i64>,
    pub document_id: Option<i64>,
    pub file_path: Option<String>,
    pub title: String,
    pub file_extension: String,
    pub content: String,
    pub is_active: bool,
    pub is_dirty: bool,
    pub is_scratchpad: bool,
    pub cursor_line: usize,
    pub cursor_col: usize,
    pub split_mode: String, // "none", "editor-only", "preview-only", "split-horizontal"
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionStateDto {
    pub tabs: Vec<TabStateDto>,
    pub active_tab_index: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SnippetDto {
    pub id: Option<i64>,
    pub supabase_id: Option<String>,
    pub title: String,
    pub language: String,
    pub category: String,
    pub content: String,
    pub tags: Option<String>,
    pub is_favorite: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SqlResultDto {
    pub success: bool,
    pub columns: Vec<String>,
    pub rows: Vec<Vec<serde_json::Value>>,
    pub affected_rows: usize,
    pub duration_ms: u64,
    pub error_message: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SupabaseConfigDto {
    pub url: String,
    pub anon_key: String,
    pub is_configured: bool,
    pub user_email: Option<String>,
    pub access_token: Option<String>,
}
