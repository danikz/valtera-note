<script lang="ts">
  import { 
    X, 
    Search, 
    Sparkles, 
    Copy, 
    Check, 
    Smile, 
    Command, 
    Layers 
  } from 'lucide-svelte';
  import { EMOJI_LIST, EMOJI_CATEGORIES, type EmojiItem } from '../../utils/emojis';
  import { editorStore } from '../../stores/editorStore.svelte';

  let { isOpen, onClose }: { isOpen: boolean; onClose: () => void } = $props();

  let searchQuery = $state('');
  let selectedCategory = $state<string>('all');
  let hoveredEmoji = $state<EmojiItem | null>(null);
  let copiedChar = $state<string | null>(null);
  let searchInputRef = $state<HTMLInputElement | null>(null);

  let filteredEmojis = $derived(
    EMOJI_LIST.filter((item) => {
      // 1. Filter by category
      if (selectedCategory !== 'all' && item.category !== selectedCategory) {
        return false;
      }

      // 2. Filter by search query
      const q = searchQuery.trim().toLowerCase();
      if (!q) return true;

      if (item.name.toLowerCase().includes(q)) return true;
      if (item.title.toLowerCase().includes(q)) return true;
      if (item.char === q) return true;
      return item.keywords.some((k) => k.toLowerCase().includes(q));
    })
  );

  $effect(() => {
    if (isOpen) {
      setTimeout(() => {
        if (searchInputRef) searchInputRef.focus();
      }, 50);
    } else {
      searchQuery = '';
      hoveredEmoji = null;
    }
  });

  function handleSelectEmoji(item: EmojiItem) {
    // If no note tab is open, open a new note first
    if (!editorStore.activeTab) {
      editorStore.addTab();
    }

    if (typeof window !== 'undefined') {
      window.dispatchEvent(new CustomEvent('valtera:insert-text', { detail: item.char }));
    }

    onClose();
  }

  async function handleCopyEmoji(e: MouseEvent, item: EmojiItem) {
    e.stopPropagation();
    try {
      await navigator.clipboard.writeText(item.char);
      copiedChar = item.char;
      setTimeout(() => {
        if (copiedChar === item.char) copiedChar = null;
      }, 1500);
    } catch (err) {
      console.warn('Failed to copy emoji to clipboard:', err);
    }
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      e.preventDefault();
      onClose();
    }
  }
</script>

