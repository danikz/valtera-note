<script lang="ts">
  import { editorStore } from '../../stores/editorStore.svelte';
  import { ipc } from '../../services/ipc';
  import { 
    X, 
    Cloud, 
    Server, 
    Key, 
    Mail, 
    Lock, 
    User, 
    CheckCircle2, 
    AlertCircle, 
    Loader2, 
    Sparkles, 
    HelpCircle, 
    Activity 
  } from 'lucide-svelte';

  let { isOpen, onClose }: { isOpen: boolean; onClose: () => void } = $props();

  let endpoint = $state(editorStore.appwriteConfig.endpoint || 'https://cloud.appwrite.io/v1');
  let projectId = $state(editorStore.appwriteConfig.project_id || '');
  let databaseId = $state(editorStore.appwriteConfig.database_id || 'valtera_note_db');
  let email = $state('');
  let password = $state('');
  let name = $state('');
  let authMode = $state<'login' | 'register'>('login');
  let isTesting = $state(false);
  let isLoading = $state(false);
  let statusMessage = $state<{ text: string; type: 'success' | 'error' } | null>(null);

  async function handleTestConnection() {
    if (!endpoint || !projectId) {
      statusMessage = { 
        text: 'Please provide both Appwrite API Endpoint and Project ID first.', 
        type: 'error' 
      };
      return;
    }

    isTesting = true;
    statusMessage = null;

    try {
      const msg = await ipc.testAppwriteConnection(endpoint, projectId);
      statusMessage = { text: `✅ ${msg}`, type: 'success' };
    } catch (e: any) {
      statusMessage = { 
        text: typeof e === 'string' ? e : e?.message || 'Cannot reach Appwrite server', 
        type: 'error' 
      };
    } finally {
      isTesting = false;
    }
  }

  async function handleSaveConfig() {
    isLoading = true;
    statusMessage = null;
    try {
      await ipc.saveAppwriteConfig(endpoint, projectId, databaseId);
      editorStore.appwriteConfig.endpoint = endpoint;
      editorStore.appwriteConfig.project_id = projectId;
      editorStore.appwriteConfig.database_id = databaseId;
      editorStore.appwriteConfig.is_configured = !(!endpoint || !projectId);

      statusMessage = { text: 'Configuration saved locally!', type: 'success' };
    } catch (e: any) {
      statusMessage = { text: e?.toString() || 'Failed to save configuration', type: 'error' };
    } finally {
      isLoading = false;
    }
  }

  async function handleAuthSubmit() {
    if (!endpoint || !projectId || !email || !password) {
      statusMessage = { text: 'Please fill in Endpoint, Project ID, Email, and Password.', type: 'error' };
      return;
    }

    isLoading = true;
    statusMessage = null;

    try {
      if (authMode === 'register') {
        await ipc.appwriteRegister(endpoint, projectId, email, password, name);
        editorStore.appwriteConfig.is_configured = true;
        editorStore.appwriteConfig.user_email = email;
        statusMessage = { text: 'Account created and connected to Appwrite successfully!', type: 'success' };
      } else {
        await ipc.appwriteLogin(endpoint, projectId, email, password);
        editorStore.appwriteConfig.is_configured = true;
        editorStore.appwriteConfig.user_email = email;
        statusMessage = { text: 'Connected and logged in to Appwrite successfully!', type: 'success' };
      }
    } catch (e: any) {
      statusMessage = { 
        text: typeof e === 'string' ? e : e?.message || 'Authentication failed', 
        type: 'error' 
      };
    } finally {
      isLoading = false;
    }
  }
</script>

