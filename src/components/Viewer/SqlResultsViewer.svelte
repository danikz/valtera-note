<script lang="ts">
  import { open } from '@tauri-apps/plugin-dialog';
  import { editorStore } from '../../stores/editorStore.svelte';
  import { ipc } from '../../services/ipc';
  import type { SqlResult } from '../../types';
  import { Play, Sparkles, Database, FolderOpen, AlertCircle, CheckCircle2 } from 'lucide-svelte';

  let dbPath = $state<string>('');
  let isExecuting = $state<boolean>(false);
  let sqlResult = $state<SqlResult | null>(null);
  let errorMessage = $state<string | null>(null);

  const isTauri = typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;

  async function handleSelectDb() {
    if (!isTauri) {
      dbPath = '/mock/sample.db';
      return;
    }
    const selected = await open({
      multiple: false,
      filters: [
        { name: 'SQLite Database', extensions: ['db', 'sqlite', 'sqlite3', 'db3'] },
        { name: 'All Files', extensions: ['*'] }
      ]
    });
    if (selected && typeof selected === 'string') {
      dbPath = selected;
    }
  }

  export async function executeQuery() {
    const tab = editorStore.activeTab;
    if (!tab || !tab.content.trim()) return;

    if (!dbPath) {
      errorMessage = 'Please select a local SQLite database file (.db / .sqlite) to query.';
      return;
    }

    isExecuting = true;
    errorMessage = null;

    try {
      const result = await ipc.executeSqlQuery(dbPath, tab.content);
      sqlResult = result;
    } catch (e: any) {
      errorMessage = e?.toString() || 'SQL execution failed';
      sqlResult = null;
    } finally {
      isExecuting = false;
    }
  }

  async function handleFormatSql() {
    const tab = editorStore.activeTab;
    if (!tab) return;
    try {
      const formatted = await ipc.formatSqlQuery(tab.content);
      editorStore.updateContent(formatted);
    } catch (e) {
      console.error('Format failed:', e);
    }
  }
</script>

<div class="h-full w-full flex flex-col bg-slate-900/40 border-l border-slate-800 select-text">
  <!-- SQL Action Toolbar -->
  <div class="h-10 bg-slate-900 border-b border-slate-800 flex items-center justify-between px-3 text-xs">
    <!-- Left: Target DB selector -->
    <div class="flex items-center space-x-2 flex-1 max-w-md">
      <Database class="w-3.5 h-3.5 text-blue-400 flex-shrink-0" />
      <input 
        type="text" 
        bind:value={dbPath} 
        placeholder="Select local .sqlite / .db database..."
        class="bg-slate-950 border border-slate-800 rounded px-2 py-1 text-xs text-slate-200 placeholder-slate-500 w-full focus:outline-none focus:border-blue-500 font-mono"
      />
      <button 
        onclick={handleSelectDb}
        class="p-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-300 transition-colors flex-shrink-0"
        title="Browse Database File"
      >
        <FolderOpen class="w-3.5 h-3.5" />
      </button>
    </div>

    <!-- Right: Run & Format Buttons -->
    <div class="flex items-center space-x-2">
      <button 
        onclick={handleFormatSql}
        class="flex items-center space-x-1 px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-300 transition-colors font-medium"
        title="Beautify / Format SQL"
      >
        <Sparkles class="w-3 h-3 text-amber-400" />
        <span>Format</span>
      </button>

      <button 
        onclick={executeQuery}
        disabled={isExecuting}
        class="flex items-center space-x-1 px-3 py-1 rounded bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white font-medium shadow-sm transition-colors"
        title="Execute Query (Ctrl+Enter)"
      >
        <Play class="w-3 h-3 fill-current" />
        <span>{isExecuting ? 'Running...' : 'Run Query'}</span>
      </button>
    </div>
  </div>

  <!-- Results Content Area -->
  <div class="flex-1 overflow-auto p-3">
    {#if errorMessage}
      <div class="p-3 bg-red-950/40 border border-red-800/60 rounded text-red-300 text-xs flex items-start space-x-2">
        <AlertCircle class="w-4 h-4 text-red-400 flex-shrink-0 mt-0.5" />
        <div>
          <div class="font-semibold mb-0.5">Execution Error</div>
          <div class="font-mono">{errorMessage}</div>
        </div>
      </div>
    {:else if sqlResult}
      <!-- Success Header -->
      <div class="flex items-center justify-between text-xs text-slate-400 mb-2 pb-1 border-b border-slate-800">
        <div class="flex items-center space-x-1.5 text-emerald-400 font-medium">
          <CheckCircle2 class="w-3.5 h-3.5" />
          <span>{sqlResult.affected_rows} rows retrieved</span>
        </div>
        <div class="font-mono text-slate-500">
          Duration: {sqlResult.duration_ms} ms
        </div>
      </div>

      <!-- Data Table -->
      {#if sqlResult.rows.length > 0}
        <div class="overflow-x-auto border border-slate-800 rounded">
          <table class="w-full text-xs text-left border-collapse font-mono">
            <thead class="bg-slate-950 text-slate-300 font-semibold border-b border-slate-800 sticky top-0">
              <tr>
                <th class="py-1.5 px-3 border-r border-slate-800 text-slate-500 w-10 text-center">#</th>
                {#each sqlResult.columns as col}
                  <th class="py-1.5 px-3 border-r border-slate-800 last:border-r-0 whitespace-nowrap">{col}</th>
                {/each}
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-800/60 bg-slate-900/30">
              {#each sqlResult.rows as row, rIdx}
                <tr class="hover:bg-slate-800/50 transition-colors">
                  <td class="py-1 px-3 border-r border-slate-800 text-slate-500 text-center select-none">{rIdx + 1}</td>
                  {#each row as cell}
                    <td class="py-1 px-3 border-r border-slate-800 last:border-r-0 whitespace-nowrap text-slate-300">
                      {cell === null ? 'NULL' : typeof cell === 'object' ? JSON.stringify(cell) : cell}
                    </td>
                  {/each}
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      {:else}
        <div class="text-xs text-slate-500 italic p-4 text-center">
          Query executed successfully with zero rows returned.
        </div>
      {/if}
    {:else}
      <div class="h-full flex flex-col items-center justify-center text-slate-500 text-xs space-y-2">
        <Database class="w-8 h-8 text-slate-700" />
        <p>Select a database and press <kbd class="px-1.5 py-0.5 bg-slate-800 rounded text-slate-400 font-mono">Run Query</kbd> (Ctrl+Enter)</p>
      </div>
    {/if}
  </div>
</div>