{#if isOpen}
  <!-- Backdrop -->
  <div 
    class="fixed inset-0 z-50 bg-black/70 backdrop-blur-xs flex items-center justify-center p-4 animate-in fade-in duration-150"
    onclick={onClose}
    role="dialog"
    aria-modal="true"
    tabindex="-1"
    onkeydown={handleKeyDown}
  >
    <!-- Modal Window -->
    <div 
      class="bg-slate-900 border border-slate-800 rounded-xl shadow-2xl w-full max-w-xl overflow-hidden flex flex-col max-h-[85vh] animate-in zoom-in-95 duration-150 text-slate-100"
      onclick={(e) => e.stopPropagation()}
      role="document"
    >
      <!-- Header -->
      <div class="px-4 py-3 bg-slate-950/80 border-b border-slate-800 flex items-center justify-between">
        <div class="flex items-center space-x-2.5">
          <div class="w-8 h-8 rounded-lg bg-blue-500/10 border border-blue-500/20 flex items-center justify-center text-blue-400">
            <Smile class="w-4 h-4" />
          </div>
          <div>
            <div class="flex items-center space-x-2">
              <h3 class="font-semibold text-sm text-slate-200">Sisipkan Emoji & Icon</h3>
              <span class="px-1.5 py-0.5 text-[10px] font-mono rounded bg-slate-800 text-slate-400 border border-slate-700">
                Ctrl+Shift+E
              </span>
            </div>
            <p class="text-[11px] text-slate-400">
              Pilih icon untuk disisipkan ke kursor editor catatan
            </p>
          </div>
        </div>

        <button 
          onclick={onClose}
          class="p-1 rounded-lg hover:bg-slate-800 text-slate-400 hover:text-slate-200 transition-colors"
          title="Tutup (Esc)"
        >
          <X class="w-4 h-4" />
        </button>
      </div>

      <!-- Search & Category Filters -->
      <div class="p-3 bg-slate-900 border-b border-slate-800 space-y-2.5">
        <!-- Search Input -->
        <div class="relative flex items-center">
          <Search class="w-4 h-4 absolute left-3 text-slate-400 pointer-events-none" />
          <input 
            bind:this={searchInputRef}
            type="text"
            bind:value={searchQuery}
            placeholder="Cari icon / emoji (cth: roket, bug, database, check, api, star)..."
            class="w-full pl-9 pr-8 py-2 bg-slate-950 border border-slate-800 rounded-lg text-xs text-slate-200 placeholder-slate-500 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500/30 transition-all font-sans"
          />
          {#if searchQuery}
            <button 
              onclick={() => (searchQuery = '')}
              class="absolute right-2.5 text-slate-500 hover:text-slate-300 p-0.5 rounded"
            >
              <X class="w-3.5 h-3.5" />
            </button>
          {/if}
        </div>

        <!-- Category Tabs -->
        <div class="flex items-center space-x-1 overflow-x-auto pb-0.5 scrollbar-none text-xs">
          {#each EMOJI_CATEGORIES as cat}
            <button 
              onclick={() => (selectedCategory = cat.id)}
              class="px-2.5 py-1 rounded-lg text-[11px] font-medium transition-all whitespace-nowrap cursor-pointer {selectedCategory === cat.id ? 'bg-blue-600 text-white shadow-xs' : 'bg-slate-950/60 text-slate-400 hover:text-slate-200 hover:bg-slate-800'}"
            >
              {cat.label}
            </button>
          {/each}
        </div>
      </div>

      <!-- Emoji Grid -->
      <div class="flex-1 overflow-y-auto p-3 min-h-[220px] max-h-[340px]">
        {#if filteredEmojis.length > 0}
          <div class="grid grid-cols-7 sm:grid-cols-8 gap-1.5">
            {#each filteredEmojis as item (item.name + item.char)}
              <button 
                onclick={() => handleSelectEmoji(item)}
                onmouseenter={() => (hoveredEmoji = item)}
                class="group flex flex-col items-center justify-center p-2 rounded-xl bg-slate-950/40 hover:bg-blue-600/20 border border-transparent hover:border-blue-500/40 transition-all cursor-pointer hover:scale-110 aspect-square"
                title="{item.title} (:{item.name}:)"
              >
                <span class="text-2xl select-none transition-transform group-hover:scale-105">
                  {item.char}
                </span>
              </button>
            {/each}
          </div>
        {:else}
          <div class="h-48 flex flex-col items-center justify-center text-slate-500 space-y-2">
            <Search class="w-6 h-6 text-slate-600" />
            <p class="text-xs">Tidak ditemukan icon untuk "{searchQuery}"</p>
          </div>
        {/if}
      </div>

      <!-- Bottom Preview & Inline Tips Footer -->
      <div class="px-4 py-2.5 bg-slate-950 border-t border-slate-800 flex items-center justify-between text-xs min-h-[46px]">
        {#if hoveredEmoji}
          <div class="flex items-center space-x-2.5 truncate">
            <span class="text-2xl select-none">{hoveredEmoji.char}</span>
            <div class="truncate">
              <div class="font-medium text-slate-200 text-xs truncate">{hoveredEmoji.title}</div>
              <div class="flex items-center space-x-1.5 text-[10.5px] text-slate-400 font-mono">
                <span class="text-blue-400">:{hoveredEmoji.name}:</span>
                {#if hoveredEmoji.keywords.length > 0}
                  <span class="text-slate-600">•</span>
                  <span class="truncate text-slate-500">{hoveredEmoji.keywords.slice(0, 3).join(', ')}</span>
                {/if}
              </div>
            </div>
          </div>

          <div class="flex items-center space-x-2 flex-shrink-0 pl-2">
            <button 
              onclick={(e) => handleCopyEmoji(e, hoveredEmoji!)}
              class="flex items-center space-x-1 px-2.5 py-1 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition-colors cursor-pointer text-xs"
              title="Salin karakter emoji"
            >
              {#if copiedChar === hoveredEmoji.char}
                <Check class="w-3 h-3 text-emerald-400" />
                <span class="text-emerald-400 text-[11px]">Tersalin</span>
              {:else}
                <Copy class="w-3 h-3" />
                <span class="text-[11px]">Salin</span>
              {/if}
            </button>
            <kbd class="px-1.5 py-0.5 bg-slate-900 border border-slate-800 rounded text-[10px] text-slate-500 font-mono">
              Esc
            </kbd>
          </div>
        {:else}
          <div class="flex items-center space-x-2 text-[11px] text-slate-400">
            <span class="text-amber-400">💡</span>
            <span>Ketik langsung <code class="px-1 py-0.5 bg-slate-900 rounded text-blue-300 font-mono">:nama_icon:</code> di editor untuk autocomplete cepat!</span>
          </div>

          <div class="flex items-center space-x-2 flex-shrink-0 pl-2">
            <kbd class="px-1.5 py-0.5 bg-slate-900 border border-slate-800 rounded text-[10px] text-slate-500 font-mono">
              Esc Tutup
            </kbd>
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}

