<script lang="ts">
  import { onMount } from 'svelte';
  import Titlebar from './components/Titlebar/Titlebar.svelte';
  import TabBar from './components/Tabs/TabBar.svelte';
  import CodeEditor from './components/Editor/CodeEditor.svelte';
  import MarkdownViewer from './components/Viewer/MarkdownViewer.svelte';
  import SqlResultsViewer from './components/Viewer/SqlResultsViewer.svelte';
  import StatusBar from './components/StatusBar/StatusBar.svelte';
  import SyncModal from './components/Sync/SyncModal.svelte';
  import SnippetDrawer from './components/Snippets/SnippetDrawer.svelte';
  import CommandPalette from './components/CommandPalette/CommandPalette.svelte';
  import { editorStore } from './stores/editorStore.svelte';

  let isSyncModalOpen = $state(false);
  let isSnippetsOpen = $state(false);
  let isCommandPaletteOpen = $state(false);
  let sqlViewerRef = $state<any>(null);

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
    // Ctrl+\ -> Toggle Split Mode
    else if ((e.ctrlKey || e.metaKey) && e.key === '\\') {
      e.preventDefault();
      const current = editorStore.activeTab?.split_mode;
      editorStore.setSplitMode(current === 'split-horizontal' ? 'editor-only' : 'split-horizontal');
    }
  }

  onMount(() => {
    window.addEventListener('keydown', handleGlobalKeyDown);
    return () => {
      window.removeEventListener('keydown', handleGlobalKeyDown);
    };
  });
</script>

<main class="h-screen w-screen flex flex-col bg-slate-950 text-slate-100 overflow-hidden font-sans select-none">
  <!-- Frameless Custom Titlebar -->
  <Titlebar 
    onOpenSyncModal={() => (isSyncModalOpen = true)}
    onOpenSnippetsModal={() => (isSnippetsOpen = true)}
    onOpenCommandPalette={() => (isCommandPaletteOpen = true)}
  />

  <!-- Multi-Tab Bar -->
  <TabBar />

  <!-- Main Work Area (Split / Single / Reader Mode) -->
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

      <!-- 4. Default / Editor Only Mode -->
      {:else}
        <div class="w-full h-full">
          <CodeEditor />
        </div>
      {/if}
    {:else}
      <!-- Empty state fallback -->
      <div class="h-full w-full flex items-center justify-center text-slate-500 text-sm">
        No tabs open
      </div>
    {/if}
  </div>

  <!-- Bottom Status Bar -->
  <StatusBar />

  <!-- Appwrite Cloud Sync Modal -->
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
  />
</main>
