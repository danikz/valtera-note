import { ipc } from '../services/ipc';
import type { TabState, SupabaseConfig, SplitMode } from '../types';

class EditorStore {
  tabs = $state<TabState[]>([
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
  ]);
  activeTabIndex = $state<number>(0);
  isSaving = $state<boolean>(false);
  supabaseConfig = $state<SupabaseConfig>({
    url: '',
    anon_key: '',
    is_configured: false
  });
  isSyncing = $state<boolean>(false);
  lastSavedAt = $state<string>('');
  sqlDatabasePath = $state<string>('');

  constructor() {
    this.init();
  }

  get activeTab(): TabState | undefined {
    return this.tabs[this.activeTabIndex] || this.tabs[0];
  }

  async init() {
    try {
      const session = await ipc.loadSession();
      if (session.tabs && session.tabs.length > 0) {
        this.tabs = session.tabs;
        this.activeTabIndex = Math.min(session.active_tab_index, session.tabs.length - 1);
      }
      this.supabaseConfig = await ipc.getSupabaseConfig();
    } catch (e) {
      console.error('Failed to init session:', e);
    }
  }

  addTab(title = 'Untitled', file_extension = 'txt', content = '') {
    const newTab: TabState = {
      title,
      file_extension,
      content,
      is_active: true,
      is_dirty: false,
      is_scratchpad: true,
      cursor_line: 1,
      cursor_col: 1,
      split_mode: file_extension === 'md' ? 'split-horizontal' : 'none'
    };
    this.tabs.push(newTab);
    this.activeTabIndex = this.tabs.length - 1;
    this.persistTabs();
  }

  closeTab(index: number) {
    if (this.tabs.length <= 1) {
      this.tabs = [
        {
          title: 'Untitled.txt',
          file_extension: 'txt',
          content: '',
          is_active: true,
          is_dirty: false,
          is_scratchpad: true,
          cursor_line: 1,
          cursor_col: 1,
          split_mode: 'none'
        }
      ];
      this.activeTabIndex = 0;
      this.persistTabs();
      return;
    }

    this.tabs.splice(index, 1);
    if (this.activeTabIndex >= this.tabs.length) {
      this.activeTabIndex = this.tabs.length - 1;
    }
    this.persistTabs();
  }

  selectTab(index: number) {
    if (index >= 0 && index < this.tabs.length) {
      this.activeTabIndex = index;
      this.persistTabs();
    }
  }

  updateContent(newContent: string) {
    const tab = this.activeTab;
    if (tab && tab.content !== newContent) {
      tab.content = newContent;
      tab.is_dirty = true;
      this.debounceAutoPersist();
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
    }
  }

  async saveCurrentTab(customPath?: string) {
    const tab = this.activeTab;
    if (!tab) return;

    this.isSaving = true;
    try {
      const path = customPath || tab.file_path;
      if (path) {
        await ipc.writeFile(path, tab.content);
        tab.file_path = path;
        tab.title = path.split(/[\\/]/).pop() || tab.title;
        tab.file_extension = path.split('.').pop() || tab.file_extension;
        tab.is_dirty = false;
        tab.is_scratchpad = false;
        this.lastSavedAt = new Date().toLocaleTimeString();
        this.persistTabs();
      }
    } catch (e) {
      console.error('Error saving file:', e);
    } finally {
      this.isSaving = false;
    }
  }

  async openFile(path: string) {
    try {
      const payload = await ipc.readFile(path);
      const existingIndex = this.tabs.findIndex(t => t.file_path === path);
      
      if (existingIndex >= 0) {
        this.activeTabIndex = existingIndex;
        return;
      }

      const newTab: TabState = {
        file_path: payload.file_path,
        title: payload.file_name,
        file_extension: payload.file_extension,
        content: payload.content,
        is_active: true,
        is_dirty: false,
        is_scratchpad: false,
        cursor_line: 1,
        cursor_col: 1,
        split_mode: payload.file_extension === 'md' ? 'split-horizontal' : 'none'
      };

      this.tabs.push(newTab);
      this.activeTabIndex = this.tabs.length - 1;
      this.persistTabs();
    } catch (e) {
      console.error('Error opening file:', e);
    }
  }

  private debounceTimer: any = null;
  private debounceAutoPersist() {
    if (this.debounceTimer) clearTimeout(this.debounceTimer);
    this.debounceTimer = setTimeout(() => {
      this.persistTabs();
    }, 1500);
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
