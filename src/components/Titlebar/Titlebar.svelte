<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { getCurrentWindow } from '@tauri-apps/api/window';
  import { open, save } from '@tauri-apps/plugin-dialog';
  import { editorStore } from '../../stores/editorStore.svelte';
  import { 
    Plus, 
    FolderOpen, 
    Save, 
    Minus, 
    Square, 
    X, 
    Cloud, 
    CheckCircle2, 
    Search, 
    Sparkles,
    BookOpen,
    RefreshCw,
    PanelLeft,
    Smile,
    Settings,
    Palette,
    FileCode,
    Binary,
    Globe,
    Key,
    Layers,
    Database,
    Download,
    LogOut,
    ChevronDown,
    Info,
    Image as ImageIcon
  } from 'lucide-svelte';

  export type ToolType = 'json' | 'sqlite' | 'favicon' | 'mysql-password' | 'base64' | 'url' | 'uuid';

  let { 
    onOpenSyncModal, 
    onOpenSnippetsModal, 
    onOpenCommandPalette,
    onOpenEmojiPicker,
    onOpenTool,
    onOpenAbout,
    onOpenSettings,
    onSwitchToNotes,
    onToggleSidebar,
    isSidebarOpen = true,
    activeView = 'notes',
    activeTool = 'json'
  }: { 
    onOpenSyncModal: () => void; 
    onOpenSnippetsModal: () => void; 
    onOpenCommandPalette: () => void; 
    onOpenEmojiPicker?: () => void;
    onOpenTool?: (tool: ToolType) => void;
    onOpenAbout?: () => void;
    onOpenSettings?: (tab?: 'supabase' | 'appearance' | 'editor' | 'about') => void;
    onSwitchToNotes?: () => void;
    onToggleSidebar?: () => void;
    isSidebarOpen?: boolean;
    activeView?: 'notes' | 'tools' | 'settings';
    activeTool?: ToolType;
  } = $props();

  let openMenu = $state<'file' | 'edit' | 'tools' | 'help' | null>(null);

  function handleMenuClick(menu: 'file' | 'edit' | 'tools' | 'help') {
    openMenu = openMenu === menu ? null : menu;
  }

  function handleMenuHover(menu: 'file' | 'edit' | 'tools' | 'help') {
    if (openMenu !== null) {
      openMenu = menu;
    }
  }

  function closeMenu() {
    openMenu = null;
  }

  let isMaximized = $state(false);
  let unlistenResize: (() => void) | undefined;

  async function updateMaximizedState() {
    try {
      const win = getWindow();
      if (win) {
        isMaximized = await win.isMaximized();
      }
    } catch {
      // ignore
    }
  }

  onMount(() => {
    window.addEventListener('click', closeMenu);
    updateMaximizedState();

    (async () => {
      try {
        const win = getWindow();
        if (win && typeof win.onResized === 'function') {
          unlistenResize = await win.onResized(() => {
            updateMaximizedState();
          });
        }
      } catch {
        // ignore in non-tauri environment
      }
    })();

    return () => {
      if (unlistenResize) unlistenResize();
    };
  });

  onDestroy(() => {
    if (typeof window !== 'undefined') {
      window.removeEventListener('click', closeMenu);
    }
    if (unlistenResize) unlistenResize();
  });

  function getWindow() {
    try {
      return getCurrentWindow();
    } catch {
      return null;
    }
  }

  async function handleMinimize() {
    try {
      const win = getWindow();
      if (win) await win.minimize();
    } catch (e) {
      console.warn('Minimize not available:', e);
    }
  }

  async function handleToggleMaximize() {
    try {
      const win = getWindow();
      if (win) {
        await win.toggleMaximize();
        setTimeout(updateMaximizedState, 60);
      }
    } catch (e) {
      console.warn('Maximize not available:', e);
    }
  }

  async function handleClose() {
    try {
      const win = getWindow();
      if (win) await win.close();
    } catch (e) {
      console.warn('Close not available:', e);
    }
  }

  async function handleOpenFile() {
    try {
      const selected = await open({
        multiple: false,
        filters: [
          { name: 'All Supported', extensions: ['txt', 'md', 'sql', 'json', 'csv', 'rs', 'ts', 'js', 'py', 'log'] },
          { name: 'Markdown', extensions: ['md', 'markdown'] },
          { name: 'SQL Scripts', extensions: ['sql'] },
          { name: 'All Files', extensions: ['*'] }
        ]
      });
      if (selected && typeof selected === 'string') {
        editorStore.openFile(selected);
      }
    } catch (e) {
      console.warn('Open dialog fallback:', e);
      editorStore.openFile('/mock/notes.md');
    }
  }

  async function handleSaveFile() {
    await editorStore.saveCurrentTab();
  }

  async function handleExportFile() {
    const tab = editorStore.activeTab;
    if (!tab) return;

    try {
      const selected = await save({
        defaultPath: tab.title.includes('.') ? tab.title : `${tab.title}.${tab.file_extension}`,
        filters: [
          { name: 'Markdown', extensions: ['md'] },
          { name: 'SQL', extensions: ['sql'] },
          { name: 'Text File', extensions: ['txt'] },
          { name: 'All Files', extensions: ['*'] }
        ]
      });
      if (selected && typeof selected === 'string') {
        await editorStore.saveCurrentTab(selected);
      }
    } catch (e) {
      console.warn('Export dialog fallback:', e);
    }
  }
