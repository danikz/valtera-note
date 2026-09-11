<script lang="ts">
  import { onMount } from 'svelte';
  import { 
    Key, 
    RefreshCw, 
    Copy, 
    Check, 
    CheckCircle2, 
    Sliders, 
    Database, 
    Code, 
    FileText,
    Sparkles
  } from 'lucide-svelte';

  let count = $state<number>(10);
  let isUppercase = $state(false);
  let removeHyphens = $state(false);
  let outputFormat = $state<'plain' | 'sql' | 'json' | 'csv'>('plain');
  let generatedUuids = $state<string[]>([]);
  let copiedToast = $state<string | null>(null);

  function generate() {
    const list: string[] = [];
    for (let i = 0; i < count; i++) {
      let id: string = crypto.randomUUID();
      if (removeHyphens) {
        id = id.replace(/-/g, '');
      }
      if (isUppercase) {
        id = id.toUpperCase();
      }
      list.push(id);
    }
    generatedUuids = list;
  }

  let formattedOutput = $derived.by(() => {
    if (generatedUuids.length === 0) return '';
    if (outputFormat === 'plain') {
      return generatedUuids.join('\n');
    } else if (outputFormat === 'sql') {
      return generatedUuids.map(id => `('${id}')`).join(',\n') + ';';
    } else if (outputFormat === 'json') {
      return JSON.stringify(generatedUuids, null, 2);
    } else if (outputFormat === 'csv') {
      return generatedUuids.map(id => `"${id}"`).join(', ');
    }
    return generatedUuids.join('\n');
  });

  async function handleCopyAll() {
    if (!formattedOutput) return;
    try {
      await navigator.clipboard.writeText(formattedOutput);
      showToast(`${generatedUuids.length} UUID tersalin!`);
    } catch (err) {
      console.warn(err);
    }
  }

  async function handleCopySingle(text: string, idx: number) {
    try {
      await navigator.clipboard.writeText(text);
      showToast(`UUID #${idx + 1} tersalin!`);
    } catch (err) {
      console.warn(err);
    }
  }

  function showToast(msg: string) {
    copiedToast = msg;
    setTimeout(() => {
      if (copiedToast === msg) copiedToast = null;
    }, 2000);
  }

  onMount(() => {
    generate();
  });
</script>