{#if isOpen}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-xs p-4 select-none animate-in fade-in duration-150">
    <div class="bg-slate-900 border border-slate-800 rounded-xl shadow-2xl w-full max-w-lg overflow-hidden flex flex-col text-slate-200">
      
      <!-- Modal Header -->
      <div class="h-12 bg-slate-950 border-b border-slate-800 flex items-center justify-between px-4">
        <div class="flex items-center space-x-2 text-sm font-semibold text-slate-100">
          <Cloud class="w-4 h-4 text-pink-500" />
          <span>Appwrite Cloud Sync Settings</span>
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

        <!-- Server Configuration -->
        <div class="space-y-3 bg-slate-950/60 p-3.5 rounded-lg border border-slate-800/70">
          <div class="flex items-center justify-between">
            <span class="font-semibold text-slate-200">1. Appwrite Server Endpoint</span>
            <button 
              onclick={handleTestConnection}
              disabled={isTesting}
              class="flex items-center space-x-1 px-2.5 py-1 rounded bg-slate-800 hover:bg-slate-700 text-blue-400 font-medium transition-colors disabled:opacity-50"
            >
              {#if isTesting}
                <Loader2 class="w-3 h-3 animate-spin" />
              {:else}
                <Activity class="w-3 h-3" />
              {/if}
              <span>{isTesting ? 'Testing...' : 'Test Connection'}</span>
            </button>
          </div>

          <!-- Endpoint URL -->
          <div class="space-y-1">
            <label for="endpoint-input" class="block text-slate-400">Endpoint URL (Cloud or Self-Hosted)</label>
            <div class="relative">
              <Server class="w-3.5 h-3.5 absolute left-3 top-2.5 text-slate-500" />
              <input 
                id="endpoint-input"
                type="text" 
                bind:value={endpoint} 
                placeholder="https://cloud.appwrite.io/v1 or http://localhost/v1"
                class="w-full bg-slate-950 border border-slate-800 rounded-lg pl-9 pr-3 py-2 text-xs text-slate-200 placeholder-slate-600 focus:outline-none focus:border-pink-500 font-mono"
              />
            </div>
          </div>

          <!-- Project ID -->
          <div class="space-y-1">
            <label for="project-id-input" class="block text-slate-400">Project ID (from Appwrite Console)</label>
            <div class="relative">
              <Key class="w-3.5 h-3.5 absolute left-3 top-2.5 text-slate-500" />
              <input 
                id="project-id-input"
                type="text" 
                bind:value={projectId} 
                placeholder="e.g. 660f... or valtera-note"
                class="w-full bg-slate-950 border border-slate-800 rounded-lg pl-9 pr-3 py-2 text-xs text-slate-200 placeholder-slate-600 focus:outline-none focus:border-pink-500 font-mono"
              />
            </div>
          </div>
        </div>

        <!-- Auth Section -->
        <div class="space-y-3 bg-slate-950/60 p-3.5 rounded-lg border border-slate-800/70">
          <div class="flex items-center justify-between">
            <span class="font-semibold text-slate-200">2. Account Authentication</span>
            <!-- Tab switch login/register -->
            <div class="flex rounded bg-slate-900 p-0.5 border border-slate-800">
              <button 
                onclick={() => (authMode = 'login')}
                class="px-2.5 py-0.5 rounded text-[11px] font-medium transition-colors {authMode === 'login' ? 'bg-pink-600 text-white shadow-xs' : 'text-slate-400 hover:text-slate-200'}"
              >
                Login
              </button>
              <button 
                onclick={() => (authMode = 'register')}
                class="px-2.5 py-0.5 rounded text-[11px] font-medium transition-colors {authMode === 'register' ? 'bg-pink-600 text-white shadow-xs' : 'text-slate-400 hover:text-slate-200'}"
              >
                Create Account
              </button>
            </div>
          </div>

          {#if authMode === 'register'}
            <div class="space-y-1">
              <label for="name-input" class="block text-slate-400">Full Name</label>
              <div class="relative">
                <User class="w-3.5 h-3.5 absolute left-3 top-2.5 text-slate-500" />
                <input 
                  id="name-input"
                  type="text" 
                  bind:value={name} 
                  placeholder="Your Name"
                  class="w-full bg-slate-950 border border-slate-800 rounded-lg pl-9 pr-3 py-2 text-xs text-slate-200 placeholder-slate-600 focus:outline-none focus:border-pink-500"
                />
              </div>
            </div>
          {/if}

          <div class="space-y-1">
            <label for="email-input" class="block text-slate-400">Email Address</label>
            <div class="relative">
              <Mail class="w-3.5 h-3.5 absolute left-3 top-2.5 text-slate-500" />
              <input 
                id="email-input"
                type="email" 
                bind:value={email} 
                placeholder="user@example.com"
                class="w-full bg-slate-950 border border-slate-800 rounded-lg pl-9 pr-3 py-2 text-xs text-slate-200 placeholder-slate-600 focus:outline-none focus:border-pink-500"
              />
            </div>
          </div>

          <div class="space-y-1">
            <label for="password-input" class="block text-slate-400">Password (min. 8 characters)</label>
            <div class="relative">
              <Lock class="w-3.5 h-3.5 absolute left-3 top-2.5 text-slate-500" />
              <input 
                id="password-input"
                type="password" 
                bind:value={password} 
                placeholder="••••••••"
                class="w-full bg-slate-950 border border-slate-800 rounded-lg pl-9 pr-3 py-2 text-xs text-slate-200 placeholder-slate-600 focus:outline-none focus:border-pink-500"
              />
            </div>
          </div>
        </div>

        <!-- Help Guide Info -->
        <div class="p-3 bg-blue-950/30 border border-blue-900/40 rounded-lg text-slate-400 space-y-1 text-[11px] leading-relaxed">
          <div class="flex items-center space-x-1.5 text-blue-400 font-semibold">
            <HelpCircle class="w-3.5 h-3.5" />
            <span>Petunjuk Koneksi Appwrite:</span>
          </div>
          <p>1. <strong>Endpoint:</strong> Gunakan <code>https://cloud.appwrite.io/v1</code> (Appwrite Cloud) atau <code>http://localhost/v1</code> (Docker lokal).</p>
          <p>2. <strong>Project ID:</strong> Buat Project di Appwrite Console dan salin Project ID nya ke kolom di atas.</p>
          <p>3. <strong>Web Platform (Penting):</strong> Di Appwrite Console ➡️ Project Settings ➡️ <strong>Add Platform (Web App)</strong> ➡️ Masukkan Hostname: <code>localhost</code>.</p>
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
            class="flex items-center space-x-1.5 px-4 py-1.5 rounded-lg bg-pink-600 hover:bg-pink-500 disabled:opacity-50 text-white font-medium shadow-md transition-colors"
          >
            {#if isLoading}
              <Loader2 class="w-3.5 h-3.5 animate-spin" />
            {/if}
            <span>{authMode === 'register' ? 'Register & Connect' : 'Login & Connect'}</span>
          </button>
        </div>
      </div>

    </div>
  </div>
{/if}