</script>

<div 
  class="h-9 bg-slate-900 border-b border-slate-800 flex items-center justify-between pl-2 pr-0 select-none z-40" 
  data-tauri-drag-region 
  ondblclick={handleToggleMaximize}
>
  <!-- Left: App Icon, Brand, Sidebar Toggle & Desktop Menu Bar -->
  <div class="flex items-center space-x-2 pointer-events-auto flex-shrink-0">
    <div class="flex items-center space-x-2 px-2 py-0.5 rounded bg-blue-600/10 text-blue-300 border border-blue-500/20 text-xs font-semibold flex-shrink-0">
      <img src="/logo.png" alt="Valtera Logo" class="w-4 h-4 object-contain" />
      <span>Valtera Note</span>
    </div>

    <!-- Sidebar Toggle (Right above the sidebar) -->
    {#if onToggleSidebar}
      <button 
        onclick={onToggleSidebar}
        class="h-6 w-6 flex items-center justify-center rounded-md border transition-all cursor-pointer {isSidebarOpen ? 'bg-blue-600/20 border-blue-500/30 text-blue-400 hover:bg-blue-600/30' : 'bg-slate-950/60 border-slate-800/80 text-slate-400 hover:text-slate-200 hover:bg-slate-800/80'}"
        title="Bilah Sisi / Sidebar (Ctrl+B)"
      >
        <PanelLeft class="w-3.5 h-3.5" />
      </button>
    {/if}

    <div class="h-3.5 w-px bg-slate-800"></div>

    <!-- Classic Desktop Menu Bar (File, Edit, Tools, Bantuan) -->
    <div class="flex items-center space-x-0.5 text-xs text-slate-300 font-sans relative">
      <!-- File Menu -->
      <div class="relative">
        <button 
          onclick={(e) => { e.stopPropagation(); handleMenuClick('file'); }}
          onmouseenter={() => handleMenuHover('file')}
          class="px-2 py-0.5 rounded text-xs transition-colors cursor-pointer {openMenu === 'file' ? 'bg-slate-800 text-white font-medium' : 'text-slate-300 hover:bg-slate-800/60 hover:text-white'}"
        >
          File
        </button>

        {#if openMenu === 'file'}
          <div 
            class="absolute top-full left-0 mt-1 min-w-[240px] bg-slate-900 border border-slate-800 rounded-xl shadow-2xl py-1.5 z-50 text-xs text-slate-200 animate-in fade-in duration-100 whitespace-nowrap"
            onclick={(e) => e.stopPropagation()}
            role="menu"
            tabindex="-1"
          >
            <button onclick={() => { if (onSwitchToNotes) onSwitchToNotes(); editorStore.addTab(); closeMenu(); }} class="w-full px-3 py-1.5 flex items-center justify-between hover:bg-slate-800 text-left cursor-pointer transition-colors whitespace-nowrap">
              <span class="flex items-center space-x-2 whitespace-nowrap"><Plus class="w-3.5 h-3.5 text-slate-400 flex-shrink-0" /><span>Catatan Baru</span></span>
              <kbd class="text-[10px] text-slate-500 font-mono ml-4 flex-shrink-0">Ctrl+N</kbd>
            </button>
            <button onclick={() => { if (onSwitchToNotes) onSwitchToNotes(); handleOpenFile(); closeMenu(); }} class="w-full px-3 py-1.5 flex items-center justify-between hover:bg-slate-800 text-left cursor-pointer transition-colors whitespace-nowrap">
              <span class="flex items-center space-x-2 whitespace-nowrap"><FolderOpen class="w-3.5 h-3.5 text-slate-400 flex-shrink-0" /><span>Buka File...</span></span>
              <kbd class="text-[10px] text-slate-500 font-mono ml-4 flex-shrink-0">Ctrl+O</kbd>
            </button>
            <button onclick={() => { handleSaveFile(); closeMenu(); }} class="w-full px-3 py-1.5 flex items-center justify-between hover:bg-slate-800 text-left cursor-pointer transition-colors whitespace-nowrap">
              <span class="flex items-center space-x-2 whitespace-nowrap"><Save class="w-3.5 h-3.5 text-slate-400 flex-shrink-0" /><span>Simpan</span></span>
              <kbd class="text-[10px] text-slate-500 font-mono ml-4 flex-shrink-0">Ctrl+S</kbd>
            </button>
            <button onclick={() => { handleExportFile(); closeMenu(); }} class="w-full px-3 py-1.5 flex items-center space-x-2 hover:bg-slate-800 text-left cursor-pointer transition-colors whitespace-nowrap">
              <Download class="w-3.5 h-3.5 text-slate-400 flex-shrink-0" /><span>Ekspor Catatan...</span>
            </button>
            <div class="my-1 border-t border-slate-800"></div>
            <button onclick={() => { if (editorStore.activeTab) editorStore.closeTab(editorStore.activeTabIndex); closeMenu(); }} class="w-full px-3 py-1.5 flex items-center justify-between hover:bg-slate-800 text-left cursor-pointer transition-colors whitespace-nowrap">
              <span class="flex items-center space-x-2 whitespace-nowrap"><X class="w-3.5 h-3.5 text-slate-400 flex-shrink-0" /><span>Tutup Tab</span></span>
              <kbd class="text-[10px] text-slate-500 font-mono ml-4 flex-shrink-0">Ctrl+W</kbd>
            </button>
            <button onclick={() => { editorStore.closeAllTabs(); closeMenu(); }} class="w-full px-3 py-1.5 flex items-center justify-between hover:bg-red-500/10 hover:text-red-400 text-left cursor-pointer transition-colors whitespace-nowrap">
              <span class="flex items-center space-x-2 whitespace-nowrap"><Layers class="w-3.5 h-3.5 flex-shrink-0" /><span>Tutup Semua Tab</span></span>
              <kbd class="text-[10px] text-slate-500 font-mono ml-4 flex-shrink-0">Ctrl+Shift+W</kbd>
            </button>
            <div class="my-1 border-t border-slate-800"></div>
            <button onclick={() => { if (onOpenSettings) onOpenSettings('appearance'); closeMenu(); }} class="w-full px-3 py-1.5 flex items-center justify-between hover:bg-slate-800 text-left cursor-pointer transition-colors whitespace-nowrap">
              <span class="flex items-center space-x-2 whitespace-nowrap"><Settings class="w-3.5 h-3.5 text-slate-400 flex-shrink-0" /><span>Pengaturan...</span></span>
              <kbd class="text-[10px] text-slate-500 font-mono ml-4 flex-shrink-0">Ctrl+,</kbd>
            </button>
            <div class="my-1 border-t border-slate-800"></div>
            <button onclick={() => { handleClose(); closeMenu(); }} class="w-full px-3 py-1.5 flex items-center space-x-2 hover:bg-red-500/10 hover:text-red-400 text-left cursor-pointer transition-colors whitespace-nowrap">
              <LogOut class="w-3.5 h-3.5 flex-shrink-0" /><span>Keluar</span>
            </button>
          </div>
        {/if}
      </div>

      <!-- Edit Menu -->
      <div class="relative">
        <button 
          onclick={(e) => { e.stopPropagation(); handleMenuClick('edit'); }}
          onmouseenter={() => handleMenuHover('edit')}
          class="px-2 py-0.5 rounded text-xs transition-colors cursor-pointer {openMenu === 'edit' ? 'bg-slate-800 text-white font-medium' : 'text-slate-300 hover:bg-slate-800/60 hover:text-white'}"
        >
          Edit
        </button>

        {#if openMenu === 'edit'}
          <div 
            class="absolute top-full left-0 mt-1 min-w-[280px] bg-slate-900 border border-slate-800 rounded-xl shadow-2xl py-1.5 z-50 text-xs text-slate-200 animate-in fade-in duration-100 whitespace-nowrap"
            onclick={(e) => e.stopPropagation()}
            role="menu"
            tabindex="-1"
          >
            {#if onOpenEmojiPicker}
              <button onclick={() => { onOpenEmojiPicker(); closeMenu(); }} class="w-full px-3 py-1.5 flex items-center justify-between hover:bg-slate-800 text-left cursor-pointer transition-colors whitespace-nowrap">
                <span class="flex items-center space-x-2 whitespace-nowrap"><Smile class="w-3.5 h-3.5 text-blue-400 flex-shrink-0" /><span>Sisipkan Emoji & Icon</span></span>
                <kbd class="text-[10px] text-slate-500 font-mono ml-4 flex-shrink-0">Ctrl+Shift+E</kbd>
              </button>
            {/if}
            <button onclick={() => { onOpenSnippetsModal(); closeMenu(); }} class="w-full px-3 py-1.5 flex items-center justify-between hover:bg-slate-800 text-left cursor-pointer transition-colors whitespace-nowrap">
              <span class="flex items-center space-x-2 whitespace-nowrap"><BookOpen class="w-3.5 h-3.5 text-amber-400 flex-shrink-0" /><span>Kamus Sintaks & Perintah</span></span>
              <kbd class="text-[10px] text-slate-500 font-mono ml-4 flex-shrink-0">Ctrl+Shift+T</kbd>
            </button>
            <button onclick={() => { onOpenCommandPalette(); closeMenu(); }} class="w-full px-3 py-1.5 flex items-center justify-between hover:bg-slate-800 text-left cursor-pointer transition-colors whitespace-nowrap">
              <span class="flex items-center space-x-2 whitespace-nowrap"><Search class="w-3.5 h-3.5 text-slate-400 flex-shrink-0" /><span>Command Palette</span></span>
              <kbd class="text-[10px] text-slate-500 font-mono ml-4 flex-shrink-0">Ctrl+K</kbd>
            </button>
            <div class="my-1 border-t border-slate-800"></div>
            <button onclick={() => { editorStore.setSplitMode('editor-only'); closeMenu(); }} class="w-full px-3 py-1.5 flex items-center space-x-2 hover:bg-slate-800 text-left cursor-pointer transition-colors whitespace-nowrap">
              <span>Mode Editor Penuh</span>
            </button>
            <button onclick={() => { editorStore.setSplitMode('split-horizontal'); closeMenu(); }} class="w-full px-3 py-1.5 flex items-center justify-between hover:bg-slate-800 text-left cursor-pointer transition-colors whitespace-nowrap">
              <span>Split Mode (Editor + Live)</span>
              <kbd class="text-[10px] text-slate-500 font-mono ml-4 flex-shrink-0">Ctrl+\</kbd>
            </button>
            <button onclick={() => { editorStore.setSplitMode('preview-only'); closeMenu(); }} class="w-full px-3 py-1.5 flex items-center space-x-2 hover:bg-slate-800 text-left cursor-pointer transition-colors whitespace-nowrap">
              <span>Reader Mode (Preview Only)</span>
            </button>
          </div>
        {/if}
      </div>

      <!-- Tools Menu (Requested by User) -->
      <div class="relative">
        <button 
          onclick={(e) => { e.stopPropagation(); handleMenuClick('tools'); }}
          onmouseenter={() => handleMenuHover('tools')}
          class="px-2 py-0.5 rounded text-xs transition-colors cursor-pointer flex items-center space-x-1 {openMenu === 'tools' ? 'bg-slate-800 text-white font-medium' : 'text-slate-300 hover:bg-slate-800/60 hover:text-white'}"
        >
          <span>Tools</span>
          <span class="w-1.5 h-1.5 rounded-full bg-blue-400"></span>
        </button>

        {#if openMenu === 'tools'}
          <div 
            class="absolute top-full left-0 mt-1 w-max min-w-[360px] bg-slate-900 border border-slate-800 rounded-xl shadow-2xl py-1.5 z-50 text-xs text-slate-200 animate-in fade-in duration-100 whitespace-nowrap"
            onclick={(e) => e.stopPropagation()}
            role="menu"
            tabindex="-1"
          >
            <div class="px-3.5 py-1 text-[10px] font-mono text-slate-500 uppercase tracking-wider whitespace-nowrap">
              Developer Tools
            </div>

            <!-- JSON, Tabel & CSV Studio -->
            <button 
              onclick={() => { if (onOpenTool) onOpenTool('json'); closeMenu(); }} 
              class="w-full px-3.5 py-1.5 flex items-center justify-between hover:bg-blue-600/20 hover:text-blue-300 text-left cursor-pointer transition-colors whitespace-nowrap {activeView === 'tools' && activeTool === 'json' ? 'text-blue-400 bg-blue-600/10 font-medium' : ''}"
            >
              <span class="flex items-center space-x-2.5 whitespace-nowrap shrink-0">
                <FileCode class="w-3.5 h-3.5 text-blue-400 shrink-0" />
                <span class="font-medium whitespace-nowrap">JSON, Tabel & CSV</span>
              </span>
              <kbd class="text-[10px] text-slate-500 font-mono ml-6 shrink-0 whitespace-nowrap">Ctrl+Shift+J</kbd>
            </button>

            <!-- Pembaca SQLite (Studio) -->
            <button 
              onclick={() => { if (onOpenTool) onOpenTool('sqlite'); closeMenu(); }} 
              class="w-full px-3.5 py-1.5 flex items-center justify-between hover:bg-indigo-600/20 hover:text-indigo-300 text-left cursor-pointer transition-colors whitespace-nowrap {activeView === 'tools' && activeTool === 'sqlite' ? 'text-indigo-400 bg-indigo-600/10 font-medium' : ''}"
            >
              <span class="flex items-center space-x-2.5 whitespace-nowrap shrink-0">
                <Database class="w-3.5 h-3.5 text-indigo-400 shrink-0" />
                <span class="font-medium whitespace-nowrap">Pembaca SQLite (Studio)</span>
              </span>
              <kbd class="text-[10px] text-slate-500 font-mono ml-6 shrink-0 whitespace-nowrap">Ctrl+Shift+D</kbd>
            </button>

            <!-- Favicon Generator -->
            <button 
              onclick={() => { if (onOpenTool) onOpenTool('favicon'); closeMenu(); }} 
              class="w-full px-3.5 py-1.5 flex items-center justify-between hover:bg-amber-600/20 hover:text-amber-300 text-left cursor-pointer transition-colors whitespace-nowrap {activeView === 'tools' && activeTool === 'favicon' ? 'text-amber-400 bg-amber-600/10 font-medium' : ''}"
            >
              <span class="flex items-center space-x-2.5 whitespace-nowrap shrink-0">
                <ImageIcon class="w-3.5 h-3.5 text-amber-400 shrink-0" />
                <span class="font-medium whitespace-nowrap">Favicon Generator</span>
              </span>
              <kbd class="text-[10px] text-slate-500 font-mono ml-6 shrink-0 whitespace-nowrap">Ctrl+Shift+F</kbd>
            </button>

            <!-- MySQL Password Generator -->
            <button 
              onclick={() => { if (onOpenTool) onOpenTool('mysql-password'); closeMenu(); }} 
              class="w-full px-3.5 py-1.5 flex items-center justify-between hover:bg-emerald-600/20 hover:text-emerald-300 text-left cursor-pointer transition-colors whitespace-nowrap {activeView === 'tools' && activeTool === 'mysql-password' ? 'text-emerald-400 bg-emerald-600/10 font-medium' : ''}"
            >
              <span class="flex items-center space-x-2.5 whitespace-nowrap shrink-0">
                <Database class="w-3.5 h-3.5 text-emerald-400 shrink-0" />
                <span class="font-medium whitespace-nowrap">MySQL Password Generator</span>
              </span>
              <kbd class="text-[10px] text-slate-500 font-mono ml-6 shrink-0 whitespace-nowrap">Ctrl+Shift+P</kbd>
            </button>

            <!-- Base64 Converter -->
            <button 
              onclick={() => { if (onOpenTool) onOpenTool('base64'); closeMenu(); }} 
              class="w-full px-3.5 py-1.5 flex items-center justify-between hover:bg-slate-800 text-left cursor-pointer transition-colors whitespace-nowrap {activeView === 'tools' && activeTool === 'base64' ? 'text-cyan-400 bg-cyan-600/10 font-medium' : ''}"
            >
              <span class="flex items-center space-x-2.5 whitespace-nowrap shrink-0">
                <Binary class="w-3.5 h-3.5 text-cyan-400 shrink-0" />
                <span class="whitespace-nowrap">Base64 Encoder / Decoder</span>
              </span>
            </button>

            <!-- URL Encoder/Decoder -->
            <button 
              onclick={() => { if (onOpenTool) onOpenTool('url'); closeMenu(); }} 
              class="w-full px-3.5 py-1.5 flex items-center justify-between hover:bg-slate-800 text-left cursor-pointer transition-colors whitespace-nowrap {activeView === 'tools' && activeTool === 'url' ? 'text-purple-400 bg-purple-600/10 font-medium' : ''}"
            >
              <span class="flex items-center space-x-2.5 whitespace-nowrap shrink-0">
                <Globe class="w-3.5 h-3.5 text-purple-400 shrink-0" />
                <span class="whitespace-nowrap">URL Encoder / Decoder</span>
              </span>
            </button>

            <!-- UUID Generator -->
            <button 
              onclick={() => { if (onOpenTool) onOpenTool('uuid'); closeMenu(); }} 
              class="w-full px-3.5 py-1.5 flex items-center justify-between hover:bg-slate-800 text-left cursor-pointer transition-colors whitespace-nowrap {activeView === 'tools' && activeTool === 'uuid' ? 'text-amber-400 bg-amber-600/10 font-medium' : ''}"
            >
              <span class="flex items-center space-x-2.5 whitespace-nowrap shrink-0">
                <Key class="w-3.5 h-3.5 text-amber-400 shrink-0" />
                <span class="whitespace-nowrap">UUID Generator (Batch)</span>
              </span>
            </button>
          </div>
        {/if}
      </div>

      <!-- Help Menu -->
      <div class="relative">
        <button 
          onclick={(e) => { e.stopPropagation(); handleMenuClick('help'); }}
          onmouseenter={() => handleMenuHover('help')}
          class="px-2 py-0.5 rounded text-xs transition-colors cursor-pointer {openMenu === 'help' ? 'bg-slate-800 text-white font-medium' : 'text-slate-300 hover:bg-slate-800/60 hover:text-white'}"
        >
          Bantuan
        </button>

        {#if openMenu === 'help'}
          <div 
            class="absolute top-full left-0 mt-1 min-w-[260px] bg-slate-900 border border-slate-800 rounded-xl shadow-2xl py-1.5 z-50 text-xs text-slate-200 animate-in fade-in duration-100 whitespace-nowrap"
            onclick={(e) => e.stopPropagation()}
            role="menu"
            tabindex="-1"
          >
            <button 
              onclick={() => { if (onOpenSettings) onOpenSettings('about'); else if (onOpenAbout) onOpenAbout(); closeMenu(); }} 
              class="w-full px-3 py-1.5 flex items-center justify-between hover:bg-slate-800 text-left cursor-pointer transition-colors whitespace-nowrap"
            >
              <span class="flex items-center space-x-2 whitespace-nowrap">
                <Info class="w-3.5 h-3.5 text-blue-400 flex-shrink-0" />
                <span>Tentang Valtera Note</span>
              </span>
              <span class="text-[10px] text-blue-300 bg-blue-500/10 px-1.5 py-0.5 rounded border border-blue-500/20 font-mono ml-4 flex-shrink-0">v0.1.8</span>
            </button>
            <button onclick={async () => { const { updaterService } = await import('../../services/updater.svelte'); await updaterService.checkForUpdates(true); closeMenu(); }} class="w-full px-3 py-1.5 flex items-center space-x-2 hover:bg-slate-800 text-left cursor-pointer transition-colors whitespace-nowrap">
              <RefreshCw class="w-3.5 h-3.5 text-slate-400 flex-shrink-0" />
              <span>Periksa Pembaruan...</span>
            </button>
            <button onclick={() => { onOpenCommandPalette(); closeMenu(); }} class="w-full px-3 py-1.5 flex items-center justify-between hover:bg-slate-800 text-left cursor-pointer transition-colors whitespace-nowrap">
              <span class="flex items-center space-x-2 whitespace-nowrap"><Search class="w-3.5 h-3.5 text-slate-400 flex-shrink-0" /><span>Pintasan Keyboard</span></span>
              <kbd class="text-[10px] text-slate-500 font-mono ml-4 flex-shrink-0">Ctrl+K</kbd>
            </button>
          </div>
        {/if}
      </div>
    </div>
  </div>

  <!-- Center: Command Palette Trigger Bar (Click to search or Ctrl+K) -->
  <button 
    onclick={onOpenCommandPalette}
    class="flex items-center space-x-2 px-3 py-1 rounded bg-slate-950/70 hover:bg-slate-800/80 border border-slate-800/80 text-xs text-slate-400 hover:text-slate-200 transition-colors cursor-pointer pointer-events-auto max-w-xs w-full justify-between mx-2"
    title="Search commands and features (Ctrl+K)"
  >
    <div class="flex items-center space-x-1.5 truncate">
      <Search class="w-3 h-3 text-slate-500" />
      <span class="truncate">{editorStore.activeTab ? editorStore.activeTab.title : 'Search or type a command...'}</span>
    </div>
    <kbd class="px-1.5 py-0.2 bg-slate-900 border border-slate-700/80 rounded text-[10px] text-slate-400 font-mono">Ctrl+K</kbd>
  </button>

  <!-- Right: Quick Action Groups, Supabase Sync Status & Window Buttons -->
  <div class="flex items-center space-x-1.5 pointer-events-auto flex-shrink-0">
    <!-- Group: File Operations (New, Open, Save) -->
    <div class="flex items-center bg-slate-950/60 border border-slate-800/80 rounded-md p-0.5 space-x-0.5">
      <button 
        onclick={() => {
          if (onSwitchToNotes) onSwitchToNotes();
          editorStore.addTab();
        }}
        class="h-5.5 w-5.5 flex items-center justify-center rounded hover:bg-slate-800 text-slate-400 hover:text-slate-200 transition-colors cursor-pointer"
        title="Catatan Baru (Ctrl+N)"
      >
        <Plus class="w-3.5 h-3.5" />
      </button>

      <button 
        onclick={() => {
          if (onSwitchToNotes) onSwitchToNotes();
          handleOpenFile();
        }}
        class="h-5.5 w-5.5 flex items-center justify-center rounded hover:bg-slate-800 text-slate-400 hover:text-slate-200 transition-colors cursor-pointer"
        title="Buka File... (Ctrl+O)"
      >
        <FolderOpen class="w-3.5 h-3.5" />
      </button>

      <button 
        onclick={handleSaveFile}
        class="h-5.5 w-5.5 flex items-center justify-center rounded hover:bg-slate-800 text-slate-400 hover:text-slate-200 transition-colors relative cursor-pointer"
        title={editorStore.supabaseConfig.is_configured ? "Simpan & Sinkronkan Supabase (Ctrl+S)" : "Simpan Catatan (Ctrl+S)"}
      >
        <Save class="w-3.5 h-3.5" />
        {#if editorStore.activeTab?.is_dirty}
          <span class="absolute top-0.5 right-0.5 w-1.5 h-1.5 bg-amber-400 rounded-full animate-pulse"></span>
        {/if}
      </button>
    </div>

    <!-- Group: Editor Content Helpers (Emoji, Snippets) -->
    <div class="flex items-center bg-slate-950/60 border border-slate-800/80 rounded-md p-0.5 space-x-0.5">
      {#if onOpenEmojiPicker}
        <button 
          onclick={onOpenEmojiPicker}
          class="h-5.5 w-5.5 flex items-center justify-center rounded hover:bg-slate-800 text-slate-400 hover:text-blue-300 transition-colors cursor-pointer"
          title="Sisipkan Emoji & Icon (Ctrl+Shift+E)"
        >
          <Smile class="w-3.5 h-3.5" />
        </button>
      {/if}

      <button 
        onclick={onOpenSnippetsModal}
        class="h-5.5 w-5.5 flex items-center justify-center rounded hover:bg-slate-800 text-slate-400 hover:text-amber-300 transition-colors cursor-pointer"
        title="Kamus Sintaks & Perintah (Markdown, SQL, JSON) (Ctrl+Shift+T)"
      >
        <BookOpen class="w-3.5 h-3.5" />
      </button>
    </div>


    <!-- Group: Unified Settings Switcher -->
    {#if onOpenSettings}
      <button 
        onclick={() => {
          if (activeView === 'settings') {
            if (onSwitchToNotes) onSwitchToNotes();
          } else {
            onOpenSettings('appearance');
          }
        }}
        class="h-6 px-2 flex items-center space-x-1.5 rounded-md border text-xs font-medium transition-all cursor-pointer {activeView === 'settings' ? 'bg-indigo-600/25 text-indigo-300 border-indigo-500/40 shadow-xs' : 'bg-slate-950/60 border-slate-800/80 hover:border-slate-700 hover:bg-slate-800/60 text-slate-400 hover:text-indigo-300'}"
        title={activeView === 'settings' ? 'Kembali ke Catatan (Esc)' : 'Pengaturan Aplikasi, Supabase & Tema (Ctrl+,)'}
      >
        <Settings class="w-3 h-3" />
        <span class="text-[11px]">Settings</span>
      </button>
    {/if}

    <!-- Supabase Sync Button -->
    <button 
      onclick={() => {
        if (onOpenSettings) onOpenSettings('supabase');
        else onOpenSyncModal();
      }}
      class="flex items-center space-x-1 px-2 py-0.5 rounded text-xs hover:bg-slate-800 transition-colors {editorStore.isSyncing ? 'text-blue-400' : editorStore.supabaseConfig.is_configured ? 'text-emerald-400' : 'text-slate-400'}"
      title={editorStore.isSyncing ? 'Auto-syncing with cloud...' : editorStore.supabaseConfig.is_configured ? `Auto-sync active (Last synced: ${editorStore.lastSyncedAt || 'just now'})` : 'Supabase Cloud Sync Settings'}
    >
      {#if editorStore.isSyncing}
        <RefreshCw class="w-3.5 h-3.5 text-blue-400 animate-spin" />
        <span class="hidden xl:inline text-[11px] text-blue-300">Syncing...</span>
      {:else if editorStore.supabaseConfig.is_configured}
        <CheckCircle2 class="w-3.5 h-3.5 text-emerald-400" />
        <span class="hidden xl:inline text-[11px]">Synced</span>
      {:else}
        <Cloud class="w-3.5 h-3.5 text-slate-500" />
        <span class="hidden xl:inline text-[11px] text-slate-500">Sync</span>
      {/if}
    </button>

    <!-- Window Management Buttons (Windows 11 / Modern Desktop Frameless Controls) -->
    <div class="flex items-center h-full ml-1 border-l border-slate-800/80">
      <button 
        onclick={handleMinimize}
        class="h-full w-11 flex items-center justify-center text-slate-400 hover:text-slate-100 hover:bg-slate-800/80 transition-colors cursor-pointer window-ctrl-btn"
        title="Minimize"
        aria-label="Minimize"
      >
        <Minus class="w-3.5 h-3.5" />
      </button>

      <button 
        onclick={handleToggleMaximize}
        class="h-full w-11 flex items-center justify-center text-slate-400 hover:text-slate-100 hover:bg-slate-800/80 transition-colors cursor-pointer window-ctrl-btn"
        title={isMaximized ? "Restore Down" : "Maximize"}
        aria-label={isMaximized ? "Restore Down" : "Maximize"}
      >
        {#if isMaximized}
          <!-- Restore Icon (Two overlapping squares) -->
          <svg class="w-3.5 h-3.5 stroke-current" viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="7" y="3" width="14" height="14" rx="1" />
            <path d="M3 7v14h14" />
          </svg>
        {:else}
          <!-- Maximize Icon (Single square) -->
          <Square class="w-3 h-3" />
        {/if}
      </button>

      <button 
        onclick={handleClose}
        class="h-full w-11 flex items-center justify-center text-slate-400 hover:text-white hover:bg-red-600 transition-colors cursor-pointer window-close-btn"
        title="Close"
        aria-label="Close"
      >
        <X class="w-3.5 h-3.5" />
      </button>
    </div>
  </div>
</div>
