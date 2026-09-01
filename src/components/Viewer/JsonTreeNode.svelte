<script lang="ts">
  import { 
    ChevronRight, 
    ChevronDown, 
    Copy, 
    Check, 
    Layers, 
    Brackets, 
    Hash, 
    Quote, 
    ToggleLeft 
  } from 'lucide-svelte';
  import JsonTreeNode from './JsonTreeNode.svelte';

  let { 
    keyName, 
    value, 
    path = '$', 
    depth = 0, 
    searchQuery = '',
    expandAllTrigger = 0,
    collapseAllTrigger = 0,
    onCopyPath,
    onCopyValue
  }: { 
    keyName?: string | number; 
    value: any; 
    path?: string; 
    depth?: number; 
    searchQuery?: string;
    expandAllTrigger?: number;
    collapseAllTrigger?: number;
    onCopyPath?: (path: string) => void;
    onCopyValue?: (val: any) => void;
  } = $props();

  let isOpen = $state(true);
  let isCopied = $state(false);

  let lastExpand = expandAllTrigger;
  let lastCollapse = collapseAllTrigger;

  $effect(() => {
    if (expandAllTrigger !== lastExpand) {
      lastExpand = expandAllTrigger;
      isOpen = true;
    }
  });

  $effect(() => {
    if (collapseAllTrigger !== lastCollapse) {
      lastCollapse = collapseAllTrigger;
      isOpen = (depth ?? 0) === 0;
    }
  });

  function isObject(val: any): boolean {
    return val !== null && typeof val === 'object' && !Array.isArray(val);
  }

  function isArray(val: any): boolean {
    return Array.isArray(val);
  }

  let valueType = $derived.by(() => {
    if (value === null) return 'null';
    if (isArray(value)) return 'array';
    if (isObject(value)) return 'object';
    return typeof value;
  });

  let childEntries = $derived.by(() => {
    if (isObject(value)) {
      return Object.entries(value);
    }
    if (isArray(value)) {
      return (value as any[]).map((item: any, idx: number) => [idx, item] as [number, any]);
    }
    return [];
  });

  let childCount = $derived(childEntries.length);

  let isMatch = $derived.by(() => {
    if (!searchQuery || !searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase().trim();
    const kStr = keyName !== undefined ? String(keyName).toLowerCase() : '';
    if (kStr.includes(q)) return true;
    if (valueType !== 'object' && valueType !== 'array') {
      const vStr = String(value).toLowerCase();
      return vStr.includes(q);
    }
    return false;
  });

  // Auto-expand if child contains search match
  $effect(() => {
    if (searchQuery && searchQuery.trim().length > 0) {
      isOpen = true;
    }
  });

  function handleCopy(e: MouseEvent, type: 'path' | 'value') {
    e.stopPropagation();
    if (type === 'path' && onCopyPath) {
      onCopyPath(path);
    } else if (type === 'value' && onCopyValue) {
      onCopyValue(value);
    } else {
      const text = type === 'path' ? path : (typeof value === 'object' ? JSON.stringify(value, null, 2) : String(value));
      navigator.clipboard.writeText(text);
    }
    isCopied = true;
    setTimeout(() => { isCopied = false; }, 1500);
  }
</script>

<div class="font-mono text-xs leading-relaxed group/node select-text">
  <!-- Node Header Row -->
  <div 
    class="flex items-center space-x-1 py-0.5 px-1.5 rounded hover:bg-slate-800/60 transition-colors cursor-pointer {isMatch && searchQuery ? 'bg-amber-950/40 border border-amber-800/40' : ''}"
    onclick={() => {
      if (valueType === 'object' || valueType === 'array') {
        isOpen = !isOpen;
      }
    }}
    role="button"
    tabindex="0"
    onkeydown={(e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        if (valueType === 'object' || valueType === 'array') isOpen = !isOpen;
      }
    }}
  >
    <!-- Expand / Collapse Toggle Icon -->
    {#if valueType === 'object' || valueType === 'array'}
      <button 
        class="w-4 h-4 flex items-center justify-center text-slate-400 hover:text-slate-200 transition-transform p-0.5 rounded hover:bg-slate-700/50"
        onclick={(e) => { e.stopPropagation(); isOpen = !isOpen; }}
        title={isOpen ? 'Collapse' : 'Expand'}
      >
        {#if isOpen}
          <ChevronDown class="w-3.5 h-3.5 text-slate-400" />
        {:else}
          <ChevronRight class="w-3.5 h-3.5 text-slate-400" />
        {/if}
      </button>
    {:else}
      <span class="w-4 h-4 inline-block"></span>
    {/if}

    <!-- Key Name -->
    {#if keyName !== undefined}
      <span class="text-blue-400 font-semibold hover:underline">
        {typeof keyName === 'number' ? `[${keyName}]` : `"${keyName}"`}
      </span>
      <span class="text-slate-500 mr-1">:</span>
    {/if}

    <!-- Value Display -->
    {#if valueType === 'object'}
      <span class="text-slate-400 font-semibold">{'{'}</span>
      {#if !isOpen}
        <span class="px-1.5 py-0.2 mx-1 text-[10px] rounded bg-slate-800 text-slate-400 border border-slate-700">
          {childCount} {childCount === 1 ? 'key' : 'keys'}
        </span>
        <span class="text-slate-400 font-semibold">{'}'}</span>
      {/if}
    {:else if valueType === 'array'}
      <span class="text-slate-400 font-semibold">{'['}</span>
      {#if !isOpen}
        <span class="px-1.5 py-0.2 mx-1 text-[10px] rounded bg-slate-800 text-slate-400 border border-slate-700">
          {childCount} {childCount === 1 ? 'item' : 'items'}
        </span>
        <span class="text-slate-400 font-semibold">{']'}</span>
      {/if}
    {:else if valueType === 'string'}
      <span class="text-emerald-300 break-all">"{value}"</span>
    {:else if valueType === 'number'}
      <span class="text-sky-400 font-semibold">{value}</span>
    {:else if valueType === 'boolean'}
      <span class="text-purple-400 font-bold">{value ? 'true' : 'false'}</span>
    {:else if valueType === 'null'}
      <span class="text-slate-500 italic">null</span>
    {:else}
      <span class="text-slate-300">{String(value)}</span>
    {/if}

    <!-- Quick Node Actions (Copy Path, Copy Value) on hover -->
    <div class="opacity-0 group-hover/node:opacity-100 flex items-center space-x-1 ml-2 transition-opacity">
      <button 
        onclick={(e) => handleCopy(e, 'path')}
        class="px-1.5 py-0.2 rounded text-[10px] bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-slate-200 border border-slate-700/60 transition-colors"
        title="Copy JSON Path ({path})"
      >
        Path
      </button>
      <button 
        onclick={(e) => handleCopy(e, 'value')}
        class="px-1.5 py-0.2 rounded text-[10px] bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-slate-200 border border-slate-700/60 transition-colors flex items-center space-x-0.5"
        title="Copy Node Value"
      >
        {#if isCopied}
          <Check class="w-2.5 h-2.5 text-emerald-400" />
          <span class="text-emerald-400">Copied</span>
        {:else}
          <Copy class="w-2.5 h-2.5" />
          <span>Copy</span>
        {/if}
      </button>
    </div>
  </div>

  <!-- Children Render (when expanded) -->
  {#if (valueType === 'object' || valueType === 'array') && isOpen}
    <div class="pl-4 ml-2 border-l border-slate-800/80 hover:border-slate-700 space-y-0.5 py-0.5 transition-colors">
      {#each childEntries as [cKey, cVal] (cKey)}
        {@const childPath = typeof cKey === 'number' ? `${path}[${cKey}]` : (path === '$' ? `$.${cKey}` : `${path}.${cKey}`)}
        <JsonTreeNode 
          keyName={cKey} 
          value={cVal} 
          path={childPath} 
          depth={depth + 1} 
          {searchQuery}
          {expandAllTrigger}
          {collapseAllTrigger}
          {onCopyPath}
          {onCopyValue}
        />
      {/each}
    </div>
    
    <!-- Closing Bracket Row -->
    <div class="pl-5 text-slate-400 font-semibold py-0.5">
      {valueType === 'object' ? '}' : ']'}
    </div>
  {/if}
</div>
