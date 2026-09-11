<script lang="ts">
  import { onMount } from 'svelte';
  import { 
    Sparkles, 
    Minimize2, 
    FileCode, 
    Trash2, 
    ClipboardPaste, 
    Copy, 
    Check, 
    AlertCircle, 
    CheckCircle2, 
    Search, 
    ChevronsDown, 
    ChevronsUp, 
    ExternalLink,
    Code,
    Layers,
    Table,
    FileSpreadsheet,
    Download,
    FileText,
    SlidersHorizontal,
    Filter
  } from 'lucide-svelte';
  import JsonTreeNode from '../Viewer/JsonTreeNode.svelte';
  import { editorStore } from '../../stores/editorStore.svelte';

  let { onBack, showBackButton = false }: { onBack?: () => void; showBackButton?: boolean } = $props();

  // Primary state
  let rawInput = $state('');
  let indentSpaces = $state<number>(2);
  let viewMode = $state<'code' | 'tree' | 'table' | 'csv'>('tree');
  let searchTreeQuery = $state('');
  let searchTableQuery = $state('');
  let flattenNested = $state<boolean>(false);
  let csvDelimiter = $state<',' | ';' | '\t'>(',');
  let includeCsvHeader = $state<boolean>(true);
  let selectedArraySource = $state<string>('');
  let expandAllTrigger = $state(0);
  let collapseAllTrigger = $state(0);
  let copiedToast = $state<string | null>(null);

  // Realistic dynamic sample with heterogeneous keys, booleans, numbers, and nested objects
  const SAMPLE_DYNAMIC_ARRAY = JSON.stringify([
    {
      "id": 101,
      "nama": "Ahmad Fauzi",
      "divisi": "Engineering",
      "jabatan": "Lead Developer",
      "gaji": 18500000,
      "lokasi": "Jakarta",
      "aktif": true,
      "kontak": { "email": "ahmad@valtera.id", "hp": "081234567890" },
      "keahlian": ["Rust", "Svelte", "PostgreSQL"]
    },
    {
      "id": 102,
      "nama": "Dewi Sartika",
      "divisi": "Design",
      "jabatan": "UI/UX Specialist",
      "gaji": 15000000,
      "lokasi": "Bandung",
      "aktif": true,
      "kontak": { "email": "dewi@valtera.id" },
      "portfolio": "https://dribbble.com/dewi"
    },
    {
      "id": 103,
      "nama": "Bambang Pamungkas",
      "divisi": "Product",
      "jabatan": "Product Manager",
      "gaji": 21000000,
      "lokasi": "Surabaya",
      "aktif": false,
      "catatan": "Cuti s.d. Maret",
      "keahlian": ["Scrum", "Roadmapping"]
    },
    {
      "id": 104,
      "nama": "Siti Nurhaliza",
      "divisi": "Marketing",
      "jabatan": "Growth Lead",
      "gaji": 13500000,
      "lokasi": "Jakarta",
      "aktif": true,
      "kontak": { "email": "siti@valtera.id", "hp": "089876543210" },
      "targetBulanan": 500000000
    }
  ], null, 2);

  const SAMPLE_API_RESPONSE = JSON.stringify({
    "status": "success",
    "timestamp": "2026-09-10T13:00:00Z",
    "total_records": 3,
    "data": [
      { "order_id": "INV-2026-001", "pelanggan": "PT Maju Bersama", "total": 4500000, "lunas": true, "metode": "BCA VA" },
      { "order_id": "INV-2026-002", "pelanggan": "CV Kreatif Digital", "total": 1250000, "lunas": false, "metode": "QRIS", "jatuh_tempo": "2026-09-20" },
      { "order_id": "INV-2026-003", "pelanggan": "Toko Berkah Abadi", "total": 8900000, "lunas": true, "metode": "Mandiri Transfer" }
    ],
    "meta": { "versi_api": "v2.1", "server": "id-cgk-01" }
  }, null, 2);

  // Initialize with sample dynamic array if empty
  onMount(() => {
    if (!rawInput) {
      rawInput = SAMPLE_DYNAMIC_ARRAY;
    }
  });

  // JSON Syntax & Validation Derived
  let parseResult = $derived.by(() => {
    const raw = rawInput.trim();
    if (!raw) {
      return { isValid: true, data: null, error: null, isEmpty: true };
    }
    try {
      const parsed = JSON.parse(raw);
      return { isValid: true, data: parsed, error: null, isEmpty: false };
    } catch (e: any) {
      return { isValid: false, data: null, error: e?.message || 'Sintaks JSON tidak valid', isEmpty: false };
    }
  });

  let formattedCode = $derived.by(() => {
    if (!parseResult.isValid || parseResult.data === null) return '';
    try {
      return JSON.stringify(parseResult.data, null, indentSpaces);
    } catch {
      return '';
    }
  });

  let stats = $derived.by(() => {
    if (!parseResult.isValid || parseResult.data === null) return null;
    const rawBytes = new Blob([rawInput]).size;
    const formattedBytes = new Blob([formattedCode]).size;
    let nodeCount = 0;
    function walk(val: any) {
      nodeCount++;
      if (val && typeof val === 'object') {
        Object.values(val).forEach(walk);
      }
    }
    walk(parseResult.data);
    const lineCount = formattedCode ? formattedCode.split('\n').length : 0;

    return {
      rawSizeStr: rawBytes < 1024 ? `${rawBytes} B` : `${(rawBytes / 1024).toFixed(1)} KB`,
      formattedSizeStr: formattedBytes < 1024 ? `${formattedBytes} B` : `${(formattedBytes / 1024).toFixed(1)} KB`,
      nodeCount,
      lineCount,
      isRootArray: Array.isArray(parseResult.data)
    };
  });

  // Detect available array sources if root is an object
  let detectedArraySources = $derived.by(() => {
    if (!parseResult.isValid || !parseResult.data || typeof parseResult.data !== 'object' || Array.isArray(parseResult.data)) {
      return [];
    }
    const sources: { key: string; length: number; label: string }[] = [];
    for (const [k, v] of Object.entries(parseResult.data)) {
      if (Array.isArray(v) && v.length > 0) {
        sources.push({ key: k, length: v.length, label: `${k} (${v.length} baris)` });
      }
    }
    return sources;
  });

  // Helper: flatten nested object keys
  function flattenObject(obj: any, prefix = ''): Record<string, any> {
    const result: Record<string, any> = {};
    if (!obj || typeof obj !== 'object') {
      if (prefix) result[prefix] = obj;
      return result;
    }
    if (Array.isArray(obj)) {
      const isPrimitiveArray = obj.every(x => typeof x !== 'object' || x === null);
      result[prefix] = isPrimitiveArray ? obj.join(', ') : JSON.stringify(obj);
      return result;
    }
    for (const [k, v] of Object.entries(obj)) {
      const fullKey = prefix ? `${prefix}.${k}` : k;
      if (v && typeof v === 'object' && !Array.isArray(v) && Object.keys(v).length > 0) {
        Object.assign(result, flattenObject(v, fullKey));
      } else if (Array.isArray(v)) {
        const isPrimitiveArray = v.every(x => typeof x !== 'object' || x === null);
        result[fullKey] = isPrimitiveArray ? v.join(', ') : JSON.stringify(v);
      } else {
        result[fullKey] = v;
      }
    }
    return result;
  }

  interface TableDataResult {
    headers: string[];
    rows: Record<string, any>[];
    totalCount: number;
    isKeyValue: boolean;
    sourceName: string;
  }

  // Dynamic Table Normalization
  let tableData = $derived.by<TableDataResult>(() => {
    if (!parseResult.isValid || parseResult.data === null || parseResult.data === undefined) {
      return { headers: [], rows: [], totalCount: 0, isKeyValue: false, sourceName: '' };
    }

    const raw = parseResult.data;
    let targetArray: any[] | null = null;
    let sourceName = '';

    if (Array.isArray(raw)) {
      targetArray = raw;
      sourceName = 'Array Utama';
    } else if (typeof raw === 'object') {
      if (selectedArraySource && selectedArraySource !== '__root__' && Array.isArray(raw[selectedArraySource])) {
        targetArray = raw[selectedArraySource];
        sourceName = selectedArraySource;
      } else if (detectedArraySources.length > 0 && selectedArraySource !== '__root__') {
        const priority = detectedArraySources.find(s => ['data', 'items', 'results', 'records', 'rows', 'list', 'users'].includes(s.key.toLowerCase()));
        const chosen = priority || detectedArraySources[0];
        targetArray = raw[chosen.key];
        sourceName = chosen.key;
      } else {
        // Render root object as 2-column key-value table
        const kvRows: Record<string, any>[] = Object.entries(raw).map(([k, v], idx) => ({
          __id: idx + 1,
          'Kunci (Key)': k,
          'Nilai (Value)': v
        }));
        return {
          headers: ['Kunci (Key)', 'Nilai (Value)'],
          rows: kvRows,
          totalCount: kvRows.length,
          isKeyValue: true,
          sourceName: 'Objek (Key-Value)'
        };
      }
    } else {
      // Single primitive value
      return {
        headers: ['Nilai (Value)'],
        rows: [{ __id: 1, 'Nilai (Value)': raw }],
        totalCount: 1,
        isKeyValue: false,
        sourceName: 'Primitive'
      };
    }

    if (!targetArray || targetArray.length === 0) {
      return { headers: [], rows: [], totalCount: 0, isKeyValue: false, sourceName };
    }

    // Check if targetArray is primitive array
    const isPrimitiveArray = targetArray.every(item => typeof item !== 'object' || item === null);
    if (isPrimitiveArray) {
      const primRows: Record<string, any>[] = targetArray.map((val, idx) => ({
        __id: idx + 1,
        '#': idx + 1,
        'Nilai': val
      }));
      return {
        headers: ['#', 'Nilai'],
        rows: primRows,
        totalCount: primRows.length,
        isKeyValue: false,
        sourceName
      };
    }

    // Dynamic Array of Objects: Collect union of all keys across all records
    const headersSet = new Set<string>();
    const processedRows: Record<string, any>[] = [];

    for (let i = 0; i < targetArray.length; i++) {
      const item = targetArray[i];
      let rowObj: Record<string, any> = {};

      if (item && typeof item === 'object') {
        if (flattenNested) {
          rowObj = flattenObject(item);
        } else {
          rowObj = { ...item };
        }
      } else {
        rowObj = { 'Nilai': item };
      }

      Object.keys(rowObj).forEach(k => headersSet.add(k));
      processedRows.push(rowObj);
    }

    const headers = Array.from(headersSet);

    // Normalize each row so all headers are present
    const rows = processedRows.map((row, idx) => {
      const normalized: Record<string, any> = { __id: idx + 1 };
      for (const h of headers) {
        normalized[h] = row[h];
      }
      return normalized;
    });

    return {
      headers,
      rows,
      totalCount: rows.length,
      isKeyValue: false,
      sourceName
    };
  });

  // Filtered Table Rows for live searching
  let filteredTableRows = $derived.by(() => {
    const query = searchTableQuery.trim().toLowerCase();
    if (!query) return tableData.rows;

    return tableData.rows.filter(row => {
      return tableData.headers.some(header => {
        const val = row[header];
        if (val === null || val === undefined) return false;
        const strVal = typeof val === 'object' ? JSON.stringify(val) : String(val);
        return strVal.toLowerCase().includes(query);
      });
    });
  });

  // RFC 4180 Compliant CSV Generator
  function formatCsvCell(val: any, delimiter: string): string {
    if (val === null || val === undefined) return '';
    let str = '';
    if (typeof val === 'object') {
      str = JSON.stringify(val);
    } else {
      str = String(val);
    }
    const needsQuotes = str.includes(delimiter) || str.includes('"') || str.includes('\n') || str.includes('\r');
    if (needsQuotes) {
      return `"${str.replace(/"/g, '""')}"`;
    }
    return str;
  }

  let csvOutput = $derived.by(() => {
    if (!tableData.headers.length || !tableData.rows.length) return '';

    const delimiter = csvDelimiter;
    const lines: string[] = [];

    // Header line
    if (includeCsvHeader) {
      const headerLine = tableData.headers
        .map(h => formatCsvCell(h, delimiter))
        .join(delimiter);
      lines.push(headerLine);
    }

    // Row lines
    for (const row of tableData.rows) {
      const rowLine = tableData.headers
        .map(h => formatCsvCell(row[h], delimiter))
        .join(delimiter);
      lines.push(rowLine);
    }

    return lines.join('\r\n');
  });

  // GitHub Flavored Markdown Table Generator
  let markdownTableOutput = $derived.by(() => {
    if (!tableData.headers.length || !tableData.rows.length) return '';

    const headers = tableData.headers;
    const headerLine = `| ${headers.map(h => String(h).replace(/\|/g, '\\|')).join(' | ')} |`;
    const separatorLine = `| ${headers.map(() => '---').join(' | ')} |`;

    const rowLines = tableData.rows.map(row => {
      const cells = headers.map(h => {
        const val = row[h];
        if (val === null || val === undefined) return '-';
        if (typeof val === 'object') return '`' + JSON.stringify(val).replace(/\|/g, '\\|') + '`';
        return String(val).replace(/\|/g, '\\|').replace(/\r?\n/g, '<br>');
      });
      return `| ${cells.join(' | ')} |`;
    });

    return [headerLine, separatorLine, ...rowLines].join('\n');
  });

  // Formatting actions
  function handleFormat(indent = 2) {
    indentSpaces = indent;
    if (parseResult.isValid && parseResult.data !== null) {
      rawInput = JSON.stringify(parseResult.data, null, indent);
      showToast(`Diformat rapi (${indent} spasi)`);
    }
  }

  function handleMinify() {
    if (parseResult.isValid && parseResult.data !== null) {
      rawInput = JSON.stringify(parseResult.data);
      showToast('JSON diminifikasi (1 baris)');
    }
  }

  async function handlePaste() {
    try {
      const text = await navigator.clipboard.readText();
      if (text) {
        rawInput = text;
        showToast('Dipaste dari clipboard');
      }
    } catch (e) {
      console.warn('Paste error:', e);
    }
  }

  async function handleCopyJson() {
    if (!formattedCode) return;
    try {
      await navigator.clipboard.writeText(formattedCode);
      showToast('Hasil JSON tersalin!');
    } catch (e) {
      console.warn('Copy error:', e);
    }
  }

  async function handleCopyCsv() {
    if (!csvOutput) return;
    try {
      await navigator.clipboard.writeText(csvOutput);
      showToast('CSV tersalin ke clipboard!');
    } catch (e) {
      console.warn('Copy CSV error:', e);
    }
  }

  async function handleCopyMarkdown() {
    if (!markdownTableOutput) return;
    try {
      await navigator.clipboard.writeText(markdownTableOutput);
      showToast('Tabel Markdown tersalin ke clipboard!');
    } catch (e) {
      console.warn('Copy Markdown error:', e);
    }
  }

  function handleDownloadCsv() {
    if (!csvOutput) return;
    try {
      const blob = new Blob([csvOutput], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      const timestamp = new Date().toISOString().slice(0, 10);
      a.href = url;
      a.download = `valtera-data-${timestamp}.csv`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      showToast('File .csv berhasil diunduh!');
    } catch (e) {
      console.error('Download error:', e);
      showToast('Gagal mengunduh file');
    }
  }

  function handleExportCsvToNewTab() {
    if (!csvOutput) return;
    editorStore.addTab('Export_Data.csv', 'csv', csvOutput);
    if (onBack) onBack();
  }

  function handleExportMarkdownToNewTab() {
    if (!markdownTableOutput) return;
    editorStore.addTab('Tabel_Data.md', 'md', markdownTableOutput);
    if (onBack) onBack();
  }

  function handleExportJsonToNewTab() {
    if (!formattedCode) return;
    editorStore.addTab(undefined, 'json', formattedCode);
    if (onBack) onBack();
  }

  function handleLoadDynamicArray() {
    rawInput = SAMPLE_DYNAMIC_ARRAY;
    selectedArraySource = '';
    showToast('Data Dinamis dimuat');
  }

  function handleLoadApiResponse() {
    rawInput = SAMPLE_API_RESPONSE;
    selectedArraySource = '';
    showToast('Contoh Respon API dimuat');
  }

  function handleClear() {
    rawInput = '';
    searchTreeQuery = '';
    searchTableQuery = '';
    showToast('Input dibersihkan');
  }

  function showToast(msg: string) {
    copiedToast = msg;
    setTimeout(() => {
      if (copiedToast === msg) copiedToast = null;
    }, 2200);
  }
</script>

{#snippet renderCellValue(val: any)}
  {#if val === null}
    <span class="text-slate-500 italic text-[11px]">null</span>
  {:else if val === undefined}
    <span class="text-slate-600 text-[11px]">-</span>
  {:else if typeof val === 'boolean'}
    <span class="inline-flex items-center px-1.5 py-0.5 rounded text-[10.5px] font-mono font-semibold {val ? 'bg-emerald-500/15 text-emerald-400 border border-emerald-500/30' : 'bg-rose-500/15 text-rose-400 border border-rose-500/30'}">
      {val ? 'true' : 'false'}
    </span>
  {:else if typeof val === 'number'}
    <span class="font-mono text-cyan-300 text-[11.5px] font-medium">
      {val.toLocaleString('id-ID')}
    </span>
  {:else if Array.isArray(val)}
    <div class="flex items-center gap-1 flex-wrap">
      {#each val.slice(0, 3) as item}
        <span class="px-1.5 py-0.5 rounded bg-slate-800 text-slate-300 text-[10.5px] font-mono border border-slate-700/60">
          {typeof item === 'object' ? '{...}' : String(item)}
        </span>
      {/each}
      {#if val.length > 3}
        <span class="text-[10px] text-slate-500 font-mono">+{val.length - 3}</span>
      {/if}
    </div>
  {:else if typeof val === 'object'}
    <span 
      class="inline-block px-1.5 py-0.5 rounded bg-blue-950/40 text-blue-300 border border-blue-800/40 font-mono text-[10.5px] max-w-[220px] truncate" 
      title={JSON.stringify(val, null, 2)}
    >
      {JSON.stringify(val)}
    </span>
  {:else}
    <span class="text-slate-200 text-xs break-words">{String(val)}</span>
  {/if}
{/snippet}

<div class="h-full w-full flex flex-col md:flex-row overflow-hidden divide-y md:divide-y-0 md:divide-x divide-slate-800 bg-slate-950 text-slate-100 select-none">
  <!-- ============================================== -->
  <!-- LEFT PANE: RAW JSON INPUT                     -->
  <!-- ============================================== -->
  <section class="w-full md:w-[42%] lg:w-[38%] flex flex-col overflow-hidden bg-slate-950/60 flex-shrink-0">
    <!-- Pane Header: Input Controls -->
    <div class="h-10 px-3 bg-slate-900/80 border-b border-slate-800 flex items-center justify-between text-xs text-slate-300 font-medium flex-shrink-0">
      <div class="flex items-center space-x-2">
        <FileCode class="w-4 h-4 text-blue-400" />
        <span class="font-bold text-slate-100">Input Data JSON</span>
        {#if rawInput}
          <span class="text-[11px] font-mono text-slate-400">
            ({rawInput.length} chars • {rawInput.split('\n').length} baris)
          </span>
        {/if}
      </div>

      <!-- Action Buttons for Input -->
      <div class="flex items-center space-x-1.5">
        <div class="flex items-center bg-slate-800/80 rounded-md p-0.5 border border-slate-700/50">
          <button 
            onclick={handleLoadDynamicArray}
            class="px-2 py-0.5 text-[11px] rounded text-slate-300 hover:text-white hover:bg-slate-700 transition-colors cursor-pointer flex items-center space-x-1"
            title="Muat contoh Array Data Karyawan Dinamis"
          >
            <Sparkles class="w-3 h-3 text-amber-400" />
            <span>Data Dinamis</span>
          </button>
          <button 
            onclick={handleLoadApiResponse}
            class="px-2 py-0.5 text-[11px] rounded text-slate-400 hover:text-white hover:bg-slate-700 transition-colors cursor-pointer"
            title="Muat contoh Respon API Bersarang"
          >
            Respon API
          </button>
        </div>

        <button 
          onclick={handlePaste}
          class="px-2 py-1 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-[11px] font-medium flex items-center space-x-1 cursor-pointer transition-colors"
          title="Paste dari Clipboard"
        >
          <ClipboardPaste class="w-3 h-3 text-blue-400" />
          <span>Paste</span>
        </button>

        <button 
          onclick={handleClear}
          disabled={!rawInput}
          class="p-1 rounded-md hover:bg-red-500/10 text-slate-400 hover:text-red-400 transition-colors cursor-pointer disabled:opacity-30 disabled:cursor-not-allowed"
          title="Bersihkan teks input"
        >
          <Trash2 class="w-3.5 h-3.5" />
        </button>
      </div>
    </div>

    <!-- Textarea Body -->
    <div class="flex-1 relative overflow-hidden p-2">
      <textarea 
        bind:value={rawInput}
        placeholder={`Paste atau ketik JSON di sini...\n\nFormat apapun didukung:\n• Array objek dengan kunci dinamis/berbeda-beda\n• Respon API dengan objek bersarang (data, items)\n• Objek tunggal (Key-Value)\n• Array nilai sederhana`}
        class="w-full h-full p-3 bg-slate-900/30 border border-slate-800/80 rounded-xl text-slate-100 font-mono text-xs leading-relaxed focus:outline-none focus:border-blue-500/60 resize-none placeholder-slate-600 transition-colors"
        spellcheck="false"
      ></textarea>
    </div>

    <!-- Live Validation Footer Bar -->
    <div class="h-8 px-3 border-t border-slate-800 text-xs flex items-center justify-between flex-shrink-0 {parseResult.isEmpty ? 'bg-slate-900/40 text-slate-500' : parseResult.isValid ? 'bg-emerald-950/20 text-emerald-300' : 'bg-red-950/30 text-red-300'}">
      <div class="flex items-center space-x-2 truncate">
        {#if parseResult.isEmpty}
          <span class="text-slate-500 text-[11px]">Ketik atau tempelkan JSON di atas untuk mengolah tabel & CSV</span>
        {:else if parseResult.isValid}
          <CheckCircle2 class="w-3.5 h-3.5 text-emerald-400 flex-shrink-0" />
          <span class="font-semibold text-[11px]">Sintaks JSON Valid</span>
          {#if stats}
            <span class="text-slate-600">•</span>
            <span class="text-[11px] text-slate-400 font-mono">{stats.nodeCount} node ({stats.rawSizeStr})</span>
          {/if}
        {:else}
          <AlertCircle class="w-3.5 h-3.5 text-red-400 flex-shrink-0" />
          <span class="font-semibold text-red-400 text-[11px]">Error:</span>
          <span class="truncate font-mono text-[11px] text-red-300">{parseResult.error}</span>
        {/if}
      </div>

      <!-- Quick Format Controls -->
      {#if parseResult.isValid && !parseResult.isEmpty}
        <div class="flex items-center space-x-1.5">
          <button 
            onclick={() => handleFormat(2)}
            class="px-1.5 py-0.5 rounded text-[10.5px] bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors cursor-pointer"
            title="Rapikan indentasi 2 spasi"
          >
            Format
          </button>
          <button 
            onclick={handleMinify}
            class="px-1.5 py-0.5 rounded text-[10.5px] bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-white transition-colors cursor-pointer"
            title="Minify JSON ke 1 baris"
          >
            Minify
          </button>
        </div>
      {/if}
    </div>
  </section>

  <!-- ============================================== -->
  <!-- RIGHT PANE: DYNAMIC TABLE, CSV, TREE & CODE   -->
  <!-- ============================================== -->
  <section class="flex-1 flex flex-col overflow-hidden bg-slate-950/30">
    <!-- Pane Header: View Mode Switcher & Global Actions -->
    <div class="h-10 px-3 bg-slate-900/80 border-b border-slate-800 flex items-center justify-between text-xs text-slate-300 font-medium flex-shrink-0">
      <!-- Left: 4 View Mode Segmented Controls -->
      <div class="flex items-center space-x-2">
        <div class="flex items-center bg-slate-950 p-0.5 rounded-lg border border-slate-800">
          <button 
            onclick={() => (viewMode = 'tree')}
            class="px-2.5 py-1 rounded-md text-[11px] font-medium transition-all cursor-pointer flex items-center space-x-1.5 {viewMode === 'tree' ? 'bg-blue-600 text-white font-semibold shadow-xs' : 'text-slate-400 hover:text-slate-200'}"
          >
            <Layers class="w-3.5 h-3.5" />
            <span>Pohon JSON</span>
          </button>

          <button 
            onclick={() => (viewMode = 'table')}
            class="px-2.5 py-1 rounded-md text-[11px] font-medium transition-all cursor-pointer flex items-center space-x-1.5 {viewMode === 'table' ? 'bg-blue-600 text-white font-semibold shadow-xs' : 'text-slate-400 hover:text-slate-200'}"
          >
            <Table class="w-3.5 h-3.5" />
            <span>Tabel Dinamis</span>
            {#if tableData.rows.length > 0}
              <span class="ml-1 px-1 py-0.2 rounded text-[10px] font-mono {viewMode === 'table' ? 'bg-blue-700 text-blue-100' : 'bg-slate-800 text-slate-400'}">
                {tableData.rows.length}
              </span>
            {/if}
          </button>

          <button 
            onclick={() => (viewMode = 'csv')}
            class="px-2.5 py-1 rounded-md text-[11px] font-medium transition-all cursor-pointer flex items-center space-x-1.5 {viewMode === 'csv' ? 'bg-blue-600 text-white font-semibold shadow-xs' : 'text-slate-400 hover:text-slate-200'}"
          >
            <FileSpreadsheet class="w-3.5 h-3.5" />
            <span>Ekspor CSV</span>
          </button>

          <button 
            onclick={() => (viewMode = 'code')}
            class="px-2.5 py-1 rounded-md text-[11px] font-medium transition-all cursor-pointer flex items-center space-x-1.5 {viewMode === 'code' ? 'bg-blue-600 text-white font-semibold shadow-xs' : 'text-slate-400 hover:text-slate-200'}"
          >
            <Code class="w-3.5 h-3.5" />
            <span>Teks JSON</span>
          </button>
        </div>
      </div>

      <!-- Right: View-Specific Toolbar Actions -->
      <div class="flex items-center space-x-1.5">
        {#if viewMode === 'tree'}
          {#if stats}
            <span class="hidden xl:inline font-mono text-[11px] text-slate-400 pr-1">
              {stats.nodeCount} elemen • {stats.formattedSizeStr}
            </span>
          {/if}

          <button 
            onclick={handleCopyJson}
            disabled={!formattedCode}
            class="px-2.5 py-1 rounded-md bg-emerald-600/20 hover:bg-emerald-600/30 text-emerald-300 border border-emerald-500/30 text-[11px] font-semibold flex items-center space-x-1 cursor-pointer transition-colors disabled:opacity-30 shadow-xs"
            title="Salin JSON"
          >
            <Copy class="w-3 h-3 text-emerald-400" />
            <span>Salin JSON</span>
          </button>

          <button 
            onclick={handleExportJsonToNewTab}
            disabled={!formattedCode}
            class="hidden lg:flex items-center space-x-1 px-2 py-1 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-[11px] font-medium transition-colors cursor-pointer disabled:opacity-30"
            title="Buka JSON di tab catatan baru"
          >
            <ExternalLink class="w-3 h-3 text-slate-400" />
            <span>Ke Tab Catatan</span>
          </button>

        {:else if viewMode === 'table'}
          <button 
            onclick={handleCopyCsv}
            disabled={!csvOutput}
            class="px-2 py-1 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-200 hover:text-white text-[11px] font-medium flex items-center space-x-1 transition-colors cursor-pointer disabled:opacity-30"
            title="Salin data ke format CSV"
          >
            <Copy class="w-3 h-3 text-emerald-400" />
            <span class="hidden sm:inline">Salin CSV</span>
          </button>

          <button 
            onclick={handleDownloadCsv}
            disabled={!csvOutput}
            class="px-2 py-1 rounded-md bg-emerald-600/20 hover:bg-emerald-600/30 text-emerald-300 border border-emerald-500/30 text-[11px] font-semibold flex items-center space-x-1 cursor-pointer transition-colors disabled:opacity-30 shadow-xs"
            title="Unduh file .csv"
          >
            <Download class="w-3 h-3 text-emerald-400" />
            <span>Unduh CSV</span>
          </button>

          <button 
            onclick={handleExportMarkdownToNewTab}
            disabled={!markdownTableOutput}
            class="hidden lg:flex items-center space-x-1 px-2 py-1 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-[11px] font-medium transition-colors cursor-pointer disabled:opacity-30"
            title="Buka tabel markdown di tab catatan baru"
          >
            <ExternalLink class="w-3 h-3 text-slate-400" />
            <span>Ke Tab Catatan</span>
          </button>

        {:else if viewMode === 'csv'}
          <button 
            onclick={handleCopyCsv}
            disabled={!csvOutput}
            class="px-2.5 py-1 rounded-md bg-emerald-600/20 hover:bg-emerald-600/30 text-emerald-300 border border-emerald-500/30 text-[11px] font-semibold flex items-center space-x-1 cursor-pointer transition-colors disabled:opacity-30 shadow-xs"
            title="Salin CSV ke Clipboard"
          >
            <Copy class="w-3 h-3 text-emerald-400" />
            <span>Salin CSV</span>
          </button>

          <button 
            onclick={handleDownloadCsv}
            disabled={!csvOutput}
            class="px-2.5 py-1 rounded-md bg-blue-600 hover:bg-blue-500 text-white text-[11px] font-semibold flex items-center space-x-1 cursor-pointer transition-colors disabled:opacity-30 shadow-xs"
            title="Unduh file .csv"
          >
            <Download class="w-3 h-3" />
            <span>Unduh File .csv</span>
          </button>

          <button 
            onclick={handleExportCsvToNewTab}
            disabled={!csvOutput}
            class="hidden lg:flex items-center space-x-1 px-2 py-1 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-[11px] font-medium transition-colors cursor-pointer disabled:opacity-30"
            title="Buka CSV di tab catatan baru"
          >
            <ExternalLink class="w-3 h-3 text-slate-400" />
            <span>Ke Tab Baru</span>
          </button>

        {:else if viewMode === 'code'}
          <button 
            onclick={handleCopyJson}
            disabled={!formattedCode}
            class="px-2.5 py-1 rounded-md bg-emerald-600/20 hover:bg-emerald-600/30 text-emerald-300 border border-emerald-500/30 text-[11px] font-semibold flex items-center space-x-1 cursor-pointer transition-colors disabled:opacity-30 shadow-xs"
          >
            <Copy class="w-3 h-3 text-emerald-400" />
            <span>Salin JSON</span>
          </button>

          <button 
            onclick={handleExportJsonToNewTab}
            disabled={!formattedCode}
            class="hidden lg:flex items-center space-x-1 px-2 py-1 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-[11px] font-medium transition-colors cursor-pointer disabled:opacity-30"
          >
            <ExternalLink class="w-3 h-3 text-slate-400" />
            <span>Ke Tab Catatan</span>
          </button>
        {/if}
      </div>
    </div>

    <!-- Output Canvas Body -->
    <div class="flex-1 overflow-hidden flex flex-col">
      {#if parseResult.isEmpty}
        <!-- Empty State -->
        <div class="h-full flex flex-col items-center justify-center text-slate-500 space-y-3 p-6 text-center">
          <div class="w-14 h-14 rounded-2xl bg-slate-900 border border-slate-800 flex items-center justify-center text-slate-600 shadow-lg">
            <Table class="w-7 h-7 text-blue-500/60" />
          </div>
          <div class="space-y-1 max-w-sm">
            <h3 class="font-bold text-slate-300 text-sm">Konversi JSON ke Tabel Dinamis & CSV</h3>
            <p class="text-xs text-slate-500 leading-relaxed">
              Mendukung data acak dengan struktur kolom dinamis, nested object, dan respon API berjenjang.
            </p>
          </div>
          <div class="flex items-center space-x-2 pt-2">
            <button 
              onclick={handleLoadDynamicArray}
              class="px-3 py-1.5 rounded-lg bg-blue-600/10 hover:bg-blue-600/20 text-blue-400 border border-blue-500/30 text-xs font-semibold transition-all cursor-pointer shadow-xs"
            >
              Muat Data Dinamis
            </button>
            <button 
              onclick={handleLoadApiResponse}
              class="px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-semibold transition-all cursor-pointer"
            >
              Muat Respon API
            </button>
          </div>
        </div>

      {:else if !parseResult.isValid}
        <!-- Syntax Error Screen -->
        <div class="h-full flex flex-col items-center justify-center p-6 text-center space-y-4">
          <div class="w-12 h-12 rounded-2xl bg-red-500/10 border border-red-500/20 flex items-center justify-center text-red-400 shadow-md">
            <AlertCircle class="w-6 h-6" />
          </div>
          <div class="space-y-2 max-w-md w-full">
            <h3 class="font-bold text-red-300 text-sm">Sintaks JSON Tidak Valid</h3>
            <div class="p-3 bg-red-950/40 border border-red-900/50 rounded-xl text-left font-mono text-xs text-red-300 select-text">
              {parseResult.error}
            </div>
            <p class="text-[11.5px] text-slate-500 leading-relaxed text-left pt-1">
              💡 <strong>Tips Perbaikan:</strong><br />
              • Pastikan setiap kunci memakai tanda petik ganda <code class="text-slate-300">"kunci"</code>.<br />
              • Periksa koma berlebih (trailing comma) di akhir elemen array atau objek.<br />
              • Periksa kurung kurawal <code class="text-slate-300">&#123; &#125;</code> dan siku <code class="text-slate-300">[ ]</code>.
            </p>
          </div>
        </div>

      {:else}
        <!-- ============================================== -->
        <!-- VIEW 1: DYNAMIC TABLE                          -->
        <!-- ============================================== -->
        {#if viewMode === 'table'}
          <div class="flex-1 flex flex-col overflow-hidden">
            <!-- Table Secondary Control Toolbar -->
            <div class="h-11 px-3 bg-slate-900/50 border-b border-slate-800 flex items-center justify-between gap-3 text-xs flex-shrink-0">
              <!-- Left: Search Box -->
              <div class="relative flex-1 max-w-xs sm:max-w-sm">
                <Search class="w-3.5 h-3.5 absolute left-2.5 top-2.5 text-slate-500 pointer-events-none" />
                <input 
                  type="text" 
                  bind:value={searchTableQuery}
                  placeholder="Cari kata kunci dalam baris data..."
                  class="w-full pl-8 pr-3 py-1 bg-slate-950 border border-slate-800 rounded-lg text-xs text-slate-200 placeholder-slate-500 focus:outline-none focus:border-blue-500 transition-colors"
                />
              </div>

              <!-- Center/Right: Array Source Selector if Root Object has Arrays -->
              {#if detectedArraySources.length > 0}
                <div class="flex items-center space-x-1 overflow-x-auto scrollbar-none py-1">
                  <span class="text-[11px] text-slate-500 whitespace-nowrap">Sumber:</span>
                  {#each detectedArraySources as src}
                    <button 
                      onclick={() => (selectedArraySource = src.key)}
                      class="px-2 py-0.5 rounded text-[11px] font-medium transition-colors cursor-pointer whitespace-nowrap {(selectedArraySource === src.key || (!selectedArraySource && src.key === tableData.sourceName)) ? 'bg-blue-600 text-white font-semibold' : 'bg-slate-800 text-slate-300 hover:text-white'}"
                    >
                      {src.label}
                    </button>
                  {/each}
                  <button 
                    onclick={() => (selectedArraySource = '__root__')}
                    class="px-2 py-0.5 rounded text-[11px] font-medium transition-colors cursor-pointer whitespace-nowrap {selectedArraySource === '__root__' ? 'bg-blue-600 text-white font-semibold' : 'bg-slate-800 text-slate-400 hover:text-white'}"
                  >
                    Objek Utama
                  </button>
                </div>
              {/if}

              <!-- Right: Flatten Nested Toggle & Markdown Copy -->
              <div class="flex items-center space-x-2 flex-shrink-0">
                <label class="flex items-center space-x-1.5 text-[11px] text-slate-400 hover:text-slate-200 cursor-pointer select-none">
                  <input 
                    type="checkbox" 
                    bind:checked={flattenNested} 
                    class="rounded border-slate-700 bg-slate-900 text-blue-600 focus:ring-0 cursor-pointer"
                  />
                  <span>Ratakan Objek (Flatten)</span>
                </label>

                <div class="h-4 w-px bg-slate-800"></div>

                <button 
                  onclick={handleCopyMarkdown}
                  class="px-2 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-[11px] font-medium flex items-center space-x-1 transition-colors cursor-pointer"
                  title="Salin format tabel Markdown (| col1 | col2 |) untuk catatan Valtera"
                >
                  <FileText class="w-3 h-3 text-purple-400" />
                  <span class="hidden md:inline">Salin Markdown</span>
                </button>
              </div>
            </div>

            <!-- Dynamic Table Scrollable Container -->
            <div class="flex-1 overflow-auto bg-slate-950/40 select-text">
              {#if tableData.headers.length === 0}
                <div class="h-full flex items-center justify-center text-slate-500 text-xs p-6 text-center">
                  Data JSON kosong atau tidak memiliki properti untuk ditampilkan sebagai tabel.
                </div>
              {:else if filteredTableRows.length === 0}
                <div class="h-full flex flex-col items-center justify-center text-slate-500 space-y-2 p-6 text-center">
                  <Filter class="w-8 h-8 text-slate-600" />
                  <p class="text-xs">Tidak ada baris yang cocok dengan kata kunci: <strong class="text-slate-300 font-mono">"{searchTableQuery}"</strong></p>
                  <button 
                    onclick={() => (searchTableQuery = '')}
                    class="px-2.5 py-1 rounded bg-slate-800 text-blue-400 hover:text-blue-300 text-xs transition-colors cursor-pointer"
                  >
                    Reset Pencarian
                  </button>
                </div>
              {:else}
                <table class="w-full text-left border-collapse text-xs">
                  <!-- Sticky Header -->
                  <thead class="sticky top-0 z-10 bg-slate-900 border-b border-slate-800 shadow-xs">
                    <tr>
                      <th class="py-2 px-3 text-[11px] font-semibold text-slate-400 bg-slate-900 border-r border-slate-800/80 w-12 text-center select-none">
                        #
                      </th>
                      {#each tableData.headers as header}
                        <th class="py-2 px-3 text-[11px] font-bold text-slate-200 bg-slate-900 border-r border-slate-800/60 whitespace-nowrap font-mono tracking-wide">
                          <span class="text-blue-400">#</span> {header}
                        </th>
                      {/each}
                    </tr>
                  </thead>

                  <!-- Table Body Rows -->
                  <tbody class="divide-y divide-slate-800/60 font-normal">
                    {#each filteredTableRows as row, idx (row.__id || idx)}
                      <tr class="hover:bg-slate-800/40 transition-colors {idx % 2 === 1 ? 'bg-slate-900/20' : 'bg-transparent'}">
                        <!-- Row Index -->
                        <td class="py-2 px-3 text-[10.5px] font-mono text-slate-500 border-r border-slate-800/60 text-center select-none bg-slate-950/30">
                          {row.__id || idx + 1}
                        </td>

                        <!-- Cells -->
                        {#each tableData.headers as header}
                          <td class="py-2 px-3 border-r border-slate-800/40 align-middle max-w-[320px]">
                            {@render renderCellValue(row[header])}
                          </td>
                        {/each}
                      </tr>
                    {/each}
                  </tbody>
                </table>
              {/if}
            </div>

            <!-- Table Status Footer -->
            <div class="h-8 px-3 bg-slate-900/60 border-t border-slate-800 flex items-center justify-between text-[11px] text-slate-400 font-mono flex-shrink-0">
              <div class="flex items-center space-x-2 truncate">
                <span>Sumber: <strong class="text-slate-200">{tableData.sourceName}</strong></span>
                <span class="text-slate-600">•</span>
                <span>{filteredTableRows.length} dari {tableData.totalCount} baris</span>
                <span class="text-slate-600">•</span>
                <span>{tableData.headers.length} kolom dinamis</span>
              </div>
              {#if searchTableQuery}
                <span class="text-blue-400">Difilter: "{searchTableQuery}"</span>
              {/if}
            </div>
          </div>

        <!-- ============================================== -->
        <!-- VIEW 2: CSV EXPORT VIEW                        -->
        <!-- ============================================== -->
        {:else if viewMode === 'csv'}
          <div class="flex-1 flex flex-col overflow-hidden">
            <!-- CSV Config Toolbar -->
            <div class="h-11 px-3 bg-slate-900/50 border-b border-slate-800 flex items-center justify-between gap-3 text-xs flex-shrink-0">
              <!-- Delimiter Selector -->
              <div class="flex items-center space-x-2">
                <span class="text-[11px] text-slate-400">Pemisah (Delimiter):</span>
                <div class="flex items-center bg-slate-950 p-0.5 rounded-lg border border-slate-800">
                  <button 
                    onclick={() => (csvDelimiter = ',')}
                    class="px-2 py-0.5 rounded text-[11px] font-mono transition-all cursor-pointer {csvDelimiter === ',' ? 'bg-blue-600 text-white font-semibold' : 'text-slate-400 hover:text-slate-200'}"
                  >
                    Koma ( , )
                  </button>
                  <button 
                    onclick={() => (csvDelimiter = ';')}
                    class="px-2 py-0.5 rounded text-[11px] font-mono transition-all cursor-pointer {csvDelimiter === ';' ? 'bg-blue-600 text-white font-semibold' : 'text-slate-400 hover:text-slate-200'}"
                    title="Standar Excel regional Indonesia / Eropa"
                  >
                    Titik Koma ( ; )
                  </button>
                  <button 
                    onclick={() => (csvDelimiter = '\t')}
                    class="px-2 py-0.5 rounded text-[11px] font-mono transition-all cursor-pointer {csvDelimiter === '\t' ? 'bg-blue-600 text-white font-semibold' : 'text-slate-400 hover:text-slate-200'}"
                  >
                    Tab ( \t )
                  </button>
                </div>
              </div>

              <!-- Options -->
              <div class="flex items-center space-x-3">
                <label class="flex items-center space-x-1.5 text-[11px] text-slate-400 hover:text-slate-200 cursor-pointer select-none">
                  <input 
                    type="checkbox" 
                    bind:checked={includeCsvHeader} 
                    class="rounded border-slate-700 bg-slate-900 text-blue-600 focus:ring-0 cursor-pointer"
                  />
                  <span>Sertakan Baris Judul Kolom (Header)</span>
                </label>

                <label class="flex items-center space-x-1.5 text-[11px] text-slate-400 hover:text-slate-200 cursor-pointer select-none">
                  <input 
                    type="checkbox" 
                    bind:checked={flattenNested} 
                    class="rounded border-slate-700 bg-slate-900 text-blue-600 focus:ring-0 cursor-pointer"
                  />
                  <span>Ratakan Objek (Flatten)</span>
                </label>
              </div>
            </div>

            <!-- CSV Code Preview Canvas -->
            <div class="flex-1 overflow-auto p-3 bg-slate-950/40 select-text">
              {#if !csvOutput}
                <div class="h-full flex items-center justify-center text-slate-500 text-xs">
                  Tidak ada data untuk diekspor ke CSV.
                </div>
              {:else}
                <pre class="font-mono text-xs text-slate-200 leading-relaxed whitespace-pre font-medium p-2 bg-slate-900/30 border border-slate-800/80 rounded-xl select-text">{csvOutput}</pre>
              {/if}
            </div>

            <!-- CSV Status Footer -->
            <div class="h-8 px-3 bg-slate-900/60 border-t border-slate-800 flex items-center justify-between text-[11px] text-slate-400 font-mono flex-shrink-0">
              <div class="flex items-center space-x-2">
                <span>Format: <strong class="text-slate-200">{csvDelimiter === ',' ? 'RFC 4180 (Koma)' : csvDelimiter === ';' ? 'Excel Semicolon (;)' : 'TSV (Tab)'}</strong></span>
                <span class="text-slate-600">•</span>
                <span>{tableData.rows.length + (includeCsvHeader ? 1 : 0)} baris</span>
                <span class="text-slate-600">•</span>
                <span>{new Blob([csvOutput]).size} Bytes</span>
              </div>

              <div class="flex items-center space-x-2">
                <button 
                  onclick={handleCopyMarkdown}
                  class="text-purple-400 hover:text-purple-300 cursor-pointer flex items-center space-x-1"
                >
                  <FileText class="w-3 h-3" />
                  <span>Salin Sebagai Tabel Markdown</span>
                </button>
              </div>
            </div>
          </div>

        <!-- ============================================== -->
        <!-- VIEW 3: COLLAPSIBLE OBJECT TREE                -->
        <!-- ============================================== -->
        {:else if viewMode === 'tree'}
          <div class="flex-1 flex flex-col overflow-hidden p-3 select-text">
            <!-- Tree Filter & Expand Controls -->
            <div class="flex items-center justify-between gap-2 pb-2 border-b border-slate-800 flex-shrink-0">
              <div class="relative flex-1 max-w-sm">
                <Search class="w-3.5 h-3.5 absolute left-2.5 top-2.5 text-slate-500 pointer-events-none" />
                <input 
                  type="text" 
                  bind:value={searchTreeQuery}
                  placeholder="Filter kunci atau nilai objek..."
                  class="w-full pl-8 pr-3 py-1 bg-slate-950 border border-slate-800 rounded-lg text-xs text-slate-200 placeholder-slate-500 focus:outline-none focus:border-blue-500 transition-colors"
                />
              </div>

              <div class="flex items-center space-x-1.5">
                <button 
                  onclick={() => expandAllTrigger++}
                  class="px-2 py-1 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-xs font-medium flex items-center space-x-1 cursor-pointer transition-colors"
                >
                  <ChevronsDown class="w-3 h-3" />
                  <span>Buka Semua</span>
                </button>
                <button 
                  onclick={() => collapseAllTrigger++}
                  class="px-2 py-1 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-xs font-medium flex items-center space-x-1 cursor-pointer transition-colors"
                >
                  <ChevronsUp class="w-3 h-3" />
                  <span>Tutup Semua</span>
                </button>
              </div>
            </div>

            <!-- Collapsible Tree Root -->
            <div class="flex-1 overflow-auto font-mono text-xs p-1">
              <JsonTreeNode 
                value={parseResult.data} 
                searchQuery={searchTreeQuery}
                expandAllTrigger={expandAllTrigger}
                collapseAllTrigger={collapseAllTrigger}
                onCopyPath={(p) => showToast(`Path: ${p}`)}
                onCopyValue={() => showToast('Nilai tersalin!')}
              />
            </div>
          </div>

        <!-- ============================================== -->
        <!-- VIEW 4: RAW FORMATTED JSON CODE                -->
        <!-- ============================================== -->
        {:else}
          <div class="flex-1 flex flex-col overflow-hidden select-text">
            <!-- Indentation Controls Toolbar -->
            <div class="h-10 px-3 bg-slate-900/50 border-b border-slate-800 flex items-center justify-between text-xs flex-shrink-0">
              <div class="flex items-center space-x-1">
                <span class="text-[11px] text-slate-400 mr-1">Spasi:</span>
                <button 
                  onclick={() => handleFormat(2)}
                  class="px-2 py-0.5 rounded text-[11px] font-mono transition-colors cursor-pointer {indentSpaces === 2 ? 'bg-blue-600/20 text-blue-300 border border-blue-500/40 font-semibold' : 'bg-slate-800/80 text-slate-400 hover:text-white'}"
                >
                  2 Spasi
                </button>
                <button 
                  onclick={() => handleFormat(4)}
                  class="px-2 py-0.5 rounded text-[11px] font-mono transition-colors cursor-pointer {indentSpaces === 4 ? 'bg-blue-600/20 text-blue-300 border border-blue-500/40 font-semibold' : 'bg-slate-800/80 text-slate-400 hover:text-white'}"
                >
                  4 Spasi
                </button>
                <button 
                  onclick={handleMinify}
                  class="px-2 py-0.5 rounded text-[11px] font-mono transition-colors cursor-pointer bg-slate-800/80 text-slate-400 hover:text-white"
                >
                  Minify
                </button>
              </div>

              {#if stats}
                <span class="font-mono text-[11px] text-slate-400">
                  {stats.lineCount} baris • {stats.formattedSizeStr}
                </span>
              {/if}
            </div>

            <!-- Code Pre Area -->
            <div class="flex-1 overflow-auto p-3">
              <pre class="font-mono text-xs text-slate-200 leading-relaxed whitespace-pre select-text p-2 font-medium">{formattedCode}</pre>
            </div>
          </div>
        {/if}
      {/if}
    </div>
  </section>

  <!-- Toast Notification -->
  {#if copiedToast}
    <div class="fixed bottom-6 right-6 z-50 bg-slate-900 border border-slate-700 text-slate-100 text-xs px-4 py-2.5 rounded-xl shadow-2xl flex items-center space-x-2 animate-in fade-in slide-in-from-bottom-2 duration-150">
      <CheckCircle2 class="w-4 h-4 text-emerald-400 flex-shrink-0" />
      <span class="font-medium">{copiedToast}</span>
    </div>
  {/if}
</div>
