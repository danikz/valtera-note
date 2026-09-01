<script lang="ts">
  import { 
    Search, 
    ChevronsDown, 
    ChevronsUp, 
    Copy, 
    Check, 
    Sparkles, 
    Minimize2, 
    AlertCircle, 
    FileCode, 
    Layers,
    Wrench,
    CheckCheck
  } from 'lucide-svelte';
  import { editorStore } from '../../stores/editorStore.svelte';
  import JsonTreeNode from './JsonTreeNode.svelte';

  let searchQuery = $state('');
  let expandTrigger = $state(0);
  let collapseTrigger = $state(0);
  let copiedToast = $state<string | null>(null);

  let parseResult = $derived.by(() => {
    const raw = editorStore.activeTab?.content || '';
    if (!raw.trim()) {
      return { isValid: true, data: null, error: null, isEmpty: true };
    }
    try {
      const parsed = JSON.parse(raw);
      return { isValid: true, data: parsed, error: null, isEmpty: false };
    } catch (e: any) {
      return { isValid: false, data: null, error: e?.message || 'Invalid JSON syntax', isEmpty: false };
    }
  });

  function handleExpandAll() {
    expandTrigger++;
  }

  function handleCollapseAll() {
    collapseTrigger++;
  }

  function handleFormatJson(spaces = 2) {
    if (!parseResult.isValid || parseResult.data === null) return;
    try {
      const formatted = JSON.stringify(parseResult.data, null, spaces);
      if (editorStore.activeTab) {
        editorStore.updateContent(formatted);
      }
      showToast(`Formatted (${spaces} spaces)`);
    } catch (e) {
      console.warn('Format error:', e);
    }
  }

  function handleMinifyJson() {
    if (!parseResult.isValid || parseResult.data === null) return;
    try {
      const minified = JSON.stringify(parseResult.data);
      if (editorStore.activeTab) {
        editorStore.updateContent(minified);
      }
      showToast('Minified JSON');
    } catch (e) {
      console.warn('Minify error:', e);
    }
  }

  function handleCopyAll() {
    if (!parseResult.isValid || parseResult.data === null) return;
    try {
      navigator.clipboard.writeText(JSON.stringify(parseResult.data, null, 2));
      showToast('Copied full JSON to clipboard');
    } catch (e) {
      console.warn('Copy error:', e);
    }
  }

  function handleCopyPath(path: string) {
    navigator.clipboard.writeText(path);
    showToast(`Copied path: ${path}`);
  }

  function handleCopyValue(val: any) {
    const text = typeof val === 'object' ? JSON.stringify(val, null, 2) : String(val);
    navigator.clipboard.writeText(text);
    showToast('Copied value');
  }

  function showToast(msg: string) {
    copiedToast = msg;
    setTimeout(() => {
      if (copiedToast === msg) copiedToast = null;
    }, 2000);
  }

  let stats = $derived.by(() => {
    if (!parseResult.isValid || parseResult.data === null) return null;
    const isArr = Array.isArray(parseResult.data);
    const count = isArr ? parseResult.data.length : Object.keys(parseResult.data).length;
    return {
      type: isArr ? 'Array' : (typeof parseResult.data === 'object' ? 'Object' : typeof parseResult.data),
      count
    };
  });
</script>

