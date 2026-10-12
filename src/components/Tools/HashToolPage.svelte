<script lang="ts">
  import {
    Hash,
    Copy,
    Check,
    Trash2,
    ClipboardPaste,
    CheckCircle2,
    AlertCircle,
    Sparkles,
    FileText,
    Upload,
    ShieldCheck,
    KeyRound,
    Loader2
  } from 'lucide-svelte';
  import { copyText, readClipboardText } from '../../utils/clipboard';
  import { md5, hmacMd5 } from '../../utils/md5';

  type Algo = 'MD5' | 'SHA-1' | 'SHA-256' | 'SHA-384' | 'SHA-512';
  type OutputFormat = 'hex' | 'HEX' | 'base64';

  const ALGOS: { id: Algo; bits: number; note?: string }[] = [
    { id: 'MD5', bits: 128, note: 'Checksum saja — tidak aman' },
    { id: 'SHA-1', bits: 160, note: 'Usang untuk keamanan' },
    { id: 'SHA-256', bits: 256 },
    { id: 'SHA-384', bits: 384 },
    { id: 'SHA-512', bits: 512 }
  ];

  let sourceMode = $state<'text' | 'file'>('text');
  let inputText = $state('');
  let fileName = $state<string | null>(null);
  let fileBytes = $state<Uint8Array | null>(null);
  let isReadingFile = $state(false);
  let useHmac = $state(false);
  let hmacKey = $state('');
  let outputFormat = $state<OutputFormat>('hex');
  let compareHash = $state('');
  let results = $state<Partial<Record<Algo, Uint8Array>>>({});
  let isHashing = $state(false);
  let error = $state<string | null>(null);
  let copiedToast = $state<string | null>(null);
  let fileInput = $state<HTMLInputElement | null>(null);

  const encoder = new TextEncoder();
  let runId = 0;

  let inputBytes = $derived(sourceMode === 'text' ? encoder.encode(inputText) : fileBytes);

  // Hitung ulang semua hash setiap kali input/kunci berubah. runId mencegah
  // hasil kalkulasi lama (async) menimpa hasil yang lebih baru.
  $effect(() => {
    const data = inputBytes;
    const hmac = useHmac;
    const key = encoder.encode(hmacKey);
    const id = ++runId;

    if (!data || (sourceMode === 'text' && data.length === 0)) {
      results = {};
      error = null;
      isHashing = false;
      return;
    }

    isHashing = true;
    computeAll(data, hmac, key)
      .then((r) => {
        if (id !== runId) return;
        results = r;
        error = null;
      })
      .catch((e) => {
        if (id !== runId) return;
        results = {};
        error = e?.message || 'Gagal menghitung hash';
      })
      .finally(() => {
        if (id === runId) isHashing = false;
      });
  });

  async function computeAll(data: Uint8Array, hmac: boolean, key: Uint8Array) {
    const out: Partial<Record<Algo, Uint8Array>> = {};
    for (const { id } of ALGOS) {
      out[id] = await computeHash(id, data, hmac, key);
    }
    return out;
  }

  async function computeHash(algo: Algo, data: Uint8Array, hmac: boolean, key: Uint8Array): Promise<Uint8Array> {
    if (algo === 'MD5') {
      return hmac ? hmacMd5(key, data) : md5(data);
    }
    if (hmac) {
      // HMAC dengan kunci kosong tetap valid (RFC 2104); WebCrypto menolak
      // panjang 0, jadi pakai satu blok nol yang ekuivalen.
      const rawKey = key.length > 0 ? key : new Uint8Array(1);
      const cryptoKey = await crypto.subtle.importKey(
        'raw',
        rawKey as BufferSource,
        { name: 'HMAC', hash: algo },
        false,
        ['sign']
      );
      return new Uint8Array(await crypto.subtle.sign('HMAC', cryptoKey, data as BufferSource));
    }
    return new Uint8Array(await crypto.subtle.digest(algo, data as BufferSource));
  }

  function formatBytes(bytes: Uint8Array, format: OutputFormat): string {
    if (format === 'base64') {
      let bin = '';
      for (const b of bytes) bin += String.fromCharCode(b);
      return btoa(bin);
    }
    const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
    return format === 'HEX' ? hex.toUpperCase() : hex;
  }

  function formatSize(n: number): string {
    if (n < 1024) return `${n} B`;
    if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
    return `${(n / (1024 * 1024)).toFixed(2)} MB`;
  }

  // Cocokkan hash pembanding ke semua algoritma (hex tidak peka huruf besar/kecil,
  // base64 dibandingkan apa adanya).
  let matchedAlgo = $derived.by<Algo | null>(() => {
    const needle = compareHash.trim();
    if (!needle) return null;
    for (const { id } of ALGOS) {
      const bytes = results[id];
      if (!bytes) continue;
      if (formatBytes(bytes, 'hex') === needle.toLowerCase()) return id;
      if (formatBytes(bytes, 'base64') === needle) return id;
    }
    return null;
  });

  async function handleFileChange(e: Event) {
    const file = (e.target as HTMLInputElement).files?.[0];
    if (!file) return;
    isReadingFile = true;
    try {
      fileBytes = new Uint8Array(await file.arrayBuffer());
      fileName = file.name;
    } catch (err: any) {
      error = err?.message || 'Gagal membaca file';
    } finally {
      isReadingFile = false;
      if (fileInput) fileInput.value = '';
    }
  }

  function handleDrop(e: DragEvent) {
    e.preventDefault();
    const file = e.dataTransfer?.files?.[0];
    if (!file) return;
    sourceMode = 'file';
    isReadingFile = true;
    file.arrayBuffer()
      .then((buf) => {
        fileBytes = new Uint8Array(buf);
        fileName = file.name;
      })
      .catch((err) => (error = err?.message || 'Gagal membaca file'))
      .finally(() => (isReadingFile = false));
  }

  async function handlePaste() {
    const clip = await readClipboardText();
    if (clip) {
      sourceMode = 'text';
      inputText = clip;
      showToast('Ditempel dari clipboard');
    } else {
      showToast('Clipboard kosong / tidak bisa dibaca');
    }
  }

  function handleClear() {
    if (sourceMode === 'text') {
      inputText = '';
    } else {
      fileBytes = null;
      fileName = null;
    }
    showToast('Input dibersihkan');
  }

  function handleLoadSample() {
    sourceMode = 'text';
    inputText = 'Valtera Note Desktop — Local-First Note Taking & Developer Utilities 🚀';
    showToast('Contoh dimuat');
  }

  async function handleCopy(algo: Algo) {
    const bytes = results[algo];
    if (!bytes) return;
    const ok = await copyText(formatBytes(bytes, outputFormat));
    showToast(ok ? `${algo} tersalin!` : `Gagal menyalin ${algo}`);
  }

  async function handleCopyAll() {
    const lines = ALGOS.filter((a) => results[a.id]).map(
      (a) => `${useHmac ? 'HMAC-' : ''}${a.id}: ${formatBytes(results[a.id]!, outputFormat)}`
    );
    if (lines.length === 0) return;
    const ok = await copyText(lines.join('\n'));
    showToast(ok ? 'Semua hash tersalin!' : 'Gagal menyalin hash');
  }

  function showToast(msg: string) {
    copiedToast = msg;
    setTimeout(() => {
      if (copiedToast === msg) copiedToast = null;
    }, 2000);
  }

  let hasResults = $derived(Object.keys(results).length > 0);
