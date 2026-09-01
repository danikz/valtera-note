<script lang="ts">
  import { open } from '@tauri-apps/plugin-dialog';
  import { editorStore } from '../../stores/editorStore.svelte';
  import { 
    Search, 
    Plus, 
    FolderOpen, 
    FolderPlus,
    Save, 
    Play, 
    Sparkles, 
    Columns, 
    Eye, 
    Cloud, 
    Edit3, 
    Database,
    PanelLeft,
    Trash2,
    ArrowUpCircle 
  } from 'lucide-svelte';

  let { 
    isOpen, 
    onClose, 
    onOpenSync, 
    onOpenSnippets, 
    onRunSql,
    onToggleSidebar 
  }: { 
    isOpen: boolean; 
    onClose: () => void; 
    onOpenSync: () => void; 
    onOpenSnippets: () => void; 
    onRunSql?: () => void; 
    onToggleSidebar?: () => void;
  } = $props();

  let query = $state('');
  let selectedIndex = $state(0);

  const commands = [
    {
      id: 'new-tab',
      title: 'New Tab / Note',
      shortcut: 'Ctrl+N',
      icon: Plus,
      action: () => editorStore.addTab()
    },
    {
      id: 'new-folder',
      title: 'Create New Folder',
      shortcut: '',
      icon: FolderPlus,
      action: () => {
        const name = prompt('Masukkan nama folder baru:');
        if (name && name.trim()) {
          editorStore.createFolder(name.trim());
        }
      }
    },
    {
      id: 'open-file',
      title: 'Open File from Disk',
      shortcut: 'Ctrl+O',
      icon: FolderOpen,
      action: async () => {
        try {
          const selected = await open({
            multiple: false,
            filters: [
              { name: 'All Supported', extensions: ['txt', 'md', 'sql', 'json', 'csv', 'rs', 'ts', 'js', 'py', 'log'] },
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
    },
    {
      id: 'save-file',
      title: 'Save / Sync Note',
      shortcut: 'Ctrl+S',
      icon: Save,
      action: () => editorStore.saveCurrentTab()
    },
    {
      id: 'delete-note',
      title: 'Delete Current Note Permanently',
      shortcut: '',
      icon: Trash2,
      action: () => {
        if (!editorStore.activeTab) return;
        if (confirm(`Hapus catatan "${editorStore.activeTab?.title}" secara permanen?`)) {
          editorStore.deleteTab(editorStore.activeTabIndex, true);
        }
      }
    },
    {
      id: 'clear-all-data',
      title: 'Reset / Clear All Notes & Folders',
      shortcut: '',
      icon: Trash2,
      action: () => {
        if (confirm('PERINGATAN: Apakah Anda yakin ingin menghapus semua catatan dan struktur folder (Lokal & Supabase Cloud)?')) {
          editorStore.clearAllData();
        }
      }
    },
    {
      id: 'snippets',
      title: 'Browse Snippets & Templates',
      shortcut: 'Ctrl+Shift+T',
      icon: Sparkles,
      action: () => onOpenSnippets()
    },
    {
      id: 'run-sql',
      title: 'Run SQL Query',
      shortcut: 'Ctrl+Enter',
      icon: Play,
      action: () => { if (onRunSql) onRunSql(); }
    },
    {
      id: 'split-view',
      title: 'Toggle Split View (Editor + Preview/Runner)',
      shortcut: 'Ctrl+\\',
      icon: Columns,
      action: () => editorStore.setSplitMode('split-horizontal')
    },
    {
      id: 'reader-mode',
      title: 'Toggle Reader Mode (Preview Only)',
      shortcut: 'Ctrl+Shift+P',
      icon: Eye,
      action: () => editorStore.setSplitMode('preview-only')
    },
    {
      id: 'lang-markdown',
      title: 'Set Language to Markdown',
      shortcut: '',
      icon: Edit3,
      action: () => editorStore.setFileExtension('md')
    },
    {
      id: 'lang-sql',
      title: 'Set Language to SQL Script',
      shortcut: '',
      icon: Database,
      action: () => editorStore.setFileExtension('sql')
    },
    {
      id: 'toggle-sidebar',
      title: 'Toggle Notes Sidebar',
      shortcut: 'Ctrl+B',
      icon: PanelLeft,
      action: () => { if (onToggleSidebar) onToggleSidebar(); }
    },
    {
      id: 'cloud-sync',
      title: 'Supabase Cloud Sync Settings',
      shortcut: '',
      icon: Cloud,
      action: () => onOpenSync()
    },
    {
      id: 'register-context-menu',
      title: 'Daftarkan "Open with Valtera Note" ke Klik-Kanan Windows',
      shortcut: '',
      icon: Sparkles,
      action: async () => {
        try {
          const { ipc } = await import('../../services/ipc');
          const msg = await ipc.registerContextMenu();
          alert(msg);
        } catch (e: any) {
          alert('Gagal mendaftarkan menu: ' + (e?.message || e));
        }
      }
    },
    {
      id: 'check-updates',
      title: 'Periksa Pembaruan Aplikasi (Check for Updates)',
      shortcut: '',
      icon: ArrowUpCircle,
      action: async () => {
        const { updaterService } = await import('../../services/updater.svelte');
        await updaterService.checkForUpdates(true);
      }
    }
  ];

  let filtered = $derived(
    commands.filter(c => c.title.toLowerCase().includes(query.toLowerCase()))
  );

  function executeCommand(cmd: typeof commands[0]) {
    cmd.action();
    onClose();
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      selectedIndex = (selectedIndex + 1) % (filtered.length || 1);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      selectedIndex = (selectedIndex - 1 + (filtered.length || 1)) % (filtered.length || 1);
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (filtered[selectedIndex]) {
        executeCommand(filtered[selectedIndex]);
      }
    } else if (e.key === 'Escape') {
      onClose();
    }
  }
</script>

{#if isOpen}
  <div 
    class="fixed inset-0 z-50 flex items-start justify-center pt-24 bg-black/70 backdrop-blur-xs p-4 select-none animate-in fade-in duration-100"
    onclick={onClose}
    role="presentation"
  >
    <!-- Modal Box -->
    <div 
      class="bg-slate-900 border border-slate-800 rounded-xl shadow-2xl w-full max-w-lg overflow-hidden flex flex-col text-slate-200"
      onclick={(e) => e.stopPropagation()}
      onkeydown={(e) => { if (e.key === 'Escape') onClose(); }}
      role="dialog"
      aria-modal="true"
      tabindex="-1"
    >
      <!-- Search Input -->
      <div class="h-12 bg-slate-950 border-b border-slate-800 flex items-center px-4 space-x-3">
        <Search class="w-4 h-4 text-blue-400 flex-shrink-0" />
        <input 
          type="text" 
          bind:value={query}
          onkeydown={handleKeyDown}
          placeholder="Type a command or search action..."
          class="w-full bg-transparent text-sm text-slate-100 placeholder-slate-500 focus:outline-none"
          autofocus
        />
        <kbd class="px-1.5 py-0.5 bg-slate-800 border border-slate-700 rounded text-[10px] text-slate-400 font-mono">ESC</kbd>
      </div>

      <!-- Commands List -->
      <div class="max-h-72 overflow-y-auto p-2 space-y-1 text-xs">
        {#each filtered as cmd, idx}
          {@const Icon = cmd.icon}
          <button 
            type="button"
            class="w-full flex items-center justify-between px-3 py-2 rounded-lg cursor-pointer transition-colors text-left {idx === selectedIndex ? 'bg-blue-600 text-white font-medium' : 'hover:bg-slate-800/70 text-slate-300'}"
            onclick={() => executeCommand(cmd)}
            onmouseenter={() => (selectedIndex = idx)}
          >
            <div class="flex items-center space-x-2.5 truncate">
              <Icon class="w-4 h-4 flex-shrink-0 {idx === selectedIndex ? 'text-white' : 'text-slate-400'}" />
              <span class="truncate">{cmd.title}</span>
            </div>

            {#if cmd.shortcut}
              <kbd class="px-1.5 py-0.2 rounded text-[10px] font-mono {idx === selectedIndex ? 'bg-blue-700 text-blue-100' : 'bg-slate-800 border border-slate-700 text-slate-400'}">{cmd.shortcut}</kbd>
            {/if}
          </button>
        {:else}
          <div class="p-6 text-center text-slate-500 text-xs italic">
            No matching commands found
          </div>
        {/each}
      </div>

      <!-- Footer Info -->
      <div class="h-8 bg-slate-950/80 border-t border-slate-800/80 px-4 flex items-center justify-between text-[11px] text-slate-500">
        <div class="flex items-center space-x-3">
          <span><kbd class="font-mono">↑↓</kbd> to navigate</span>
          <span><kbd class="font-mono">↵</kbd> to select</span>
        </div>
        <span>Valtera Note Command Palette</span>
      </div>

    </div>
  </div>
{/if}
