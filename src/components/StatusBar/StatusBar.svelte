<script lang="ts">
  import { editorStore } from '../../stores/editorStore.svelte';
  import { Cloud, CheckCircle2, Check, Sparkles } from 'lucide-svelte';

  const languages = [
    { label: 'Plain Text', ext: 'txt' },
    { label: 'Markdown', ext: 'md' },
    { label: 'SQL Script', ext: 'sql' },
    { label: 'JSON Data', ext: 'json' },
    { label: 'CSV Data', ext: 'csv' },
    { label: 'Rust Source', ext: 'rs' },
    { label: 'TypeScript', ext: 'ts' }
  ];

  let activeTab = $derived(editorStore.activeTab);
  let contentLength = $derived(activeTab ? activeTab.content.length : 0);
  let lineCount = $derived(activeTab ? activeTab.content.split('\n').length : 0);

  function handleLanguageChange(e: Event) {
    const target = e.target as HTMLSelectElement;
    editorStore.setFileExtension(target.value);
  }
</script>

<div class="h-6 bg-slate-950 border-t border-slate-800 flex items-center justify-between px-3 text-[11px] text-slate-400 select-none">
  <!-- Left info: Cursor Position & Document Stats -->
  <div class="flex items-center space-x-3">
    {#if activeTab}
      <div class="flex items-center space-x-1 font-mono">
        <span>Ln {activeTab.cursor_line}, Col {activeTab.cursor_col}</span>
      </div>

      <div class="text-slate-600">|</div>

      <div class="flex items-center space-x-1 font-mono text-slate-500">
        <span>{lineCount} lines</span>
        <span>•</span>
        <span>{contentLength} chars</span>
      </div>

      {#if editorStore.lastSavedAt}
        <div class="text-slate-600">|</div>
        <div class="text-emerald-500/80 flex items-center space-x-1">
          <Check class="w-3 h-3" />
          <span>Saved at {editorStore.lastSavedAt}</span>
        </div>
      {/if}
    {/if}
  </div>

  <!-- Right info: Language, Encoding, Sync Status -->
  <div class="flex items-center space-x-3">
    <!-- RAM Footprint Tag -->
    <div class="px-1.5 py-0.2 rounded bg-emerald-950/60 text-emerald-400 border border-emerald-800/40 text-[10px] font-mono">
      RAM: ~38MB
    </div>

    <div class="text-slate-600">|</div>

    <!-- Language Selector -->
    {#if activeTab}
      <div class="flex items-center">
        <select 
          value={activeTab.file_extension}
          onchange={handleLanguageChange}
          class="bg-transparent text-slate-300 hover:text-white cursor-pointer focus:outline-none text-[11px] font-medium"
        >
          {#each languages as lang}
            <option value={lang.ext} class="bg-slate-900 text-slate-200">{lang.label}</option>
          {/each}
        </select>
      </div>
    {/if}

    <div class="text-slate-600">|</div>

    <!-- Encoding & Line Ending -->
    <div class="font-mono text-slate-400">UTF-8</div>
    <div class="font-mono text-slate-400">LF</div>

    <div class="text-slate-600">|</div>

    <!-- Appwrite Sync Status -->
    <div class="flex items-center space-x-1 {editorStore.appwriteConfig.is_configured ? 'text-emerald-400' : 'text-slate-500'}">
      {#if editorStore.appwriteConfig.is_configured}
        <CheckCircle2 class="w-3 h-3 text-emerald-400" />
        <span>Appwrite Connected</span>
      {:else}
        <Cloud class="w-3 h-3 text-slate-600" />
        <span>Offline</span>
      {/if}
    </div>
  </div>
</div>