</script>

<div class="h-full w-full flex flex-col md:flex-row overflow-hidden divide-y md:divide-y-0 md:divide-x divide-slate-800 bg-slate-950 text-slate-100 select-none">
  <!-- Left Pane: Input -->
  <section class="flex-1 flex flex-col overflow-hidden bg-slate-950/60">
    <div class="h-10 px-3 bg-slate-900/80 border-b border-slate-800 flex items-center justify-between text-xs text-slate-300 font-medium flex-shrink-0">
      <!-- Source Segmented Pill -->
      <div class="flex items-center bg-slate-950 p-0.5 rounded-lg border border-slate-800">
        <button
          onclick={() => (sourceMode = 'text')}
          class="px-2.5 py-1 rounded-md text-[11px] font-medium transition-all cursor-pointer flex items-center space-x-1 {sourceMode === 'text' ? 'bg-blue-600 text-white font-semibold shadow-xs' : 'text-slate-400 hover:text-slate-200'}"
        >
          <FileText class="w-3 h-3" />
          <span>Teks</span>
        </button>
        <button
          onclick={() => (sourceMode = 'file')}
          class="px-2.5 py-1 rounded-md text-[11px] font-medium transition-all cursor-pointer flex items-center space-x-1 {sourceMode === 'file' ? 'bg-blue-600 text-white font-semibold shadow-xs' : 'text-slate-400 hover:text-slate-200'}"
        >
          <Upload class="w-3 h-3" />
          <span>File</span>
        </button>
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
          disabled={sourceMode === 'text' ? !inputText : !fileBytes}
          class="p-1 rounded-md hover:bg-red-500/10 text-slate-400 hover:text-red-400 transition-colors cursor-pointer disabled:opacity-30 disabled:cursor-not-allowed"
          title="Bersihkan input"
        >
          <Trash2 class="w-3.5 h-3.5" />
        </button>
      </div>
    </div>

    <!-- Input Area -->
    <div class="flex-1 relative overflow-hidden p-2">
      {#if sourceMode === 'text'}
        <textarea
          bind:value={inputText}
          placeholder="Ketik atau tempelkan teks yang ingin di-hash (UTF-8)..."
          class="w-full h-full p-3 bg-slate-900/30 border border-slate-800/80 rounded-xl text-slate-100 font-mono text-xs leading-relaxed focus:outline-none focus:border-blue-500/60 resize-none placeholder-slate-600 transition-colors"
          spellcheck="false"
        ></textarea>
      {:else}
        <button
          type="button"
          onclick={() => fileInput?.click()}
          ondragover={(e) => e.preventDefault()}
          ondrop={handleDrop}
          class="w-full h-full flex flex-col items-center justify-center space-y-3 bg-slate-900/30 border-2 border-dashed border-slate-800 hover:border-blue-500/50 rounded-xl text-slate-400 hover:text-slate-200 transition-colors cursor-pointer"
        >
          {#if isReadingFile}
            <Loader2 class="w-8 h-8 text-blue-400 animate-spin" />
            <span class="text-xs">Membaca file...</span>
          {:else if fileName && fileBytes}
            <FileText class="w-8 h-8 text-blue-400" />
            <span class="text-xs font-mono text-slate-200 break-all px-6 text-center">{fileName}</span>
            <span class="text-[11px] font-mono text-slate-500">{formatSize(fileBytes.length)} • klik untuk ganti file</span>
          {:else}
            <Upload class="w-8 h-8 text-slate-500" />
            <span class="text-xs">Klik untuk memilih file, atau seret & lepas di sini</span>
            <span class="text-[11px] text-slate-500">File diproses lokal di memori, tidak diunggah ke mana pun</span>
          {/if}
        </button>
        <input bind:this={fileInput} type="file" class="hidden" onchange={handleFileChange} />
      {/if}
    </div>

    <!-- HMAC Options -->
    <div class="px-3 py-2 border-t border-slate-800 bg-slate-900/40 flex items-center gap-3 flex-shrink-0">
      <label class="flex items-center space-x-1.5 text-[11px] text-slate-400 hover:text-white cursor-pointer flex-shrink-0">
        <input
          type="checkbox"
          bind:checked={useHmac}
          class="rounded border-slate-700 text-blue-600 focus:ring-blue-500 bg-slate-950 w-3.5 h-3.5"
        />
        <KeyRound class="w-3 h-3 text-violet-400" />
        <span>HMAC</span>
      </label>
      <input
        type="text"
        bind:value={hmacKey}
        disabled={!useHmac}
        placeholder="Kunci rahasia HMAC..."
        class="flex-1 min-w-0 px-2.5 py-1 bg-slate-950 border border-slate-800 rounded-md text-xs font-mono text-slate-200 placeholder-slate-600 focus:outline-none focus:border-violet-500/60 disabled:opacity-40"
        spellcheck="false"
      />
    </div>

    <!-- Input Footer Bar -->
    <div class="h-8 px-3 border-t border-slate-800 text-[11px] font-mono text-slate-400 flex items-center justify-between bg-slate-900/40 flex-shrink-0">
      <span>Ukuran Input: {formatSize(inputBytes?.length ?? 0)}</span>
      {#if sourceMode === 'text'}
        <span>{inputText.length} karakter</span>
      {/if}
    </div>
  </section>

  <!-- Right Pane: Hash Results -->
  <section class="flex-1 flex flex-col overflow-hidden bg-slate-950/30">
    <div class="h-10 px-3 bg-slate-900/80 border-b border-slate-800 flex items-center justify-between text-xs text-slate-300 font-medium flex-shrink-0">
      <div class="flex items-center space-x-2">
        <Hash class="w-4 h-4 text-rose-400" />
        <span class="font-bold text-slate-100">{useHmac ? 'Hasil HMAC' : 'Hasil Hash'}</span>
        {#if isHashing}
          <Loader2 class="w-3.5 h-3.5 text-slate-400 animate-spin" />
        {/if}
      </div>

      <div class="flex items-center space-x-1.5">
        <div class="flex items-center bg-slate-950 p-0.5 rounded-lg border border-slate-800">
          {#each [['hex', 'hex'], ['HEX', 'HEX'], ['base64', 'Base64']] as [fmt, label]}
            <button
              onclick={() => (outputFormat = fmt as OutputFormat)}
              class="px-2 py-0.5 rounded-md text-[11px] font-mono transition-all cursor-pointer {outputFormat === fmt ? 'bg-blue-600 text-white font-semibold shadow-xs' : 'text-slate-400 hover:text-slate-200'}"
            >
              {label}
            </button>
          {/each}
        </div>

        <button
          onclick={handleCopyAll}
          disabled={!hasResults}
          class="px-2.5 py-1 rounded-md bg-emerald-600/20 hover:bg-emerald-600/30 text-emerald-300 border border-emerald-500/30 text-[11px] font-semibold flex items-center space-x-1 cursor-pointer transition-colors disabled:opacity-30 disabled:cursor-not-allowed shadow-xs"
        >
          {#if copiedToast === 'Semua hash tersalin!'}
            <Check class="w-3 h-3 text-emerald-400" />
            <span>Tersalin!</span>
          {:else}
            <Copy class="w-3 h-3 text-emerald-400" />
            <span>Salin Semua</span>
          {/if}
        </button>
      </div>
    </div>

    <div class="flex-1 overflow-y-auto p-3 space-y-2">
      {#if error}
        <div class="p-3 flex items-start space-x-2.5 bg-red-950/30 border border-red-900/40 rounded-xl text-red-300 text-xs">
          <AlertCircle class="w-4 h-4 text-red-400 flex-shrink-0 mt-0.5" />
          <div>
            <div class="font-bold text-[11px]">Gagal Menghitung Hash</div>
            <div class="text-[11px] text-red-400/90">{error}</div>
          </div>
        </div>
      {/if}

      {#each ALGOS as algo (algo.id)}
        {@const bytes = results[algo.id]}
        {@const isMatch = matchedAlgo === algo.id}
        <div class="rounded-xl border p-3 transition-colors {isMatch ? 'bg-emerald-950/30 border-emerald-500/50' : 'bg-slate-900/40 border-slate-800/80'}">
          <div class="flex items-center justify-between mb-1.5">
            <div class="flex items-center space-x-2">
              <span class="text-xs font-bold text-slate-100">{useHmac ? 'HMAC-' : ''}{algo.id}</span>
              <span class="text-[10px] font-mono text-slate-500">{algo.bits} bit</span>
              {#if algo.note}
                <span class="text-[10px] text-amber-400/80">{algo.note}</span>
              {/if}
              {#if isMatch}
                <span class="flex items-center space-x-1 text-[10px] font-semibold text-emerald-400">
                  <ShieldCheck class="w-3 h-3" />
                  <span>Cocok</span>
                </span>
              {/if}
            </div>
            <button
              onclick={() => handleCopy(algo.id)}
              disabled={!bytes}
              class="px-2 py-0.5 rounded bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-[11px] font-mono flex items-center space-x-1 cursor-pointer transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
            >
              {#if copiedToast === `${algo.id} tersalin!`}
                <Check class="w-3 h-3 text-emerald-400" />
              {:else}
                <Copy class="w-3 h-3 text-slate-400" />
              {/if}
              <span>Salin</span>
            </button>
          </div>
          <div class="font-mono text-xs break-all select-text {bytes ? 'text-rose-300' : 'text-slate-600'}">
            {bytes ? formatBytes(bytes, outputFormat) : '—'}
          </div>
        </div>
      {/each}
    </div>

    <!-- Compare / Verify -->
    <div class="px-3 py-2 border-t border-slate-800 bg-slate-900/40 flex items-center gap-2 flex-shrink-0">
      <ShieldCheck class="w-3.5 h-3.5 flex-shrink-0 {matchedAlgo ? 'text-emerald-400' : 'text-slate-500'}" />
      <input
        type="text"
        bind:value={compareHash}
        placeholder="Tempel hash pembanding untuk verifikasi checksum..."
        class="flex-1 min-w-0 px-2.5 py-1 bg-slate-950 border rounded-md text-xs font-mono text-slate-200 placeholder-slate-600 focus:outline-none {compareHash.trim() ? (matchedAlgo ? 'border-emerald-500/60' : 'border-red-500/50') : 'border-slate-800 focus:border-blue-500/60'}"
        spellcheck="false"
      />
      {#if compareHash.trim()}
        <span class="text-[11px] font-semibold flex-shrink-0 {matchedAlgo ? 'text-emerald-400' : 'text-red-400'}">
          {matchedAlgo ? `Cocok (${matchedAlgo})` : 'Tidak cocok'}
        </span>
      {/if}
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
