import { ipc } from '../services/ipc';
import type { TabState, SupabaseConfig, SplitMode, RemoteNote } from '../types';

export function extractTitleFromContent(content: string, ext: string = 'md'): string {
  if (!content || !content.trim()) return `Untitled.${ext}`;

  const lines = content.split('\n');
  for (const rawLine of lines) {
    let line = rawLine.trim();
    if (!line) continue;

    // Strip markdown formatting headers: #, ##, ###, >, -, *, numbers, etc.
    line = line.replace(/^[#>\-*_`~0-9.)]+\s*/, '');
    // Strip SQL comment markers: -- or /* */
    line = line.replace(/^(--|\/\*)\s*/, '');
    line = line.replace(/\*\/$/, '');
    line = line.trim();

    if (line.length > 0) {
      // Clean invalid filename characters: \ / : * ? " < > |
      line = line.replace(/[\\/:*?"<>|]/g, '').trim();
      if (line.length > 35) {
        line = line.substring(0, 35).trim() + '...';
      }
      if (line.length > 0) {
        return `${line}.${ext}`;
      }
    }
  }

  return `Untitled.${ext}`;
}

class EditorStore {
  tabs = $state<TabState[]>([]);
  folders = $state<string[]>(['Personal', 'Work', 'Projects', 'SQL Queries']);
  deletedNoteIds = $state<string[]>([]);
  activeTabIndex = $state<number>(0);
  isSaving = $state<boolean>(false);
  supabaseConfig = $state<SupabaseConfig>({
    url: '',
    anon_key: '',
    is_configured: false
  });
  isSyncing = $state<boolean>(false);
  syncStatus = $state<'idle' | 'syncing' | 'synced' | 'error'>('idle');
  lastSavedAt = $state<string>('');
  lastSyncedAt = $state<string>('');
  syncMessage = $state<string>('');
  sqlDatabasePath = $state<string>('');

  private autoSyncInterval: any = null;
  private debounceSaveTimer: any = null;
  private debounceSyncTimer: any = null;

  constructor() {
    this.init();
  }

  get openTabs(): { tab: TabState; originalIndex: number }[] {
    return this.tabs
      .map((tab, originalIndex) => ({ tab, originalIndex }))
      .filter(({ tab }) => tab.is_open !== false);
  }

  get activeTab(): TabState | undefined {
    if (this.tabs.length === 0) return undefined;
    const current = this.tabs[this.activeTabIndex];
    if (current && current.is_open !== false) {
      return current;
    }
    const firstOpen = this.tabs.findIndex(t => t.is_open !== false);
    if (firstOpen !== -1) {
      this.activeTabIndex = firstOpen;
      return this.tabs[firstOpen];
    }
    return undefined;
  }

  async init() {
    try {
      const session = await ipc.loadSession();
      if (session && Array.isArray(session.tabs)) {
        this.tabs = session.tabs;
        this.activeTabIndex = session.tabs.length > 0
          ? Math.max(0, Math.min(session.active_tab_index, session.tabs.length - 1))
          : 0;
      }
      this.supabaseConfig = await ipc.getSupabaseConfig();

      // Load custom folders
      const savedFoldersStr = (await ipc.getAppSetting('custom_folders')) || localStorage.getItem('valtera_folders');
      if (savedFoldersStr !== null && savedFoldersStr !== undefined) {
        try {
          const parsed = JSON.parse(savedFoldersStr);
          if (Array.isArray(parsed)) {
            this.folders = Array.from(new Set(parsed.filter(f => typeof f === 'string' && f.trim().length > 0)));
          }
        } catch {
          // ignore
        }
      }

      // Load deleted note IDs (tombstones) to prevent resurrection during sync
      const savedDeletedStr = (await ipc.getAppSetting('deleted_note_ids')) || localStorage.getItem('valtera_deleted_note_ids');
      if (savedDeletedStr !== null && savedDeletedStr !== undefined) {
        try {
          const parsed = JSON.parse(savedDeletedStr);
          if (Array.isArray(parsed)) {
            this.deletedNoteIds = Array.from(new Set(parsed.filter(id => typeof id === 'string' && id.trim().length > 0)));
          }
        } catch {
          // ignore
        }
      }

      // Collect folders from tabs
      if (this.tabs && this.tabs.length > 0) {
        for (const t of this.tabs) {
          if (t.folder && !this.folders.includes(t.folder)) {
            this.folders.push(t.folder);
          }
        }
      }

      // Trigger automatic initial cloud sync if configured
      if (this.supabaseConfig.is_configured) {
        this.autoSyncAll();
      }

      // Setup background periodic sync (every 30 seconds)
      if (!this.autoSyncInterval && typeof window !== 'undefined') {
        this.autoSyncInterval = setInterval(() => {
          if (this.supabaseConfig.is_configured && !this.isSyncing) {
            this.autoSyncAll(true);
          }
        }, 30000);
      }
    } catch (e) {
      console.error('Failed to init session:', e);
    }
  }

  setSupabaseConfig(config: Partial<SupabaseConfig>) {
    const url = (config.url ?? this.supabaseConfig.url).trim();
    const anon_key = (config.anon_key ?? this.supabaseConfig.anon_key).trim();
    this.supabaseConfig = {
      url,
      anon_key,
      is_configured: Boolean(url && anon_key),
      user_email: config.user_email !== undefined ? config.user_email : this.supabaseConfig.user_email,
      access_token: config.access_token !== undefined ? config.access_token : this.supabaseConfig.access_token
    };
  }

  createFolder(name: string, createInitialNote: boolean = true) {
    const trimmed = name.trim();
    if (!trimmed) return;
    if (!this.folders.includes(trimmed)) {
      this.folders.push(trimmed);
      this.persistFolders();
    }
    if (createInitialNote) {
      this.addTab(undefined, 'md', '', trimmed);
    }
  }

  renameFolder(oldName: string, newName: string) {
    const trimmedOld = oldName.trim();
    const trimmedNew = newName.trim();
    if (!trimmedNew || trimmedOld === trimmedNew) return;

    const idx = this.folders.indexOf(trimmedOld);
    if (idx !== -1) {
      this.folders[idx] = trimmedNew;
    } else if (!this.folders.includes(trimmedNew)) {
      this.folders.push(trimmedNew);
    }

    this.tabs.forEach(tab => {
      if (tab.folder === trimmedOld) {
        tab.folder = trimmedNew;
        tab.is_dirty = true;
      }
    });

    this.persistFolders();
    this.persistTabs();

    if (this.supabaseConfig.is_configured) {
      this.autoSyncAll(true);
    }
  }

  async deleteFolder(folderName: string, deleteNotes: boolean = false) {
    const trimmed = folderName.trim();
    this.folders = this.folders.filter(f => f !== trimmed);

    const notesInFolder = this.tabs.filter(t => t.folder === trimmed);

    if (deleteNotes) {
      // If deleting notes, also remove them from Supabase Cloud
      if (this.supabaseConfig.is_configured) {
        for (const note of notesInFolder) {
          if (note.supabase_id) {
            try {
              await ipc.deleteRemoteNote(
                this.supabaseConfig.url,
                this.supabaseConfig.anon_key,
                note.supabase_id,
                this.supabaseConfig.access_token || undefined
              );
            } catch (err) {
              console.warn('Failed to delete remote note during folder delete:', err);
            }
          }
        }
      }

      this.tabs = this.tabs.filter(t => t.folder !== trimmed);
      if (this.tabs.length === 0) {
        this.activeTabIndex = 0;
      } else {
        this.activeTabIndex = Math.min(this.activeTabIndex, this.tabs.length - 1);
      }
    } else {
      // Unfile notes and push update to Supabase Cloud so the folder is disassociated
      for (const tab of this.tabs) {
        if (tab.folder === trimmed) {
          tab.folder = undefined;
          tab.is_dirty = true;
          if (this.supabaseConfig.is_configured) {
            this.debounceAutoSync(tab);
          }
        }
      }
    }

    this.persistFolders();
    this.persistTabs();
  }

  setNoteFolder(tabIndex: number, folderName?: string) {
    const tab = this.tabs[tabIndex];
    if (tab) {
      tab.folder = folderName && folderName.trim() ? folderName.trim() : undefined;
      tab.is_dirty = true;
      if (tab.folder && !this.folders.includes(tab.folder)) {
        this.folders.push(tab.folder);
        this.persistFolders();
      }
      this.persistTabs();
      if (this.supabaseConfig.is_configured) {
        this.debounceAutoSync(tab);
      }
    }
  }

  persistFolders() {
    try {
      const json = JSON.stringify(this.folders);
      localStorage.setItem('valtera_folders', json);
      ipc.setAppSetting('custom_folders', json);
    } catch (e) {
      console.warn('Failed to persist folders:', e);
    }
  }

  persistDeletedNotes() {
    try {
      const json = JSON.stringify(this.deletedNoteIds);
      localStorage.setItem('valtera_deleted_note_ids', json);
      ipc.setAppSetting('deleted_note_ids', json);
    } catch (e) {
      console.warn('Failed to persist deleted note IDs:', e);
    }
  }

  addTab(title?: string, file_extension = 'md', content = '', folder?: string) {
    const defaultTitle = title || (content ? extractTitleFromContent(content, file_extension) : `Untitled.${file_extension}`);
    const newTab: TabState = {
      title: defaultTitle,
      file_extension,
      content,
      folder: folder && folder.trim() ? folder.trim() : undefined,
      is_active: true,
      is_open: true,
      is_dirty: false,
      is_scratchpad: true,
      cursor_line: 1,
      cursor_col: 1,
      split_mode: 'editor-only',
      is_custom_named: Boolean(title && title !== 'Untitled' && title !== `Untitled.${file_extension}`)
    };

    if (newTab.folder && !this.folders.includes(newTab.folder)) {
      this.folders.push(newTab.folder);
      this.persistFolders();
    }

    this.tabs.push(newTab);
    this.activeTabIndex = this.tabs.length - 1;
    this.persistTabs();

    if (this.supabaseConfig.is_configured && content.trim().length > 0) {
      this.debounceAutoSync(newTab);
    }
  }

  async closeTab(index: number) {
    if (index < 0 || index >= this.tabs.length) return;
    const tab = this.tabs[index];
    if (!tab) return;

    // Discard empty unsaved scratchpad (no file path, no cloud sync, no folder, no content)
    if (!tab.file_path && !tab.supabase_id && !tab.folder && (!tab.content || !tab.content.trim())) {
      this.tabs.splice(index, 1);
    } else {
      // For existing notes, cloud notes, or notes in folders:
      // Simply close the tab view (is_open = false). It remains safe in Sidebar and Supabase!
      tab.is_open = false;
    }

    // Switch active tab to another currently open tab if needed
    if (this.activeTabIndex === index) {
      const nextOpenIdx = this.tabs.findIndex(t => t.is_open !== false);
      if (nextOpenIdx !== -1) {
        this.activeTabIndex = nextOpenIdx;
      }
    } else if (this.activeTabIndex >= this.tabs.length) {
      this.activeTabIndex = Math.max(0, this.tabs.length - 1);
    }

    this.persistTabs();
  }

  /**
   * Delete a note permanently (from memory, SQLite local DB, and Supabase Cloud)
   */
  async deleteTab(index: number, deleteFromCloud = true) {
    if (index < 0 || index >= this.tabs.length) return;

    const tab = this.tabs[index];
    if (!tab) return;

    // 1. If supabase_id is present, delete and record tombstone
    if (tab.supabase_id) {
      if (!this.deletedNoteIds.includes(tab.supabase_id)) {
        this.deletedNoteIds.push(tab.supabase_id);
        this.persistDeletedNotes();
      }
      // Delete from Supabase cloud if connected
      if (deleteFromCloud && this.supabaseConfig.is_configured) {
        try {
          await ipc.deleteRemoteNote(
            this.supabaseConfig.url,
            this.supabaseConfig.anon_key,
            tab.supabase_id,
            this.supabaseConfig.access_token || undefined
          );
        } catch (e) {
          console.warn('Failed to delete remote note from Supabase:', e);
        }
      }
    } else if (deleteFromCloud && this.supabaseConfig.is_configured) {
      // If note had no local supabase_id assigned yet, check if matching note exists remotely
      try {
        const remoteNotes = await ipc.fetchRemoteNotes(
          this.supabaseConfig.url,
          this.supabaseConfig.anon_key,
          this.supabaseConfig.access_token || undefined
        );
        if (Array.isArray(remoteNotes)) {
          for (const remote of remoteNotes) {
            if (remote.id && remote.title === tab.title) {
              if (!this.deletedNoteIds.includes(remote.id)) {
                this.deletedNoteIds.push(remote.id);
                this.persistDeletedNotes();
              }
              await ipc.deleteRemoteNote(
                this.supabaseConfig.url,
                this.supabaseConfig.anon_key,
                remote.id,
                this.supabaseConfig.access_token || undefined
              );
            }
          }
        }
      } catch (err) {
        console.warn('Failed to search remote note by title for deletion:', err);
      }
    }

    // 2. Remove from local tabs & SQLite DB
    this.tabs.splice(index, 1);
    const nextOpenIdx = this.tabs.findIndex(t => t.is_open !== false);
    if (nextOpenIdx !== -1) {
      this.activeTabIndex = nextOpenIdx;
    } else {
      this.activeTabIndex = 0;
    }
    this.persistTabs();
  }

  /**
   * Clear all notes and folders completely (Full Reset / Clean Start)
   */
  async clearAllData() {
    this.isSyncing = true;
    this.syncStatus = 'syncing';
    this.syncMessage = 'Membersihkan semua data di database & lokal...';

    // 1. Delete all remote notes in Supabase if configured
    if (this.supabaseConfig.is_configured) {
      try {
        const remoteNotes = await ipc.fetchRemoteNotes(
          this.supabaseConfig.url,
          this.supabaseConfig.anon_key,
          this.supabaseConfig.access_token || undefined
        );
        if (Array.isArray(remoteNotes)) {
          for (const note of remoteNotes) {
            if (note.id) {
              if (!this.deletedNoteIds.includes(note.id)) {
                this.deletedNoteIds.push(note.id);
              }
              await ipc.deleteRemoteNote(
                this.supabaseConfig.url,
                this.supabaseConfig.anon_key,
                note.id,
                this.supabaseConfig.access_token || undefined
              );
            }
          }
          this.persistDeletedNotes();
        }
      } catch (e) {
        console.warn('Failed to delete all remote notes from Supabase:', e);
      }
    }

    // 2. Clear all custom folders
    this.folders = [];
    this.persistFolders();

    // 3. Reset tabs to empty list
    this.tabs = [];
    this.activeTabIndex = 0;
    this.persistTabs();

    // Clear localStorage backups
    try {
      localStorage.removeItem('valtera_tabs_state');
      localStorage.removeItem('valtera_folders');
    } catch {}

    this.isSyncing = false;
    this.syncStatus = 'synced';
    this.syncMessage = 'Semua data di database & lokal telah dibersihkan';
  }

  selectTab(index: number) {
    if (index >= 0 && index < this.tabs.length) {
      this.tabs[index].is_open = true;
      this.activeTabIndex = index;
      this.persistTabs();
    }
  }

  setActiveTab(index: number) {
    this.selectTab(index);
  }

  renameTab(index: number, newTitle: string) {
    const tab = this.tabs[index];
    if (tab && newTitle.trim()) {
      let title = newTitle.trim();
      if (!title.includes('.') && tab.file_extension) {
        title = `${title}.${tab.file_extension}`;
      }
      tab.title = title;
      tab.is_custom_named = true;
      tab.is_dirty = true;
      this.persistTabs();
      if (this.supabaseConfig.is_configured) {
        this.debounceAutoSync(tab);
      }
    }
  }

  updateContent(newContent: string) {
    const tab = this.activeTab;
    if (tab && tab.content !== newContent) {
      tab.content = newContent;
      tab.is_dirty = true;

      // Auto-title scratchpad/cloud notes from first line of content (like Notepad/Notion)
      if (!tab.file_path && !tab.is_custom_named) {
        const autoTitle = extractTitleFromContent(newContent, tab.file_extension);
        if (autoTitle && tab.title !== autoTitle) {
          tab.title = autoTitle;
        }
      }

      this.triggerAutoSaveAndSync(tab);
    }
  }

  updateCursor(line: number, col: number) {
    const tab = this.activeTab;
    if (tab) {
      tab.cursor_line = line;
      tab.cursor_col = col;
    }
  }

  setSplitMode(mode: SplitMode) {
    const tab = this.activeTab;
    if (tab) {
      tab.split_mode = mode;
      this.persistTabs();
    }
  }

  setFileExtension(ext: string) {
    const tab = this.activeTab;
    if (tab) {
      tab.file_extension = ext;
      if (tab.title.includes('.')) {
        tab.title = `${tab.title.substring(0, tab.title.lastIndexOf('.'))}.${ext}`;
      } else {
        tab.title = `${tab.title}.${ext}`;
      }
      this.persistTabs();
      if (this.supabaseConfig.is_configured) {
        this.debounceAutoSync(tab);
      }
    }
  }

  async saveCurrentTab(customPath?: string) {
    const tab = this.activeTab;
    if (!tab) return;

    this.isSaving = true;
    try {
      const path = customPath || tab.file_path;
      if (path) {
        // Save to local file system
        await ipc.writeFile(path, tab.content);
        tab.file_path = path;
        tab.title = path.split(/[\\/]/).pop() || tab.title;
        tab.file_extension = path.split('.').pop() || tab.file_extension;
        tab.is_dirty = false;
        tab.is_scratchpad = false;
        this.lastSavedAt = new Date().toLocaleTimeString();
        this.persistTabs();

        if (this.supabaseConfig.is_configured) {
          await this.syncSingleTab(tab);
        }
      } else {
        // Cloud Note / Scratchpad (no local disk file needed)
        if (this.supabaseConfig.is_configured) {
          await this.syncSingleTab(tab);
        } else {
          tab.is_dirty = false;
          this.lastSavedAt = new Date().toLocaleTimeString();
          this.persistTabs();
        }
      }
    } catch (e) {
      console.error('Error saving note:', e);
    } finally {
      this.isSaving = false;
    }
  }

  async openFile(path: string) {
    try {
      const payload = await ipc.readFile(path);
      const existingIndex = this.tabs.findIndex(t => t.file_path === path);
      
      if (existingIndex >= 0) {
        this.tabs[existingIndex].is_open = true;
        this.activeTabIndex = existingIndex;
        this.persistTabs();
        return;
      }

      const ext = (payload.file_extension || '').toLowerCase();
      const defaultSplit = (ext === 'json' || ext === 'md' || ext === 'sql') ? 'split-horizontal' : 'editor-only';

      const newTab: TabState = {
        file_path: payload.file_path,
        title: payload.file_name,
        file_extension: payload.file_extension,
        content: payload.content,
        is_active: true,
        is_open: true,
        is_dirty: false,
        is_scratchpad: false,
        cursor_line: 1,
        cursor_col: 1,
        split_mode: defaultSplit
      };

      this.tabs.push(newTab);
      this.activeTabIndex = this.tabs.length - 1;
      this.persistTabs();

      if (this.supabaseConfig.is_configured) {
        this.debounceAutoSync(newTab);
      }
    } catch (e) {
      console.error('Error opening file:', e);
    }
  }

  /**
   * Triggers debounced automatic disk save and debounced cloud sync
   */
  private triggerAutoSaveAndSync(tab: TabState) {
    // 1. Debounced Auto-Save to Disk (only if note has an assigned file path on disk)
    if (this.debounceSaveTimer) clearTimeout(this.debounceSaveTimer);
    this.debounceSaveTimer = setTimeout(async () => {
      if (tab.file_path) {
        try {
          this.isSaving = true;
          await ipc.writeFile(tab.file_path, tab.content);
          tab.is_dirty = false;
          this.lastSavedAt = new Date().toLocaleTimeString();
        } catch (err) {
          console.error('Auto-save to disk failed:', err);
        } finally {
          this.isSaving = false;
        }
      }
      this.persistTabs();
    }, 1200);

    // 2. Debounced Auto-Sync to Supabase Cloud (1500ms)
    if (this.supabaseConfig.is_configured) {
      this.debounceAutoSync(tab);
    }
  }

  /**
   * Debounced single tab sync to Supabase
   */
  private debounceAutoSync(tab: TabState) {
    if (!this.supabaseConfig.is_configured) return;
    if (this.debounceSyncTimer) clearTimeout(this.debounceSyncTimer);

    this.debounceSyncTimer = setTimeout(async () => {
      await this.syncSingleTab(tab);
    }, 1500);
  }

  /**
   * Sync a single tab directly to Supabase
   */
  async syncSingleTab(tab: TabState) {
    if (!this.supabaseConfig.is_configured) return;

    try {
      this.isSyncing = true;
      this.syncStatus = 'syncing';
      this.syncMessage = 'Syncing...';

      const remotePayload: RemoteNote = {
        id: tab.supabase_id || undefined,
        title: tab.title || 'Untitled',
        content: tab.content || '',
        file_extension: tab.file_extension || 'txt',
        folder: tab.folder || undefined,
        is_pinned: false,
        is_deleted: false
      };

      const res = await ipc.upsertRemoteNote(
        this.supabaseConfig.url,
        this.supabaseConfig.anon_key,
        remotePayload,
        this.supabaseConfig.access_token || undefined
      );

      if (res && res.id) {
        tab.supabase_id = res.id;
        tab.synced_at = new Date().toISOString();
        tab.sync_status = 'synced';
        tab.is_dirty = false;
      }

      this.syncStatus = 'synced';
      this.lastSyncedAt = new Date().toLocaleTimeString();
      this.lastSavedAt = this.lastSyncedAt;
      this.syncMessage = `Auto-synced at ${this.lastSyncedAt}`;
      this.persistTabs();
    } catch (e: any) {
      console.warn('Auto-sync single tab error:', e);
      this.syncStatus = 'error';
      this.syncMessage = 'Sync failed';
    } finally {
      this.isSyncing = false;
    }
  }

  /**
   * Full bidirectional sync: pull remote notes and push unsynced local tabs
   */
  async autoSyncAll(silent = false) {
    if (!this.supabaseConfig.is_configured || this.isSyncing) return;

    try {
      this.isSyncing = true;
      this.syncStatus = 'syncing';
      if (!silent) this.syncMessage = 'Syncing cloud notes...';

      const remoteNotes = await ipc.fetchRemoteNotes(
        this.supabaseConfig.url,
        this.supabaseConfig.anon_key,
        this.supabaseConfig.access_token || undefined
      );

      // 1. Merge remote notes into local tabs
      if (Array.isArray(remoteNotes) && remoteNotes.length > 0) {
        for (const remote of remoteNotes) {
          if (!remote.id || remote.is_deleted || this.deletedNoteIds.includes(remote.id)) {
            // If it was deleted locally but remote returned it, clean up remotely again
            if (remote.id && this.deletedNoteIds.includes(remote.id)) {
              ipc.deleteRemoteNote(
                this.supabaseConfig.url,
                this.supabaseConfig.anon_key,
                remote.id,
                this.supabaseConfig.access_token || undefined
              );
            }
            continue;
          }

          // Track folder from remote note
          if (remote.folder && !this.folders.includes(remote.folder)) {
            this.folders.push(remote.folder);
            this.persistFolders();
          }

          const existingTab = this.tabs.find(
            t => t.supabase_id === remote.id || 
                 (!t.supabase_id && t.title === remote.title && t.file_extension === (remote.file_extension || 'txt'))
          );

          if (existingTab) {
            existingTab.supabase_id = remote.id;
            if (remote.folder && !existingTab.folder) {
              existingTab.folder = remote.folder;
            }
            // Only update local content if local tab is not currently dirty
            if (!existingTab.is_dirty && existingTab.content !== remote.content) {
              existingTab.content = remote.content;
              existingTab.title = remote.title;
              existingTab.file_extension = remote.file_extension || 'txt';
            }
          } else {
            // New remote note not open in local tabs -> add as new tab
            this.tabs.push({
              title: remote.title || 'Untitled',
              file_extension: remote.file_extension || 'md',
              content: remote.content || '',
              folder: remote.folder || undefined,
              supabase_id: remote.id,
              is_active: false,
              is_open: true,
              is_dirty: false,
              is_scratchpad: true,
              cursor_line: 1,
              cursor_col: 1,
              split_mode: 'editor-only'
            });
          }
        }
      }

      // 2. Push local tabs that have content and are not yet on Supabase (or dirty)
      for (const tab of this.tabs) {
        if (tab.content.trim().length > 0 && (!tab.supabase_id || tab.is_dirty)) {
          const res = await ipc.upsertRemoteNote(
            this.supabaseConfig.url,
            this.supabaseConfig.anon_key,
            {
              id: tab.supabase_id || undefined,
              title: tab.title,
              content: tab.content,
              file_extension: tab.file_extension,
              folder: tab.folder || undefined,
              is_pinned: false,
              is_deleted: false
            },
            this.supabaseConfig.access_token || undefined
          );

          if (res && res.id) {
            tab.supabase_id = res.id;
            tab.synced_at = new Date().toISOString();
            tab.sync_status = 'synced';
            tab.is_dirty = false;
          }
        }
      }

      this.syncStatus = 'synced';
      this.lastSyncedAt = new Date().toLocaleTimeString();
      this.syncMessage = `Auto-synced at ${this.lastSyncedAt}`;
      this.persistTabs();
    } catch (e: any) {
      console.warn('Full sync error:', e);
      this.syncStatus = 'error';
      this.syncMessage = 'Sync failed';
    } finally {
      this.isSyncing = false;
    }
  }

  private async persistTabs() {
    try {
      const snapshot = this.tabs.map((t, idx) => ({
        ...t,
        is_active: idx === this.activeTabIndex
      }));
      await ipc.saveTabsState(snapshot);
    } catch (e) {
      console.error('Failed to persist tabs:', e);
    }
  }
}

export const editorStore = new EditorStore();

if (typeof window !== 'undefined') {
  (window as any).editorStore = editorStore;
}
