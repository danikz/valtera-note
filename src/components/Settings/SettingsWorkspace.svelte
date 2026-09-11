<script lang="ts">
  import { onMount, untrack } from 'svelte';
  import { 
    Cloud, 
    Palette, 
    Sliders, 
    Info, 
    ArrowLeft, 
    Check, 
    Copy, 
    ExternalLink, 
    RefreshCw, 
    Eye, 
    EyeOff, 
    Key, 
    Database, 
    Server, 
    CheckCircle2, 
    AlertCircle, 
    Loader2, 
    ShieldCheck, 
    Zap, 
    Wrench, 
    Sparkles, 
    Sun, 
    Moon, 
    Monitor, 
    Type, 
    WrapText, 
    Hash, 
    Save, 
    Clock, 
    Trash2, 
    FolderGit2, 
    Code2,
    BookOpen
  } from 'lucide-svelte';
  import { editorStore } from '../../stores/editorStore.svelte';
  import { themeStore, type ThemeMode, type ThemePreset } from '../../stores/themeStore.svelte';
  import { updaterService } from '../../services/updater.svelte';
  import { ipc } from '../../services/ipc';

  export type SettingsTab = 'supabase' | 'appearance' | 'editor' | 'about';

  let { 
    activeTab = 'supabase',
    onSelectTab,
    onClose 
  }: { 
    activeTab?: SettingsTab;
    onSelectTab?: (tab: SettingsTab) => void;
    onClose?: () => void;
  } = $props();

  let currentTab = $state<SettingsTab>(untrack(() => activeTab));

  $effect(() => {
    currentTab = activeTab;
  });

  function setTab(tab: SettingsTab) {
    currentTab = tab;
    if (onSelectTab) onSelectTab(tab);
  }

  // ==========================================
  // 1. SUPABASE CLOUD STATE & ACTIONS
  // ==========================================
  let url = $state(editorStore.supabaseConfig.url || '');
  let anonKey = $state(editorStore.supabaseConfig.anon_key || '');
  let showKey = $state(false);
  let isTesting = $state(false);
  let isCheckingTable = $state(false);
  let isAutoCreating = $state(false);
  let showAutoCreateInput = $state(false);
  let showSqlGuide = $state(false);
  let managementToken = $state('');
  let tableStatus = $state<'ready' | 'missing' | 'unknown'>('unknown');
  let statusMessage = $state<{ text: string; type: 'success' | 'error' } | null>(null);
  let copiedSql = $state(false);

  const SQL_MIGRATION = `-- 1. Buat tabel notes di Supabase
create table if not exists public.notes (
    id uuid default gen_random_uuid() primary key,
    title text not null default 'Untitled',
    content text not null default '',
    file_extension text not null default 'md',
    folder text,
    is_pinned boolean not null default false,
    is_deleted boolean not null default false,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Tambah kolom folder bila belum ada
alter table public.notes add column if not exists folder text;

-- 3. Buat indeks untuk kecepatan query
create index if not exists idx_notes_updated_at on public.notes(updated_at desc);

-- 4. Aktifkan RLS dan izinkan akses API
alter table public.notes enable row level security;

drop policy if exists "Allow API access" on public.notes;
drop policy if exists "Allow all for anon and authenticated" on public.notes;

create policy "Allow all for anon and authenticated" 
on public.notes 
for all 
to anon, authenticated 
using (true) 
with check (true);`;

  function getProjectRef(): string | null {
    try {
      const clean = url.trim();
      const parsed = new URL(clean.startsWith('http') ? clean : `https://${clean}`);
      const host = parsed.hostname;
      if (host.includes('.supabase.co')) {
        return host.split('.supabase.co')[0];
      }
    } catch {
      // ignore
    }
    return null;
  }

  async function checkTable() {
    const cleanUrl = url.trim();
    const cleanKey = anonKey.trim();
    if (!cleanUrl || !cleanKey) return;

    isCheckingTable = true;
    try {
      const exists = await ipc.checkSupabaseTable(cleanUrl, cleanKey);
      tableStatus = exists ? 'ready' : 'missing';
    } catch {
      tableStatus = 'unknown';
    } finally {
      isCheckingTable = false;
    }
  }

  onMount(async () => {
    try {
      const stored = await ipc.getSupabaseConfig();
      if (stored) {
        if (stored.url) url = stored.url;
        if (stored.anon_key) anonKey = stored.anon_key;
      }
      if (url && anonKey) {
        checkTable();
      }
    } catch (e) {
      console.warn('Failed to load supabase config in settings:', e);
    }
  });

  async function handleSaveCredentials() {
    const cleanUrl = url.trim().replace(/\/+$/, '');
    const cleanKey = anonKey.trim();

    if (!cleanUrl || !cleanKey) {
      statusMessage = { text: 'Mohon isi Project URL dan Anon Key Supabase.', type: 'error' };
      return;
    }

    try {
      await ipc.saveSupabaseConfig(cleanUrl, cleanKey);
      editorStore.setSupabaseConfig({
        url: cleanUrl,
        anon_key: cleanKey,
        is_configured: true
      });
      statusMessage = { text: 'Kredensial Supabase berhasil disimpan!', type: 'success' };
      await checkTable();
    } catch (e: any) {
      statusMessage = { text: `Gagal menyimpan: ${e?.message || e}`, type: 'error' };
    }
  }

  async function handleTestConnection() {
    const cleanUrl = url.trim().replace(/\/+$/, '');
    const cleanKey = anonKey.trim();

    if (!cleanUrl || !cleanKey) {
      statusMessage = { text: 'Project URL dan Anon Key wajib diisi untuk pengujian.', type: 'error' };
      return;
    }

    isTesting = true;
    statusMessage = null;

    try {
      const ok = await ipc.testSupabaseConnection(cleanUrl, cleanKey);
      if (ok) {
        statusMessage = { text: 'Koneksi ke Supabase berhasil! Kredensial valid.', type: 'success' };
        await ipc.saveSupabaseConfig(cleanUrl, cleanKey);
        editorStore.setSupabaseConfig({
          url: cleanUrl,
          anon_key: cleanKey,
          is_configured: true
        });
        await checkTable();
      } else {
        statusMessage = { text: 'Gagal terhubung ke Supabase. Periksa kembali URL dan Anon Key.', type: 'error' };
      }
    } catch (err: any) {
      statusMessage = { text: `Error koneksi: ${err.message || err}`, type: 'error' };
    } finally {
      isTesting = false;
    }
  }

  async function handleAutoCreate() {
    if (!managementToken.trim()) {
      statusMessage = { text: 'Mohon masukkan Supabase Access Token pribadi Anda.', type: 'error' };
      return;
    }

    isAutoCreating = true;
    statusMessage = null;

    try {
      await ipc.autoCreateSupabaseTable(url.trim(), anonKey.trim(), managementToken.trim());
      statusMessage = { text: 'Skema tabel notes berhasil dibuat secara otomatis!', type: 'success' };
      tableStatus = 'ready';
      showAutoCreateInput = false;
      managementToken = '';
    } catch (e: any) {
      statusMessage = { text: `Gagal membuat tabel: ${e.message || e}`, type: 'error' };
    } finally {
      isAutoCreating = false;
    }
  }

  async function handleSyncNow() {
    try {
      await editorStore.autoSyncAll();
      if (editorStore.syncStatus === 'error') {
        statusMessage = { text: '⚠️ Sinkronisasi selesai dengan peringatan. Pastikan tabel notes sudah ada di database.', type: 'error' };
      } else {
        statusMessage = { text: `✅ Sinkronisasi cloud berhasil dijalankan! (${editorStore.lastSyncedAt || 'Baru saja'})`, type: 'success' };
      }
    } catch (e: any) {
      statusMessage = { text: `Sinkronisasi gagal: ${e.message || e}`, type: 'error' };
    }
  }

  async function handleClearCredentials() {
    if (confirm('Yakin ingin menghapus kredensial Supabase dari aplikasi ini? Catatan lokal tetap aman.')) {
      await ipc.saveSupabaseConfig('', '');
      editorStore.setSupabaseConfig({
        url: '',
        anon_key: '',
        is_configured: false
      });
      url = '';
      anonKey = '';
      tableStatus = 'unknown';
      statusMessage = { text: 'Kredensial Supabase berhasil dihapus.', type: 'success' };
    }
  }

  function handleCopySql() {
    navigator.clipboard.writeText(SQL_MIGRATION);
    copiedSql = true;
    setTimeout(() => (copiedSql = false), 2500);
  }

  // ==========================================
  // 2. THEMES & PRESETS CONFIGURATION
  // ==========================================
  const presets: { id: ThemePreset; name: string; desc: string; type: 'dark' | 'light'; colors: string[] }[] = [
    {
      id: 'slate',
      name: 'Valtera Slate',
      desc: 'Default arang gelap dengan aksen biru profesional',
      type: 'dark',
      colors: ['#090d16', '#0f172a', '#1e293b', '#0284c7']
    },
    {
      id: 'tokyo',
      name: 'Tokyo Night',
      desc: 'Navy dalam bernuansa cyberpunk dengan aksen neon cyan & ungu',
      type: 'dark',
      colors: ['#16161e', '#1a1b26', '#24283b', '#7aa2f7']
    },
    {
      id: 'dracula',
      name: 'Dracula',
      desc: 'Ungu gelap legendaris dengan aksen pink & violet cerah',
      type: 'dark',
      colors: ['#1e1f29', '#282a36', '#343746', '#ff79c6']
    },
    {
      id: 'emerald',
      name: 'Forest Emerald',
      desc: 'Nuansa hutan pinus malam dengan kilau hijau zamrud',
      type: 'dark',
      colors: ['#061712', '#0c241c', '#133429', '#10b981']
    },
    {
      id: 'nord',
      name: 'Nordic Frost',
      desc: 'Abu-abu es kutub utara yang menyejukkan mata',
      type: 'dark',
      colors: ['#242933', '#2e3440', '#3b4252', '#88c0d0']
    },
    {
      id: 'github-light',
      name: 'GitHub Light',
      desc: 'Mode putih bersih dengan kontras tinggi untuk siang hari',
      type: 'light',
      colors: ['#f8fafc', '#ffffff', '#e2e8f0', '#0284c7']
    }
  ];

  const fontFamilies = [
    { label: 'System Monospace (Ultra Ringan)', value: 'ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace' },
    { label: 'JetBrains Mono', value: '"JetBrains Mono", ui-monospace, Menlo, monospace' },
    { label: 'Fira Code', value: '"Fira Code", monospace' },
    { label: 'Consolas / Lucida', value: 'Consolas, "Lucida Console", monospace' }
  ];

  onMount(() => {
    if (editorStore.supabaseConfig.is_configured) {
      checkTable();
    }
  });
