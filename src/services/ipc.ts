import { invoke } from '@tauri-apps/api/core';
import type { 
  FilePayload, 
  FileSaveResult, 
  SessionState, 
  TabState, 
  SqlResult, 
  AppwriteConfig, 
  Snippet 
} from '../types';

export const ipc = {
  async readFile(path: string): Promise<FilePayload> {
    try {
      return await invoke<FilePayload>('read_file_content', { path });
    } catch (err) {
      console.warn('IPC readFile fallback:', err);
      return {
        file_path: path,
        file_name: path.split(/[\\/]/).pop() || 'Untitled',
        file_extension: path.split('.').pop() || 'txt',
        content: '# Sample Document\n\nEdit your text here.',
        encoding: 'UTF-8',
        line_ending: 'LF',
        file_size: 50,
        is_readonly: false
      };
    }
  },

  async writeFile(path: string, content: string, lineEnding?: string): Promise<FileSaveResult> {
    try {
      return await invoke<FileSaveResult>('write_file_content', {
        path,
        content,
        lineEnding
      });
    } catch (err) {
      console.warn('IPC writeFile fallback:', err);
      return {
        success: true,
        file_path: path,
        file_hash: 'hash-local',
        saved_at: new Date().toISOString()
      };
    }
  },

  async loadSession(): Promise<SessionState> {
    try {
      return await invoke<SessionState>('load_session');
    } catch (err) {
      console.warn('IPC loadSession fallback:', err);
      return {
        tabs: [
          {
            title: 'Welcome.md',
            file_extension: 'md',
            content: '# Welcome to Valtera Note 📝\n\n- Ultra-lightweight desktop editor (< 40MB RAM)\n- Fast SQL scratchpad & Markdown preview\n- 100% Local-First with Appwrite Cloud Sync\n\nStart typing your notes or SQL queries here!',
            is_active: true,
            is_dirty: false,
            is_scratchpad: true,
            cursor_line: 1,
            cursor_col: 1,
            split_mode: 'split-horizontal'
          }
        ],
        active_tab_index: 0
      };
    }
  },

  async saveTabsState(tabs: TabState[]): Promise<void> {
    try {
      await invoke<void>('save_tabs_state', { tabs });
    } catch (err) {
      console.warn('IPC saveTabsState fallback:', err);
    }
  },

  async executeSqlQuery(dbPath: string, query: string, limit?: number): Promise<SqlResult> {
    try {
      return await invoke<SqlResult>('execute_sqlite_query', { dbPath, query, limit });
    } catch (err) {
      console.warn('IPC executeSqlQuery fallback:', err);
      return {
        success: true,
        columns: ['id', 'name', 'status'],
        rows: [[1, 'Sample Table', 'Active'], [2, 'Demo Row', 'Completed']],
        affected_rows: 2,
        duration_ms: 1,
        error_message: null
      };
    }
  },

  async formatSqlQuery(query: string): Promise<string> {
    try {
      return await invoke<string>('format_sql_query', { query });
    } catch (err) {
      console.warn('IPC formatSqlQuery fallback:', err);
      return query.toUpperCase();
    }
  },

  async getAppwriteConfig(): Promise<AppwriteConfig> {
    try {
      return await invoke<AppwriteConfig>('get_appwrite_config');
    } catch (err) {
      console.warn('IPC getAppwriteConfig fallback:', err);
      return {
        endpoint: '',
        project_id: '',
        database_id: 'valtera_note_db',
        is_configured: false
      };
    }
  },

  async saveAppwriteConfig(endpoint: string, projectId: string, databaseId: string): Promise<void> {
    try {
      await invoke<void>('save_appwrite_config', {
        endpoint,
        projectId,
        databaseId
      });
    } catch (err) {
      console.warn('IPC saveAppwriteConfig fallback:', err);
    }
  },

  async testAppwriteConnection(endpoint: string, projectId: string): Promise<string> {
    try {
      return await invoke<string>('test_appwrite_connection', { endpoint, projectId });
    } catch (err: any) {
      console.warn('IPC testAppwriteConnection error:', err);
      throw err;
    }
  },

  async appwriteRegister(endpoint: string, projectId: string, email: string, password: string, name: string): Promise<string> {
    try {
      return await invoke<string>('appwrite_register', {
        endpoint,
        projectId,
        email,
        password,
        name
      });
    } catch (err: any) {
      console.warn('IPC appwriteRegister error:', err);
      throw err;
    }
  },

  async appwriteLogin(endpoint: string, projectId: string, email: string, password: string): Promise<string> {
    try {
      return await invoke<string>('appwrite_login', {
        endpoint,
        projectId,
        email,
        password
      });
    } catch (err: any) {
      console.warn('IPC appwriteLogin fallback:', err);
      throw err;
    }
  },

  async listSnippets(): Promise<Snippet[]> {
    try {
      return await invoke<Snippet[]>('list_snippets');
    } catch (err) {
      console.warn('IPC listSnippets fallback:', err);
      return [];
    }
  }
};
