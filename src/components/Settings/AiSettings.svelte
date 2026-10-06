<script lang="ts">
  import { onMount } from 'svelte';
  import { Bot, Loader2, CheckCircle2, AlertCircle, Eye, EyeOff, Server, Key, Cpu, ShieldAlert } from 'lucide-svelte';
  import { ipc } from '../../services/ipc';

  type ProviderKind = 'openai' | 'anthropic';

  interface Preset {
    id: string;
    label: string;
    kind: ProviderKind;
    base_url: string;
    model: string;
    hint: string;
  }

  const PRESETS: Preset[] = [
    {
      id: 'openai',
      label: 'OpenAI',
      kind: 'openai',
      base_url: 'https://api.openai.com/v1',
      model: 'gpt-4o-mini',
      hint: 'platform.openai.com/api-keys'
    },
    {
      id: 'anthropic',
      label: 'Anthropic Claude',
      kind: 'anthropic',
      base_url: 'https://api.anthropic.com',
      model: 'claude-sonnet-4-5',
      hint: 'console.anthropic.com'
    },
    {
      id: 'openrouter',
      label: 'OpenRouter',
      kind: 'openai',
      base_url: 'https://openrouter.ai/api/v1',
      model: 'anthropic/claude-sonnet-4.5',
      hint: 'openrouter.ai/keys — akses banyak model dengan satu key'
    },
    {
      id: 'groq',
      label: 'Groq',
      kind: 'openai',
      base_url: 'https://api.groq.com/openai/v1',
      model: 'llama-3.3-70b-versatile',
      hint: 'console.groq.com — gratis & sangat cepat'
    },
    {
      id: 'ollama',
      label: 'Ollama (lokal)',
      kind: 'openai',
      base_url: 'http://localhost:11434/v1',
      model: 'llama3.1',
      hint: 'Jalankan `ollama serve` — 100% offline, key diisi bebas'
    }
  ];

  let kind = $state<ProviderKind>('openai');
  let baseUrl = $state('');
  let apiKey = $state('');
  let model = $state('');
  let hasApiKey = $state(false);
  let showKey = $state(false);
  let isLoading = $state(true);
  let isSaving = $state(false);
  let isTesting = $state(false);
  let isLoadingModels = $state(false);
  let models = $state<string[]>([]);
  let statusMessage = $state<{ text: string; type: 'success' | 'error' } | null>(null);

  onMount(async () => {
    try {
      const cfg = await ipc.aiGetConfig();
      kind = cfg.kind === 'anthropic' ? 'anthropic' : 'openai';
      baseUrl = cfg.base_url;
      hasApiKey = cfg.has_api_key;
      model = cfg.model;
    } catch (err) {
      console.warn('Gagal memuat konfigurasi AI:', err);
    } finally {
      isLoading = false;
    }
  });

  function applyPreset(p: Preset) {
    kind = p.kind;
    baseUrl = p.base_url;
    model = p.model;
    models = []; // daftar model project lama tidak berlaku
  }

  async function loadModels(): Promise<number> {
    isLoadingModels = true;
    try {
      const list = await ipc.aiListModels();
      models = list;
      return list.length;
    } finally {
      isLoadingModels = false;
    }
  }

  async function handleSave() {
    isSaving = true;
    statusMessage = null;
    try {
      // Kirim key hanya kalau diisi (kosong = pertahankan key lama).
      await ipc.aiSaveConfig(kind, baseUrl, apiKey.trim() ? apiKey.trim() : null, model);
      hasApiKey = hasApiKey || !!apiKey.trim();
      apiKey = '';
      statusMessage = { text: 'Konfigurasi AI tersimpan.', type: 'success' };
    } catch (err: any) {
      statusMessage = { text: `Gagal menyimpan: ${err?.message || err}`, type: 'error' };
    } finally {
      isSaving = false;
    }
  }

  async function handleTest() {
    isTesting = true;
    statusMessage = null;
    try {
      await handleSave();
      await ipc.aiTestConnection();
      let suffix = '';
      try {
        const n = await loadModels();
        suffix = n > 0 ? ` — ${n} model tersedia, klik kolom Model untuk memilih.` : '';
      } catch (e: any) {
        suffix = ` — daftar model gagal dimuat: ${typeof e === 'string' ? e : e?.message || ''}`;
      }
      statusMessage = { text: `Koneksi berhasil${suffix}`, type: 'success' };
    } catch (err: any) {
      statusMessage = { text: typeof err === 'string' ? err : err?.message || String(err), type: 'error' };
    } finally {
      isTesting = false;
    }
  }
