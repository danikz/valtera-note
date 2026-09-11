<script lang="ts">
  import { 
    Binary, 
    Copy, 
    Check, 
    Trash2, 
    ClipboardPaste, 
    ArrowRightLeft, 
    CheckCircle2, 
    AlertCircle, 
    Sparkles,
    FileText
  } from 'lucide-svelte';

  let mode = $state<'encode' | 'decode'>('encode');
  let inputText = $state('');
  let urlSafe = $state(false);
  let copiedToast = $state<string | null>(null);

  // UTF-8 safe encode/decode
  let conversionResult = $derived.by(() => {
    const text = inputText.trim();
    if (!text) {
      return { output: '', isValid: true, error: null };
    }

    try {
      if (mode === 'encode') {
        let b64 = btoa(unescape(encodeURIComponent(inputText)));
        if (urlSafe) {
          b64 = b64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
        }
        return { output: b64, isValid: true, error: null };
      } else {
        let b64 = text;
        if (urlSafe || b64.includes('-') || b64.includes('_')) {
          b64 = b64.replace(/-/g, '+').replace(/_/g, '/');
          while (b64.length % 4) {
            b64 += '=';
          }
        }
        const decoded = decodeURIComponent(escape(atob(b64)));
        return { output: decoded, isValid: true, error: null };
      }
    } catch (e: any) {
      return { 
        output: '', 
        isValid: false, 
        error: mode === 'decode' 
          ? 'String input bukan format Base64 yang valid atau karakter rusak.' 
          : e?.message || 'Gagal mengonversi teks' 
      };
    }
  });

  let stats = $derived.by(() => {
    const inputBytes = new Blob([inputText]).size;
    const outputBytes = new Blob([conversionResult.output]).size;
    const ratio = inputBytes > 0 ? ((outputBytes / inputBytes) * 100).toFixed(0) : '0';
    return {
      inputBytes: inputBytes < 1024 ? `${inputBytes} B` : `${(inputBytes / 1024).toFixed(1)} KB`,
      outputBytes: outputBytes < 1024 ? `${outputBytes} B` : `${(outputBytes / 1024).toFixed(1)} KB`,
      ratio: `${ratio}%`
    };
  });

  async function handlePaste() {
    try {
      const clip = await navigator.clipboard.readText();
      if (clip) {
        inputText = clip;
        showToast('Ditempel dari clipboard');
      }
    } catch (err) {
      console.warn('Paste error:', err);
    }
  }

  async function handleCopy() {
    if (!conversionResult.output) return;
    try {
      await navigator.clipboard.writeText(conversionResult.output);
      showToast('Hasil Base64 tersalin!');
    } catch (err) {
      console.warn('Copy error:', err);
    }
  }

  function handleSwap() {
    if (conversionResult.output && conversionResult.isValid) {
      inputText = conversionResult.output;
      mode = mode === 'encode' ? 'decode' : 'encode';
      showToast('Posisi dibalik (Swap)');
    }
  }

  function handleClear() {
    inputText = '';
    showToast('Input dibersihkan');
  }

  function handleLoadSample() {
    if (mode === 'encode') {
      inputText = 'Valtera Note Desktop — Local-First Note Taking & Developer Utilities 🚀';
    } else {
      inputText = 'VmFsdGVyYSBOb3RlIERlc2t0b3Ag4oCUyExvY2FsLUZpcnN0IE5vdGUgVGFraW5nICYgRGV2ZWxvcGVyIFV0aWxpdGllcyDwn5mp';
    }
    showToast('Contoh dimuat');
  }

  function showToast(msg: string) {
    copiedToast = msg;
    setTimeout(() => {
      if (copiedToast === msg) copiedToast = null;
    }, 2000);
  }
</script>

