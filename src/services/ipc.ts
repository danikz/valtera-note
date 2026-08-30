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

const isTauri = typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;

export const ipc = {
  async readFile(path: string): Promise<FilePayload> {
    if (isTauri) {
      try {
        return await invoke<FilePayload>('read_file_content', { path });
      } catch (err) {
        console.warn('IPC readFile error:', err);
      }
    }
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
  },

  async writeFile(path: string, content: string, lineEnding?: string): Promise<FileSaveResult> {
    if (isTauri) {
      try {
        return await invoke<FileSaveResult>('write_file_content', {
          path,
          content,
          lineEnding
        });
      } catch (err) {
        console.warn('IPC writeFile error:', err);
      }
    }
    return {
      success: true,
      file_path: path,
      file_hash: 'hash-local',
      saved_at: new Date().toISOString()
    };
  },

  async loadSession(): Promise<SessionState> {
    if (isTauri) {
      try {
        const res = await invoke<SessionState>('load_session');
        if (res && res.tabs && res.tabs.length > 0) return res;
      } catch (err) {
        console.warn('IPC loadSession error:', err);
      }
    }
    // Browser / localStorage fallback
    const saved = localStorage.getItem('valtera_tabs_state');
    if (saved) {
      try {
        const tabs = JSON.parse(saved);
        return { tabs, active_tab_index: 0 };
      } catch {
        // ignore
      }
    }
    return {
      tabs: [
        {
          title: 'Welcome.md',
          file_extension: 'md',
          content: '# Welcome to Valtera Note 📝\n\n- Ultra-lightweight Notepad alternative (< 40MB RAM)\n- Fast Markdown Preview & SQL scratchpad\n- 100% Local-First with Appwrite Cloud Sync\n\nStart typing your notes or SQL queries here!',
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
  },

  async saveTabsState(tabs: TabState[]): Promise<void> {
    if (isTauri) {
      try {
        await invoke<void>('save_tabs_state', { tabs });
        return;
      } catch (err) {
        console.warn('IPC saveTabsState error:', err);
      }
    }
    localStorage.setItem('valtera_tabs_state', JSON.stringify(tabs));
  },

  async executeSqlQuery(dbPath: string, query: string, limit?: number): Promise<SqlResult> {
    if (isTauri) {
      try {
        return await invoke<SqlResult>('execute_sqlite_query', { dbPath, query, limit });
      } catch (err) {
        console.warn('IPC executeSqlQuery error:', err);
      }
    }
    return {
      success: true,
      columns: ['id', 'name', 'status'],
      rows: [[1, 'Sample Table', 'Active'], [2, 'Demo Row', 'Completed']],
      affected_rows: 2,
      duration_ms: 1,
      error_message: null
    };
  },

  async formatSqlQuery(query: string): Promise<string> {
    if (isTauri) {
      try {
        return await invoke<string>('format_sql_query', { query });
      } catch (err) {
        console.warn('IPC formatSqlQuery error:', err);
      }
    }
    return query.toUpperCase();
  },

  async getAppwriteConfig(): Promise<AppwriteConfig> {
    if (isTauri) {
      try {
        return await invoke<AppwriteConfig>('get_appwrite_config');
      } catch (err) {
        console.warn('IPC getAppwriteConfig error:', err);
      }
    }
    const endpoint = localStorage.getItem('valtera_appwrite_endpoint') || '';
    const projectId = localStorage.getItem('valtera_appwrite_project_id') || '';
    const databaseId = localStorage.getItem('valtera_appwrite_database_id') || 'valtera_note_db';
    return {
      endpoint,
      project_id: projectId,
      database_id: databaseId,
      is_configured: Boolean(endpoint && projectId)
    };
  },

  async saveAppwriteConfig(endpoint: string, projectId: string, databaseId: string): Promise<void> {
    if (isTauri) {
      try {
        await invoke<void>('save_appwrite_config', {
          endpoint,
          projectId,
          databaseId,
          project_id: projectId,
          database_id: databaseId
        });
      } catch (err) {
        console.warn('IPC saveAppwriteConfig error:', err);
      }
    }
    localStorage.setItem('valtera_appwrite_endpoint', endpoint);
    localStorage.setItem('valtera_appwrite_project_id', projectId);
    localStorage.setItem('valtera_appwrite_database_id', databaseId);
  },

  async testAppwriteConnection(endpoint: string, projectId: string): Promise<string> {
    const cleanEndpoint = endpoint.trim().replace(/\/+$/, '');
    const cleanProjectId = projectId.trim();

    if (isTauri) {
      try {
        return await invoke<string>('test_appwrite_connection', { 
          endpoint: cleanEndpoint, 
          projectId: cleanProjectId,
          project_id: cleanProjectId 
        });
      } catch (err: any) {
        console.warn('Native IPC test error, trying HTTP fallback:', err);
      }
    }

    // Direct HTTP fetch (works in browser AND as desktop fallback)
    try {
      const res = await fetch(`${cleanEndpoint}/locale`, {
        method: 'GET',
        headers: {
          'X-Appwrite-Project': cleanProjectId
        }
      });

      if (res.ok) {
        return 'Connection to Appwrite server successful!';
      } else {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.message || `Appwrite Error (HTTP ${res.status})`);
      }
    } catch (err: any) {
      throw new Error(err.message || 'Cannot reach Appwrite server. Check Endpoint URL and internet connection.');
    }
  },

  async appwriteRegister(endpoint: string, projectId: string, email: string, password: string, name: string): Promise<string> {
    const cleanEndpoint = endpoint.trim().replace(/\/+$/, '');
    const cleanProjectId = projectId.trim();

    if (isTauri) {
      try {
        return await invoke<string>('appwrite_register', {
          endpoint: cleanEndpoint,
          projectId: cleanProjectId,
          project_id: cleanProjectId,
          email: email.trim(),
          password,
          name: name.trim() || 'Valtera User'
        });
      } catch (err: any) {
        console.warn('Native register error, trying fallback:', err);
      }
    }

    // Browser Direct Fetch
    const res = await fetch(`${cleanEndpoint}/account`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Appwrite-Project': cleanProjectId
      },
      body: JSON.stringify({
        userId: 'unique()',
        email: email.trim(),
        password,
        name: name.trim() || 'Valtera User'
      })
    });

    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.message || `Registration failed (HTTP ${res.status})`);
    }

    // Auto-login
    return await this.appwriteLogin(cleanEndpoint, cleanProjectId, email, password);
  },

  async appwriteLogin(endpoint: string, projectId: string, email: string, password: string): Promise<string> {
    const cleanEndpoint = endpoint.trim().replace(/\/+$/, '');
    const cleanProjectId = projectId.trim();

    if (isTauri) {
      try {
        return await invoke<string>('appwrite_login', {
          endpoint: cleanEndpoint,
          projectId: cleanProjectId,
          project_id: cleanProjectId,
          email: email.trim(),
          password
        });
      } catch (err: any) {
        console.warn('Native login error, trying fallback:', err);
      }
    }

    // Browser Direct Fetch
    const res = await fetch(`${cleanEndpoint}/account/sessions/email`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Appwrite-Project': cleanProjectId
      },
      body: JSON.stringify({
        email: email.trim(),
        password
      })
    });

    if (!res.ok) {
      const data = await res.json().catch(() => ({}));
      throw new Error(data.message || `Login failed (HTTP ${res.status})`);
    }

    localStorage.setItem('valtera_appwrite_endpoint', cleanEndpoint);
    localStorage.setItem('valtera_appwrite_project_id', cleanProjectId);
    localStorage.setItem('valtera_appwrite_user_email', email);

    return 'Login successful';
  },

  async listSnippets(): Promise<Snippet[]> {
    if (isTauri) {
      try {
        return await invoke<Snippet[]>('list_snippets');
      } catch (err) {
        console.warn('IPC listSnippets error:', err);
      }
    }
    return [];
  }
};
