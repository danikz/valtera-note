import { invoke } from '@tauri-apps/api/core';
import type { 
  FilePayload, 
  FileSaveResult, 
  SessionState, 
  TabState, 
  SqlResult, 
  SupabaseConfig, 
  Snippet,
  RemoteNote,
  TableSummary 
} from '../types';

const isTauri = typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;

export const ipc = {
  async getCliOpenFile(): Promise<string | null> {
    if (isTauri) {
      try {
        return await invoke<string | null>('get_cli_open_file');
      } catch (err) {
        console.warn('IPC getCliOpenFile error:', err);
      }
    }
    return null;
  },

  async registerContextMenu(): Promise<string> {
    if (isTauri) {
      try {
        return await invoke<string>('register_windows_context_menu');
      } catch (err: any) {
        throw new Error(typeof err === 'string' ? err : err?.message || 'Gagal mendaftarkan menu klik kanan');
      }
    }
    return 'Menu context didaftarkan (Simulated)';
  },

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
        if (res && Array.isArray(res.tabs)) return res;
      } catch (err) {
        console.warn('IPC loadSession error:', err);
      }
    }
    // Browser / localStorage fallback
    const saved = localStorage.getItem('valtera_tabs_state');
    if (saved !== null) {
      try {
        const tabs = JSON.parse(saved);
        if (Array.isArray(tabs)) {
          return { tabs, active_tab_index: 0 };
        }
      } catch {
        // ignore
      }
    }
    return {
      tabs: [],
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

  async inspectSqliteTables(dbPath: string): Promise<TableSummary[]> {
    if (isTauri) {
      try {
        return await invoke<TableSummary[]>('inspect_sqlite_tables', { dbPath });
      } catch (err) {
        console.warn('IPC inspectSqliteTables error:', err);
        throw err;
      }
    }
    return [
      {
        name: 'notes',
        table_type: 'table',
        total_rows: 3,
        columns: [
          { cid: 0, name: 'id', col_type: 'INTEGER', notnull: true, dflt_value: null, pk: true },
          { cid: 1, name: 'title', col_type: 'TEXT', notnull: true, dflt_value: "'Untitled'", pk: false },
          { cid: 2, name: 'content', col_type: 'TEXT', notnull: false, dflt_value: null, pk: false },
          { cid: 3, name: 'updated_at', col_type: 'DATETIME', notnull: true, dflt_value: 'CURRENT_TIMESTAMP', pk: false }
        ]
      }
    ];
  },

  async getInternalDbPath(): Promise<string> {
    if (isTauri) {
      try {
        return await invoke<string>('get_internal_db_path');
      } catch (err) {
        console.warn('IPC getInternalDbPath error:', err);
        return '';
      }
    }
    return '';
  },

  async getSupabaseConfig(): Promise<SupabaseConfig> {
    let nativeConfig: SupabaseConfig | null = null;
    if (isTauri) {
      try {
        nativeConfig = await invoke<SupabaseConfig>('get_supabase_config');
        if (nativeConfig && (nativeConfig.url || nativeConfig.anon_key)) {
          return nativeConfig;
        }
      } catch (err) {
        console.warn('IPC getSupabaseConfig error:', err);
      }
    }

    const url = localStorage.getItem('valtera_supabase_url') || '';
    const anonKey = localStorage.getItem('valtera_supabase_anon_key') || '';
    const userEmail = localStorage.getItem('valtera_supabase_user_email') || null;
    const accessToken = localStorage.getItem('valtera_supabase_access_token') || null;

    // Self-healing: if localStorage had credentials but SQLite didn't, save back to SQLite
    if (isTauri && (url || anonKey)) {
      invoke<void>('save_supabase_config', {
        url: url.trim(),
        anonKey: anonKey.trim(),
        anon_key: anonKey.trim()
      }).catch(err => console.warn('IPC auto-heal SQLite config error:', err));

      // Pulihkan juga sesi auth (untuk auto-refresh token di sisi Rust)
      if (accessToken && !nativeConfig?.access_token) {
        invoke<void>('set_app_setting', { key: 'supabase_access_token', value: accessToken })
          .catch(err => console.warn('IPC auto-heal access token error:', err));
      }
      const lsRefresh = localStorage.getItem('valtera_supabase_refresh_token');
      const lsExpires = localStorage.getItem('valtera_supabase_token_expires_at');
      if (lsRefresh) {
        invoke<void>('set_app_setting', { key: 'supabase_refresh_token', value: lsRefresh })
          .catch(err => console.warn('IPC auto-heal refresh token error:', err));
      }
      if (lsExpires) {
        invoke<void>('set_app_setting', { key: 'supabase_token_expires_at', value: lsExpires })
          .catch(err => console.warn('IPC auto-heal token expiry error:', err));
      }
    }

    return {
      url: nativeConfig?.url || url,
      anon_key: nativeConfig?.anon_key || anonKey,
      is_configured: Boolean((nativeConfig?.url || url) && (nativeConfig?.anon_key || anonKey)),
      user_email: nativeConfig?.user_email || userEmail,
      access_token: nativeConfig?.access_token || accessToken
    };
  },

  async saveSupabaseConfig(url: string, anonKey: string): Promise<void> {
    const cleanUrl = url.trim();
    const cleanKey = anonKey.trim();
    if (isTauri) {
      try {
        await invoke<void>('save_supabase_config', {
          url: cleanUrl,
          anonKey: cleanKey,
          anon_key: cleanKey
        });
      } catch (err) {
        console.error('IPC saveSupabaseConfig error:', err);
        throw err;
      }
    }
    // Ganti project: sesi (token/email) milik project lama tidak berlaku lagi.
    const oldUrl = localStorage.getItem('valtera_supabase_url');
    if (oldUrl && oldUrl !== cleanUrl) {
      this.clearSupabaseSessionStorage();
    }
    localStorage.setItem('valtera_supabase_url', cleanUrl);
    localStorage.setItem('valtera_supabase_anon_key', cleanKey);
  },

  clearSupabaseSessionStorage(): void {
    localStorage.removeItem('valtera_supabase_user_email');
    localStorage.removeItem('valtera_supabase_access_token');
    localStorage.removeItem('valtera_supabase_refresh_token');
    localStorage.removeItem('valtera_supabase_token_expires_at');
  },

  async supabaseLogout(): Promise<void> {
    if (isTauri) {
      try {
        await invoke<void>('supabase_logout');
      } catch (err) {
        console.warn('IPC supabaseLogout error:', err);
      }
    }
    this.clearSupabaseSessionStorage();
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

  async autoCreateSupabaseTable(url: string, anonKey: string, token: string): Promise<string> {
    const cleanUrl = url.trim().replace(/\/+$/, '');
    const cleanKey = anonKey.trim();

    if (isTauri) {
      try {
        return await invoke<string>('auto_create_supabase_table', {
          url: cleanUrl,
          anonKey: cleanKey,
          anon_key: cleanKey,
          token: token.trim()
        });
      } catch (err: any) {
        throw new Error(typeof err === 'string' ? err : err?.message || 'Gagal membuat tabel via Tauri command');
      }
    }

    // Extract project ref
    let projectRef = '';
    try {
      const parsed = new URL(cleanUrl);
      projectRef = parsed.hostname.split('.')[0];
    } catch {
      projectRef = cleanUrl.replace(/https?:\/\//, '').split('.')[0];
    }

    const sql = `
      create table if not exists public.notes (
          id uuid default gen_random_uuid() primary key,
          user_id uuid default auth.uid(),
          title text not null default 'Untitled',
          content text not null default '',
          file_extension text not null default 'md',
          folder text,
          is_pinned boolean not null default false,
          is_deleted boolean not null default false,
          created_at timestamp with time zone default timezone('utc'::text, now()) not null,
          updated_at timestamp with time zone default timezone('utc'::text, now()) not null
      );
      alter table public.notes add column if not exists folder text;
      alter table public.notes add column if not exists user_id uuid default auth.uid();
      create index if not exists idx_notes_updated_at on public.notes(updated_at desc);
      alter table public.notes enable row level security;
      revoke all on public.notes from anon;
      drop policy if exists "Allow API access" on public.notes;
      drop policy if exists "Allow all for anon and authenticated" on public.notes;
      drop policy if exists "Enable read access for all users" on public.notes;
      drop policy if exists "Owner full access" on public.notes;
      create policy "Owner full access" on public.notes for all to authenticated using (auth.uid() = user_id or user_id is null) with check (auth.uid() = user_id);
    `;

    const res = await fetch(`https://api.supabase.com/v1/projects/${projectRef}/database/query`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token.trim()}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ query: sql })
    });

    if (res.ok) {
      return "Tabel 'notes' berhasil dibuat secara otomatis!";
    }
    const errText = await res.text().catch(() => '');
    throw new Error(`Supabase Management API error: ${errText}`);
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
      const healthRes = await fetch(`${cleanUrl}/auth/v1/health`, {
        method: 'GET',
        headers: { 'apikey': cleanKey }
      }).catch(() => null);

      if (healthRes && healthRes.ok) {
        return 'Koneksi ke Supabase REST API berhasil!';
      }

      const res = await fetch(`${cleanUrl}/rest/v1/notes?select=id&limit=1`, {
        method: 'GET',
        headers: {
          'apikey': cleanKey,
          'Authorization': `Bearer ${cleanKey}`
        }
      });

      if (res.ok) {
        return 'Koneksi ke Supabase REST API berhasil!';
      } else {
        const text = await res.text().catch(() => '');
        if (text.includes('42P01') || text.includes('does not exist') || text.includes('PGRST204') || text.includes('PGRST205')) {
          return "Koneksi ke Supabase berhasil! (Tabel 'notes' belum dibuat)";
        }
        throw new Error(`Supabase Error (HTTP ${res.status}): ${text}`);
      }
    } catch (err: any) {
      throw new Error(err.message || 'Tidak dapat menghubungi server Supabase. Periksa Project URL dan API Key.');
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
      if (data.refresh_token) {
        localStorage.setItem('valtera_supabase_refresh_token', data.refresh_token);
      }
      const expiresIn = typeof data.expires_in === 'number' ? data.expires_in : 3600;
      localStorage.setItem('valtera_supabase_token_expires_at', String(Math.floor(Date.now() / 1000) + expiresIn));
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
      if (data.refresh_token) {
        localStorage.setItem('valtera_supabase_refresh_token', data.refresh_token);
      }
      const expiresIn = typeof data.expires_in === 'number' ? data.expires_in : 3600;
      localStorage.setItem('valtera_supabase_token_expires_at', String(Math.floor(Date.now() / 1000) + expiresIn));
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
  },

  async fetchRemoteNotes(url: string, anonKey: string, accessToken?: string): Promise<RemoteNote[]> {
    const cleanUrl = url.trim().replace(/\/+$/, '');
    const cleanKey = anonKey.trim();

    if (isTauri) {
      try {
        return await invoke<RemoteNote[]>('fetch_remote_notes', {
          url: cleanUrl,
          anonKey: cleanKey,
          anon_key: cleanKey,
          accessToken: accessToken || null,
          access_token: accessToken || null
        });
      } catch (err) {
        console.warn('Native fetchRemoteNotes error, fallback to fetch:', err);
      }
    }

    try {
      const res = await fetch(`${cleanUrl}/rest/v1/notes?select=*&is_deleted=eq.false&order=updated_at.desc`, {
        method: 'GET',
        headers: {
          'apikey': cleanKey,
          'Authorization': `Bearer ${accessToken || cleanKey}`
        }
      });
      if (!res.ok) {
        const errText = await res.text().catch(() => '');
        // Jangan ditelan: pull yang gagal (mis. 401 JWT expired / 403 RLS)
        // harus terlihat, bukan terlihat seperti "cloud kosong".
        throw new Error(`HTTP ${res.status}: ${errText}`);
      }
      return await res.json();
    } catch (e) {
      console.warn('fetchRemoteNotes failed:', e);
      throw e;
    }
  },

  async upsertRemoteNote(url: string, anonKey: string, note: RemoteNote, accessToken?: string): Promise<RemoteNote> {
    const cleanUrl = url.trim().replace(/\/+$/, '');
    const cleanKey = anonKey.trim();

    // Ensure note has a valid ID assigned if missing
    const noteId = (note.id && typeof note.id === 'string' && note.id.trim()) 
      ? note.id.trim() 
      : (typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : undefined);

    const noteToSync: RemoteNote = {
      ...note,
      id: noteId
    };

    if (isTauri) {
      try {
        const nativeRes = await invoke<RemoteNote>('upsert_remote_note', {
          url: cleanUrl,
          anonKey: cleanKey,
          anon_key: cleanKey,
          note: noteToSync,
          accessToken: accessToken || null,
          access_token: accessToken || null
        });
        if (nativeRes && nativeRes.id) {
          return nativeRes;
        }
      } catch (err) {
        console.warn('Native upsertRemoteNote error, trying fetch fallback:', err);
      }
    }

    try {
      const payload: any = { ...noteToSync };
      const hasId = Boolean(payload.id && typeof payload.id === 'string' && payload.id.trim().length > 0);
      if (!hasId) delete payload.id;
      if (!payload.created_at) delete payload.created_at;
      payload.updated_at = new Date().toISOString();

      const requestUrl = hasId 
        ? `${cleanUrl}/rest/v1/notes?on_conflict=id` 
        : `${cleanUrl}/rest/v1/notes`;

      const prefer = hasId
        ? 'resolution=merge-duplicates,return=representation'
        : 'return=representation';

      const res = await fetch(requestUrl, {
        method: 'POST',
        headers: {
          'apikey': cleanKey,
          'Authorization': `Bearer ${accessToken || cleanKey}`,
          'Content-Type': 'application/json',
          'Prefer': prefer
        },
        body: JSON.stringify(payload)
      });

      if (!res.ok) {
        const errText = await res.text().catch(() => '');
        throw new Error(`HTTP ${res.status}: ${errText}`);
      }

      const data = await res.json();
      if (Array.isArray(data) && data.length > 0) {
        return data[0];
      }
      if (data && typeof data === 'object' && (data as any).id) {
        return data;
      }
      return noteToSync;
    } catch (e) {
      console.error('upsertRemoteNote failed:', e);
      throw e;
    }
  },

  async deleteRemoteNote(url: string, anonKey: string, id: string, accessToken?: string): Promise<void> {
    const cleanUrl = url.trim().replace(/\/+$/, '');
    const cleanKey = anonKey.trim();

    if (isTauri) {
      try {
        await invoke<void>('delete_remote_note', {
          url: cleanUrl,
          anonKey: cleanKey,
          anon_key: cleanKey,
          id,
          accessToken: accessToken || null,
          access_token: accessToken || null
        });
        return;
      } catch (err) {
        console.warn('Native deleteRemoteNote error, fallback to fetch:', err);
      }
    }

    try {
      const res = await fetch(`${cleanUrl}/rest/v1/notes?id=eq.${id}`, {
        method: 'DELETE',
        headers: {
          'apikey': cleanKey,
          'Authorization': `Bearer ${accessToken || cleanKey}`
        }
      });
      if (!res.ok) {
        const patchRes = await fetch(`${cleanUrl}/rest/v1/notes?id=eq.${id}`, {
          method: 'PATCH',
          headers: {
            'apikey': cleanKey,
            'Authorization': `Bearer ${accessToken || cleanKey}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({ is_deleted: true, updated_at: new Date().toISOString() })
        });
        if (!patchRes.ok) {
          throw new Error(`Delete gagal (HTTP ${res.status}, soft-delete HTTP ${patchRes.status})`);
        }
      }
    } catch (e) {
      console.warn('deleteRemoteNote failed:', e);
      throw e;
    }
  },

  async getAppSetting(key: string): Promise<string | null> {
    if (isTauri) {
      try {
        const val = await invoke<string | null>('get_app_setting', { key });
        if (val !== null && val !== undefined) return val;
      } catch (err) {
        console.warn('IPC getAppSetting error:', err);
      }
    }
    return localStorage.getItem(`valtera_setting_${key}`);
  },

  async hasMasterPassword(): Promise<boolean> {
    if (isTauri) {
      try {
        return await invoke<boolean>('has_master_password');
      } catch (err) {
        console.warn('IPC hasMasterPassword error:', err);
      }
    }
    return false;
  },

  async e2eStatus(): Promise<'none' | 'locked' | 'ready'> {
    if (isTauri) {
      try {
        return await invoke<'none' | 'locked' | 'ready'>('e2e_status');
      } catch (err) {
        console.warn('IPC e2eStatus error:', err);
      }
    }
    return 'none';
  },

  async setMasterPassword(password: string, rememberDevice: boolean): Promise<void> {
    if (isTauri) {
      await invoke<void>('set_master_password', {
        password,
        rememberDevice
      });
      return;
    }
    throw new Error('Enkripsi hanya tersedia di aplikasi desktop');
  },

  async unlockMasterPassword(password: string): Promise<void> {
    if (isTauri) {
      await invoke<void>('unlock', { password });
      return;
    }
    throw new Error('Enkripsi hanya tersedia di aplikasi desktop');
  },

  async lockApp(): Promise<void> {
    if (isTauri) {
      await invoke<void>('lock');
    }
  },

  async changeMasterPassword(oldPassword: string, newPassword: string, rememberDevice: boolean): Promise<void> {
    if (isTauri) {
      await invoke<void>('change_password', {
        oldPassword,
        newPassword,
        rememberDevice
      });
      return;
    }
    throw new Error('Enkripsi hanya tersedia di aplikasi desktop');
  },

  async forgetDevice(): Promise<void> {
    if (isTauri) {
      await invoke<void>('forget_device');
    }
  },

  async encryptContent(content: string): Promise<string> {
    if (isTauri) {
      // Tidak ditelan: gagal enkripsi (mis. app terkunci) harus menghentikan
      // alur sync agar plaintext/ciphertext lama tidak pernah ter-push.
      return await invoke<string>('encrypt_content', { content });
    }
    return content;
  },

  async decryptContent(content: string): Promise<string> {
    if (isTauri) {
      // Tidak ditelan: ciphertext yang gagal didekripsi TIDAK boleh diteruskan —
      // error menghentikan sync sebelum merge menimpa konten lokal.
      return await invoke<string>('decrypt_content', { content });
    }
    return content;
  },

  async setAppSetting(key: string, value: string): Promise<void> {
    if (isTauri) {
      try {
        await invoke<void>('set_app_setting', { key, value });
      } catch (err) {
        console.warn('IPC setAppSetting error:', err);
      }
    }
    localStorage.setItem(`valtera_setting_${key}`, value);
  }
};