<div class="h-full w-full flex flex-col bg-slate-950 text-slate-200 overflow-hidden select-none">
  <!-- Top Toolbar -->
  <div class="h-10 bg-slate-900 border-b border-slate-800 flex items-center justify-between px-3 text-xs flex-shrink-0">
    <!-- Left: Search Box -->
    <div class="flex items-center space-x-2 flex-1 max-w-xs">
      <div class="relative w-full">
        <Search class="w-3.5 h-3.5 absolute left-2.5 top-2 text-slate-500" />
        <input 
          type="text" 
          bind:value={searchQuery}
          placeholder="Filter keys or values..."
          class="w-full bg-slate-950 border border-slate-800 rounded-md pl-8 pr-2.5 py-1 text-xs text-slate-200 placeholder-slate-500 focus:outline-none focus:border-blue-500"
        />
      </div>
    </div>

    <!-- Center: Stats / Type Tag -->
    {#if stats}
      <div class="hidden sm:flex items-center space-x-1.5 px-2 py-0.5 rounded bg-slate-950 border border-slate-800 text-[11px] font-mono text-slate-400">
        <span class="text-blue-400 font-semibold">{stats.type}</span>
        <span>•</span>
        <span>{stats.count} {stats.type === 'Array' ? 'items' : 'keys'}</span>
      </div>
    {/if}

    <!-- Right: Tree & Format Actions -->
    <div class="flex items-center space-x-1">
      <!-- Expand All -->
      <button 
        onclick={handleExpandAll}
        disabled={!parseResult.isValid || parseResult.isEmpty}
        class="flex items-center space-x-1 px-2 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-300 font-medium transition-colors disabled:opacity-40"
        title="Expand All Nodes"
      >
        <ChevronsDown class="w-3.5 h-3.5 text-blue-400" />
        <span class="hidden md:inline text-[11px]">Expand</span>
      </button>

      <!-- Collapse All -->
      <button 
        onclick={handleCollapseAll}
        disabled={!parseResult.isValid || parseResult.isEmpty}
        class="flex items-center space-x-1 px-2 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-300 font-medium transition-colors disabled:opacity-40"
        title="Collapse All Nodes"
      >
        <ChevronsUp class="w-3.5 h-3.5 text-blue-400" />
        <span class="hidden md:inline text-[11px]">Collapse</span>
      </button>

      <div class="h-4 w-px bg-slate-800 mx-1"></div>

      <!-- Format / Prettify Button -->
      <button 
        onclick={() => handleFormatJson(2)}
        disabled={!parseResult.isValid || parseResult.isEmpty}
        class="flex items-center space-x-1 px-2 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-300 font-medium transition-colors disabled:opacity-40"
        title="Format JSON with 2-spaces indent"
      >
        <Sparkles class="w-3.5 h-3.5 text-amber-400" />
        <span class="hidden md:inline text-[11px]">Prettify</span>
      </button>

      <!-- Minify Button -->
      <button 
        onclick={handleMinifyJson}
        disabled={!parseResult.isValid || parseResult.isEmpty}
        class="flex items-center space-x-1 px-2 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-300 font-medium transition-colors disabled:opacity-40"
        title="Minify JSON (Compact 1 line)"
      >
        <Minimize2 class="w-3.5 h-3.5 text-sky-400" />
        <span class="hidden md:inline text-[11px]">Minify</span>
      </button>

      <!-- Copy All Button -->
      <button 
        onclick={handleCopyAll}
        disabled={!parseResult.isValid || parseResult.isEmpty}
        class="p-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-300 transition-colors disabled:opacity-40"
        title="Copy Formatted JSON"
      >
        <Copy class="w-3.5 h-3.5" />
      </button>
    </div>
  </div>

  <!-- Main Tree View Body -->
  <div class="flex-1 overflow-auto p-4 bg-slate-900/40 relative select-text">
    {#if parseResult.isEmpty}
      <div class="h-full flex flex-col items-center justify-center text-slate-500 space-y-2">
        <FileCode class="w-10 h-10 opacity-30 text-slate-400" />
        <span class="text-xs italic">JSON document is empty</span>
      </div>
    {:else if !parseResult.isValid}
      <!-- JSON Syntax Error Banner -->
      <div class="max-w-md mx-auto my-8 p-4 rounded-xl bg-red-950/40 border border-red-800/60 text-red-300 space-y-2 text-xs shadow-xl">
        <div class="flex items-center space-x-2 text-red-400 font-semibold text-sm">
          <AlertCircle class="w-4 h-4" />
          <span>Invalid JSON Syntax</span>
        </div>
        <p class="font-mono text-[11px] bg-red-950/80 p-2.5 rounded border border-red-900/50 text-red-200 break-all">
          {parseResult.error}
        </p>
        <p class="text-[11px] text-red-300/80">
          Periksa kembali tanda kutip ganda, koma di akhir baris, atau tanda kurung kurawal pada editor sebelah kiri.
        </p>
      </div>
    {:else}
      <!-- Interactive Recursive Tree -->
      <div class="space-y-0.5">
        <JsonTreeNode 
          value={parseResult.data} 
          path="$" 
          depth={0} 
          {searchQuery}
          expandAllTrigger={expandTrigger}
          collapseAllTrigger={collapseTrigger}
          onCopyPath={handleCopyPath}
          onCopyValue={handleCopyValue}
        />
      </div>
    {/if}

    <!-- Toast Notification -->
    {#if copiedToast}
      <div class="absolute bottom-4 right-4 px-3 py-1.5 rounded-lg bg-slate-800 border border-slate-700 text-slate-200 text-xs shadow-2xl flex items-center space-x-2 animate-in fade-in zoom-in-95 duration-150">
        <Check class="w-3.5 h-3.5 text-emerald-400" />
        <span>{copiedToast}</span>
      </div>
    {/if}
  </div>
</div>
