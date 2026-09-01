<script lang="ts">
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
    RefreshCw,
    PanelLeft
  } from 'lucide-svelte';

  let { 
    onOpenSyncModal, 
    onOpenSnippetsModal, 
    onOpenCommandPalette,
    onToggleSidebar,
    isSidebarOpen = true
  }: { 
    onOpenSyncModal: () => void; 
    onOpenSnippetsModal: () => void; 
    onOpenCommandPalette: () => void; 
    onToggleSidebar?: () => void;
    isSidebarOpen?: boolean;
  } = $props();

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
      if (win) await win.toggleMaximize();
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

<div class="h-9 bg-slate-900 border-b border-slate-800 flex items-center justify-between px-2 select-none z-40" data-tauri-drag-region>
  <!-- Left: App Icon & Brand -->
  <div class="flex items-center space-x-2 pointer-events-auto">
    <div class="flex items-center space-x-2 px-2 py-0.5 rounded bg-blue-600/10 text-blue-300 border border-blue-500/20 text-xs font-semibold">
      <img src="/logo.png" alt="Valtera Logo" class="w-4 h-4 object-contain" />
      <span>Valtera Note</span>
    </div>

    <!-- Quick Tools -->
    <div class="flex items-center space-x-1 pl-2 border-l border-slate-800">
      {#if onToggleSidebar}
        <button 
          onclick={onToggleSidebar}
          class="p-1 rounded hover:bg-slate-800 {isSidebarOpen ? 'text-blue-400 bg-blue-600/10' : 'text-slate-400'} hover:text-slate-200 transition-colors"
          title="Toggle Sidebar (Ctrl+B)"
        >
          <PanelLeft class="w-3.5 h-3.5" />
        </button>
      {/if}

      <button 
        onclick={() => editorStore.addTab()}
        class="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-slate-200 transition-colors"
        title="New Tab (Ctrl+N)"
      >
        <Plus class="w-3.5 h-3.5" />
      </button>

      <button 
        onclick={handleOpenFile}
        class="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-slate-200 transition-colors"
        title="Open File (Ctrl+O)"
      >
        <FolderOpen class="w-3.5 h-3.5" />
      </button>

      <button 
        onclick={handleSaveFile}
        class="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-slate-200 transition-colors relative"
        title={editorStore.supabaseConfig.is_configured ? "Save & Sync to Supabase (Ctrl+S)" : "Save Note (Ctrl+S)"}
      >
        <Save class="w-3.5 h-3.5" />
        {#if editorStore.activeTab?.is_dirty}
          <span class="absolute top-1 right-1 w-1.5 h-1.5 bg-amber-400 rounded-full animate-pulse"></span>
        {/if}
      </button>

      <button 
        onclick={onOpenSnippetsModal}
        class="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-amber-300 transition-colors"
        title="Snippets & Templates (Ctrl+Shift+T)"
      >
        <Sparkles class="w-3.5 h-3.5" />
      </button>
    </div>
  </div>

  <!-- Center: Command Palette Trigger Bar (Click to search or Ctrl+K) -->
  <button 
    onclick={onOpenCommandPalette}
    class="flex items-center space-x-2 px-3 py-1 rounded bg-slate-950/70 hover:bg-slate-800/80 border border-slate-800/80 text-xs text-slate-400 hover:text-slate-200 transition-colors cursor-pointer pointer-events-auto max-w-xs w-full justify-between"
    title="Search commands and features (Ctrl+K)"
  >
    <div class="flex items-center space-x-1.5 truncate">
      <Search class="w-3 h-3 text-slate-500" />
      <span class="truncate">{editorStore.activeTab ? editorStore.activeTab.title : 'Search or type a command...'}</span>
    </div>
    <kbd class="px-1.5 py-0.2 bg-slate-900 border border-slate-700/80 rounded text-[10px] text-slate-400 font-mono">Ctrl+K</kbd>
  </button>

  <!-- Right: Supabase Sync Status & Window Buttons -->
  <div class="flex items-center space-x-1 pointer-events-auto">
    <!-- Supabase Sync Button -->
    <button 
      onclick={onOpenSyncModal}
      class="flex items-center space-x-1 px-2 py-0.5 rounded text-xs hover:bg-slate-800 transition-colors {editorStore.isSyncing ? 'text-blue-400' : editorStore.supabaseConfig.is_configured ? 'text-emerald-400' : 'text-slate-400'}"
      title={editorStore.isSyncing ? 'Auto-syncing with cloud...' : editorStore.supabaseConfig.is_configured ? `Auto-sync active (Last synced: ${editorStore.lastSyncedAt || 'just now'})` : 'Supabase Cloud Sync Settings'}
    >
      {#if editorStore.isSyncing}
        <RefreshCw class="w-3.5 h-3.5 text-blue-400 animate-spin" />
        <span class="hidden md:inline text-[11px] text-blue-300">Syncing...</span>
      {:else if editorStore.supabaseConfig.is_configured}
        <CheckCircle2 class="w-3.5 h-3.5 text-emerald-400" />
        <span class="hidden md:inline text-[11px]">Synced</span>
      {:else}
        <Cloud class="w-3.5 h-3.5 text-slate-500" />
        <span class="hidden md:inline text-[11px] text-slate-500">Sync</span>
      {/if}
    </button>

    <!-- Window Management Buttons -->
    <div class="flex items-center ml-2 border-l border-slate-800 pl-1">
      <button 
        onclick={handleMinimize}
        class="w-7 h-7 flex items-center justify-center hover:bg-slate-800 text-slate-400 hover:text-slate-200 rounded transition-colors"
        title="Minimize"
      >
        <Minus class="w-3.5 h-3.5" />
      </button>

      <button 
        onclick={handleToggleMaximize}
        class="w-7 h-7 flex items-center justify-center hover:bg-slate-800 text-slate-400 hover:text-slate-200 rounded transition-colors"
        title="Maximize"
      >
        <Square class="w-3 h-3" />
      </button>

      <button 
        onclick={handleClose}
        class="w-7 h-7 flex items-center justify-center hover:bg-red-600/80 text-slate-400 hover:text-white rounded transition-colors"
        title="Close"
      >
        <X class="w-3.5 h-3.5" />
      </button>
    </div>
  </div>
</div>