</script>

<div class="space-y-6">
  <div>
    <h2 class="text-lg font-bold text-slate-100">AI Assistant</h2>
    <p class="text-xs text-slate-400 mt-1">
      Bawa API key sendiri — provider bebas. Semua yang kompatibel dengan OpenAI (OpenAI, OpenRouter,
      Groq, Ollama lokal, dll.) dan Anthropic Claude (native) didukung. Key tersimpan hanya di perangkat ini.
    </p>
  </div>

  <!-- Presets -->
  <div class="space-y-2">
    <span class="block text-xs font-bold text-slate-300 uppercase tracking-wider">Preset Cepat</span>
    <div class="grid grid-cols-2 md:grid-cols-5 gap-2">
      {#each PRESETS as p (p.id)}
        <button
          onclick={() => applyPreset(p)}
          class="p-3 rounded-xl border text-left transition-all cursor-pointer {baseUrl === p.base_url
            ? 'bg-violet-600/10 border-violet-500 text-white'
            : 'bg-slate-900/60 border-slate-800 hover:border-violet-600/50 text-slate-300'}"
        >
          <div class="text-xs font-bold">{p.label}</div>
          <div class="text-[10px] text-slate-500 mt-0.5 leading-tight">{p.hint}</div>
        </button>
      {/each}
    </div>
  </div>

  <!-- Config Form -->
  <div class="p-5 rounded-2xl border border-slate-800 bg-slate-900/40 space-y-4">
    <!-- Provider kind -->
    <div class="space-y-1.5">
      <label class="text-xs font-semibold text-slate-300 flex items-center space-x-1.5">
        <Bot class="w-3.5 h-3.5 text-violet-400" />
        <span>Jenis Provider</span>
      </label>
      <select
        bind:value={kind}
        class="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-100 focus:outline-none focus:border-violet-500 transition-colors cursor-pointer"
      >
        <option value="openai">OpenAI-compatible (OpenAI, OpenRouter, Groq, Ollama, dll.)</option>
        <option value="anthropic">Anthropic Claude (native Messages API)</option>
      </select>
    </div>

    <!-- Base URL -->
    <div class="space-y-1.5">
      <label class="text-xs font-semibold text-slate-300 flex items-center space-x-1.5">
        <Server class="w-3.5 h-3.5 text-blue-400" />
        <span>Base URL</span>
      </label>
      <input
        type="text"
        bind:value={baseUrl}
        placeholder={kind === 'anthropic' ? 'https://api.anthropic.com' : 'https://api.openai.com/v1'}
        class="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-100 placeholder-slate-600 focus:outline-none focus:border-violet-500 font-mono transition-colors"
      />
      <p class="text-[10px] text-slate-500">
        {kind === 'anthropic'
          ? 'Domain dasar Anthropic — endpoint /v1/messages ditambahkan otomatis.'
          : 'Domain dasar + /v1 — endpoint /chat/completions ditambahkan otomatis.'}
      </p>
    </div>

    <!-- API Key -->
    <div class="space-y-1.5">
      <label class="text-xs font-semibold text-slate-300 flex items-center space-x-1.5">
        <Key class="w-3.5 h-3.5 text-amber-400" />
        <span>API Key</span>
        {#if hasApiKey && !apiKey}
          <span class="text-[10px] font-normal text-emerald-400">(tersimpan)</span>
        {/if}
      </label>
      <div class="relative">
        <input
          type={showKey ? 'text' : 'password'}
          bind:value={apiKey}
          placeholder={hasApiKey ? '•••••••• (biarkan kosong untuk mempertahankan)' : 'sk-…'}
          class="w-full px-3 py-2 pr-10 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-100 placeholder-slate-600 focus:outline-none focus:border-violet-500 font-mono transition-colors"
        />
        <button
          type="button"
          onclick={() => (showKey = !showKey)}
          class="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-500 hover:text-slate-200 transition-colors cursor-pointer"
          aria-label="Tampilkan/sembunyikan API key"
        >
          {#if showKey}<EyeOff class="w-3.5 h-3.5" />{:else}<Eye class="w-3.5 h-3.5" />{/if}
        </button>
      </div>
    </div>

    <!-- Model -->
    <div class="space-y-1.5">
      <label class="text-xs font-semibold text-slate-300 flex items-center space-x-1.5">
        <Cpu class="w-3.5 h-3.5 text-emerald-400" />
        <span>Model</span>
      </label>
      <input
        type="text"
        bind:value={model}
        list="ai-model-datalist"
        placeholder={kind === 'anthropic' ? 'claude-sonnet-4-5' : 'gpt-4o-mini'}
        class="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-100 placeholder-slate-600 focus:outline-none focus:border-violet-500 font-mono transition-colors"
      />
      <datalist id="ai-model-datalist">
        {#each models as m (m)}
          <option value={m} />
        {/each}
      </datalist>
      {#if models.length > 0}
        <p class="text-[10px] text-emerald-400">
          {models.length} model dimuat dari provider — mulai mengetik untuk melihat saran.
        </p>
      {:else if isLoadingModels}
        <p class="text-[10px] text-slate-500 flex items-center space-x-1">
          <Loader2 class="w-3 h-3 animate-spin" />
          <span>Memuat daftar model…</span>
        </p>
      {/if}
    </div>

    <!-- Actions -->
    <div class="flex flex-wrap items-center gap-2 pt-1">
      <button
        onclick={handleSave}
        disabled={isSaving || isLoading}
        class="px-4 py-2 rounded-xl bg-violet-600 hover:bg-violet-500 disabled:opacity-50 text-white text-xs font-semibold transition-colors cursor-pointer"
      >
        {#if isSaving}<Loader2 class="w-3.5 h-3.5 inline animate-spin mr-1" />{/if}
        Simpan
      </button>
      <button
        onclick={handleTest}
        disabled={isTesting || isLoading}
        class="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-200 text-xs font-medium transition-colors cursor-pointer disabled:opacity-50"
      >
        {#if isTesting}<Loader2 class="w-3.5 h-3.5 inline animate-spin mr-1" />{:else}<CheckCircle2 class="w-3.5 h-3.5 inline mr-1 text-emerald-400" />{/if}
        Test Koneksi
      </button>
    </div>

    {#if statusMessage}
      <div
        class="flex items-start space-x-2 text-xs p-3 rounded-xl border {statusMessage.type === 'success'
          ? 'bg-emerald-950/40 border-emerald-800/60 text-emerald-200'
          : 'bg-rose-950/50 border-rose-800/60 text-rose-200'}"
      >
        {#if statusMessage.type === 'success'}
          <CheckCircle2 class="w-4 h-4 flex-shrink-0 mt-0.5" />
        {:else}
          <AlertCircle class="w-4 h-4 flex-shrink-0 mt-0.5" />
        {/if}
        <span class="break-all leading-relaxed">{statusMessage.text}</span>
      </div>
    {/if}
  </div>

  <!-- Privacy note -->
  <div class="p-3.5 rounded-xl bg-amber-950/30 border border-amber-900/50 text-[11px] text-amber-200/90 leading-relaxed flex items-start space-x-2">
    <ShieldAlert class="w-4 h-4 flex-shrink-0 mt-0.5 text-amber-400" />
    <span>
      <strong>Catatan privasi:</strong> teks yang kamu kirim ke AI keluar dari perangkat sebagai plaintext —
      enkripsi E2E melindungi penyimpanan lokal & cloud, bukan permintaan AI. Gunakan provider lokal (Ollama)
      bila kamu bekerja dengan konten yang sangat sensitif.
    </span>
  </div>
</div>
