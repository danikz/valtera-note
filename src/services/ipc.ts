import { invoke } from '@tauri-apps/api/core';
import type { 
  FilePayload, 
  FileSaveResult, 
  SessionState, 
  TabState, 
  SqlResult, 
  SupabaseConfig, 
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
          content: '# Welcome to Valtera Note 📝\n\n- Ultra-lightweight Notepad alternative (< 40MB RAM)\n- Fast Markdown Preview & SQL scratchpad\n- 100% Local-First with Supabase Cloud Sync\n\nStart typing your notes or SQL queries here!',
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

  async getSupabaseConfig(): Promise<SupabaseConfig> {
    if (isTauri) {
      try {
        return await invoke<SupabaseConfig>('get_supabase_config');
      } catch (err) {
        console.warn('IPC getSupabaseConfig error:', err);
      }
    }
    const url = localStorage.getItem('valtera_supabase_url') || '';
    const anonKey = localStorage.getItem('valtera_supabase_anon_key') || '';
    const userEmail = localStorage.getItem('valtera_supabase_user_email') || null;
    const accessToken = localStorage.getItem('valtera_supabase_access_token') || null;
    return {
      url,
      anon_key: anonKey,
      is_configured: Boolean(url && anonKey),
      user_email: userEmail,
      access_token: accessToken
    };
  },

  async saveSupabaseConfig(url: string, anonKey: string): Promise<void> {
    if (isTauri) {
      try {
        await invoke<void>('save_supabase_config', {
          url: url.trim(),
          anonKey: anonKey.trim(),
          anon_key: anonKey.trim()
        });
      } catch (err) {
        console.warn('IPC saveSupabaseConfig error:', err);
      }
    }
    localStorage.setItem('valtera_supabase_url', url.trim());
    localStorage.setItem('valtera_supabase_anon_key', anonKey.trim());
  },

  async checkSupabaseTable(url: string, anonKey: string, accessToken?: string): Promise<boolean> {
    const cleanUrl = url.trim().replace(/\/+$/, '');
    const cleanKey = anonKey.trim();

    if (isTauri) {
      try {
        return await invoke<boolean>('check_supabase_table', {
          url: cleanUrl,
          anonKey: cleanKey,
          anon_key: cleanKey,
          accessToken: accessToken || null,
          access_token: accessToken || null
        });
      } catch (err) {
        console.warn('Native check table error, fallback to fetch:', err);
      }
    }

    try {
      const res = await fetch(`${cleanUrl}/rest/v1/notes?select=id&limit=1`, {
        method: 'GET',
        headers: {
          'apikey': cleanKey,
          'Authorization': `Bearer ${accessToken || cleanKey}`
        }
      });
      if (res.ok) return true;
      const text = await res.text().catch(() => '');
      if (text.includes('42P01') || text.includes('does not exist') || text.includes('PGRST204') || text.includes('PGRST205')) {
        return false;
      }
      return res.status === 401 || res.status === 403;
    } catch {
      return false;
    }
  },

  async testSupabaseConnection(url: string, anonKey: string): Promise<string> {
    const cleanUrl = url.trim().replace(/\/+$/, '');
    const cleanKey = anonKey.trim();

    if (isTauri) {
      try {
        return await invoke<string>('test_supabase_connection', { 
          url: cleanUrl, 
          anonKey: cleanKey,
          anon_key: cleanKey 
        });
      } catch (err: any) {
        console.warn('Native IPC Supabase test error, trying HTTP fallback:', err);
      }
    }

    // Direct HTTP fetch (works in browser AND as desktop fallback)
    try {
      const res = await fetch(`${cleanUrl}/rest/v1/`, {
        method: 'GET',
        headers: {
          'apikey': cleanKey,
          'Authorization': `Bearer ${cleanKey}`
        }
      });

      if (res.ok) {
        return 'Connection to Supabase REST API successful!';
      } else {
        const text = await res.text().catch(() => '');
        throw new Error(`Supabase Error (HTTP ${res.status}): ${text}`);
      }
    } catch (err: any) {
      throw new Error(err.message || 'Cannot reach Supabase server. Check Project URL and API Key.');
    }
  },

  async supabaseRegister(url: string, anonKey: string, email: string, password: string): Promise<string> {
    const cleanUrl = url.trim().replace(/\/+$/, '');
    const cleanKey = anonKey.trim();

    if (isTauri) {
      try {
        return await invoke<string>('supabase_register', {
          url: cleanUrl,
          anonKey: cleanKey,
          anon_key: cleanKey,
          email: email.trim(),
          password
        });
      } catch (err: any) {
        console.warn('Native register error, trying fallback:', err);
      }
    }

    // Browser Direct Fetch
    const res = await fetch(`${cleanUrl}/auth/v1/signup`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': cleanKey
      },
      body: JSON.stringify({
        email: email.trim(),
        password
      })
    });

    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      throw new Error(data.msg || data.error_description || data.message || `Registration failed (HTTP ${res.status})`);
    }

    localStorage.setItem('valtera_supabase_url', cleanUrl);
    localStorage.setItem('valtera_supabase_anon_key', cleanKey);
    localStorage.setItem('valtera_supabase_user_email', email.trim());

    if (data.access_token) {
      localStorage.setItem('valtera_supabase_access_token', data.access_token);
      return 'Registration and login successful!';
    }

    return 'Registration successful. Please check your email if confirmation is required.';
  },

  async supabaseLogin(url: string, anonKey: string, email: string, password: string): Promise<string> {
    const cleanUrl = url.trim().replace(/\/+$/, '');
    const cleanKey = anonKey.trim();

    if (isTauri) {
      try {
        return await invoke<string>('supabase_login', {
          url: cleanUrl,
          anonKey: cleanKey,
          anon_key: cleanKey,
          email: email.trim(),
          password
        });
      } catch (err: any) {
        console.warn('Native login error, trying fallback:', err);
      }
    }

    // Browser Direct Fetch
    const res = await fetch(`${cleanUrl}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': cleanKey
      },
      body: JSON.stringify({
        email: email.trim(),
        password
      })
    });

    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      throw new Error(data.msg || data.error_description || data.message || `Login failed (HTTP ${res.status})`);
    }

    localStorage.setItem('valtera_supabase_url', cleanUrl);
    localStorage.setItem('valtera_supabase_anon_key', cleanKey);
    localStorage.setItem('valtera_supabase_user_email', email.trim());
    if (data.access_token) {
      localStorage.setItem('valtera_supabase_access_token', data.access_token);
    }

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