<div class="h-full w-full flex flex-col md:flex-row overflow-hidden divide-y md:divide-y-0 md:divide-x divide-slate-800 bg-slate-950 text-slate-100 select-none">
  <!-- Left Pane: Input -->
  <section class="flex-1 flex flex-col overflow-hidden bg-slate-950/60">
    <div class="h-10 px-3 bg-slate-900/80 border-b border-slate-800 flex items-center justify-between text-xs text-slate-300 font-medium flex-shrink-0">
      <!-- Mode Segmented Pill -->
      <div class="flex items-center space-x-2">
        <div class="flex items-center bg-slate-950 p-0.5 rounded-lg border border-slate-800">
          <button 
            onclick={() => mode = 'encode'}
            class="px-2.5 py-1 rounded-md text-[11px] font-medium transition-all cursor-pointer {mode === 'encode' ? 'bg-blue-600 text-white font-semibold shadow-xs' : 'text-slate-400 hover:text-slate-200'}"
          >
            Encode (Teks → Base64)
          </button>
          <button 
            onclick={() => mode = 'decode'}
            class="px-2.5 py-1 rounded-md text-[11px] font-medium transition-all cursor-pointer {mode === 'decode' ? 'bg-blue-600 text-white font-semibold shadow-xs' : 'text-slate-400 hover:text-slate-200'}"
          >
            Decode (Base64 → Teks)
          </button>
        </div>

        <label class="hidden sm:flex items-center space-x-1.5 text-[11px] text-slate-400 hover:text-white cursor-pointer pl-2 border-l border-slate-800">
          <input 
            type="checkbox" 
            bind:checked={urlSafe} 
            class="rounded border-slate-700 text-blue-600 focus:ring-blue-500 bg-slate-950 w-3.5 h-3.5"
          />
          <span>URL-Safe (- _)</span>
        </label>
      </div>

      <!-- Action Buttons -->
      <div class="flex items-center space-x-1.5">
        <button 
          onclick={handleLoadSample}
          class="px-2 py-1 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-[11px] font-medium flex items-center space-x-1 cursor-pointer transition-colors"
        >
          <Sparkles class="w-3 h-3 text-amber-400" />
          <span>Contoh</span>
        </button>

        <button 
          onclick={handlePaste}
          class="px-2 py-1 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-[11px] font-medium flex items-center space-x-1 cursor-pointer transition-colors"
        >
          <ClipboardPaste class="w-3 h-3 text-blue-400" />
          <span>Paste</span>
        </button>

        <button 
          onclick={handleClear}
          disabled={!inputText}
          class="p-1 rounded-md hover:bg-red-500/10 text-slate-400 hover:text-red-400 transition-colors cursor-pointer disabled:opacity-30 disabled:cursor-not-allowed"
          title="Bersihkan input"
        >
          <Trash2 class="w-3.5 h-3.5" />
        </button>
      </div>
    </div>

    <!-- Input Textarea -->
    <div class="flex-1 relative overflow-hidden p-2">
      <textarea 
        bind:value={inputText}
        placeholder={mode === 'encode' ? 'Ketik atau tempelkan teks apa saja yang ingin di-encode ke Base64 (mendukung UTF-8 & Emoji)...' : 'Tempelkan string Base64 yang ingin di-decode...'}
        class="w-full h-full p-3 bg-slate-900/30 border border-slate-800/80 rounded-xl text-slate-100 font-mono text-xs leading-relaxed focus:outline-none focus:border-blue-500/60 resize-none placeholder-slate-600 transition-colors"
        spellcheck="false"
      ></textarea>
    </div>

    <!-- Input Footer Bar -->
    <div class="h-8 px-3 border-t border-slate-800 text-[11px] font-mono text-slate-400 flex items-center justify-between bg-slate-900/40 flex-shrink-0">
      <span>Ukuran Input: {stats.inputBytes}</span>
      <span>{inputText.length} karakter</span>
    </div>
  </section>

  <!-- Right Pane: Output -->
  <section class="flex-1 flex flex-col overflow-hidden bg-slate-950/30">
    <div class="h-10 px-3 bg-slate-900/80 border-b border-slate-800 flex items-center justify-between text-xs text-slate-300 font-medium flex-shrink-0">
      <div class="flex items-center space-x-2">
        <Binary class="w-4 h-4 text-cyan-400" />
        <span class="font-bold text-slate-100">
          {mode === 'encode' ? 'Hasil Base64' : 'Hasil Decode'}
        </span>
        {#if conversionResult.output && conversionResult.isValid}
          <span class="text-[11px] font-mono text-emerald-400">
            ({stats.outputBytes} • Rasio: {stats.ratio})
          </span>
        {/if}
      </div>

      <div class="flex items-center space-x-1.5">
        <button 
          onclick={handleSwap}
          disabled={!conversionResult.output || !conversionResult.isValid}
          class="px-2 py-1 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-[11px] font-medium flex items-center space-x-1 cursor-pointer transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
          title="Tukar input dan output"
        >
          <ArrowRightLeft class="w-3 h-3" />
          <span>Swap</span>
        </button>

        <button 
          onclick={handleCopy}
          disabled={!conversionResult.output || !conversionResult.isValid}
          class="px-2.5 py-1 rounded-md bg-emerald-600/20 hover:bg-emerald-600/30 text-emerald-300 border border-emerald-500/30 text-[11px] font-semibold flex items-center space-x-1 cursor-pointer transition-colors disabled:opacity-30 disabled:cursor-not-allowed shadow-xs"
        >
          {#if copiedToast === 'Hasil Base64 tersalin!'}
            <Check class="w-3 h-3 text-emerald-400" />
            <span>Tersalin!</span>
          {:else}
            <Copy class="w-3 h-3 text-emerald-400" />
            <span>Salin</span>
          {/if}
        </button>
      </div>
    </div>

    <div class="flex-1 relative overflow-hidden flex flex-col p-2">
      {#if !conversionResult.isValid}
        <div class="p-3 mb-2 flex items-start space-x-2.5 bg-red-950/30 border border-red-900/40 rounded-xl text-red-300 text-xs">
          <AlertCircle class="w-4 h-4 text-red-400 flex-shrink-0 mt-0.5" />
          <div>
            <div class="font-bold text-[11px]">Gagal Mengurai Base64</div>
            <div class="text-[11px] text-red-400/90">{conversionResult.error}</div>
          </div>
        </div>
      {/if}

      <textarea 
        readonly
        value={conversionResult.output}
        placeholder="Hasil konversi Base64 akan otomatis muncul di sini secara real-time..."
        class="flex-1 w-full p-3 bg-slate-900/30 border border-slate-800/80 rounded-xl text-blue-300 font-mono text-xs leading-relaxed focus:outline-none resize-none placeholder-slate-600 select-all"
      ></textarea>
    </div>

    <!-- Output Footer Bar -->
    <div class="h-8 px-3 border-t border-slate-800 text-[11px] font-mono text-slate-400 flex items-center justify-between bg-slate-900/40 flex-shrink-0">
      <span>Ukuran Output: {stats.outputBytes}</span>
      <span>{conversionResult.output.length} karakter</span>
    </div>
  </section>

  <!-- Toast -->
  {#if copiedToast}
    <div class="fixed bottom-6 right-6 z-50 bg-slate-900 border border-slate-700 text-slate-100 text-xs px-4 py-2 rounded-xl shadow-2xl flex items-center space-x-2 animate-in fade-in slide-in-from-bottom-2 duration-150">
      <CheckCircle2 class="w-4 h-4 text-emerald-400" />
      <span>{copiedToast}</span>
    </div>
  {/if}
</div>
