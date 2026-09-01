<script lang="ts">
  import { untrack } from 'svelte';
  import { editorStore } from '../../stores/editorStore.svelte';
  import { ipc } from '../../services/ipc';
  import { 
    X, 
    Database, 
    Server, 
    Key, 
    CheckCircle2, 
    AlertCircle, 
    Loader2, 
    HelpCircle, 
    Activity, 
    Copy, 
    ExternalLink, 
    Check, 
    ShieldCheck, 
    Zap,
    Wrench,
    RefreshCw,
    Eye,
    EyeOff,
    CheckCheck
  } from 'lucide-svelte';

  let { isOpen, onClose }: { isOpen: boolean; onClose: () => void } = $props();

  let url = $state(editorStore.supabaseConfig.url || '');
  let anonKey = $state(editorStore.supabaseConfig.anon_key || '');
  let showKey = $state(false);
  let isTesting = $state(false);
  let isCheckingTable = $state(false);
  let isAutoCreating = $state(false);
  let showAutoCreateInput = $state(false);
  let managementToken = $state('');
  let tableStatus = $state<'ready' | 'missing' | 'unknown'>('unknown');
  let isLoading = $state(false);
  let copiedSql = $state(false);
  let statusMessage = $state<{ text: string; type: 'success' | 'error' } | null>(null);

  const SQL_MIGRATION = `-- 1. Create notes table
create table if not exists public.notes (
    id uuid default gen_random_uuid() primary key,
    title text not null default 'Untitled',
    content text not null default '',
    file_extension text not null default 'md',
    is_pinned boolean not null default false,
    is_deleted boolean not null default false,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Create indices
create index if not exists idx_notes_updated_at on public.notes(updated_at desc);

-- 3. Enable RLS and allow full access with API Key
alter table public.notes enable row level security;
create policy "Allow API access" on public.notes for all using (true) with check (true);`;

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

  async function handleTestConnection() {
    const cleanUrl = url.trim();
    const cleanKey = anonKey.trim();

    if (!cleanUrl || !cleanKey) {
      statusMessage = { 
        text: 'Masukkan Project URL dan API Key Supabase Anda terlebih dahulu.', 
        type: 'error' 
      };
      return;
    }

    isTesting = true;
    statusMessage = null;

    try {
      const msg = await ipc.testSupabaseConnection(cleanUrl, cleanKey);
      statusMessage = { text: `✅ ${msg}`, type: 'success' };
      await checkTable();
    } catch (e: any) {
      statusMessage = { 
        text: typeof e === 'string' ? e : e?.message || 'Gagal menghubungi server Supabase', 
        type: 'error' 
      };
    } finally {
      isTesting = false;
    }
  }

  async function handleAutoCreateTable() {
    const cleanUrl = url.trim();
    const cleanKey = anonKey.trim();
    const tokenToUse = managementToken.trim() || cleanKey;

    if (!cleanUrl || !tokenToUse) {
      statusMessage = { text: 'Masukkan Access Token atau Service Key untuk membuat tabel otomatis.', type: 'error' };
      return;
    }

    isAutoCreating = true;
    statusMessage = null;

    try {
      const msg = await ipc.autoCreateSupabaseTable(cleanUrl, cleanKey, tokenToUse);
      statusMessage = { text: `✅ ${msg}`, type: 'success' };
      showAutoCreateInput = false;
      await checkTable();
    } catch (e: any) {
      statusMessage = { 
        text: typeof e === 'string' ? e : e?.message || 'Gagal membuat tabel secara otomatis. Gunakan Access Token akun Supabase Anda.', 
        type: 'error' 
      };
    } finally {
      isAutoCreating = false;
    }
  }

  async function handleCopySql() {
    try {
      await navigator.clipboard.writeText(SQL_MIGRATION);
      copiedSql = true;
      setTimeout(() => { copiedSql = false; }, 2000);
    } catch (e) {
      console.warn('Copy failed:', e);
    }
  }

  function handleOpenSqlEditor() {
    const ref = getProjectRef();
    const targetUrl = ref 
      ? `https://supabase.com/dashboard/project/${ref}/sql/new` 
      : 'https://supabase.com/dashboard';
    window.open(targetUrl, '_blank');
  }

  async function handleConnectAndSave() {
    const cleanUrl = url.trim().replace(/\/+$/, '');
    const cleanKey = anonKey.trim();

    if (!cleanUrl || !cleanKey) {
      statusMessage = { text: 'Harap isi Project URL dan API Key.', type: 'error' };
      return;
    }

    isLoading = true;
    statusMessage = null;

    try {
      await ipc.saveSupabaseConfig(cleanUrl, cleanKey);
      editorStore.setSupabaseConfig({
        url: cleanUrl,
        anon_key: cleanKey,
        is_configured: true
      });
      url = cleanUrl;
      anonKey = cleanKey;

      await checkTable();
      await editorStore.autoSyncAll();
      statusMessage = { text: '✅ Tersimpan & Tersambung! Catatan Anda otomatis tersinkronisasi ke Supabase Cloud.', type: 'success' };
    } catch (e: any) {
      statusMessage = { text: e?.toString() || 'Gagal menyimpan konfigurasi', type: 'error' };
    } finally {
      isLoading = false;
    }
  }

  async function handleForceSync() {
    isLoading = true;
    try {
      await editorStore.autoSyncAll();
      statusMessage = { text: `✅ Berhasil sinkronisasi otomatis! (${editorStore.lastSyncedAt})`, type: 'success' };
    } catch (e: any) {
      statusMessage = { text: 'Gagal sinkronisasi: ' + (e?.message || e), type: 'error' };
    } finally {
      isLoading = false;
    }
  }

  async function handleDisconnect() {
    await ipc.saveSupabaseConfig('', '');
    editorStore.setSupabaseConfig({
      url: '',
      anon_key: '',
      is_configured: false
    });
    url = '';
    anonKey = '';
    tableStatus = 'unknown';
    statusMessage = { text: 'Koneksi Supabase diputuskan. Bekerja dalam mode offline.', type: 'success' };
  }

  let wasOpen = false;

  async function loadInitialConfig() {
    try {
      const stored = await ipc.getSupabaseConfig();
      if (stored && (stored.url || stored.anon_key)) {
        if (stored.url) url = stored.url;
        if (stored.anon_key) anonKey = stored.anon_key;
      }
      const cleanUrl = url.trim();
      const cleanKey = anonKey.trim();
      if (cleanUrl && cleanKey && !isCheckingTable) {
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
    } catch (e) {
      console.warn('Error loading Supabase config into modal:', e);
    }
  }

  $effect(() => {
    const open = isOpen;
    untrack(() => {
      if (open && !wasOpen) {
        wasOpen = true;
        url = editorStore.supabaseConfig.url || '';
        anonKey = editorStore.supabaseConfig.anon_key || '';
        setTimeout(() => {
          loadInitialConfig();
        }, 0);
      } else if (!open) {
        wasOpen = false;
      }
    });
  });
</script>

{#if isOpen}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-xs p-4 select-none animate-in fade-in duration-150">
    <div class="bg-slate-900 border border-slate-800 rounded-xl shadow-2xl w-full max-w-lg overflow-hidden flex flex-col text-slate-200">
      
      <!-- Modal Header -->
      <div class="h-12 bg-slate-950 border-b border-slate-800 flex items-center justify-between px-4">
        <div class="flex items-center space-x-2 text-sm font-semibold text-slate-100">
          <Database class="w-4 h-4 text-emerald-400" />
          <span>Supabase API Sync Settings</span>
        </div>
        <button 
          onclick={onClose}
          class="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-slate-100 transition-colors"
        >
          <X class="w-4 h-4" />
        </button>
      </div>

      <!-- Modal Body -->
      <div class="p-5 space-y-4 text-xs max-h-[75vh] overflow-y-auto">
        <!-- Active Connection Card (Shown when configured) -->
        {#if editorStore.supabaseConfig.is_configured}
          <div class="p-3 rounded-lg bg-emerald-950/40 border border-emerald-700/60 flex items-center justify-between">
            <div class="flex items-center space-x-2.5">
              <span class="flex h-2.5 w-2.5 relative">
                <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                <span class="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500"></span>
              </span>
              <div class="flex flex-col">
                <div class="flex items-center space-x-1.5">
                  <span class="font-semibold text-emerald-300 text-xs">Supabase Terhubung & Aktif</span>
                  <span class="px-1.5 py-0.2 rounded bg-emerald-900/60 text-emerald-300 text-[10px] font-mono border border-emerald-700/40">Synced</span>
                </div>
                {#if editorStore.supabaseConfig.url}
                  <span class="text-[11px] text-emerald-200/70 font-mono truncate max-w-xs">{editorStore.supabaseConfig.url}</span>
                {/if}
              </div>
            </div>
            <div class="text-right">
              <span class="text-[10px] text-emerald-400/80 font-mono block">
                {editorStore.lastSyncedAt ? `Sync ${editorStore.lastSyncedAt}` : 'Auto-Sync Ready'}
              </span>
            </div>
          </div>
        {/if}

        <!-- Status Message Banner -->
        {#if statusMessage}
          <div class="p-3 rounded-lg flex items-start space-x-2.5 {statusMessage.type === 'success' ? 'bg-emerald-950/70 border border-emerald-800/80 text-emerald-300' : 'bg-red-950/70 border border-red-800/80 text-red-300'}">
            {#if statusMessage.type === 'success'}
              <CheckCircle2 class="w-4 h-4 flex-shrink-0 mt-0.5" />
            {:else}
              <AlertCircle class="w-4 h-4 flex-shrink-0 mt-0.5" />
            {/if}
            <span class="font-medium leading-relaxed">{statusMessage.text}</span>
          </div>
        {/if}

        <!-- Table Status Indicator Banner -->
        {#if tableStatus === 'ready'}
          <div class="p-2.5 rounded-lg bg-emerald-950/40 border border-emerald-700/60 flex items-center justify-between text-emerald-300">
            <div class="flex items-center space-x-2">
              <ShieldCheck class="w-4 h-4 text-emerald-400" />
              <span class="font-medium">Tabel <code>notes</code> Siap di Database</span>
            </div>
            <button 
              onclick={checkTable}
              disabled={isCheckingTable}
              class="flex items-center space-x-1 px-2 py-0.5 rounded bg-emerald-900/60 hover:bg-emerald-800/80 border border-emerald-700/60 text-emerald-200 text-[11px] font-medium transition-colors disabled:opacity-50 cursor-pointer"
            >
              <RefreshCw class="w-2.5 h-2.5 {isCheckingTable ? 'animate-spin' : ''}" />
              <span>{isCheckingTable ? 'Memeriksa...' : 'Re-check'}</span>
            </button>
          </div>
        {:else if tableStatus === 'missing'}
          <div class="p-3.5 rounded-lg bg-amber-950/50 border border-amber-700/70 text-amber-200 space-y-2.5">
            <div class="flex items-center justify-between font-semibold text-amber-300">
              <div class="flex items-center space-x-1.5">
                <AlertCircle class="w-4 h-4 text-amber-400" />
                <span>Tabel <code>notes</code> Belum Ada di Supabase</span>
              </div>
              <button 
                onclick={checkTable}
                disabled={isCheckingTable}
                class="flex items-center space-x-1 px-2 py-0.5 rounded bg-amber-900/60 hover:bg-amber-800/80 border border-amber-700/60 text-amber-200 text-[11px] font-medium transition-colors disabled:opacity-50 cursor-pointer"
              >
                <RefreshCw class="w-2.5 h-2.5 {isCheckingTable ? 'animate-spin' : ''}" />
                <span>{isCheckingTable ? 'Memeriksa...' : 'Re-check'}</span>
              </button>
            </div>
            
            <p class="text-[11px] text-amber-200/80 leading-relaxed">
              Anda bisa membuat tabel secara otomatis dalam 1-klik menggunakan Access Token, atau salin skrip SQL:
            </p>

            {#if showAutoCreateInput}
              <div class="space-y-2 pt-1 bg-amber-950/70 p-2.5 rounded border border-amber-800/80">
                <label for="mgmt-token" class="block text-[11px] text-amber-300 font-medium">
                  Supabase Access Token (<a href="https://supabase.com/dashboard/account/tokens" target="_blank" class="underline text-amber-200 hover:text-white">Dapatkan di sini</a>)
                </label>
                <div class="flex items-center space-x-2">
                  <input 
                    id="mgmt-token"
                    type="password" 
                    bind:value={managementToken}
                    placeholder="sbp_xxxxxxxxxxxx..."
                    class="flex-1 bg-slate-950 border border-amber-700 rounded px-2.5 py-1 text-xs text-white placeholder-slate-600 focus:outline-none"
                  />
                  <button 
                    onclick={handleAutoCreateTable}
                    disabled={isAutoCreating}
                    class="flex items-center space-x-1 px-3 py-1 bg-emerald-600 hover:bg-emerald-500 text-white rounded font-medium text-xs disabled:opacity-50"
                  >
                    {#if isAutoCreating}
                      <Loader2 class="w-3 h-3 animate-spin" />
                    {:else}
                      <Zap class="w-3 h-3" />
                    {/if}
                    <span>Eksekusi</span>
                  </button>
                </div>
              </div>
            {/if}

            <div class="flex items-center space-x-2 pt-1">
              <button 
                onclick={() => (showAutoCreateInput = !showAutoCreateInput)}
                class="flex items-center space-x-1 px-2.5 py-1 rounded bg-amber-500 hover:bg-amber-400 text-slate-950 font-semibold transition-colors"
              >
                <Wrench class="w-3.5 h-3.5" />
                <span>{showAutoCreateInput ? 'Tutup Auto-Setup' : '⚡ Buat Otomatis (1-Klik)'}</span>
              </button>

              <button 
                onclick={handleCopySql}
                class="flex items-center space-x-1 px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-200 font-medium transition-colors"
              >
                {#if copiedSql}
                  <Check class="w-3.5 h-3.5" />
                  <span>Copied!</span>
                {:else}
                  <Copy class="w-3.5 h-3.5" />
                  <span>Copy SQL</span>
                {/if}
              </button>

              <button 
                onclick={handleOpenSqlEditor}
                class="flex items-center space-x-1 px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-200 font-medium transition-colors"
              >
                <ExternalLink class="w-3.5 h-3.5" />
                <span>SQL Editor</span>
              </button>
            </div>
          </div>
        {/if}

        <!-- Credentials Form -->
        <div class="space-y-3 bg-slate-950/60 p-3.5 rounded-lg border border-slate-800/70">
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-2">
              <span class="font-semibold text-slate-200">Supabase API Credentials</span>
              {#if editorStore.supabaseConfig.is_configured}
                <span class="px-1.5 py-0.2 rounded bg-emerald-950 text-emerald-400 border border-emerald-800/50 text-[10px]">Tersimpan</span>
              {/if}
            </div>
            <button 
              onclick={handleTestConnection}
              disabled={isTesting}
              class="flex items-center space-x-1 px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-emerald-400 font-medium transition-colors disabled:opacity-50"
            >
              {#if isTesting}
                <Loader2 class="w-3 h-3 animate-spin" />
              {:else}
                <Activity class="w-3 h-3" />
              {/if}
              <span>{isTesting ? 'Testing...' : 'Test Connection'}</span>
            </button>
          </div>

          <!-- Project URL -->
          <div class="space-y-1">
            <label for="url-input" class="block text-slate-400">Project URL</label>
            <div class="relative">
              <Server class="w-3.5 h-3.5 absolute left-3 top-2.5 text-slate-500" />
              <input 
                id="url-input"
                type="text" 
                bind:value={url} 
                placeholder="https://xyzcompany.supabase.co"
                class="w-full bg-slate-950 border border-slate-800 rounded-lg pl-9 pr-3 py-2 text-xs text-slate-200 placeholder-slate-600 focus:outline-none focus:border-emerald-500 font-mono"
              />
            </div>
          </div>

          <!-- Anon Public Key with Eye Toggle -->
          <div class="space-y-1">
            <label for="key-input" class="block text-slate-400">API Key (anon public atau service role)</label>
            <div class="relative flex items-center">
              <Key class="w-3.5 h-3.5 absolute left-3 text-slate-500 pointer-events-none" />
              <input 
                id="key-input"
                type={showKey ? 'text' : 'password'} 
                bind:value={anonKey} 
                placeholder="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
                class="w-full bg-slate-950 border border-slate-800 rounded-lg pl-9 pr-9 py-2 text-xs text-slate-200 placeholder-slate-600 focus:outline-none focus:border-emerald-500 font-mono"
              />
              <button 
                type="button"
                onclick={() => (showKey = !showKey)}
                class="absolute right-2.5 text-slate-500 hover:text-slate-200 p-1 rounded transition-colors"
                title={showKey ? "Sembunyikan API Key" : "Lihat API Key"}
              >
                {#if showKey}
                  <EyeOff class="w-3.5 h-3.5" />
                {:else}
                  <Eye class="w-3.5 h-3.5" />
                {/if}
              </button>
            </div>
          </div>
        </div>

        <!-- Help Guide Info -->
        <div class="p-3 bg-emerald-950/20 border border-emerald-900/30 rounded-lg text-slate-400 space-y-1.5 text-[11px] leading-relaxed">
          <div class="flex items-center space-x-1.5 text-emerald-400 font-semibold">
            <HelpCircle class="w-3.5 h-3.5" />
            <span>Auto-Sync Aktif Otomatis:</span>
          </div>
          <p>• Setelah tersambung, <strong>setiap catatan yang Anda ketik akan otomatis tersinkronisasi ke cloud</strong> dalam 1.5 detik tanpa perlu klik sync manual.</p>
          <p>• Aplikasi juga otomatis menarik pembaruan cloud secara berkala di background setiap 30 detik.</p>
        </div>

      </div>

      <!-- Modal Footer -->
      <div class="h-14 bg-slate-950 border-t border-slate-800 flex items-center justify-between px-5 text-xs">
        {#if editorStore.supabaseConfig.is_configured}
          <div class="flex items-center space-x-2">
            <button 
              onclick={handleDisconnect}
              class="px-3 py-1.5 rounded-lg bg-red-950/60 hover:bg-red-900/80 border border-red-800/60 text-red-300 font-medium transition-colors"
            >
              Disconnect
            </button>
            <button 
              onclick={handleForceSync}
              disabled={isLoading || editorStore.isSyncing}
              class="flex items-center space-x-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-200 font-medium transition-colors disabled:opacity-50"
            >
              <RefreshCw class="w-3 h-3 {editorStore.isSyncing ? 'animate-spin text-blue-400' : 'text-slate-400'}" />
              <span>{editorStore.isSyncing ? 'Syncing...' : 'Sync Now'}</span>
            </button>
          </div>
        {:else}
          <div></div>
        {/if}

        <div class="flex items-center space-x-2">
          <button 
            onclick={onClose}
            class="px-3.5 py-1.5 rounded-lg text-slate-400 hover:text-slate-200 hover:bg-slate-900 transition-colors"
          >
            Tutup
          </button>

          <button 
            onclick={handleConnectAndSave}
            disabled={isLoading}
            class="flex items-center space-x-1.5 px-4 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white font-medium shadow-md transition-colors"
          >
            {#if isLoading}
              <Loader2 class="w-3.5 h-3.5 animate-spin" />
            {:else}
              <Zap class="w-3.5 h-3.5" />
            {/if}
            <span>Connect & Sync</span>
          </button>
        </div>
      </div>

    </div>
  </div>
{/if}
