<script lang="ts">
  import { onMount } from 'svelte';
  import { open } from '@tauri-apps/plugin-dialog';
  import { listen } from '@tauri-apps/api/event';
  import { ipc } from './services/ipc';
  import { 
    Plus, 
    FolderOpen, 
    Sparkles, 
    Search, 
    FileText, 
    Database, 
    Keyboard, 
    Layers,
    Command
  } from 'lucide-svelte';
  import Titlebar from './components/Titlebar/Titlebar.svelte';
  import Sidebar from './components/Sidebar/Sidebar.svelte';
  import TabBar from './components/Tabs/TabBar.svelte';
  import CodeEditor from './components/Editor/CodeEditor.svelte';
  import MarkdownViewer from './components/Viewer/MarkdownViewer.svelte';
  import SqlResultsViewer from './components/Viewer/SqlResultsViewer.svelte';
  import JsonTreeViewer from './components/Viewer/JsonTreeViewer.svelte';
  import StatusBar from './components/StatusBar/StatusBar.svelte';
  import SyncModal from './components/Sync/SyncModal.svelte';
  import SnippetDrawer from './components/Snippets/SnippetDrawer.svelte';
  import CommandPalette from './components/CommandPalette/CommandPalette.svelte';
  import UpdateModal from './components/Update/UpdateModal.svelte';
  import { editorStore } from './stores/editorStore.svelte';
  import { updaterService } from './services/updater';

  let isSidebarOpen = $state(true);
  let isSyncModalOpen = $state(false);
  let isSnippetsOpen = $state(false);
  let isCommandPaletteOpen = $state(false);
  let sqlViewerRef = $state<any>(null);

  async function handleOpenFile() {
    try {
      const selected = await open({
        multiple: false,
        filters: [
          { name: 'All Supported', extensions: ['txt', 'md', 'sql', 'json', 'csv', 'rs', 'ts', 'js', 'py', 'log', 'env', 'yml', 'yaml'] },
          { name: 'JSON Files', extensions: ['json'] },
          { name: 'Text Documents', extensions: ['txt', 'text'] },
          { name: 'Markdown', extensions: ['md', 'markdown'] },
          { name: 'SQL Scripts', extensions: ['sql'] },
          { name: 'All Files', extensions: ['*'] }
        ]
      });
      if (selected && typeof selected === 'string') {
        editorStore.openFile(selected);
      }
    } catch (e) {
      console.warn('Open file error:', e);
    }
  }

  function handleRunSqlFromShortcut() {
    if (sqlViewerRef && typeof sqlViewerRef.executeQuery === 'function') {
      sqlViewerRef.executeQuery();
    }
  }

  function handleGlobalKeyDown(e: KeyboardEvent) {
    // Ctrl+K or Cmd+K -> Command Palette
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
      e.preventDefault();
      isCommandPaletteOpen = !isCommandPaletteOpen;
    }
    // Ctrl+B or Cmd+B -> Toggle Sidebar
    else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'b') {
      e.preventDefault();
      isSidebarOpen = !isSidebarOpen;
    }
    // Ctrl+Shift+T -> Snippets Drawer
    else if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key.toLowerCase() === 't') {
      e.preventDefault();
      isSnippetsOpen = !isSnippetsOpen;
    }
    // Ctrl+N -> New Tab
    else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'n' && !e.shiftKey) {
      e.preventDefault();
      editorStore.addTab();
    }
    // Ctrl+O -> Open File
    else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'o' && !e.shiftKey) {
      e.preventDefault();
      handleOpenFile();
    }
    // Ctrl+S -> Save / Cloud Sync
    else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's' && !e.shiftKey) {
      e.preventDefault();
      editorStore.saveCurrentTab();
    }
    // Ctrl+\ -> Toggle Split Mode
    else if ((e.ctrlKey || e.metaKey) && e.key === '\\') {
      e.preventDefault();
      const current = editorStore.activeTab?.split_mode;
      editorStore.setSplitMode(current === 'split-horizontal' ? 'editor-only' : 'split-horizontal');
    }
  }

  onMount(() => {
    window.addEventListener('keydown', handleGlobalKeyDown);

    // 1. Check if launched with a file argument (Open With or Double-click)
    (async () => {
      try {
        const fileToOpen = await ipc.getCliOpenFile();
        if (fileToOpen) {
          editorStore.openFile(fileToOpen);
        }
      } catch (err) {
        console.warn('Check initial CLI file error:', err);
      }
    })();

    // 2. Listen for files opened while app is running (Single Instance event)
    let unlisten: (() => void) | undefined;
    (async () => {
      try {
        unlisten = await listen<string>('open-file-path', (event) => {
          if (event.payload) {
            editorStore.openFile(event.payload);
          }
        });
      } catch {
        // ignore if not running in tauri
      }
    })();

    // 3. Automatic check for mandatory/critical updates (2.5s after launch)
    const updateTimer = setTimeout(() => {
      updaterService.checkForUpdates();
    }, 2500);

    return () => {
      window.removeEventListener('keydown', handleGlobalKeyDown);
      if (unlisten) unlisten();
      clearTimeout(updateTimer);
    };
  });
