<script lang="ts">
  import { onMount } from 'svelte';
  import { open } from '@tauri-apps/plugin-dialog';
  import { 
    Database, 
    FolderOpen, 
    RefreshCw, 
    Search, 
    Table, 
    Play, 
    Sparkles, 
    Copy, 
    Check, 
    Download, 
    FileText, 
    FileSpreadsheet, 
    ExternalLink, 
    Layers, 
    Key, 
    AlertCircle, 
    CheckCircle2, 
    ArrowUpDown, 
    ChevronLeft, 
    ChevronRight, 
    Code, 
    Upload,
    SlidersHorizontal,
    HardDrive
  } from 'lucide-svelte';
  import { ipc } from '../../services/ipc';
  import { editorStore } from '../../stores/editorStore.svelte';
  import type { TableSummary, TableColumn, SqlResult } from '../../types';

  let { onBack, showBackButton = false }: { onBack?: () => void; showBackButton?: boolean } = $props();

  // Database Connection State
  let dbPath = $state<string>('');
  let isLoadingDb = $state<boolean>(false);
  let dbError = $state<string | null>(null);
  let tables = $state<TableSummary[]>([]);
  let selectedTableName = $state<string>('');
  let tableSearchFilter = $state<string>('');

  // Main View Mode: 'browse' (Table Data Grid) | 'query' (SQL Console) | 'schema' (DDL & Structure)
  let activeTab = $state<'browse' | 'query' | 'schema'>('browse');

  // Table Data Browser State
  let tableData = $state<SqlResult | null>(null);
  let isLoadingData = $state<boolean>(false);
  let rowSearchFilter = $state<string>('');
  let sortColumn = $state<string | null>(null);
  let sortDirection = $state<'asc' | 'desc'>('asc');
  let currentPage = $state<number>(1);
  let rowsPerPage = $state<number>(100);

  // SQL Console / Scratchpad State
  let customQuery = $state<string>('SELECT * FROM notes LIMIT 50;');
  let isExecutingQuery = $state<boolean>(false);
  let queryResult = $state<SqlResult | null>(null);
  let queryError = $state<string | null>(null);

  // General Toast State
  let copiedToast = $state<string | null>(null);
  let isDragging = $state<boolean>(false);

  // Selected Table Metadata helper
  let selectedTableMeta = $derived(tables.find(t => t.name === selectedTableName) || null);

  // Filtered Tables in Sidebar
  let filteredTables = $derived(
    tables.filter(t => t.name.toLowerCase().includes(tableSearchFilter.toLowerCase().trim()))
  );

  // Filtered & Sorted Rows in Data Browser
  let processedRows = $derived(() => {
    if (!tableData || !tableData.rows) return [];
    let rows = [...tableData.rows];
    const columns = tableData.columns || [];

    // Filter by row search query
    if (rowSearchFilter.trim()) {
      const q = rowSearchFilter.toLowerCase().trim();
      rows = rows.filter(r => r.some(cell => String(cell ?? '').toLowerCase().includes(q)));
    }

    // Sort by column
    if (sortColumn !== null) {
      const colIdx = columns.indexOf(sortColumn);
      if (colIdx !== -1) {
        rows.sort((a, b) => {
          const valA = a[colIdx];
          const valB = b[colIdx];
          if (valA === valB) return 0;
          if (valA === null || valA === undefined) return 1;
          if (valB === null || valB === undefined) return -1;
          if (typeof valA === 'number' && typeof valB === 'number') {
            return sortDirection === 'asc' ? valA - valB : valB - valA;
          }
          return sortDirection === 'asc' 
            ? String(valA).localeCompare(String(valB)) 
            : String(valB).localeCompare(String(valA));
        });
      }
    }

    return rows;
  });

  function showToast(msg: string) {
    copiedToast = msg;
    setTimeout(() => {
      if (copiedToast === msg) copiedToast = null;
    }, 1800);
  }

  // Load Database and inspect schema
  async function loadDatabase(path: string) {
    if (!path || !path.trim()) return;
    dbPath = path.trim();
    isLoadingDb = true;
    dbError = null;
    tables = [];
    selectedTableName = '';
    tableData = null;

    try {
      const result = await ipc.inspectSqliteTables(dbPath);
      tables = result;
      if (tables.length > 0) {
        // Auto select first non-system table
        const firstTable = tables.find(t => !t.name.startsWith('sqlite_')) || tables[0];
        selectTable(firstTable.name);
      }
      showToast(`Database berhasil dimuat (${tables.length} tabel)`);
    } catch (err: any) {
      console.error('Failed to load sqlite db:', err);
      dbError = err?.toString() || 'Gagal membaca berkas database SQLite.';
    } finally {
      isLoadingDb = false;
    }
  }

  // Select a table and browse its data
  async function selectTable(name: string) {
    selectedTableName = name;
    currentPage = 1;
    sortColumn = null;
    rowSearchFilter = '';
    customQuery = `SELECT * FROM "${name.replace(/"/g, '""')}" LIMIT 100;`;
    await fetchTableData();
  }

  async function fetchTableData() {
    if (!dbPath || !selectedTableName) return;
    isLoadingData = true;
    dbError = null;

    const offset = (currentPage - 1) * rowsPerPage;
    const query = `SELECT * FROM "${selectedTableName.replace(/"/g, '""')}" LIMIT ${rowsPerPage} OFFSET ${offset};`;

    try {
      const res = await ipc.executeSqlQuery(dbPath, query, rowsPerPage);
      tableData = res;
    } catch (e: any) {
      console.error('Fetch table data error:', e);
      tableData = null;
    } finally {
      isLoadingData = false;
    }
  }

  // Execute Custom Query in Console
  async function executeCustomQuery() {
    if (!dbPath) {
      queryError = 'Silakan pilih berkas database SQLite terlebih dahulu.';
      return;
    }
    if (!customQuery.trim()) return;

    isExecutingQuery = true;
    queryError = null;

    try {
      const res = await ipc.executeSqlQuery(dbPath, customQuery.trim(), 500);
      queryResult = res;
      if (!res.success && res.error_message) {
        queryError = res.error_message;
      }
    } catch (e: any) {
      queryError = e?.toString() || 'Query execution failed';
      queryResult = null;
    } finally {
      isExecutingQuery = false;
    }
  }

  // Browse SQLite File dialog
  async function handleBrowseFile() {
    try {
      const selected = await open({
        multiple: false,
        filters: [
          { name: 'SQLite Database', extensions: ['db', 'sqlite', 'sqlite3', 'db3', 'sqlitedb'] },
          { name: 'Semua Berkas', extensions: ['*'] }
        ]
      });
      if (selected && typeof selected === 'string') {
        loadDatabase(selected);
      }
    } catch (err) {
      console.warn('Browse db cancelled or failed:', err);
    }
  }

  // Open Valtera Note's Internal DB
  async function handleOpenInternalDb() {
    try {
      const internalPath = await ipc.getInternalDbPath();
      if (internalPath) {
        loadDatabase(internalPath);
      } else {
        showToast('Tidak dapat menemukan lokasi basis data lokal Valtera Note.');
      }
    } catch (e) {
      console.error('Error fetching internal db path:', e);
    }
  }

  // Format SQL Query
  async function handleFormatQuery() {
    if (!customQuery.trim()) return;
    try {
      const formatted = await ipc.formatSqlQuery(customQuery);
      customQuery = formatted;
    } catch (e) {
      console.error('Format SQL error:', e);
    }
  }

  // Sort toggle
  function handleSort(colName: string) {
    if (sortColumn === colName) {
      sortDirection = sortDirection === 'asc' ? 'desc' : 'asc';
    } else {
      sortColumn = colName;
      sortDirection = 'asc';
    }
  }

  // Copy Cell
  async function handleCopyCell(val: any) {
    if (val === null || val === undefined) return;
    try {
      await navigator.clipboard.writeText(String(val));
      showToast('Nilai sel disalin!');
    } catch (e) {
      console.warn('Copy failed:', e);
    }
  }

  // Export Table Data to CSV
  function handleExportCsv() {
    const data = activeTab === 'query' ? queryResult : tableData;
    if (!data || !data.columns || !data.rows) {
      showToast('Tidak ada data untuk diekspor.');
      return;
    }
    const cols = data.columns.map(c => `"${c.replace(/"/g, '""')}"`).join(',');
    const rows = data.rows.map(r => 
      r.map(cell => {
        if (cell === null || cell === undefined) return '';
        const str = String(cell);
        return `"${str.replace(/"/g, '""')}"`;
      }).join(',')
    ).join('\n');

    const csvContent = `${cols}\n${rows}`;
    downloadFile(csvContent, `${selectedTableName || 'query_result'}.csv`, 'text/csv');
    showToast('Berkas CSV berhasil diekspor!');
  }

  // Export Table Data to JSON
  function handleExportJson() {
    const data = activeTab === 'query' ? queryResult : tableData;
    if (!data || !data.columns || !data.rows) {
      showToast('Tidak ada data untuk diekspor.');
      return;
    }
    const jsonObjects = data.rows.map(row => {
      const obj: Record<string, any> = {};
      data.columns.forEach((col, idx) => {
        obj[col] = row[idx];
      });
      return obj;
    });

    const jsonContent = JSON.stringify(jsonObjects, null, 2);
    downloadFile(jsonContent, `${selectedTableName || 'query_result'}.json`, 'application/json');
    showToast('Berkas JSON berhasil diekspor!');
  }

  // Export to Markdown Table
  function handleExportMarkdown() {
    const data = activeTab === 'query' ? queryResult : tableData;
    if (!data || !data.columns || !data.rows) {
      showToast('Tidak ada data untuk diekspor.');
      return;
    }
    const headers = `| ${data.columns.join(' | ')} |`;
    const separators = `| ${data.columns.map(() => '---').join(' | ')} |`;
    const rows = data.rows.map(row => 
      `| ${row.map(c => (c === null || c === undefined ? '*null*' : String(c).replace(/\|/g, '\\|'))).join(' | ')} |`
    ).join('\n');

    const mdTable = `${headers}\n${separators}\n${rows}`;
    navigator.clipboard.writeText(mdTable);
    showToast('Tabel Markdown tersalin ke clipboard!');
  }

  // Open query or table in editor tab
  function handleOpenInEditor() {
    const data = activeTab === 'query' ? queryResult : tableData;
    if (!data || !data.columns || !data.rows) return;

    const headers = `| ${data.columns.join(' | ')} |`;
    const separators = `| ${data.columns.map(() => '---').join(' | ')} |`;
    const rows = data.rows.map(row => 
      `| ${row.map(c => (c === null || c === undefined ? '*null*' : String(c).replace(/\|/g, '\\|'))).join(' | ')} |`
    ).join('\n');

    const content = `# 📊 Ekspor Data: ${selectedTableName || 'Hasil Query SQL'}\n\n**Total Data:** ${data.rows.length} baris | **Waktu Eksekusi:** ${data.duration_ms}ms\n\n${headers}\n${separators}\n${rows}\n`;
    editorStore.addTab(`${selectedTableName || 'query_data'}.md`, 'md', content);
    if (onBack) onBack();
  }

  function downloadFile(content: string, filename: string, mime: string) {
    const blob = new Blob([content], { type: mime });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  // Drag and Drop
  function handleDragOver(e: DragEvent) {
    e.preventDefault();
    isDragging = true;
  }

  function handleDragLeave() {
    isDragging = false;
  }

  function handleDrop(e: DragEvent) {
    e.preventDefault();
    isDragging = false;
    if (e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      const file = e.dataTransfer.files[0];
      // In Tauri, file object contains .path
      const path = (file as any).path || file.name;
      if (path) {
        loadDatabase(path);
      }
    }
  }

  // Generate DDL for Table
  let tableDdl = $derived(() => {
    if (!selectedTableMeta) return '';
    const cols = selectedTableMeta.columns.map(c => {
      let def = `  "${c.name}" ${c.col_type || 'TEXT'}`;
      if (c.pk) def += ' PRIMARY KEY';
      if (c.notnull) def += ' NOT NULL';
      if (c.dflt_value !== null && c.dflt_value !== undefined) def += ` DEFAULT ${c.dflt_value}`;
      return def;
    }).join(',\n');
    return `CREATE TABLE IF NOT EXISTS "${selectedTableMeta.name}" (\n${cols}\n);`;
  });

  onMount(async () => {
    // Check if internal DB exists and load by default if not set
    if (!dbPath) {
      try {
        const internal = await ipc.getInternalDbPath();
        if (internal) {
          loadDatabase(internal);
        }
      } catch (e) {
        console.warn('Auto-loading internal DB failed:', e);
      }
    }
  });
</script>

<div 
  class="h-full w-full flex flex-col bg-slate-950 text-slate-100 overflow-hidden select-none"
  ondragover={handleDragOver}
  ondragenter={handleDragOver}
  ondragleave={handleDragLeave}
  ondrop={handleDrop}
  role="region"
  aria-label="SQLite Studio Workspace"
>
  <!-- Top Control & Database Connection Bar -->
  <div class="h-12 bg-slate-900 border-b border-slate-800 flex items-center justify-between px-3 md:px-4 flex-shrink-0 z-10 gap-3">
    <!-- Left: Title & Back Button -->
    <div class="flex items-center space-x-2.5 min-w-0 flex-shrink-0">
      <div class="w-7 h-7 rounded-lg bg-indigo-500/15 border border-indigo-500/30 flex items-center justify-center text-indigo-400">
        <Database class="w-4 h-4" />
      </div>
      <div>
        <div class="flex items-center space-x-2">
          <span class="text-xs font-bold text-slate-100 whitespace-nowrap">Pembaca SQLite (Studio)</span>
          <span class="text-[9.5px] px-1.5 py-0.5 rounded bg-indigo-500/10 text-indigo-300 border border-indigo-500/20 font-mono hidden sm:inline">SQLite 3</span>
        </div>
      </div>
    </div>

    <!-- Center: Database Path Bar with Quick Browse and Internal DB Switcher -->
    <div class="flex items-center space-x-2 flex-1 max-w-xl mx-2 min-w-0">
      <div class="relative flex-1 min-w-0">
        <input 
          type="text"
          bind:value={dbPath}
          placeholder="Pilih berkas database SQLite (.db, .sqlite)..."
          class="w-full bg-slate-950 border border-slate-800 rounded-lg pl-3 pr-8 py-1 text-xs text-slate-200 placeholder-slate-500 focus:outline-none focus:border-indigo-500 font-mono truncate"
          onkeydown={(e) => { if (e.key === 'Enter') loadDatabase(dbPath); }}
        />
        {#if dbPath}
          <button 
            onclick={() => { navigator.clipboard.writeText(dbPath); showToast('Path database tersalin!'); }}
            class="absolute right-2 top-1.5 text-slate-400 hover:text-slate-200 transition-colors"
            title="Salin path database"
          >
            <Copy class="w-3.5 h-3.5" />
          </button>
        {/if}
      </div>

      <!-- Browse Button -->
      <button 
        onclick={handleBrowseFile}
        class="px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-slate-750 text-slate-200 border border-slate-700/80 text-xs font-medium flex items-center space-x-1.5 transition-colors cursor-pointer flex-shrink-0"
        title="Buka Berkas Database SQLite dari Disk"
      >
        <FolderOpen class="w-3.5 h-3.5 text-amber-400" />
        <span class="hidden md:inline">Buka Berkas</span>
      </button>

      <!-- Open Internal DB -->
      <button 
        onclick={handleOpenInternalDb}
        class="px-2.5 py-1 rounded-lg bg-indigo-600/20 hover:bg-indigo-600/30 text-indigo-300 border border-indigo-500/30 text-xs font-medium flex items-center space-x-1.5 transition-colors cursor-pointer flex-shrink-0"
        title="Buka Database Internal Catatan Valtera Note"
      >
        <HardDrive class="w-3.5 h-3.5 text-indigo-400" />
        <span class="hidden lg:inline">DB Valtera Note</span>
      </button>

      <!-- Reload Button -->
      {#if dbPath}
        <button 
          onclick={() => loadDatabase(dbPath)}
          class="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-750 text-slate-300 transition-colors cursor-pointer flex-shrink-0"
          title="Muat Ulang Database"
        >
          <RefreshCw class="w-3.5 h-3.5 {isLoadingDb ? 'animate-spin text-indigo-400' : ''}" />
        </button>
      {/if}
    </div>

    <!-- Right: Export / Back Action Buttons -->
    <div class="flex items-center space-x-1.5 flex-shrink-0">
      {#if tableData || queryResult}
        <button 
          onclick={handleExportCsv}
          class="p-1.5 rounded-lg hover:bg-slate-800 text-slate-400 hover:text-emerald-400 transition-colors cursor-pointer"
          title="Ekspor Data ke CSV"
        >
          <FileSpreadsheet class="w-4 h-4" />
        </button>
        <button 
          onclick={handleExportJson}
          class="p-1.5 rounded-lg hover:bg-slate-800 text-slate-400 hover:text-blue-400 transition-colors cursor-pointer"
          title="Ekspor Data ke JSON"
        >
          <Download class="w-4 h-4" />
        </button>
        <button 
          onclick={handleExportMarkdown}
          class="p-1.5 rounded-lg hover:bg-slate-800 text-slate-400 hover:text-amber-400 transition-colors cursor-pointer"
          title="Salin sebagai Tabel Markdown"
        >
          <FileText class="w-4 h-4" />
        </button>
        <button 
          onclick={handleOpenInEditor}
          class="px-2 py-1 rounded-lg bg-blue-600/20 hover:bg-blue-600/30 text-blue-300 border border-blue-500/30 text-xs font-medium flex items-center space-x-1 transition-colors cursor-pointer"
          title="Buka Data di Tab Catatan Editor"
        >
          <ExternalLink class="w-3.5 h-3.5" />
          <span class="hidden sm:inline">Buka di Editor</span>
        </button>
      {/if}
    </div>
  </div>

  <!-- Global Error Banner if DB cannot open -->
  {#if dbError}
    <div class="p-3 bg-rose-950/70 border-b border-rose-800 flex items-center justify-between text-xs text-rose-200 animate-in fade-in">
      <div class="flex items-center space-x-2">
        <AlertCircle class="w-4 h-4 text-rose-400 flex-shrink-0" />
        <span><strong>Gagal membuka SQLite:</strong> {dbError}</span>
      </div>
      <button onclick={() => (dbError = null)} class="p-1 text-rose-400 hover:text-white">✕</button>
    </div>
  {/if}

  <!-- Main Body: Split Sidebar (Tables) + Content Area -->
  <div class="flex-1 flex overflow-hidden">
    
    <!-- LEFT SIDEBAR: Table & View Explorer -->
    <aside class="w-60 md:w-64 bg-slate-900 border-r border-slate-800 flex flex-col flex-shrink-0 select-none">
      <!-- Search Tables Filter -->
      <div class="p-2.5 border-b border-slate-800 bg-slate-950/40">
        <div class="relative">
          <Search class="w-3.5 h-3.5 absolute left-2.5 top-2.5 text-slate-500" />
          <input 
            type="text" 
            bind:value={tableSearchFilter} 
            placeholder="Cari tabel ({tables.length})..."
            class="w-full bg-slate-950 border border-slate-800 rounded-lg pl-8 pr-2.5 py-1 text-xs text-slate-200 placeholder-slate-500 focus:outline-none focus:border-indigo-500"
          />
        </div>
      </div>

      <!-- Tables List -->
      <div class="flex-1 overflow-y-auto p-1.5 space-y-0.5">
        {#if tables.length === 0}
          <div class="p-4 text-center text-xs text-slate-500 italic space-y-2">
            <Database class="w-6 h-6 mx-auto text-slate-600 opacity-50" />
            <p>Belum ada database yang dibuka.</p>
            <p class="text-[11px] text-slate-600">Klik tombol "Buka Berkas" atau "DB Valtera Note" di atas.</p>
          </div>
        {:else}
          {#each filteredTables as t}
            <button 
              onclick={() => selectTable(t.name)}
              class="w-full px-2.5 py-1.5 rounded-lg flex items-center justify-between text-left text-xs transition-colors cursor-pointer group {selectedTableName === t.name ? 'bg-indigo-600/20 text-indigo-300 font-semibold border border-indigo-500/30' : 'text-slate-300 hover:bg-slate-800/80'}"
            >
              <div class="flex items-center space-x-2 min-w-0">
                <Table class="w-3.5 h-3.5 {selectedTableName === t.name ? 'text-indigo-400' : 'text-slate-500 group-hover:text-slate-400'} flex-shrink-0" />
                <span class="truncate">{t.name}</span>
              </div>
              <span class="text-[10px] font-mono px-1.5 py-0.2 rounded bg-slate-950/60 text-slate-400 border border-slate-800/60 flex-shrink-0">
                {t.total_rows}
              </span>
            </button>
          {/each}
        {/if}
      </div>

      <!-- Sidebar Footer: Table Stats -->
      {#if selectedTableMeta}
        <div class="p-3 bg-slate-950/60 border-t border-slate-800 text-[11px] text-slate-400 space-y-1">
          <div class="flex justify-between font-mono">
            <span>Tabel:</span>
            <span class="text-slate-200 font-semibold">{selectedTableMeta.name}</span>
          </div>
          <div class="flex justify-between font-mono">
            <span>Kolom:</span>
            <span class="text-slate-200">{selectedTableMeta.columns.length} kolom</span>
          </div>
          <div class="flex justify-between font-mono">
            <span>Total Baris:</span>
            <span class="text-indigo-300 font-bold">{selectedTableMeta.total_rows}</span>
          </div>
        </div>
      {/if}
    </aside>

    <!-- RIGHT MAIN WORKSPACE -->
    <main class="flex-1 flex flex-col overflow-hidden bg-slate-950 select-text">
      
      <!-- Tab Navigation Header (Browse Data, Query Console, Schema & DDL) -->
      <div class="h-10 bg-slate-900 border-b border-slate-800 flex items-center justify-between px-3 flex-shrink-0 select-none">
        <!-- Tabs -->
        <div class="flex items-center space-x-1 text-xs">
          <button 
            onclick={() => (activeTab = 'browse')}
            class="px-3 py-1 rounded-md font-medium flex items-center space-x-1.5 transition-colors cursor-pointer {activeTab === 'browse' ? 'bg-indigo-600 text-white shadow-xs' : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800'}"
          >
            <Table class="w-3.5 h-3.5" />
            <span>Jelajahi Data</span>
            {#if selectedTableMeta}
              <span class="text-[10.5px] opacity-75 font-mono">({selectedTableMeta.name})</span>
            {/if}
          </button>

          <button 
            onclick={() => (activeTab = 'query')}
            class="px-3 py-1 rounded-md font-medium flex items-center space-x-1.5 transition-colors cursor-pointer {activeTab === 'query' ? 'bg-indigo-600 text-white shadow-xs' : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800'}"
          >
            <Code class="w-3.5 h-3.5" />
            <span>Query SQL</span>
          </button>

          <button 
            onclick={() => (activeTab = 'schema')}
            class="px-3 py-1 rounded-md font-medium flex items-center space-x-1.5 transition-colors cursor-pointer {activeTab === 'schema' ? 'bg-indigo-600 text-white shadow-xs' : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800'}"
          >
            <Layers class="w-3.5 h-3.5" />
            <span>Skema & DDL</span>
          </button>
        </div>

        <!-- Filter within Current View -->
        {#if activeTab === 'browse'}
          <div class="flex items-center space-x-2">
            <div class="relative w-48 sm:w-60">
              <Search class="w-3 h-3 absolute left-2.5 top-2 text-slate-500" />
              <input 
                type="text" 
                bind:value={rowSearchFilter} 
                placeholder="Cari dalam tabel..."
                class="w-full bg-slate-950 border border-slate-800 rounded px-2 pl-7 py-1 text-[11px] text-slate-200 placeholder-slate-500 focus:outline-none focus:border-indigo-500"
              />
              {#if rowSearchFilter}
                <button onclick={() => (rowSearchFilter = '')} class="absolute right-2 top-1.5 text-slate-500 hover:text-slate-300 text-xs">✕</button>
              {/if}
            </div>

            <!-- Page Size Selector -->
            <select 
              bind:value={rowsPerPage} 
              onchange={() => { currentPage = 1; fetchTableData(); }}
              class="bg-slate-950 border border-slate-800 rounded px-2 py-1 text-[11px] text-slate-300 focus:outline-none font-mono"
            >
              <option value={50}>50 baris</option>
              <option value={100}>100 baris</option>
              <option value={200}>200 baris</option>
              <option value={500}>500 baris</option>
            </select>
          </div>
        {/if}
      </div>

      <!-- TAB 1: DATA BROWSER VIEW -->
      {#if activeTab === 'browse'}
        <div class="flex-1 flex flex-col overflow-hidden">
          {#if !selectedTableName}
            <div class="flex-1 flex flex-col items-center justify-center text-slate-500 space-y-3">
              <Table class="w-10 h-10 text-slate-600 opacity-40" />
              <p class="text-xs">Pilih tabel di sidebar kiri untuk menampilkan isi data.</p>
            </div>
          {:else if isLoadingData}
            <div class="flex-1 flex items-center justify-center space-x-2 text-xs text-indigo-400">
              <RefreshCw class="w-4 h-4 animate-spin" />
              <span>Memuat data tabel "{selectedTableName}"...</span>
            </div>
          {:else if !tableData || tableData.rows.length === 0}
            <div class="flex-1 flex flex-col items-center justify-center text-slate-500 space-y-2">
              <p class="text-xs">Tabel <strong>"{selectedTableName}"</strong> kosong (0 baris).</p>
            </div>
          {:else}
            <!-- Data Grid Table -->
            <div class="flex-1 overflow-auto select-text scrollbar-thin">
              <table class="w-full text-left text-xs border-collapse">
                <thead class="sticky top-0 bg-slate-900/95 backdrop-blur-xs border-b border-slate-800 z-10 font-mono shadow-xs">
                  <tr>
                    <th class="py-2 px-3 text-[10px] text-slate-500 font-normal border-r border-slate-800/80 w-12 text-center select-none">#</th>
                    {#each tableData.columns as col}
                      {@const isColSorted = sortColumn === col}
                      <th 
                        class="py-2 px-3 text-slate-300 font-semibold border-r border-slate-800/80 hover:bg-slate-800/60 cursor-pointer transition-colors whitespace-nowrap group select-none"
                        onclick={() => handleSort(col)}
                        title="Klik untuk mengurutkan kolom {col}"
                      >
                        <div class="flex items-center justify-between space-x-2">
                          <span>{col}</span>
                          <span class="text-slate-500 group-hover:text-slate-300">
                            {#if isColSorted}
                              <span class="text-indigo-400 font-bold">{sortDirection === 'asc' ? '▲' : '▼'}</span>
                            {:else}
                              <ArrowUpDown class="w-3 h-3 opacity-40 group-hover:opacity-100" />
                            {/if}
                          </span>
                        </div>
                      </th>
                    {/each}
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-800/60 font-mono">
                  {#each processedRows() as row, rowIdx}
                    <tr class="hover:bg-indigo-950/20 transition-colors group">
                      <td class="py-1.5 px-3 text-[10px] text-slate-500 border-r border-slate-800/60 text-center select-none bg-slate-950/40">
                        {(currentPage - 1) * rowsPerPage + rowIdx + 1}
                      </td>
                      {#each row as cell}
                        <td 
                          class="py-1.5 px-3 text-slate-200 border-r border-slate-800/60 max-w-xs truncate cursor-pointer hover:bg-slate-800/50 hover:text-indigo-200 transition-colors"
                          onclick={() => handleCopyCell(cell)}
                          title="Klik untuk menyalin isi sel: {String(cell ?? 'NULL')}"
                        >
                          {#if cell === null || cell === undefined}
                            <span class="text-[10px] italic text-slate-600 bg-slate-900 px-1 py-0.2 rounded">NULL</span>
                          {:else if typeof cell === 'boolean'}
                            <span class="text-[10px] font-bold px-1 py-0.2 rounded {cell ? 'bg-emerald-950 text-emerald-300' : 'bg-rose-950 text-rose-300'}">
                              {cell ? 'TRUE' : 'FALSE'}
                            </span>
                          {:else if typeof cell === 'number'}
                            <span class="text-amber-300">{cell}</span>
                          {:else}
                            <span class="text-slate-300">{cell}</span>
                          {/if}
                        </td>
                      {/each}
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>

            <!-- Table Footer: Pagination & Stats -->
            <div class="h-10 bg-slate-900 border-t border-slate-800 flex items-center justify-between px-4 text-xs select-none flex-shrink-0 font-mono text-slate-400">
              <div class="flex items-center space-x-3">
                <span>Menampilkan <strong class="text-slate-200">{processedRows().length}</strong> dari <strong class="text-slate-200">{selectedTableMeta?.total_rows || 0}</strong> baris</span>
                <span class="text-slate-600">|</span>
                <span class="text-slate-500">Waktu: {tableData.duration_ms}ms</span>
              </div>

              <!-- Pagination Controls -->
              <div class="flex items-center space-x-2">
                <button 
                  disabled={currentPage <= 1}
                  onclick={() => { currentPage -= 1; fetchTableData(); }}
                  class="p-1 rounded bg-slate-800 hover:bg-slate-700 disabled:opacity-30 disabled:cursor-not-allowed text-slate-300 transition-colors cursor-pointer"
                  title="Halaman Sebelumnya"
                >
                  <ChevronLeft class="w-3.5 h-3.5" />
                </button>
                <span class="text-slate-300 font-semibold px-2">Halaman {currentPage}</span>
                <button 
                  disabled={Boolean(selectedTableMeta && currentPage * rowsPerPage >= selectedTableMeta.total_rows)}
                  onclick={() => { currentPage += 1; fetchTableData(); }}
                  class="p-1 rounded bg-slate-800 hover:bg-slate-700 disabled:opacity-30 disabled:cursor-not-allowed text-slate-300 transition-colors cursor-pointer"
                  title="Halaman Berikutnya"
                >
                  <ChevronRight class="w-3.5 h-3.5" />
                </button>
              </div>
            </div>
          {/if}
        </div>

      <!-- TAB 2: SQL QUERY CONSOLE -->
      {:else if activeTab === 'query'}
        <div class="flex-1 flex flex-col overflow-hidden">
          <!-- Editor Area -->
          <div class="h-44 bg-slate-950 border-b border-slate-800 flex flex-col p-3 space-y-2 flex-shrink-0">
            <!-- SQL Quick Templates -->
            <div class="flex items-center space-x-1.5 overflow-x-auto scrollbar-none text-[11px] pb-1">
              <span class="text-slate-500 text-[10px] font-mono mr-1">Template:</span>
              <button 
                onclick={() => (customQuery = selectedTableName ? `SELECT * FROM "${selectedTableName}" LIMIT 50;` : 'SELECT * FROM sqlite_master;')}
                class="px-2 py-0.5 rounded bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800 font-mono transition-colors"
              >
                SELECT *
              </button>
              <button 
                onclick={() => (customQuery = selectedTableName ? `SELECT COUNT(*) AS total_rows FROM "${selectedTableName}";` : 'SELECT COUNT(*) FROM notes;')}
                class="px-2 py-0.5 rounded bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800 font-mono transition-colors"
              >
                COUNT(*)
              </button>
              <button 
                onclick={() => (customQuery = selectedTableName ? `PRAGMA table_info("${selectedTableName}");` : 'PRAGMA table_info(notes);')}
                class="px-2 py-0.5 rounded bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800 font-mono transition-colors"
              >
                PRAGMA table_info
              </button>
              <button 
                onclick={() => (customQuery = 'PRAGMA integrity_check;')}
                class="px-2 py-0.5 rounded bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800 font-mono transition-colors"
              >
                Integrity Check
              </button>
              <button 
                onclick={() => (customQuery = 'SELECT name, type, sql FROM sqlite_master WHERE type="table";')}
                class="px-2 py-0.5 rounded bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-800 font-mono transition-colors"
              >
                sqlite_master
              </button>
            </div>

            <!-- SQL Textarea Input -->
            <textarea 
              bind:value={customQuery} 
              placeholder="Tulis query SQL (misal: SELECT * FROM notes WHERE is_pinned = 1;)... Tekan Ctrl+Enter untuk eksekusi."
              class="flex-1 w-full bg-slate-900/90 border border-slate-800 rounded-lg p-2.5 font-mono text-xs text-slate-200 placeholder-slate-600 focus:outline-none focus:border-indigo-500 resize-none leading-relaxed"
              onkeydown={(e) => {
                if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
                  e.preventDefault();
                  executeCustomQuery();
                }
              }}
            ></textarea>

            <!-- Console Actions Bar -->
            <div class="flex items-center justify-between pt-1">
              <span class="text-[11px] text-slate-500 font-mono">
                Pintasan: <kbd class="px-1 py-0.5 rounded bg-slate-900 border border-slate-800 text-[10px]">Ctrl+Enter</kbd> untuk jalankan.
              </span>
              <div class="flex items-center space-x-2">
                <button 
                  onclick={handleFormatQuery}
                  class="px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-medium flex items-center space-x-1.5 transition-colors cursor-pointer"
                  title="Format / Rapikan SQL"
                >
                  <Sparkles class="w-3.5 h-3.5 text-amber-400" />
                  <span>Format</span>
                </button>
                <button 
                  onclick={executeCustomQuery}
                  disabled={isExecutingQuery}
                  class="px-4 py-1 rounded bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold flex items-center space-x-1.5 transition-colors cursor-pointer shadow-xs disabled:opacity-50"
                  title="Eksekusi Query SQL"
                >
                  <Play class="w-3.5 h-3.5 fill-current" />
                  <span>{isExecutingQuery ? 'Mengeksekusi...' : 'Jalankan Query'}</span>
                </button>
              </div>
            </div>
          </div>

          <!-- Query Error Banner -->
          {#if queryError}
            <div class="p-3 bg-rose-950/70 border-b border-rose-800 text-xs text-rose-200 flex items-start space-x-2">
              <AlertCircle class="w-4 h-4 text-rose-400 flex-shrink-0 mt-0.5" />
              <div class="space-y-1">
                <p class="font-semibold">Kesalahan Eksekusi SQL:</p>
                <pre class="font-mono text-[11px] text-rose-300 whitespace-pre-wrap">{queryError}</pre>
              </div>
            </div>
          {/if}

          <!-- Query Results Grid -->
          <div class="flex-1 overflow-auto select-text scrollbar-thin">
            {#if !queryResult}
              <div class="h-full flex flex-col items-center justify-center text-slate-500 text-xs space-y-2">
                <Code class="w-8 h-8 text-slate-600 opacity-40" />
                <p>Tulis perintah SQL di atas dan tekan <strong>"Jalankan Query"</strong>.</p>
              </div>
            {:else if queryResult.rows.length === 0}
              <div class="p-8 text-center text-slate-400 text-xs space-y-1 font-mono">
                <CheckCircle2 class="w-6 h-6 mx-auto text-emerald-400" />
                <p>Query berhasil dijalankan dalam {queryResult.duration_ms}ms.</p>
                <p class="text-slate-500">Hasil: 0 baris data dikembalikan.</p>
              </div>
            {:else}
              <table class="w-full text-left text-xs border-collapse">
                <thead class="sticky top-0 bg-slate-900 border-b border-slate-800 z-10 font-mono shadow-xs">
                  <tr>
                    <th class="py-2 px-3 text-[10px] text-slate-500 font-normal border-r border-slate-800/80 w-12 text-center">#</th>
                    {#each queryResult.columns as col}
                      <th class="py-2 px-3 text-slate-300 font-semibold border-r border-slate-800/80 whitespace-nowrap">
                        {col}
                      </th>
                    {/each}
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-800/60 font-mono">
                  {#each queryResult.rows as row, idx}
                    <tr class="hover:bg-indigo-950/20 transition-colors">
                      <td class="py-1.5 px-3 text-[10px] text-slate-500 border-r border-slate-800/60 text-center bg-slate-950/40">
                        {idx + 1}
                      </td>
                      {#each row as cell}
                        <td 
                          class="py-1.5 px-3 text-slate-200 border-r border-slate-800/60 max-w-xs truncate cursor-pointer hover:bg-slate-800/50 hover:text-indigo-200"
                          onclick={() => handleCopyCell(cell)}
                          title="Klik untuk menyalin: {String(cell ?? 'NULL')}"
                        >
                          {#if cell === null || cell === undefined}
                            <span class="text-[10px] italic text-slate-600 bg-slate-900 px-1 py-0.2 rounded">NULL</span>
                          {:else if typeof cell === 'number'}
                            <span class="text-amber-300">{cell}</span>
                          {:else}
                            <span class="text-slate-300">{cell}</span>
                          {/if}
                        </td>
                      {/each}
                    </tr>
                  {/each}
                </tbody>
              </table>
            {/if}
          </div>

          <!-- Query Footer Stats -->
          {#if queryResult}
            <div class="h-8 bg-slate-900 border-t border-slate-800 flex items-center justify-between px-4 text-xs select-none font-mono text-slate-400">
              <span>{queryResult.rows.length} baris dikembalikan</span>
              <span class="text-indigo-300">Waktu: {queryResult.duration_ms} ms</span>
            </div>
          {/if}
        </div>

      <!-- TAB 3: SCHEMA & DDL INSPECTOR -->
      {:else if activeTab === 'schema'}
        <div class="flex-1 overflow-y-auto p-4 md:p-6 space-y-6">
          {#if !selectedTableMeta}
            <div class="p-8 text-center text-slate-500 text-xs italic">
              Pilih tabel di sidebar kiri untuk memeriksa rincian skema.
            </div>
          {:else}
            <!-- Columns Table -->
            <div class="space-y-2">
              <div class="flex items-center justify-between">
                <h3 class="text-xs font-bold text-slate-200 uppercase tracking-wider flex items-center space-x-2">
                  <Table class="w-4 h-4 text-indigo-400" />
                  <span>Struktur Kolom ({selectedTableMeta.columns.length})</span>
                </h3>
              </div>
              <div class="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden shadow-xs">
                <table class="w-full text-left text-xs font-mono">
                  <thead class="bg-slate-950 border-b border-slate-800 text-slate-400">
                    <tr>
                      <th class="py-2.5 px-4 font-semibold">Nama Kolom</th>
                      <th class="py-2.5 px-4 font-semibold">Tipe Data</th>
                      <th class="py-2.5 px-4 font-semibold">Primary Key</th>
                      <th class="py-2.5 px-4 font-semibold">Not Null</th>
                      <th class="py-2.5 px-4 font-semibold">Default Value</th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-slate-800/80">
                    {#each selectedTableMeta.columns as col}
                      <tr class="hover:bg-slate-850/60 transition-colors">
                        <td class="py-2 px-4 font-bold text-slate-100">{col.name}</td>
                        <td class="py-2 px-4 text-indigo-300">{col.col_type || 'TEXT'}</td>
                        <td class="py-2 px-4">
                          {#if col.pk}
                            <span class="px-2 py-0.5 rounded text-[10px] font-bold bg-amber-500/15 text-amber-300 border border-amber-500/30 flex items-center space-x-1 w-max">
                              <Key class="w-3 h-3" />
                              <span>PRIMARY KEY</span>
                            </span>
                          {:else}
                            <span class="text-slate-600">-</span>
                          {/if}
                        </td>
                        <td class="py-2 px-4">
                          {#if col.notnull}
                            <span class="text-rose-400 font-semibold">YES</span>
                          {:else}
                            <span class="text-slate-500">NO</span>
                          {/if}
                        </td>
                        <td class="py-2 px-4 text-slate-400">
                          {col.dflt_value ?? 'NULL'}
                        </td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>
            </div>

            <!-- Generated DDL Statement -->
            <div class="space-y-2">
              <div class="flex items-center justify-between">
                <h3 class="text-xs font-bold text-slate-200 uppercase tracking-wider flex items-center space-x-2">
                  <Code class="w-4 h-4 text-amber-400" />
                  <span>Sintaks DDL (CREATE TABLE)</span>
                </h3>
                <button 
                  onclick={() => { navigator.clipboard.writeText(tableDdl()); showToast('DDL disalin!'); }}
                  class="px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-medium flex items-center space-x-1 transition-colors cursor-pointer"
                >
                  <Copy class="w-3 h-3" />
                  <span>Salin DDL</span>
                </button>
              </div>
              <div class="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden p-4 shadow-inner">
                <pre class="font-mono text-xs text-indigo-300 leading-relaxed overflow-x-auto select-text whitespace-pre">{tableDdl()}</pre>
              </div>
            </div>
          {/if}
        </div>
      {/if}

    </main>
  </div>

  <!-- Global Drag and Drop Active Overlay -->
  {#if isDragging}
    <div class="pointer-events-none absolute inset-0 z-50 bg-slate-950/80 backdrop-blur-xs flex flex-col items-center justify-center p-6 text-center animate-in fade-in duration-100">
      <div class="p-8 rounded-2xl border-2 border-dashed border-indigo-400 bg-indigo-950/60 shadow-2xl flex flex-col items-center space-y-3 max-w-sm w-full">
        <div class="w-16 h-16 rounded-2xl bg-indigo-600 text-white flex items-center justify-center shadow-lg animate-bounce">
          <Upload class="w-8 h-8" />
        </div>
        <div class="space-y-1">
          <p class="text-base font-bold text-slate-100">Jatuhkan Berkas SQLite ke Sini</p>
          <p class="text-xs text-indigo-300">Format .db, .sqlite, .sqlite3, .db3</p>
        </div>
      </div>
    </div>
  {/if}

  <!-- Toast Notification -->
  {#if copiedToast}
    <div class="fixed bottom-6 right-6 z-50 bg-slate-900 border border-slate-700 text-slate-100 text-xs px-4 py-2 rounded-xl shadow-2xl flex items-center space-x-2 animate-in fade-in slide-in-from-bottom-2 duration-150">
      <CheckCircle2 class="w-4 h-4 text-emerald-400 flex-shrink-0" />
      <span class="font-medium">{copiedToast}</span>
    </div>
  {/if}
</div>
