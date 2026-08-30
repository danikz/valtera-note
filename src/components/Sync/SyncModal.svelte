<script lang="ts">
  import { editorStore } from '../../stores/editorStore.svelte';
  import { ipc } from '../../services/ipc';
  import { 
    X, 
    Database, 
    Server, 
    Key, 
    Mail, 
    Lock, 
    CheckCircle2, 
    AlertCircle, 
    Loader2, 
    HelpCircle, 
    Activity, 
    Copy, 
    ExternalLink, 
    Check, 
    ShieldCheck 
  } from 'lucide-svelte';

  let { isOpen, onClose }: { isOpen: boolean; onClose: () => void } = $props();

  let url = $state(editorStore.supabaseConfig.url || '');
  let anonKey = $state(editorStore.supabaseConfig.anon_key || '');
  let email = $state(editorStore.supabaseConfig.user_email || '');
  let password = $state('');
  let authMode = $state<'login' | 'register'>('login');
  let isTesting = $state(false);
  let isCheckingTable = $state(false);
  let tableStatus = $state<'ready' | 'missing' | 'unknown'>('unknown');
  let isLoading = $state(false);
  let copiedSql = $state(false);
  let statusMessage = $state<{ text: string; type: 'success' | 'error' } | null>(null);

  const SQL_MIGRATION = `-- 1. Create notes table
create table if not exists public.notes (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references auth.users(id) on delete cascade not null,
    title text not null default 'Untitled',
    content text not null default '',
    file_extension text not null default 'md',
    is_pinned boolean not null default false,
    is_deleted boolean not null default false,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Create index
create index if not exists idx_notes_user_id on public.notes(user_id);
create index if not exists idx_notes_updated_at on public.notes(updated_at desc);

-- 3. Enable Row Level Security (RLS)
alter table public.notes enable row level security;

-- 4. Create RLS Policies
create policy "Users can view own notes" on public.notes for select using (auth.uid() = user_id);
create policy "Users can insert own notes" on public.notes for insert with check (auth.uid() = user_id);
create policy "Users can update own notes" on public.notes for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users can delete own notes" on public.notes for delete using (auth.uid() = user_id);`;

  function getProjectRef(): string | null {
    try {
      const parsed = new URL(url);
      const host = parsed.hostname;
      if (host.endsWith('.supabase.co')) {
        return host.replace('.supabase.co', '');
      }
    } catch {
      // ignore
    }
    return null;
  }

  async function checkTable() {
    if (!url || !anonKey) return;
    isCheckingTable = true;
    try {
      const exists = await ipc.checkSupabaseTable(url, anonKey, editorStore.supabaseConfig.access_token || undefined);
      tableStatus = exists ? 'ready' : 'missing';
    } catch {
      tableStatus = 'unknown';
    } finally {
      isCheckingTable = false;
    }
  }

  async function handleTestConnection() {
    if (!url || !anonKey) {
      statusMessage = { 
        text: 'Please provide both Supabase Project URL and Anon API Key first.', 
        type: 'error' 
      };
      return;
    }

    isTesting = true;
    statusMessage = null;

    try {
      const msg = await ipc.testSupabaseConnection(url, anonKey);
      statusMessage = { text: `✅ ${msg}`, type: 'success' };
      await checkTable();
    } catch (e: any) {
      statusMessage = { 
        text: typeof e === 'string' ? e : e?.message || 'Cannot reach Supabase server', 
        type: 'error' 
      };
    } finally {
      isTesting = false;
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

  async function handleSaveConfig() {
    isLoading = true;
    statusMessage = null;
    try {
      await ipc.saveSupabaseConfig(url, anonKey);
      editorStore.supabaseConfig.url = url;
      editorStore.supabaseConfig.anon_key = anonKey;
      editorStore.supabaseConfig.is_configured = !(!url || !anonKey);

      statusMessage = { text: 'Configuration saved locally!', type: 'success' };
      await checkTable();
    } catch (e: any) {
      statusMessage = { text: e?.toString() || 'Failed to save configuration', type: 'error' };
    } finally {
      isLoading = false;
    }
  }

  async function handleAuthSubmit() {
    if (!url || !anonKey || !email || !password) {
      statusMessage = { text: 'Please fill in Project URL, Anon Key, Email, and Password.', type: 'error' };
      return;
    }

    isLoading = true;
    statusMessage = null;

    try {
      if (authMode === 'register') {
        const msg = await ipc.supabaseRegister(url, anonKey, email, password);
        editorStore.supabaseConfig.is_configured = true;
        editorStore.supabaseConfig.user_email = email;
        statusMessage = { text: msg, type: 'success' };
      } else {
        await ipc.supabaseLogin(url, anonKey, email, password);
        editorStore.supabaseConfig.is_configured = true;
        editorStore.supabaseConfig.user_email = email;
        statusMessage = { text: 'Connected and logged in to Supabase successfully!', type: 'success' };
      }
      await checkTable();
    } catch (e: any) {
      statusMessage = { 
        text: typeof e === 'string' ? e : e?.message || 'Authentication failed', 
        type: 'error' 
      };
    } finally {
      isLoading = false;
    }
  }

  $effect(() => {
    if (isOpen && url && anonKey && tableStatus === 'unknown') {
      checkTable();
    }
  });
</script>

{#if isOpen}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-xs p-4 select-none animate-in fade-in duration-150">
    <div class="bg-slate-900 border border-slate-800 rounded-xl shadow-2xl w-full max-w-lg overflow-hidden flex flex-col text-slate-200">
      
      <!-- Modal Header -->
      <div class="h-12 bg-slate-950 border-b border-slate-800 flex items-center justify-between px-4">
        <div class="flex items-center space-x-2 text-sm font-semibold text-slate-100">
          <Database class="w-4 h-4 text-emerald-400" />
          <span>Supabase Cloud Sync Settings</span>
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
              <span class="font-medium">Tabel <code>notes</code> Siap & RLS Aktif</span>
            </div>
            <button 
              onclick={checkTable}
              disabled={isCheckingTable}
              class="text-[11px] underline hover:text-emerald-200"
            >
              {isCheckingTable ? 'Checking...' : 'Re-check'}
            </button>
          </div>
        {:else if tableStatus === 'missing'}
          <div class="p-3 rounded-lg bg-amber-950/50 border border-amber-700/70 text-amber-200 space-y-2">
            <div class="flex items-center justify-between font-semibold text-amber-300">
              <div class="flex items-center space-x-1.5">
                <AlertCircle class="w-4 h-4 text-amber-400" />
                <span>Tabel <code>notes</code> Belum Ditemukan di Supabase</span>
              </div>
              <button 
                onclick={checkTable}
                disabled={isCheckingTable}
                class="text-[11px] underline text-amber-300 hover:text-white"
              >
                {isCheckingTable ? 'Checking...' : 'Re-check'}
              </button>
            </div>
            <p class="text-[11px] text-amber-200/80 leading-relaxed">
              Jalankan skrip DDL SQL berikut di SQL Editor Supabase untuk membuat tabel dan mengaktifkan Row-Level Security:
            </p>
            <div class="flex items-center space-x-2 pt-1">
              <button 
                onclick={handleCopySql}
                class="flex items-center space-x-1 px-2.5 py-1 rounded bg-amber-500 hover:bg-amber-400 text-slate-950 font-semibold transition-colors"
              >
                {#if copiedSql}
                  <Check class="w-3.5 h-3.5" />
                  <span>Copied!</span>
                {:else}
                  <Copy class="w-3.5 h-3.5" />
                  <span>Copy SQL Migration</span>
                {/if}
              </button>

              <button 
                onclick={handleOpenSqlEditor}
                class="flex items-center space-x-1 px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-200 font-medium transition-colors"
              >
                <ExternalLink class="w-3.5 h-3.5" />
                <span>Buka SQL Editor</span>
              </button>
            </div>
          </div>
        {/if}

        <!-- Server Configuration -->
        <div class="space-y-3 bg-slate-950/60 p-3.5 rounded-lg border border-slate-800/70">
          <div class="flex items-center justify-between">
            <span class="font-semibold text-slate-200">1. Supabase Project Credentials</span>
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

          <!-- Anon Public Key -->
          <div class="space-y-1">
            <label for="key-input" class="block text-slate-400">Anon Public API Key</label>
            <div class="relative">
              <Key class="w-3.5 h-3.5 absolute left-3 top-2.5 text-slate-500" />
              <input 
                id="key-input"
                type="password" 
                bind:value={anonKey} 
                placeholder="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
                class="w-full bg-slate-950 border border-slate-800 rounded-lg pl-9 pr-3 py-2 text-xs text-slate-200 placeholder-slate-600 focus:outline-none focus:border-emerald-500 font-mono"
              />
            </div>
          </div>
        </div>

        <!-- Auth Section -->
        <div class="space-y-3 bg-slate-950/60 p-3.5 rounded-lg border border-slate-800/70">
          <div class="flex items-center justify-between">
            <span class="font-semibold text-slate-200">2. Supabase User Authentication</span>
            <!-- Tab switch login/register -->
            <div class="flex rounded bg-slate-900 p-0.5 border border-slate-800">
              <button 
                onclick={() => (authMode = 'login')}
                class="px-2.5 py-0.5 rounded text-[11px] font-medium transition-colors {authMode === 'login' ? 'bg-emerald-600 text-white shadow-xs' : 'text-slate-400 hover:text-slate-200'}"
              >
                Login
              </button>
              <button 
                onclick={() => (authMode = 'register')}
                class="px-2.5 py-0.5 rounded text-[11px] font-medium transition-colors {authMode === 'register' ? 'bg-emerald-600 text-white shadow-xs' : 'text-slate-400 hover:text-slate-200'}"
              >
                Sign Up
              </button>
            </div>
          </div>

          <div class="space-y-1">
            <label for="email-input" class="block text-slate-400">Email Address</label>
            <div class="relative">
              <Mail class="w-3.5 h-3.5 absolute left-3 top-2.5 text-slate-500" />
              <input 
                id="email-input"
                type="email" 
                bind:value={email} 
                placeholder="user@example.com"
                class="w-full bg-slate-950 border border-slate-800 rounded-lg pl-9 pr-3 py-2 text-xs text-slate-200 placeholder-slate-600 focus:outline-none focus:border-emerald-500"
              />
            </div>
          </div>

          <div class="space-y-1">
            <label for="password-input" class="block text-slate-400">Password</label>
            <div class="relative">
              <Lock class="w-3.5 h-3.5 absolute left-3 top-2.5 text-slate-500" />
              <input 
                id="password-input"
                type="password" 
                bind:value={password} 
                placeholder="••••••••"
                class="w-full bg-slate-950 border border-slate-800 rounded-lg pl-9 pr-3 py-2 text-xs text-slate-200 placeholder-slate-600 focus:outline-none focus:border-emerald-500"
              />
            </div>
          </div>
        </div>

        <!-- Help Guide Info -->
        <div class="p-3 bg-emerald-950/20 border border-emerald-900/30 rounded-lg text-slate-400 space-y-1 text-[11px] leading-relaxed">
          <div class="flex items-center space-x-1.5 text-emerald-400 font-semibold">
            <HelpCircle class="w-3.5 h-3.5" />
            <span>Petunjuk Supabase RLS:</span>
          </div>
          <p>1. <strong>Project URL & Anon Key:</strong> Buka <strong>Supabase Dashboard</strong> ➡️ <strong>Project Settings</strong> ➡️ <strong>API</strong>.</p>
          <p>2. <strong>Row-Level Security:</strong> Dengan RLS aktif, catatan Anda hanya bisa dibaca dan diubah oleh akun Anda sendiri.</p>
        </div>

      </div>

      <!-- Modal Footer -->
      <div class="h-14 bg-slate-950 border-t border-slate-800 flex items-center justify-between px-5 text-xs">
        <button 
          onclick={handleSaveConfig}
          disabled={isLoading}
          class="px-3.5 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 font-medium transition-colors"
        >
          Save Config Only
        </button>

        <div class="flex items-center space-x-2">
          <button 
            onclick={onClose}
            class="px-3.5 py-1.5 rounded-lg text-slate-400 hover:text-slate-200 hover:bg-slate-900 transition-colors"
          >
            Cancel
          </button>

          <button 
            onclick={handleAuthSubmit}
            disabled={isLoading}
            class="flex items-center space-x-1.5 px-4 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white font-medium shadow-md transition-colors"
          >
            {#if isLoading}
              <Loader2 class="w-3.5 h-3.5 animate-spin" />
            {/if}
            <span>{authMode === 'register' ? 'Sign Up & Connect' : 'Login & Connect'}</span>
          </button>
        </div>
      </div>

    </div>
  </div>
{/if}