</script>

<div class="h-full w-full flex flex-col bg-slate-950 text-slate-100 overflow-hidden select-none animate-in fade-in duration-150">
  
  <!-- Header Bar -->
  <header class="h-12 px-4 border-b border-slate-800 bg-slate-900/60 flex items-center justify-between flex-shrink-0">
    <div class="flex items-center space-x-3">
      {#if onClose}
        <button 
          onclick={onClose}
          class="flex items-center space-x-1.5 px-2.5 py-1 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-xs font-medium transition-colors cursor-pointer"
          title="Kembali ke Editor Catatan (Esc)"
        >
          <ArrowLeft class="w-3.5 h-3.5" />
          <span>Kembali</span>
        </button>
      {/if}

      <div class="h-4 w-px bg-slate-800"></div>

      <div class="flex items-center space-x-2">
        <Sliders class="w-4 h-4 text-blue-400" />
        <h1 class="text-sm font-bold text-slate-100">Pengaturan Aplikasi</h1>
        <span class="text-[11px] text-slate-500 hidden sm:inline">• Kredensial, Tampilan & Preferensi</span>
      </div>
    </div>

    <!-- Quick Mode Switcher Indicator -->
    <div class="flex items-center space-x-2">
      <button 
        onclick={() => themeStore.toggleMode()}
        class="flex items-center space-x-1.5 px-2.5 py-1 rounded-lg bg-slate-800/80 hover:bg-slate-700 text-slate-300 text-xs font-medium transition-colors cursor-pointer"
        title="Ganti Mode Gelap / Terang Langsung"
      >
        {#if themeStore.isDarkEffective()}
          <Moon class="w-3.5 h-3.5 text-blue-400" />
          <span class="text-[11px]">Mode Gelap</span>
        {:else}
          <Sun class="w-3.5 h-3.5 text-amber-400" />
          <span class="text-[11px]">Mode Terang</span>
        {/if}
      </button>
    </div>
  </header>

  <!-- Main Settings Layout (Sidebar + Content Canvas) -->
  <div class="flex-1 flex overflow-hidden">
    
    <!-- Left Navigation Sidebar -->
    <aside class="w-60 border-r border-slate-800 bg-slate-900/40 p-3 space-y-1 flex-shrink-0 overflow-y-auto">
      <div class="px-3 py-1.5 text-[10.5px] font-semibold tracking-wider uppercase text-slate-500">
        Kategori Pengaturan
      </div>

      <!-- Item: Supabase -->
      <button 
        onclick={() => setTab('supabase')}
        class="w-full flex items-center justify-between px-3 py-2.5 rounded-xl text-xs font-medium transition-all cursor-pointer {currentTab === 'supabase' ? 'bg-blue-600 text-white shadow-sm font-semibold' : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'}"
      >
        <div class="flex items-center space-x-2.5">
          <Cloud class="w-4 h-4 {currentTab === 'supabase' ? 'text-white' : 'text-blue-400'}" />
          <span>Supabase Cloud</span>
        </div>
        {#if editorStore.supabaseConfig.is_configured}
          <span class="w-2 h-2 rounded-full bg-emerald-400"></span>
        {/if}
      </button>

      <!-- Item: Tampilan & Tema -->
      <button 
        onclick={() => setTab('appearance')}
        class="w-full flex items-center justify-between px-3 py-2.5 rounded-xl text-xs font-medium transition-all cursor-pointer {currentTab === 'appearance' ? 'bg-blue-600 text-white shadow-sm font-semibold' : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'}"
      >
        <div class="flex items-center space-x-2.5">
          <Palette class="w-4 h-4 {currentTab === 'appearance' ? 'text-white' : 'text-purple-400'}" />
          <span>Tampilan & Tema</span>
        </div>
        <span class="text-[10px] uppercase font-mono px-1.5 py-0.2 rounded bg-slate-800/80 {currentTab === 'appearance' ? 'text-blue-100 bg-blue-700/60' : 'text-slate-400'}">
          {themeStore.preset}
        </span>
      </button>

      <!-- Item: Preferensi Editor -->
      <button 
        onclick={() => setTab('editor')}
        class="w-full flex items-center justify-between px-3 py-2.5 rounded-xl text-xs font-medium transition-all cursor-pointer {currentTab === 'editor' ? 'bg-blue-600 text-white shadow-sm font-semibold' : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'}"
      >
        <div class="flex items-center space-x-2.5">
          <Code2 class="w-4 h-4 {currentTab === 'editor' ? 'text-white' : 'text-emerald-400'}" />
          <span>Preferensi Editor</span>
        </div>
        <span class="text-[10px] font-mono text-slate-400">{themeStore.fontSize}px</span>
      </button>

      <!-- Item: Tentang Aplikasi -->
      <button 
        onclick={() => setTab('about')}
        class="w-full flex items-center justify-between px-3 py-2.5 rounded-xl text-xs font-medium transition-all cursor-pointer {currentTab === 'about' ? 'bg-blue-600 text-white shadow-sm font-semibold' : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'}"
      >
        <div class="flex items-center space-x-2.5">
          <Info class="w-4 h-4 {currentTab === 'about' ? 'text-white' : 'text-amber-400'}" />
          <span>Tentang & Pembaruan</span>
        </div>
        <span class="text-[10px] font-mono text-slate-500">v0.1.7</span>
      </button>
    </aside>

    <!-- Right Main Scrollable View Area -->
    <main class="flex-1 overflow-y-auto p-6 md:p-8 bg-slate-950 select-text">
      <div class="max-w-3xl mx-auto space-y-6">
        
        <!-- Status Toast Banner -->
        {#if statusMessage}
          <div class="p-4 rounded-xl text-xs font-medium flex items-center justify-between border animate-in fade-in duration-150 {statusMessage.type === 'success' ? 'bg-emerald-950/40 border-emerald-800 text-emerald-200' : 'bg-rose-950/40 border-rose-800 text-rose-200'}">
            <div class="flex items-center space-x-2">
              {#if statusMessage.type === 'success'}
                <CheckCircle2 class="w-4 h-4 text-emerald-400 flex-shrink-0" />
              {:else}
                <AlertCircle class="w-4 h-4 text-rose-400 flex-shrink-0" />
              {/if}
              <span>{statusMessage.text}</span>
            </div>
            <button onclick={() => (statusMessage = null)} class="text-xs opacity-70 hover:opacity-100">✕</button>
          </div>
        {/if}

        <!-- ==================================================== -->
        <!-- TAB 1: SUPABASE CLOUD CONFIGURATION -->
        <!-- ==================================================== -->
        {#if currentTab === 'supabase'}
          <div class="space-y-6">
            <!-- Header section -->
            <div>
              <h2 class="text-lg font-bold text-slate-100">Konfigurasi Supabase Cloud Sync</h2>
              <p class="text-xs text-slate-400 mt-1">
                Hubungkan basis data Supabase gratis Anda untuk sinkronisasi catatan otomatis antar-perangkat secara aman dan terenkripsi.
              </p>
            </div>

            <!-- Connection Status Card -->
            <div class="p-4 rounded-xl border bg-slate-900/60 {editorStore.supabaseConfig.is_configured ? 'border-emerald-800/60' : 'border-slate-800'} flex items-center justify-between">
              <div class="flex items-center space-x-3">
                <div class="w-10 h-10 rounded-xl {editorStore.supabaseConfig.is_configured ? 'bg-emerald-600/20 text-emerald-400' : 'bg-slate-800 text-slate-500'} flex items-center justify-center">
                  <Cloud class="w-5 h-5" />
                </div>
                <div>
                  <div class="flex items-center space-x-2">
                    <p class="text-xs font-bold text-slate-200">
                      {editorStore.supabaseConfig.is_configured ? 'Supabase Terhubung' : 'Belum Dikonfigurasi'}
                    </p>
                    <span class="px-2 py-0.5 rounded-full text-[10px] font-semibold {editorStore.supabaseConfig.is_configured ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-slate-800 text-slate-400'}">
                      {editorStore.supabaseConfig.is_configured ? 'Aktif' : 'Offline'}
                    </span>
                  </div>
                  <p class="text-[11px] text-slate-400 mt-0.5">
                    {editorStore.supabaseConfig.is_configured ? `Project: ${getProjectRef() || url}` : 'Aplikasi saat ini menyimpan semua catatan secara lokal di SQLite.'}
                  </p>
                </div>
              </div>

              {#if editorStore.supabaseConfig.is_configured}
                <button 
                  onclick={handleSyncNow}
                  disabled={editorStore.isSyncing}
                  class="px-3 py-1.5 rounded-lg bg-blue-600 hover:bg-blue-700 text-white text-xs font-medium flex items-center space-x-1.5 transition-colors cursor-pointer disabled:opacity-50"
                >
                  <RefreshCw class="w-3.5 h-3.5 {editorStore.isSyncing ? 'animate-spin' : ''}" />
                  <span>{editorStore.isSyncing ? 'Sinkronisasi...' : 'Sinkronkan'}</span>
                </button>
              {/if}
            </div>

            <!-- Credentials Form -->
            <div class="p-5 rounded-2xl border border-slate-800 bg-slate-900/40 space-y-4">
              <!-- URL input -->
              <div class="space-y-1.5">
                <label class="text-xs font-semibold text-slate-300 flex items-center justify-between">
                  <span class="flex items-center space-x-1.5">
                    <Server class="w-3.5 h-3.5 text-blue-400" />
                    <span>Project URL</span>
                  </span>
                  <span class="text-[10.5px] text-slate-500">Contoh: https://xyzcompany.supabase.co</span>
                </label>
                <input 
                  type="text" 
                  bind:value={url}
                  placeholder="https://your-project-id.supabase.co"
                  class="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-100 placeholder-slate-600 focus:outline-none focus:border-blue-500 font-mono transition-colors"
                />
              </div>

              <!-- Anon Key input -->
              <div class="space-y-1.5">
                <label class="text-xs font-semibold text-slate-300 flex items-center justify-between">
                  <span class="flex items-center space-x-1.5">
                    <Key class="w-3.5 h-3.5 text-amber-400" />
                    <span>Public Anon Key</span>
                  </span>
                  <button 
                    type="button"
                    onclick={() => (showKey = !showKey)}
                    class="text-[11px] text-slate-400 hover:text-slate-200 flex items-center space-x-1 cursor-pointer"
                  >
                    {#if showKey}
                      <EyeOff class="w-3 h-3" />
                      <span>Sembunyikan</span>
                    {:else}
                      <Eye class="w-3 h-3" />
                      <span>Lihat Key</span>
                    {/if}
                  </button>
                </label>
                <input 
                  type={showKey ? "text" : "password"} 
                  bind:value={anonKey}
                  placeholder="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
                  class="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-100 placeholder-slate-600 focus:outline-none focus:border-blue-500 font-mono transition-colors"
                />
              </div>

              <!-- Actions row -->
              <div class="pt-2 flex flex-wrap items-center justify-between gap-3">
                <div class="flex items-center space-x-2">
                  <button 
                    onclick={handleSaveCredentials}
                    class="px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-700 text-white text-xs font-semibold flex items-center space-x-1.5 transition-colors cursor-pointer shadow-sm"
                  >
                    <Save class="w-3.5 h-3.5" />
                    <span>Simpan Kredensial</span>
                  </button>

                  <button 
                    onclick={handleTestConnection}
                    disabled={isTesting}
                    class="px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-medium flex items-center space-x-1.5 transition-colors cursor-pointer disabled:opacity-50"
                  >
                    {#if isTesting}
                      <Loader2 class="w-3.5 h-3.5 animate-spin text-blue-400" />
                      <span>Menguji...</span>
                    {:else}
                      <Zap class="w-3.5 h-3.5 text-amber-400" />
                      <span>Uji Koneksi</span>
                    {/if}
                  </button>
                </div>

                {#if editorStore.supabaseConfig.is_configured}
                  <button 
                    onclick={handleClearCredentials}
                    class="px-3 py-2 rounded-xl hover:bg-rose-950/40 text-rose-400 text-xs font-medium flex items-center space-x-1.5 transition-colors cursor-pointer"
                  >
                    <Trash2 class="w-3.5 h-3.5" />
                    <span>Hapus Kredensial</span>
                  </button>
                {/if}
              </div>
            </div>

            <!-- Table Schema Status & Auto-Setup Card -->
            <div class="p-5 rounded-2xl border border-slate-800 bg-slate-900/40 space-y-4">
              <div class="flex items-center justify-between">
                <div class="flex items-center space-x-2">
                  <Database class="w-4 h-4 text-emerald-400" />
                  <h3 class="text-xs font-bold text-slate-200">Status Skema Tabel (public.notes)</h3>
                </div>

                <div class="flex items-center space-x-2">
                  {#if tableStatus === 'ready'}
                    <span class="px-2.5 py-0.5 rounded-full text-[10.5px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 flex items-center space-x-1">
                      <CheckCircle2 class="w-3 h-3" />
                      <span>Tabel Siap</span>
                    </span>
                  {:else if tableStatus === 'missing'}
                    <span class="px-2.5 py-0.5 rounded-full text-[10.5px] font-semibold bg-rose-500/10 text-rose-400 border border-rose-500/20 flex items-center space-x-1">
                      <AlertCircle class="w-3 h-3" />
                      <span>Tabel Belum Ada</span>
                    </span>
                  {:else}
                    <button 
                      onclick={checkTable}
                      disabled={isCheckingTable}
                      class="text-[11px] text-blue-400 hover:text-blue-300 flex items-center space-x-1 cursor-pointer"
                    >
                      <RefreshCw class="w-3 h-3 {isCheckingTable ? 'animate-spin' : ''}" />
                      <span>Periksa Skema</span>
                    </button>
                  {/if}
                </div>
              </div>

              <!-- SQL Schema Guide Accordion -->
              <div class="pt-2 border-t border-slate-800/80">
                <div class="flex items-center justify-between">
                  <span class="text-xs text-slate-400">Skrip DDL SQL Resmi:</span>
                  <div class="flex items-center space-x-2">
                    <button 
                      onclick={handleCopySql}
                      class="px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-[11px] font-medium flex items-center space-x-1.5 transition-colors cursor-pointer"
                    >
                      {#if copiedSql}
                        <Check class="w-3 h-3 text-emerald-400" />
                        <span class="text-emerald-400">Tersalin!</span>
                      {:else}
                        <Copy class="w-3 h-3 text-blue-400" />
                        <span>Salin Skrip SQL</span>
                      {/if}
                    </button>

                    <button 
                      onclick={() => (showSqlGuide = !showSqlGuide)}
                      class="px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-[11px] font-medium transition-colors cursor-pointer"
                    >
                      {showSqlGuide ? 'Tutup Pratinjau' : 'Lihat Skrip SQL'}
                    </button>
                  </div>
                </div>

                {#if showSqlGuide}
                  <div class="mt-3 bg-slate-950 rounded-xl border border-slate-800 overflow-hidden">
                    <pre class="p-3 font-mono text-[11px] text-slate-300 overflow-x-auto whitespace-pre leading-relaxed max-h-48">{SQL_MIGRATION}</pre>
                  </div>
                {/if}
              </div>
            </div>
          </div>

        <!-- ==================================================== -->
        <!-- TAB 2: APPEARANCE & THEMES -->
        <!-- ==================================================== -->
        {:else if currentTab === 'appearance'}
          <div class="space-y-6">
            <div>
              <h2 class="text-lg font-bold text-slate-100">Tampilan & Tema Warna</h2>
              <p class="text-xs text-slate-400 mt-1">
                Personalisasikan nuansa visual Valtera Note dengan pilihan mode gelap, mode terang profesional, dan palet tema koding.
              </p>
            </div>

            <!-- Color Mode Selection (Dark / Light / System) -->
            <div class="space-y-2">
              <span class="block text-xs font-bold text-slate-300 uppercase tracking-wider">Mode Warna Utama</span>
              <div class="grid grid-cols-3 gap-3">
                <!-- Dark Mode Option -->
                <button 
                  onclick={() => themeStore.setMode('dark')}
                  class="p-4 rounded-2xl border text-left transition-all cursor-pointer flex flex-col justify-between {themeStore.mode === 'dark' ? 'bg-blue-600/10 border-blue-500 text-white shadow-xs' : 'bg-slate-900/60 border-slate-800 hover:border-slate-700 text-slate-300'}"
                >
                  <div class="flex items-center justify-between w-full mb-3">
                    <div class="w-8 h-8 rounded-lg bg-slate-950 flex items-center justify-center text-blue-400 border border-slate-800">
                      <Moon class="w-4 h-4" />
                    </div>
                    {#if themeStore.mode === 'dark'}
                      <CheckCircle2 class="w-4 h-4 text-blue-400" />
                    {/if}
                  </div>
                  <div>
                    <h4 class="text-xs font-bold">Mode Gelap</h4>
                    <p class="text-[10.5px] text-slate-400 mt-0.5">Nyaman untuk koding malam hari</p>
                  </div>
                </button>

                <!-- Light Mode Option -->
                <button 
                  onclick={() => themeStore.setMode('light')}
                  class="p-4 rounded-2xl border text-left transition-all cursor-pointer flex flex-col justify-between {themeStore.mode === 'light' ? 'bg-blue-600/10 border-blue-500 text-white shadow-xs' : 'bg-slate-900/60 border-slate-800 hover:border-slate-700 text-slate-300'}"
                >
                  <div class="flex items-center justify-between w-full mb-3">
                    <div class="w-8 h-8 rounded-lg bg-white flex items-center justify-center text-amber-500 border border-slate-200">
                      <Sun class="w-4 h-4" />
                    </div>
                    {#if themeStore.mode === 'light'}
                      <CheckCircle2 class="w-4 h-4 text-blue-400" />
                    {/if}
                  </div>
                  <div>
                    <h4 class="text-xs font-bold">Mode Terang</h4>
                    <p class="text-[10.5px] text-slate-400 mt-0.5">Bersih, tajam & profesional</p>
                  </div>
                </button>

                <!-- System Mode Option -->
                <button 
                  onclick={() => themeStore.setMode('system')}
                  class="p-4 rounded-2xl border text-left transition-all cursor-pointer flex flex-col justify-between {themeStore.mode === 'system' ? 'bg-blue-600/10 border-blue-500 text-white shadow-xs' : 'bg-slate-900/60 border-slate-800 hover:border-slate-700 text-slate-300'}"
                >
                  <div class="flex items-center justify-between w-full mb-3">
                    <div class="w-8 h-8 rounded-lg bg-slate-800 flex items-center justify-center text-purple-400 border border-slate-700">
                      <Monitor class="w-4 h-4" />
                    </div>
                    {#if themeStore.mode === 'system'}
                      <CheckCircle2 class="w-4 h-4 text-blue-400" />
                    {/if}
                  </div>
                  <div>
                    <h4 class="text-xs font-bold">Ikuti Sistem</h4>
                    <p class="text-[10.5px] text-slate-400 mt-0.5">Otomatis sinkron preferensi OS</p>
                  </div>
                </button>
              </div>
            </div>

            <!-- Theme Presets Grid -->
            <div class="space-y-3 pt-2">
              <div class="flex items-center justify-between">
                <span class="text-xs font-bold text-slate-300 uppercase tracking-wider">Palet Tema Editor</span>
                <span class="text-[11px] text-slate-500">Pilih tema favorit Anda</span>
              </div>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {#each presets as p}
                  <button 
                    onclick={() => themeStore.setPreset(p.id)}
                    class="p-4 rounded-2xl border text-left transition-all cursor-pointer flex items-center justify-between {themeStore.preset === p.id ? 'bg-blue-600/10 border-blue-500 shadow-sm' : 'bg-slate-900/40 border-slate-800 hover:border-slate-700'}"
                  >
                    <div class="space-y-1 pr-3">
                      <div class="flex items-center space-x-2">
                        <span class="text-xs font-bold text-slate-100">{p.name}</span>
                        <span class="text-[9.5px] px-1.5 py-0.2 rounded font-semibold {p.type === 'light' ? 'bg-amber-500/20 text-amber-300' : 'bg-slate-800 text-slate-400'}">
                          {p.type.toUpperCase()}
                        </span>
                      </div>
                      <p class="text-[11px] text-slate-400 leading-snug">{p.desc}</p>
                    </div>

                    <!-- Color Swatches -->
                    <div class="flex items-center space-x-1 flex-shrink-0">
                      {#each p.colors as c}
                        <span class="w-3.5 h-6 rounded-sm shadow-xs border border-white/10" style="background-color: {c};"></span>
                      {/each}
                    </div>
                  </button>
                {/each}
              </div>
            </div>

            <!-- Live Theme Preview Box -->
            <div class="p-4 rounded-2xl border border-slate-800 bg-slate-900/50 space-y-2">
              <div class="flex items-center justify-between text-xs text-slate-400">
                <span>Pratinjau Langsung CodeMirror</span>
                <span class="font-mono text-blue-400">Active: {themeStore.preset}</span>
              </div>
              <div class="p-4 rounded-xl border border-slate-800 font-mono text-xs leading-relaxed overflow-x-auto bg-slate-950">
                <p><span class="text-slate-500">1</span>  <span class="text-purple-400">const</span> <span class="text-blue-400">app</span> = <span class="text-amber-400">"Valtera Note"</span>;</p>
                <p><span class="text-slate-500">2</span>  <span class="text-emerald-400">function</span> <span class="text-blue-300">syncNotes</span>() &#123;</p>
                <p><span class="text-slate-500">3</span>    <span class="text-purple-400">return</span> <span class="text-emerald-400">true</span>; <span class="text-slate-500">// Theme looks clean & modern</span></p>
                <p><span class="text-slate-500">4</span>  &#125;</p>
              </div>
            </div>
          </div>

        <!-- ==================================================== -->
        <!-- TAB 3: EDITOR PREFERENCES -->
        <!-- ==================================================== -->
        {:else if currentTab === 'editor'}
          <div class="space-y-6">
            <div>
              <h2 class="text-lg font-bold text-slate-100">Preferensi Editor & Penulisan</h2>
              <p class="text-xs text-slate-400 mt-1">
                Atur ukuran huruf, jenis font koding, dan perilaku buffer CodeMirror.
              </p>
            </div>

            <div class="p-5 rounded-2xl border border-slate-800 bg-slate-900/40 space-y-5">
              <!-- Font Size Selector -->
              <div class="space-y-2">
                <div class="flex items-center justify-between">
                  <label class="text-xs font-semibold text-slate-300 flex items-center space-x-1.5">
                    <Type class="w-3.5 h-3.5 text-blue-400" />
                    <span>Ukuran Font Editor</span>
                  </label>
                  <span class="text-xs font-mono font-bold text-blue-400">{themeStore.fontSize} px</span>
                </div>
                <div class="grid grid-cols-5 gap-2">
                  {#each [12, 13.5, 15, 16, 18] as size}
                    <button 
                      onclick={() => themeStore.setFontSize(size)}
                      class="py-2 rounded-xl text-xs font-mono font-semibold transition-all cursor-pointer {themeStore.fontSize === size ? 'bg-blue-600 text-white shadow-sm' : 'bg-slate-950 border border-slate-800 text-slate-400 hover:text-slate-200'}"
                    >
                      {size}px
                    </button>
                  {/each}
                </div>
              </div>

              <!-- Font Family Dropdown -->
              <div class="space-y-2 pt-2 border-t border-slate-800/80">
                <span class="block text-xs font-semibold text-slate-300">Jenis Font (Font Family)</span>
                <div class="space-y-1.5">
                  {#each fontFamilies as font}
                    <button 
                      onclick={() => themeStore.setFontFamily(font.value)}
                      class="w-full text-left px-3.5 py-2.5 rounded-xl border text-xs flex items-center justify-between transition-colors cursor-pointer {themeStore.fontFamily === font.value ? 'bg-blue-600/15 border-blue-500 text-white font-medium' : 'bg-slate-950 border-slate-800 text-slate-300 hover:border-slate-700'}"
                    >
                      <span>{font.label}</span>
                      {#if themeStore.fontFamily === font.value}
                        <Check class="w-3.5 h-3.5 text-blue-400" />
                      {/if}
                    </button>
                  {/each}
                </div>
              </div>

              <!-- Tab Size & Formatting -->
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2 border-t border-slate-800/80">
                <!-- Tab Size -->
                <div class="space-y-2">
                  <span class="block text-xs font-semibold text-slate-300">Ukuran Tab Indentasi</span>
                  <div class="grid grid-cols-2 gap-2">
                    <button 
                      onclick={() => themeStore.setTabSize(2)}
                      class="py-2 rounded-xl text-xs font-mono transition-all cursor-pointer {themeStore.tabSize === 2 ? 'bg-blue-600 text-white font-bold' : 'bg-slate-950 border border-slate-800 text-slate-400'}"
                    >
                      2 Spasi
                    </button>
                    <button 
                      onclick={() => themeStore.setTabSize(4)}
                      class="py-2 rounded-xl text-xs font-mono transition-all cursor-pointer {themeStore.tabSize === 4 ? 'bg-blue-600 text-white font-bold' : 'bg-slate-950 border border-slate-800 text-slate-400'}"
                    >
                      4 Spasi
                    </button>
                  </div>
                </div>

                <!-- Auto-Save Delay -->
                <div class="space-y-2">
                  <label class="text-xs font-semibold text-slate-300 flex items-center space-x-1.5">
                    <Clock class="w-3.5 h-3.5 text-amber-400" />
                    <span>Auto-Save Buffer Delay</span>
                  </label>
                  <select 
                    value={themeStore.autoSaveDelay}
                    onchange={(e) => themeStore.setAutoSaveDelay(parseInt(e.currentTarget.value, 10))}
                    class="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-100 focus:outline-none focus:border-blue-500 cursor-pointer"
                  >
                    <option value="500">500 ms (Sangat Cepat)</option>
                    <option value="1000">1000 ms (Standar)</option>
                    <option value="2000">2000 ms (Hemat CPU)</option>
                  </select>
                </div>
              </div>
            </div>
          </div>

        <!-- ==================================================== -->
        <!-- TAB 4: ABOUT & UPDATES -->
        <!-- ==================================================== -->
        {:else if currentTab === 'about'}
          <div class="space-y-6">
            <div>
              <h2 class="text-lg font-bold text-slate-100">Tentang Valtera Note</h2>
              <p class="text-xs text-slate-400 mt-1">
                Informasi versi, lisensi open-source, dan status pembaruan perangkat lunak.
              </p>
            </div>

            <!-- Identity Card -->
            <div class="p-6 rounded-2xl border border-slate-800 bg-slate-900/50 flex flex-col sm:flex-row sm:items-center space-y-4 sm:space-y-0 sm:space-x-5">
              <img src="/logo.png" alt="Valtera Note" class="w-16 h-16 rounded-2xl shadow-lg border border-slate-800 flex-shrink-0" />
              <div class="space-y-1 flex-1">
                <div class="flex items-center space-x-2.5">
                  <h3 class="text-base font-bold text-slate-100">Valtera Note</h3>
                  <span class="px-2 py-0.5 text-[10.5px] font-bold rounded-full bg-blue-500/10 text-blue-400 border border-blue-500/20 font-mono">v0.1.7</span>
                </div>
                <p class="text-xs text-slate-400">
                  Ultra-lightweight Notepad, SQL scratchpad, Markdown workspace & Developer Tools.
                </p>
                <p class="text-[11px] text-slate-500">
                  Hak Cipta © 2026 PT Valtera Teknologi Digital. Lisensi MIT.
                </p>
              </div>
            </div>

            <!-- Tech Specs Grid -->
            <div class="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
              <div class="p-3.5 rounded-xl border border-slate-800 bg-slate-900/30 space-y-1">
                <span class="text-[10.5px] text-slate-500 uppercase font-semibold">Backend Engine</span>
                <p class="font-bold text-slate-200">Rust 1.75+</p>
              </div>
              <div class="p-3.5 rounded-xl border border-slate-800 bg-slate-900/30 space-y-1">
                <span class="text-[10.5px] text-slate-500 uppercase font-semibold">Desktop Runtime</span>
                <p class="font-bold text-slate-200">Tauri v2</p>
              </div>
              <div class="p-3.5 rounded-xl border border-slate-800 bg-slate-900/30 space-y-1">
                <span class="text-[10.5px] text-slate-500 uppercase font-semibold">Frontend</span>
                <p class="font-bold text-slate-200">Svelte 5 Runes</p>
              </div>
              <div class="p-3.5 rounded-xl border border-slate-800 bg-slate-900/30 space-y-1">
                <span class="text-[10.5px] text-slate-500 uppercase font-semibold">RAM Usage</span>
                <p class="font-bold text-emerald-400">~38 MB</p>
              </div>
            </div>

            <!-- Update Checker Card -->
            <div class="p-5 rounded-2xl border border-slate-800 bg-slate-900/40 flex items-center justify-between">
              <div>
                <h4 class="text-xs font-bold text-slate-200">Pembaruan Otomatis Terenkripsi</h4>
                <p class="text-[11px] text-slate-400 mt-0.5">
                  Aplikasi otomatis memeriksa update baru saat startup dengan verifikasi signature cryptographic.
                </p>
              </div>
              <button 
                onclick={() => updaterService.checkForUpdates(true)}
                class="px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-700 text-white text-xs font-semibold flex items-center space-x-1.5 transition-colors cursor-pointer shadow-sm"
              >
                <RefreshCw class="w-3.5 h-3.5" />
                <span>Cek Update</span>
              </button>
            </div>
          </div>
        {/if}

      </div>
    </main>
  </div>
</div>
