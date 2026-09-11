<script lang="ts">
  import { onMount } from 'svelte';
  import { 
    ArrowLeft, 
    FileCode, 
    Database, 
    Binary, 
    Globe, 
    Key, 
    Lock,
    Sparkles,
    Sliders,
    Image as ImageIcon
  } from 'lucide-svelte';
  import JsonToolPage from './JsonToolPage.svelte';
  import FaviconToolPage from './FaviconToolPage.svelte';
  import MysqlPasswordToolPage from './MysqlPasswordToolPage.svelte';
  import Base64ToolPage from './Base64ToolPage.svelte';
  import UrlToolPage from './UrlToolPage.svelte';
  import UuidToolPage from './UuidToolPage.svelte';

  export type ToolType = 'json' | 'favicon' | 'mysql-password' | 'base64' | 'url' | 'uuid';

  let { 
    activeTool = 'json',
    onSelectTool,
    onBack 
  }: { 
    activeTool?: ToolType;
    onSelectTool: (tool: ToolType) => void;
    onBack: () => void;
  } = $props();

  const TOOL_TABS: { id: ToolType; label: string; icon: any; iconColor: string; shortcut?: string }[] = [
    { 
      id: 'json', 
      label: 'JSON, Tabel & CSV', 
      icon: FileCode, 
      iconColor: 'text-blue-400',
      shortcut: 'Ctrl+Shift+J'
    },
    { 
      id: 'favicon', 
      label: 'Favicon Generator', 
      icon: ImageIcon, 
      iconColor: 'text-amber-400',
      shortcut: 'Ctrl+Shift+F'
    },
    { 
      id: 'mysql-password', 
      label: 'MySQL Password', 
      icon: Database, 
      iconColor: 'text-emerald-400',
      shortcut: 'Ctrl+Shift+P'
    },
    { 
      id: 'base64', 
      label: 'Base64', 
      icon: Binary, 
      iconColor: 'text-cyan-400' 
    },
    { 
      id: 'url', 
      label: 'URL Encoder', 
      icon: Globe, 
      iconColor: 'text-purple-400' 
    },
    { 
      id: 'uuid', 
      label: 'UUID Generator', 
      icon: Key, 
      iconColor: 'text-amber-400' 
    }
  ];

  function handleKeyDown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      e.preventDefault();
      onBack();
    } else if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key.toLowerCase() === 'j') {
      e.preventDefault();
      onSelectTool('json');
    } else if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key.toLowerCase() === 'f') {
      e.preventDefault();
      onSelectTool('favicon');
    } else if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key.toLowerCase() === 'p') {
      e.preventDefault();
      onSelectTool('mysql-password');
    }
  }

  onMount(() => {
    window.addEventListener('keydown', handleKeyDown);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
    };
  });
</script>

<div class="h-full w-full flex flex-col bg-slate-950 text-slate-100 overflow-hidden select-none">
  <!-- Top Master Navigation & Tool Switcher Bar -->
  <header class="h-11 bg-slate-900 border-b border-slate-800 flex items-center justify-between px-3 flex-shrink-0 z-30 shadow-xs">
    <!-- Left: Back Button & Tool Switcher Tabs -->
    <div class="flex items-center space-x-2 md:space-x-3 overflow-x-auto scrollbar-none py-1 min-w-0">
      <button 
        onclick={onBack}
        class="flex items-center space-x-1.5 px-2.5 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 hover:text-white text-xs font-semibold transition-all cursor-pointer shadow-xs flex-shrink-0"
        title="Kembali ke Editor Catatan (Esc)"
      >
        <ArrowLeft class="w-4 h-4 text-slate-400" />
        <span class="hidden sm:inline">Kembali ke Catatan</span>
        <span class="sm:hidden">Catatan</span>
        <kbd class="hidden md:inline text-[9px] font-mono px-1 rounded bg-slate-950 text-slate-400 border border-slate-700 ml-0.5">Esc</kbd>
      </button>

      <div class="h-4 w-px bg-slate-800 flex-shrink-0"></div>

      <!-- Tool Tabs Strip -->
      <nav class="flex items-center space-x-1 flex-shrink-0">
        {#each TOOL_TABS as tab}
          {@const Icon = tab.icon}
          <button 
            onclick={() => onSelectTool(tab.id)}
            class="flex items-center space-x-1.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition-all cursor-pointer {activeTool === tab.id ? 'bg-blue-600 text-white font-semibold shadow-xs' : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/80'}"
            title={tab.shortcut ? `${tab.label} (${tab.shortcut})` : tab.label}
          >
            <Icon class="w-3.5 h-3.5 {activeTool === tab.id ? 'text-white' : tab.iconColor}" />
            <span>{tab.label}</span>
          </button>
        {/each}
      </nav>
    </div>

    <!-- Right: In-Memory Privacy Badge -->
    <div class="flex items-center space-x-2 flex-shrink-0 pl-2">
      <span class="hidden lg:flex items-center space-x-1 px-2.5 py-1 text-[11px] font-mono rounded-full bg-amber-500/10 text-amber-400 border border-amber-500/20 font-medium">
        <Lock class="w-3 h-3 text-amber-400" />
        <span>🔒 In-Memory Only (Tidak Disimpan)</span>
      </span>
      <span class="lg:hidden flex items-center space-x-1 px-2 py-0.5 text-[10px] font-mono rounded-full bg-amber-500/10 text-amber-400 border border-amber-500/20">
        <Lock class="w-3 h-3 text-amber-400" />
        <span>In-Memory</span>
      </span>
    </div>
  </header>

  <!-- Active Tool Full-Page Content Canvas -->
  <main class="flex-1 overflow-hidden relative">
    {#if activeTool === 'json'}
      <JsonToolPage onBack={onBack} showBackButton={false} />
    {:else if activeTool === 'favicon'}
      <FaviconToolPage onBack={onBack} />
    {:else if activeTool === 'mysql-password'}
      <MysqlPasswordToolPage />
    {:else if activeTool === 'base64'}
      <Base64ToolPage />
    {:else if activeTool === 'url'}
      <UrlToolPage />
    {:else if activeTool === 'uuid'}
      <UuidToolPage />
    {/if}
  </main>
</div>
