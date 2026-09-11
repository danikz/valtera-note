<script lang="ts">
  import { 
    Globe, 
    Copy, 
    Check, 
    Trash2, 
    ClipboardPaste, 
    ArrowRightLeft, 
    CheckCircle2, 
    AlertCircle, 
    Sparkles,
    Table
  } from 'lucide-svelte';

  let mode = $state<'encode' | 'decode'>('encode');
  let encodeType = $state<'component' | 'full-uri'>('component');
  let inputUrl = $state('');
  let copiedToast = $state<string | null>(null);

  // Conversion result
  let conversionResult = $derived.by(() => {
    const raw = inputUrl.trim();
    if (!raw) return { output: '', isValid: true, error: null };

    try {
      if (mode === 'encode') {
        const out = encodeType === 'component' 
          ? encodeURIComponent(inputUrl) 
          : encodeURI(inputUrl);
        return { output: out, isValid: true, error: null };
      } else {
        const out = decodeURIComponent(inputUrl);
        return { output: out, isValid: true, error: null };
      }
    } catch (e: any) {
      return { 
        output: '', 
        isValid: false, 
        error: e?.message || 'String URL encoding tidak valid' 
      };
    }
  });

  // Query parameter parser
  let parsedUrlDetails = $derived.by(() => {
    const text = inputUrl.trim();
    if (!text) return null;

    let target = text;
    if (mode === 'decode' && conversionResult.isValid && conversionResult.output) {
      target = conversionResult.output;
    }

    try {
      let urlObj: URL | null = null;
      if (target.startsWith('http://') || target.startsWith('https://')) {
        urlObj = new URL(target);
      } else if (target.includes('?')) {
        urlObj = new URL('https://placeholder.local/' + target);
      }

      if (urlObj) {
        const params: { key: string; value: string }[] = [];
        urlObj.searchParams.forEach((value, key) => {
          params.push({ key, value });
        });

        return {
          protocol: urlObj.protocol !== 'https:' || target.startsWith('http') ? urlObj.protocol : '',
          host: target.startsWith('http') ? urlObj.host : '',
          pathname: target.startsWith('http') ? urlObj.pathname : target.split('?')[0],
          hasParams: params.length > 0,
          params
        };
      }
      return null;
    } catch {
      return null;
    }
  });

  async function handlePaste() {
    try {
      const clip = await navigator.clipboard.readText();
      if (clip) {
        inputUrl = clip;
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
      showToast('Hasil URL tersalin!');
    } catch (err) {
      console.warn('Copy error:', err);
    }
  }

  async function copyItem(text: string, label: string) {
    try {
      await navigator.clipboard.writeText(text);
      showToast(`${label} tersalin!`);
    } catch (err) {
      console.warn(err);
    }
  }

  function handleSwap() {
    if (conversionResult.output && conversionResult.isValid) {
      inputUrl = conversionResult.output;
      mode = mode === 'encode' ? 'decode' : 'encode';
      showToast('Mode dan input ditukar');
    }
  }

  function handleClear() {
    inputUrl = '';
    showToast('Input dibersihkan');
  }

  function handleLoadSample() {
    if (mode === 'encode') {
      inputUrl = 'https://valtera.id/api/v1/search?query=catatan penting & developer tools&category=productivity#section-1';
    } else {
      inputUrl = 'https%3A%2F%2Fvaltera.id%2Fapi%2Fv1%2Fsearch%3Fquery%3Dcatatan%2520penting%2520%26%2520developer%2520tools%26category%3Dproductivity%23section-1';
    }
    showToast('Contoh URL dimuat');
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
      <!-- Mode Toggle -->
      <div class="flex items-center space-x-2">
        <div class="flex items-center bg-slate-950 p-0.5 rounded-lg border border-slate-800">
          <button 
            onclick={() => mode = 'encode'}
            class="px-2.5 py-1 rounded-md text-[11px] font-medium transition-all cursor-pointer {mode === 'encode' ? 'bg-blue-600 text-white font-semibold shadow-xs' : 'text-slate-400 hover:text-slate-200'}"
          >
            Encode URL
          </button>
          <button 
            onclick={() => mode = 'decode'}
            class="px-2.5 py-1 rounded-md text-[11px] font-medium transition-all cursor-pointer {mode === 'decode' ? 'bg-blue-600 text-white font-semibold shadow-xs' : 'text-slate-400 hover:text-slate-200'}"
          >
            Decode URL
          </button>
        </div>

        {#if mode === 'encode'}
          <div class="hidden sm:flex items-center space-x-2 text-[11px] text-slate-400 pl-2 border-l border-slate-800">
            <label class="flex items-center space-x-1 cursor-pointer hover:text-white">
              <input 
                type="radio" 
                name="encodeType" 
                value="component" 
                bind:group={encodeType}
                class="text-blue-500 bg-slate-950"
              />
              <span>encodeURIComponent</span>
            </label>
            <label class="flex items-center space-x-1 cursor-pointer hover:text-white">
              <input 
                type="radio" 
                name="encodeType" 
                value="full-uri" 
                bind:group={encodeType}
                class="text-blue-500 bg-slate-950"
              />
              <span>encodeURI</span>
            </label>
          </div>
        {/if}
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
          disabled={!inputUrl}
          class="p-1 rounded-md hover:bg-red-500/10 text-slate-400 hover:text-red-400 transition-colors cursor-pointer disabled:opacity-30 disabled:cursor-not-allowed"
          title="Bersihkan input"
        >
          <Trash2 class="w-3.5 h-3.5" />
        </button>
      </div>
    </div>

    <!-- Textarea -->
    <div class="flex-1 relative overflow-hidden p-2">
      <textarea 
        bind:value={inputUrl}
        placeholder={mode === 'encode' ? 'Ketik atau tempelkan URL atau teks yang ingin di-encode...' : 'Tempelkan URL encoded (mengandung %20, %3A, dll) yang ingin di-decode...'}
        class="w-full h-full p-3 bg-slate-900/30 border border-slate-800/80 rounded-xl text-slate-100 font-mono text-xs leading-relaxed focus:outline-none focus:border-blue-500/60 resize-none placeholder-slate-600 transition-colors"
        spellcheck="false"
      ></textarea>
    </div>

    <!-- Footer -->
    <div class="h-8 px-3 border-t border-slate-800 text-[11px] font-mono text-slate-400 flex items-center justify-between bg-slate-900/40 flex-shrink-0">
      <span>{inputUrl.length} karakter</span>
      <span>UTF-8 Encoding</span>
    </div>
  </section>

  <!-- Right Pane: Output & Parameter Breakdown -->
  <section class="flex-1 flex flex-col overflow-hidden bg-slate-950/30">
    <div class="h-10 px-3 bg-slate-900/80 border-b border-slate-800 flex items-center justify-between text-xs text-slate-300 font-medium flex-shrink-0">
      <div class="flex items-center space-x-2">
        <Globe class="w-4 h-4 text-purple-400" />
        <span class="font-bold text-slate-100">
          {mode === 'encode' ? 'Hasil URL Encoded' : 'Hasil URL Bersih'}
        </span>
        {#if conversionResult.output && conversionResult.isValid}
          <span class="text-[11px] font-mono text-purple-400">
            ({conversionResult.output.length} chars)
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
          {#if copiedToast === 'Hasil URL tersalin!'}
            <Check class="w-3 h-3 text-emerald-400" />
            <span>Tersalin!</span>
          {:else}
            <Copy class="w-3 h-3 text-emerald-400" />
            <span>Salin</span>
          {/if}
        </button>
      </div>
    </div>

    <!-- Output Body & Query Table -->
    <div class="flex-1 flex flex-col overflow-hidden p-2 gap-2">
      {#if !conversionResult.isValid}
        <div class="p-3 flex items-start space-x-2.5 bg-red-950/30 border border-red-900/40 rounded-xl text-red-300 text-xs">
          <AlertCircle class="w-4 h-4 text-red-400 flex-shrink-0 mt-0.5" />
          <div>
            <div class="font-bold text-[11px]">Gagal Mengurai URL</div>
            <div class="text-[11px] text-red-400/90">{conversionResult.error}</div>
          </div>
        </div>
      {/if}

      <!-- Output Textarea -->
      <div class="h-1/2 min-h-[120px]">
        <textarea 
          readonly
          value={conversionResult.output}
          placeholder="Hasil konversi URL akan otomatis tampil di sini..."
          class="w-full h-full p-3 bg-slate-900/30 border border-slate-800/80 rounded-xl text-purple-300 font-mono text-xs leading-relaxed focus:outline-none resize-none placeholder-slate-600 select-all"
        ></textarea>
      </div>

      <!-- Query Parameter Table -->
      <div class="flex-1 flex flex-col overflow-hidden bg-slate-900/20 border border-slate-800/80 rounded-xl">
        <div class="h-8 px-3 bg-slate-900/60 border-b border-slate-800 flex items-center justify-between text-xs text-slate-400 font-medium flex-shrink-0">
          <span class="flex items-center space-x-1.5 text-slate-300 text-[11px]">
            <Table class="w-3.5 h-3.5 text-blue-400" />
            <span>Daftar Parameter Query (?key=value)</span>
          </span>
          {#if parsedUrlDetails?.hasParams}
            <span class="px-1.5 py-0.2 rounded bg-blue-500/10 text-blue-400 border border-blue-500/20 font-mono text-[10px]">
              {parsedUrlDetails.params.length} parameter
            </span>
          {/if}
        </div>

        <div class="flex-1 overflow-y-auto p-2">
          {#if parsedUrlDetails && parsedUrlDetails.hasParams}
            <div class="border border-slate-800/80 rounded-lg overflow-hidden divide-y divide-slate-800/80 font-mono text-xs">
              {#each parsedUrlDetails.params as param}
                <div class="flex items-center justify-between p-2 bg-slate-950/60 hover:bg-slate-900/60 transition-colors">
                  <div class="flex items-center space-x-2 min-w-0 flex-1 pr-2">
                    <span class="font-semibold text-blue-400 flex-shrink-0">{param.key}</span>
                    <span class="text-slate-600">=</span>
                    <span class="text-slate-200 truncate select-all">{param.value}</span>
                  </div>
                  <div class="flex items-center space-x-1 flex-shrink-0">
                    <button 
                      onclick={() => copyItem(param.key, `Key '${param.key}'`)}
                      class="px-1.5 py-0.5 rounded bg-slate-800 hover:bg-slate-700 text-[10px] text-slate-300 cursor-pointer"
                    >
                      Key
                    </button>
                    <button 
                      onclick={() => copyItem(param.value, `Value '${param.value}'`)}
                      class="px-1.5 py-0.5 rounded bg-slate-800 hover:bg-slate-700 text-[10px] text-slate-300 cursor-pointer"
                    >
                      Val
                    </button>
                  </div>
                </div>
              {/each}
            </div>
          {:else}
            <div class="h-full flex items-center justify-center text-center p-4 text-slate-500 text-xs">
              Tidak ada query parameter terdeteksi (?key=value) dalam input URL.
            </div>
          {/if}
        </div>
      </div>
    </div>

    <!-- Output Footer -->
    <div class="h-8 px-3 border-t border-slate-800 text-[11px] font-mono text-slate-400 flex items-center justify-between bg-slate-900/40 flex-shrink-0">
      <span>Parameter terurai: {parsedUrlDetails?.hasParams ? parsedUrlDetails.params.length : 0}</span>
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
