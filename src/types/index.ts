export interface FilePayload {
  file_path: string | null;
  file_name: string;
  file_extension: string;
  content: string;
  encoding: string;
  line_ending: string;
  file_size: number;
  is_readonly: boolean;
}

export interface FileSaveResult {
  success: boolean;
  file_path: string;
  file_hash: string;
  saved_at: string;
}

export type SplitMode = 'none' | 'editor-only' | 'preview-only' | 'split-horizontal';

export interface TabState {
  id?: number;
  document_id?: number;
  file_path?: string | null;
  title: string;
  file_extension: string;
  content: string;
  is_active: boolean;
  is_dirty: boolean;
  is_scratchpad: boolean;
  cursor_line: number;
  cursor_col: number;
  split_mode: SplitMode;
}

export interface SessionState {
  tabs: TabState[];
  active_tab_index: number;
}

export interface Snippet {
  id?: number;
  appwrite_id?: string;
  title: string;
  language: string;
  category: string;
  content: string;
  tags?: string;
  is_favorite: boolean;
}

export interface SqlResult {
  success: boolean;
  columns: string[];
  rows: any[][];
  affected_rows: number;
  duration_ms: number;
  error_message?: string | null;
}

export interface AppwriteConfig {
  endpoint: string;
  project_id: string;
  database_id: string;
  is_configured: boolean;
  user_email?: string | null;
  user_name?: string | null;
}
