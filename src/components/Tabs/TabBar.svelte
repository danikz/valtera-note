<script lang="ts">
  import { editorStore } from '../../stores/editorStore.svelte';
  import { 
    FileText, 
    Database, 
    FileCode, 
    Plus, 
    X, 
    Columns, 
    Eye, 
    Edit3 
  } from 'lucide-svelte';

  function getFileIcon(ext: string) {
    switch (ext.toLowerCase()) {
      case 'sql': return Database;
      case 'md': case 'markdown': return Edit3;
      case 'json': case 'csv': case 'rs': case 'ts': case 'js': return FileCode;
      default: return FileText;
    }
  }
</script>

<div class="h-9 bg-slate-950 border-b border-slate-800 flex items-center justify-between px-2 overflow-hidden select-none">
  <!-- Tabs list -->
  <div class="flex items-center space-x-1 overflow-x-auto h-full py-1 scrollbar-none flex-1">
    {#each editorStore.tabs as tab, idx}
      {@const IconComponent = getFileIcon(tab.file_extension)}
      <div 
        class="group relative flex items-center space-x-1.5 px-3 py-1 rounded-t text-xs cursor-pointer border-t-2 transition-all max-w-[200px] h-full
        {idx === editorStore.activeTabIndex 
          ? 'bg-slate-900 text-slate-100 border-blue-500 font-medium' 
          : 'bg-slate-950/60 text-slate-400 border-transparent hover:bg-slate-900/40 hover:text-slate-300'}"
        onclick={() => editorStore.setActiveTab(idx)}
        onauxclick={(e) => { if (e.button === 1) editorStore.closeTab(idx); }}
        role="button"
        tabindex="0"
        onkeydown={(e) => { if (e.key === 'Enter') editorStore.setActiveTab(idx); }}
      >
        <IconComponent class="w-3.5 h-3.5 flex-shrink-0 {idx === editorStore.activeTabIndex ? 'text-blue-400' : 'text-slate-500'}" />
        
        <span class="truncate">{tab.title}</span>

        <!-- Dirty Indicator or Close Button -->
        <div class="flex items-center ml-1">
          {#if tab.is_dirty}
            <span class="w-2 h-2 rounded-full bg-amber-400 group-hover:hidden"></span>
          {/if}
          <button 
            onclick={(e) => { e.stopPropagation(); editorStore.closeTab(idx); }}
            class="p-0.5 rounded hover:bg-slate-800 text-slate-500 hover:text-slate-200 {tab.is_dirty ? 'hidden group-hover:block' : 'opacity-0 group-hover:opacity-100'} transition-opacity"
            title="Close Tab"
          >
            <X class="w-3 h-3" />
          </button>
        </div>
      </div>
    {/each}

    <!-- Add New Tab Button -->
    <button 
      onclick={() => editorStore.addTab()}
      class="p-1 rounded hover:bg-slate-800 text-slate-500 hover:text-slate-300 transition-colors"
      title="New Tab"
    >
      <Plus class="w-3.5 h-3.5" />
    </button>
  </div>

  <!-- Right: View Mode Switches (For Markdown or SQL) -->
  {#if editorStore.activeTab}
    {@const ext = editorStore.activeTab.file_extension}
    {#if ext === 'md' || ext === 'sql'}
      <div class="flex items-center space-x-1 pl-2 border-l border-slate-800">
        <button 
          onclick={() => editorStore.setSplitMode('editor-only')}
          class="p-1 rounded text-xs transition-colors {editorStore.activeTab.split_mode === 'editor-only' ? 'bg-blue-600/30 text-blue-400' : 'text-slate-500 hover:text-slate-300 hover:bg-slate-900'}"
          title="Editor Only"
        >
          <Edit3 class="w-3.5 h-3.5" />
        </button>

        <button 
          onclick={() => editorStore.setSplitMode('split-horizontal')}
          class="p-1 rounded text-xs transition-colors {editorStore.activeTab.split_mode === 'split-horizontal' ? 'bg-blue-600/30 text-blue-400' : 'text-slate-500 hover:text-slate-300 hover:bg-slate-900'}"
          title="Split View (Editor + Live Preview/Runner)"
        >
          <Columns class="w-3.5 h-3.5" />
        </button>

        <button 
          onclick={() => editorStore.setSplitMode('preview-only')}
          class="p-1 rounded text-xs transition-colors {editorStore.activeTab.split_mode === 'preview-only' ? 'bg-blue-600/30 text-blue-400' : 'text-slate-500 hover:text-slate-300 hover:bg-slate-900'}"
          title="Preview Only (Reader Mode)"
        >
          <Eye class="w-3.5 h-3.5" />
        </button>
      </div>
    {/if}
  {/if}
</div>