<div class="h-full w-full flex flex-col bg-slate-950 text-slate-100 overflow-hidden select-none">
  <!-- Main Grid Area -->
  <div class="flex-1 overflow-y-auto p-4 md:p-6 flex flex-col items-center">
    <div class="w-full max-w-5xl space-y-6">

      <!-- Header & Intro -->
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-4 border-b border-slate-800">
        <div class="space-y-1">
          <div class="flex items-center space-x-2">
            <div class="w-8 h-8 rounded-lg bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400 shadow-xs">
              <Key class="w-4 h-4" />
            </div>
            <h2 class="text-lg font-bold text-white tracking-tight">UUIDv4 Batch Generator</h2>
            <span class="px-2 py-0.5 text-[11px] font-mono rounded-full bg-blue-500/10 text-blue-400 border border-blue-500/20 font-medium">
              RFC 4122 Standard
            </span>
          </div>
          <p class="text-xs text-slate-400 leading-relaxed max-w-2xl">
            Menghasilkan identifier unik global (Universally Unique Identifier) versi 4 yang acak secara kriptografis menggunakan <code class="text-slate-300">crypto.randomUUID()</code>.
          </p>
        </div>

        <div class="flex items-center space-x-2">
          <button 
            onclick={generate}
            class="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 hover:text-white text-xs font-semibold flex items-center space-x-1.5 cursor-pointer transition-colors shadow-xs"
          >
            <RefreshCw class="w-3.5 h-3.5 text-amber-400" />
            <span>Generate Baru</span>
          </button>

          <button 
            onclick={handleCopyAll}
            class="px-3.5 py-1.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-semibold flex items-center space-x-1.5 cursor-pointer transition-colors shadow-md shadow-blue-900/30"
          >
            {#if copiedToast?.includes('tersalin')}
              <Check class="w-3.5 h-3.5 text-emerald-300" />
              <span>Tersalin!</span>
            {:else}
              <Copy class="w-3.5 h-3.5" />
              <span>Salin Semua ({generatedUuids.length})</span>
            {/if}
          </button>
        </div>
      </div>

      <!-- Settings & Controls Grid -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Left 1/3: Configuration Options -->
        <div class="lg:col-span-1 bg-slate-900 border border-slate-800 rounded-2xl p-5 space-y-5 h-fit">
          <div class="flex items-center space-x-2 text-sm font-bold text-slate-200">
            <Sliders class="w-4 h-4 text-amber-400" />
            <span>Opsi Pembuatan</span>
          </div>

          <!-- Quantity Selector -->
          <div class="space-y-2">
            <span class="text-xs text-slate-300 font-medium block">Jumlah UUID yang Dibuat:</span>
            <div class="grid grid-cols-5 gap-1">
              {#each [1, 5, 10, 25, 50] as cnt}
                <button 
                  onclick={() => { count = cnt; generate(); }}
                  class="py-1.5 rounded-lg text-xs font-mono font-medium transition-colors cursor-pointer {count === cnt ? 'bg-blue-600 text-white shadow-xs' : 'bg-slate-800 text-slate-400 hover:text-white'}"
                >
                  {cnt}
                </button>
              {/each}
            </div>
          </div>

          <!-- Format Style -->
          <div class="space-y-2">
            <span class="text-xs text-slate-300 font-medium block">Format Output Ekspor:</span>
            <div class="grid grid-cols-2 gap-1.5 text-xs">
              <button 
                onclick={() => outputFormat = 'plain'}
                class="px-2.5 py-1.5 rounded-lg font-medium transition-colors cursor-pointer {outputFormat === 'plain' ? 'bg-slate-800 text-white border border-blue-500/50' : 'bg-slate-950 text-slate-400 hover:text-white border border-slate-800'}"
              >
                Plain Text (1 / Baris)
              </button>
              <button 
                onclick={() => outputFormat = 'sql'}
                class="px-2.5 py-1.5 rounded-lg font-medium transition-colors cursor-pointer {outputFormat === 'sql' ? 'bg-slate-800 text-white border border-blue-500/50' : 'bg-slate-950 text-slate-400 hover:text-white border border-slate-800'}"
              >
                SQL In-Clause ('id'),
              </button>
              <button 
                onclick={() => outputFormat = 'json'}
                class="px-2.5 py-1.5 rounded-lg font-medium transition-colors cursor-pointer {outputFormat === 'json' ? 'bg-slate-800 text-white border border-blue-500/50' : 'bg-slate-950 text-slate-400 hover:text-white border border-slate-800'}"
              >
                JSON Array [...]
              </button>
              <button 
                onclick={() => outputFormat = 'csv'}
                class="px-2.5 py-1.5 rounded-lg font-medium transition-colors cursor-pointer {outputFormat === 'csv' ? 'bg-slate-800 text-white border border-blue-500/50' : 'bg-slate-950 text-slate-400 hover:text-white border border-slate-800'}"
              >
                CSV List
              </button>
            </div>
          </div>

          <!-- Toggles -->
          <div class="space-y-2.5 text-xs pt-1 border-t border-slate-800">
            <label class="flex items-center space-x-2.5 cursor-pointer text-slate-300 hover:text-white">
              <input 
                type="checkbox" 
                bind:checked={isUppercase} 
                onchange={generate}
                class="rounded border-slate-700 text-blue-600 focus:ring-blue-500 bg-slate-950 w-4 h-4"
              />
              <span>Huruf Kapital (UPPERCASE)</span>
            </label>

            <label class="flex items-center space-x-2.5 cursor-pointer text-slate-300 hover:text-white">
              <input 
                type="checkbox" 
                bind:checked={removeHyphens} 
                onchange={generate}
                class="rounded border-slate-700 text-blue-600 focus:ring-blue-500 bg-slate-950 w-4 h-4"
              />
              <span>Hapus Tanda Strip / Hyphen (32 Char Hex)</span>
            </label>
          </div>
        </div>

        <!-- Right 2/3: Generated UUID List & Formatted Preview -->
        <div class="lg:col-span-2 bg-slate-900 border border-slate-800 rounded-2xl p-5 space-y-4 flex flex-col">
          <div class="flex items-center justify-between text-xs pb-2 border-b border-slate-800">
            <span class="font-bold text-slate-200">
              Hasil ({generatedUuids.length} UUID Dihasilkan)
            </span>
            <span class="font-mono text-slate-500 text-[11px]">Format: {outputFormat.toUpperCase()}</span>
          </div>

          {#if outputFormat === 'plain'}
            <!-- Interactive Row List -->
            <div class="space-y-2 max-h-[480px] overflow-y-auto pr-1">
              {#each generatedUuids as id, idx}
                <div class="flex items-center justify-between p-2.5 bg-slate-950 border border-slate-800 rounded-xl hover:border-slate-700 transition-colors">
                  <div class="flex items-center space-x-2 min-w-0 pr-2">
                    <span class="text-[11px] font-mono text-slate-500 w-5 flex-shrink-0 text-right">{idx + 1}.</span>
                    <span class="font-mono text-xs text-amber-300 font-medium select-all truncate">{id}</span>
                  </div>
                  <button 
                    onclick={() => handleCopySingle(id, idx)}
                    class="px-2 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-[11px] font-mono flex items-center space-x-1 cursor-pointer transition-colors flex-shrink-0"
                  >
                    <Copy class="w-3 h-3 text-slate-400" />
                    <span>Salin</span>
                  </button>
                </div>
              {/each}
            </div>
          {:else}
            <!-- Formatted Code Text View -->
            <div class="flex-1 min-h-[300px] flex flex-col">
              <textarea 
                readonly
                value={formattedOutput}
                class="flex-1 w-full bg-slate-950 border border-slate-800 rounded-xl p-3.5 font-mono text-xs text-blue-300 focus:outline-none resize-none leading-relaxed select-all"
              ></textarea>
            </div>
          {/if}
        </div>
      </div>

    </div>
  </div>

  <!-- Toast -->
  {#if copiedToast}
    <div class="fixed bottom-6 right-6 z-50 bg-slate-900 border border-slate-700 text-slate-100 text-xs px-4 py-2.5 rounded-xl shadow-2xl flex items-center space-x-2 animate-in fade-in slide-in-from-bottom-2 duration-150">
      <CheckCircle2 class="w-4 h-4 text-emerald-400" />
      <span>{copiedToast}</span>
    </div>
  {/if}
</div>