</script>

<main class="h-screen w-screen flex flex-col bg-slate-950 text-slate-100 overflow-hidden font-sans select-none">
  <!-- Frameless Custom Titlebar -->
  <Titlebar 
    onOpenSyncModal={() => (isSyncModalOpen = true)}
    onOpenSnippetsModal={() => (isSnippetsOpen = true)}
    onOpenCommandPalette={() => (isCommandPaletteOpen = true)}
    onToggleSidebar={() => (isSidebarOpen = !isSidebarOpen)}
    isSidebarOpen={isSidebarOpen}
  />

  <!-- Main Work Area (Sidebar + Tabs Workspace) -->
  <div class="flex-1 flex overflow-hidden relative">
    <!-- Left Navigation & Tab Search Sidebar -->
    <Sidebar 
      isOpen={isSidebarOpen} 
      onToggle={() => (isSidebarOpen = !isSidebarOpen)} 
    />

    <!-- Editor Workspace (Tabs + Editor/Viewer) -->
    <div class="flex-1 flex flex-col overflow-hidden relative">
      <!-- Multi-Tab Bar -->
      <TabBar />

      <!-- Main Editor / Viewer Area -->
      <div class="flex-1 flex overflow-hidden relative">
        {#if editorStore.activeTab}
          {@const tab = editorStore.activeTab}
          {@const ext = tab.file_extension.toLowerCase()}
          {@const split = tab.split_mode}

          <!-- 1. Markdown Split View -->
          {#if ext === 'md' && split === 'split-horizontal'}
            <div class="w-1/2 h-full border-r border-slate-800">
              <CodeEditor />
            </div>
            <div class="w-1/2 h-full">
              <MarkdownViewer />
            </div>

          <!-- 2. Markdown Preview Only (Reader Mode) -->
          {:else if ext === 'md' && split === 'preview-only'}
            <div class="w-full h-full">
              <MarkdownViewer />
            </div>

          <!-- 3. SQL Split View (Editor + Query Runner) -->
          {:else if ext === 'sql' && split === 'split-horizontal'}
            <div class="w-1/2 h-full border-r border-slate-800">
              <CodeEditor onRunSql={handleRunSqlFromShortcut} />
            </div>
            <div class="w-1/2 h-full">
              <SqlResultsViewer bind:this={sqlViewerRef} />
            </div>

          <!-- 4. JSON Split View (Editor + Collapsible JSON Tree Viewer) -->
          {:else if ext === 'json' && split === 'split-horizontal'}
            <div class="w-1/2 h-full border-r border-slate-800">
              <CodeEditor />
            </div>
            <div class="w-1/2 h-full">
              <JsonTreeViewer />
            </div>

          <!-- 5. JSON Tree Only Mode (Reader Mode) -->
          {:else if ext === 'json' && split === 'preview-only'}
            <div class="w-full h-full">
              <JsonTreeViewer />
            </div>

          <!-- 6. Default / Editor Only Mode -->
          {:else}
            <div class="w-full h-full">
              <CodeEditor />
            </div>
          {/if}
        {:else}
          <!-- Premium Clean Empty State (Tanpa Lembar Kosong) -->
          <div class="h-full w-full flex flex-col items-center justify-center p-6 bg-radial from-slate-900/60 to-slate-950 text-slate-300">
            <div class="max-w-md w-full flex flex-col items-center text-center space-y-6 animate-in fade-in zoom-in-95 duration-200">
              
              <!-- Logo & Brand Badge -->
              <div class="relative group">
                <div class="absolute -inset-1 bg-gradient-to-r from-blue-600 to-indigo-600 rounded-2xl blur-md opacity-30 group-hover:opacity-60 transition duration-300"></div>
                <div class="relative w-16 h-16 rounded-2xl bg-slate-900 border border-slate-800 flex items-center justify-center p-2.5 shadow-2xl">
                  <img src="/logo.png" alt="Valtera Logo" class="w-full h-full object-contain" />
                </div>
              </div>

              <!-- Title & Tagline -->
              <div class="space-y-1">
                <h2 class="text-xl font-bold text-slate-100 tracking-tight flex items-center justify-center space-x-2">
                  <span>Valtera Note</span>
                  <span class="px-2 py-0.5 text-[10px] font-mono font-medium rounded-full bg-blue-500/10 text-blue-400 border border-blue-500/20">
                    Local-First
                  </span>
                </h2>
                <p class="text-xs text-slate-400 max-w-sm">
                  Tidak ada catatan yang sedang terbuka. Mulai buat catatan baru atau pilih file untuk dibuka.
                </p>
              </div>

              <!-- Quick Action Cards Grid -->
              <div class="grid grid-cols-2 gap-2.5 w-full pt-1">
                <!-- Action 1: New Note -->
                <button
                  onclick={() => editorStore.addTab()}
                  class="flex flex-col items-start p-3 rounded-xl bg-slate-900/80 hover:bg-slate-850 border border-slate-800/90 hover:border-blue-500/50 text-left transition-all group cursor-pointer shadow-lg hover:shadow-blue-500/5"
                >
                  <div class="w-8 h-8 rounded-lg bg-blue-500/10 border border-blue-500/20 flex items-center justify-center text-blue-400 mb-2 group-hover:scale-105 transition-transform">
                    <Plus class="w-4 h-4" />
                  </div>
                  <div class="font-semibold text-xs text-slate-200 group-hover:text-blue-300 flex items-center justify-between w-full">
                    <span>Catatan Baru</span>
                    <kbd class="text-[9px] font-mono px-1.5 py-0.5 rounded bg-slate-950 border border-slate-800 text-slate-400">Ctrl+N</kbd>
                  </div>
                  <span class="text-[10.5px] text-slate-500 mt-0.5">Markdown / SQL / Teks</span>
                </button>

                <!-- Action 2: Open File -->
                <button
                  onclick={handleOpenFile}
                  class="flex flex-col items-start p-3 rounded-xl bg-slate-900/80 hover:bg-slate-850 border border-slate-800/90 hover:border-amber-500/50 text-left transition-all group cursor-pointer shadow-lg hover:shadow-amber-500/5"
                >
                  <div class="w-8 h-8 rounded-lg bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400 mb-2 group-hover:scale-105 transition-transform">
                    <FolderOpen class="w-4 h-4" />
                  </div>
                  <div class="font-semibold text-xs text-slate-200 group-hover:text-amber-300 flex items-center justify-between w-full">
                    <span>Buka File</span>
                    <kbd class="text-[9px] font-mono px-1.5 py-0.5 rounded bg-slate-950 border border-slate-800 text-slate-400">Ctrl+O</kbd>
                  </div>
                  <span class="text-[10.5px] text-slate-500 mt-0.5">Buka file dari komputer</span>
                </button>

                <!-- Action 3: Browse Templates -->
                <button
                  onclick={() => (isSnippetsOpen = true)}
                  class="flex flex-col items-start p-3 rounded-xl bg-slate-900/80 hover:bg-slate-850 border border-slate-800/90 hover:border-emerald-500/50 text-left transition-all group cursor-pointer shadow-lg hover:shadow-emerald-500/5"
                >
                  <div class="w-8 h-8 rounded-lg bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center text-emerald-400 mb-2 group-hover:scale-105 transition-transform">
                    <Sparkles class="w-4 h-4" />
                  </div>
                  <div class="font-semibold text-xs text-slate-200 group-hover:text-emerald-300 flex items-center justify-between w-full">
                    <span>Template</span>
                    <kbd class="text-[9px] font-mono px-1.5 py-0.5 rounded bg-slate-950 border border-slate-800 text-slate-400">Ctrl+⇧+T</kbd>
                  </div>
                  <span class="text-[10.5px] text-slate-500 mt-0.5">Snippet SQL & Markdown</span>
                </button>

                <!-- Action 4: Command Palette -->
                <button
                  onclick={() => (isCommandPaletteOpen = true)}
                  class="flex flex-col items-start p-3 rounded-xl bg-slate-900/80 hover:bg-slate-850 border border-slate-800/90 hover:border-indigo-500/50 text-left transition-all group cursor-pointer shadow-lg hover:shadow-indigo-500/5"
                >
                  <div class="w-8 h-8 rounded-lg bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400 mb-2 group-hover:scale-105 transition-transform">
                    <Command class="w-4 h-4" />
                  </div>
                  <div class="font-semibold text-xs text-slate-200 group-hover:text-indigo-300 flex items-center justify-between w-full">
                    <span>Perintah</span>
                    <kbd class="text-[9px] font-mono px-1.5 py-0.5 rounded bg-slate-950 border border-slate-800 text-slate-400">Ctrl+K</kbd>
                  </div>
                  <span class="text-[10.5px] text-slate-500 mt-0.5">Semua fitur & pintasan</span>
                </button>
              </div>

              <!-- Shortcut hints footer -->
              <div class="pt-2 border-t border-slate-800/70 w-full flex items-center justify-center space-x-4 text-[11px] text-slate-500 font-mono">
                <span class="flex items-center space-x-1">
                  <kbd class="px-1 py-0.2 rounded bg-slate-900 border border-slate-800 text-slate-400">Ctrl+B</kbd>
                  <span>Sidebar</span>
                </span>
                <span>•</span>
                <span class="flex items-center space-x-1">
                  <kbd class="px-1 py-0.2 rounded bg-slate-900 border border-slate-800 text-slate-400">Ctrl+N</kbd>
                  <span>Catatan Baru</span>
                </span>
                <span>•</span>
                <span class="flex items-center space-x-1">
                  <kbd class="px-1 py-0.2 rounded bg-slate-900 border border-slate-800 text-slate-400">Ctrl+K</kbd>
                  <span>Cari</span>
                </span>
              </div>

            </div>
          </div>
        {/if}
      </div>
    </div>
  </div>

  <!-- Bottom Status Bar -->
  <StatusBar />

  <!-- Supabase Cloud Sync Modal -->
  <SyncModal 
    isOpen={isSyncModalOpen} 
    onClose={() => (isSyncModalOpen = false)} 
  />

  <!-- Snippets & Templates Drawer -->
  <SnippetDrawer 
    isOpen={isSnippetsOpen} 
    onClose={() => (isSnippetsOpen = false)} 
  />

  <!-- Command Palette Modal (Ctrl+K) -->
  <CommandPalette 
    isOpen={isCommandPaletteOpen}
    onClose={() => (isCommandPaletteOpen = false)}
    onOpenSync={() => (isSyncModalOpen = true)}
    onOpenSnippets={() => (isSnippetsOpen = true)}
    onRunSql={handleRunSqlFromShortcut}
    onToggleSidebar={() => (isSidebarOpen = !isSidebarOpen)}
  />

  <!-- Mandatory / Automated Update Modal -->
  <UpdateModal />
</main>
