<script lang="ts">
  import { onMount, onDestroy, tick } from 'svelte';
  import {
    Terminal as TerminalIcon,
    Plus,
    Trash2,
    Loader2,
    Plug,
    Eye,
    EyeOff,
    Lock,
    AlertTriangle,
    Square
  } from 'lucide-svelte';
  import { Terminal } from '@xterm/xterm';
  import { FitAddon } from '@xterm/addon-fit';
  import { listen, type UnlistenFn } from '@tauri-apps/api/event';
  import { ipc } from '../../services/ipc';
  import { copyText } from '../../utils/clipboard';
  import { sshStore, consumeSshConnectRequest } from '../../stores/sshStore.svelte';
  import '@xterm/xterm/css/xterm.css';

  interface SshConnection {
    id: string;
    label: string;
    payload: string; // ciphertext enc:v1:...
    updated_at: string;
  }

  interface SshPayload {
    host: string;
    port: number;
    username: string;
    authType: 'password' | 'key';
    password?: string;
    privateKey?: string;
    passphrase?: string;
  }

  let connections = $state<SshConnection[]>([]);
  let isLoading = $state(true);
  let e2eState = $state<'none' | 'locked' | 'ready'>('ready');

  // Form
  let editingId = $state<string | null>(null);
  let label = $state('');
  let host = $state('');
  let port = $state(22);
  let username = $state('');
  let authType = $state<'password' | 'key'>('password');
  let password = $state('');
  let privateKey = $state('');
  let passphrase = $state('');
  let showSecret = $state(false);
  let isSaving = $state(false);
  let formError = $state('');

  // Sesi
  let activeId = $state<string | null>(null);
  let activeLabel = $state('');
  let sessions = $state<string[]>([]);
  let connecting = $state(false);
  let connectError = $state('');
  let terminalEl: HTMLDivElement | null = $state(null);
  let term: Terminal | null = null;
  let fitAddon: FitAddon | null = null;
  let unlisteners: UnlistenFn[] = [];
  let resizeObserver: ResizeObserver | null = null;

  onMount(async () => {
    e2eState = await ipc.e2eStatus();
    await refreshList();
    try {
      sessions = await ipc.sshActiveSessions();
    } catch {
      sessions = [];
    }
    unlisteners.push(
      await listen<{ id: string; data: string }>('ssh-data', (e) => {
        if (e.payload.id === activeId && term) {
          term.write(e.payload.data);
        }
      })
    );
    unlisteners.push(
      await listen<{ id: string; status: string }>('ssh-status', (e) => {
        if (e.payload.id === activeId) {
          if (e.payload.status === 'closed' || e.payload.status === 'disconnected') {
            term?.writeln(`\r\n\x1b[33m[Sesi ditutup]\x1b[0m`);
          }
        }
        sessions = sessions.filter((s) => s !== e.payload.id || e.payload.status === 'connected');
      })
    );
  });

  onDestroy(() => {
    unlisteners.forEach((u) => u());
    resizeObserver?.disconnect();
    term?.dispose();
  });

  // Auto-connect dari menu SSH titlebar (pendingConnectId dikonsumsi sekali).
  $effect(() => {
    const pid = sshStore.pendingConnectId;
    if (!pid || isLoading || connecting) return;
    const conn = connections.find((c) => c.id === pid);
    if (conn) {
      consumeSshConnectRequest();
      connect(conn);
    } else if (connections.length > 0) {
      consumeSshConnectRequest(); // koneksi sudah terhapus — buang permintaan
    }
  });

  async function refreshList() {
    isLoading = true;
    try {
      connections = await ipc.sshConnList();
    } catch (e) {
      console.warn('Gagal memuat koneksi SSH:', e);
    } finally {
      isLoading = false;
    }
  }

  function resetForm() {
    editingId = null;
    label = '';
    host = '';
    port = 22;
    username = '';
    authType = 'password';
    password = '';
    privateKey = '';
    passphrase = '';
    formError = '';
  }

  function editConnection(conn: SshConnection) {
    editingId = conn.id;
    label = conn.label;
    // payload terenkripsi hanya didekripsi saat connect — form edit mengisi
    // ulang data dari user (label saja yang di-prefill, sesuai keamanan).
    host = '';
    username = '';
    formError = '';
  }

  async function saveConnection() {
    formError = '';
    if (!label.trim() || !host.trim() || !username.trim()) {
      formError = 'Label, host, dan username wajib diisi.';
      return;
    }
    if (authType === 'password' && !password && !editingId) {
      formError = 'Password wajib diisi untuk koneksi baru.';
      return;
    }
    if (authType === 'key' && !privateKey && !editingId) {
      formError = 'Private key wajib diisi untuk koneksi baru.';
      return;
    }
    isSaving = true;
    try {
      const payloadObj: SshPayload = {
        host: host.trim(),
        port,
        username: username.trim(),
        authType,
        ...(password ? { password } : {}),
        ...(privateKey ? { privateKey } : {}),
        ...(passphrase ? { passphrase } : {})
      };
      const payload = await ipc.encryptContent(JSON.stringify(payloadObj));
      const id = editingId ?? crypto.randomUUID();
      await ipc.sshConnSave(id, label.trim(), payload);
      await refreshList();
      resetForm();
    } catch (e: any) {
      formError = typeof e === 'string' ? e : e?.message || String(e);
    } finally {
      isSaving = false;
    }
  }

  async function deleteConnection(conn: SshConnection) {
    if (!confirm(`Hapus koneksi "${conn.label}"?`)) return;
    await ipc.sshConnDelete(conn.id);
    if (activeId === conn.id) await detachTerminal();
    await refreshList();
  }

  // ===== Terminal =====

  function ensureTerminal() {
    if (term || !terminalEl) return;
    term = new Terminal({
      fontFamily: 'ui-monospace, "Cascadia Mono", Consolas, monospace',
      fontSize: 13,
      cursorBlink: true,
      theme: { background: '#0b0f19', foreground: '#e2e8f0' }
    });
    fitAddon = new FitAddon();
    term.loadAddon(fitAddon);
    term.attachCustomKeyEventHandler(customKeyHandler);
    term.open(terminalEl);
    fitAddon.fit();
    term.onData((data) => {
      if (activeId) ipc.sshWrite(activeId, data);
    });
    terminalEl.addEventListener('contextmenu', openCtxMenu);
    resizeObserver = new ResizeObserver(() => {
      if (!fitAddon || !activeId) return;
      try {
        fitAddon.fit();
        ipc.sshResize(activeId, term!.cols, term!.rows);
      } catch {
        /* abaikan resize saat container 0 */
      }
    });
    resizeObserver.observe(terminalEl);
  }

  async function connect(conn: SshConnection) {
    if (e2eState !== 'ready') return;
    connectError = '';
    connecting = true;
    try {
      const plain = await ipc.decryptContent(conn.payload);
      const payload: SshPayload = JSON.parse(plain);
      const cols = term?.cols ?? 80;
      const rows = term?.rows ?? 24;
      activeId = await ipc.sshConnect({
        id: conn.id,
        label: conn.label,
        host: payload.host,
        port: payload.port,
        username: payload.username,
        authType: payload.authType,
        password: payload.password ?? null,
        privateKey: payload.privateKey ?? null,
        passphrase: payload.passphrase ?? null,
        cols,
        rows
      });
      activeLabel = conn.label;
      if (!sessions.includes(activeId)) sessions = [...sessions, activeId];
      await tick();
      ensureTerminal();
      fitAddon?.fit();
      await ipc.sshResize(activeId, term!.cols, term!.rows);
      term!.focus();
    } catch (e: any) {
      connectError = typeof e === 'string' ? e : e?.message || String(e);
      activeId = null;
    } finally {
      connecting = false;
    }
  }

  async function detachTerminal() {
    // Melepas tampilan tanpa memutus sesi (sesi tetap hidup di Rust).
    activeId = null;
    activeLabel = '';
    term?.dispose();
    term = null;
    fitAddon = null;
    try {
      sessions = await ipc.sshActiveSessions();
    } catch {
      sessions = [];
    }
  }

  async function disconnectActive() {
    if (!activeId) return;
    await ipc.sshDisconnect(activeId);
    sessions = sessions.filter((s) => s !== activeId);
    await detachTerminal();
  }

  async function attachExisting(sessionId: string) {
    activeId = sessionId;
    activeLabel = sessionId;
    await tick();
    ensureTerminal();
    fitAddon?.fit();
    term!.focus();
  }

  // ===== Paste & clipboard terminal =====

  // Clipboard Windows pakai CRLF; terminal mengharapkan CR per baris.
  function normalizePaste(text: string): string {
    return text.replace(/\r\n/g, '\r').replace(/\n/g, '\r');
  }

  async function sendPaste(text: string) {
    if (!text || !activeId) return;
    const normalized = normalizePaste(text);
    const lineCount = normalized.split('\r').length;
    if (
      lineCount > 3 &&
      !confirm(`Tempel ${lineCount} baris ke terminal?\nBaris akan langsung dieksekusi satu per satu (kecuali shell mendukung bracketed paste).`)
    ) {
      return;
    }
    const CHUNK = 4096;
    for (let i = 0; i < normalized.length; i += CHUNK) {
      await ipc.sshWrite(activeId, normalized.slice(i, i + CHUNK));
      if (i + CHUNK < normalized.length) await new Promise((r) => setTimeout(r, 20));
    }
  }

  // Ctrl+C cerdas: ada seleksi = salin, tanpa seleksi = SIGINT.
  // Ctrl+Shift+V = paste eksplisit via clipboard API.
  function customKeyHandler(e: KeyboardEvent): boolean {
    const ctrl = e.ctrlKey || e.metaKey;
    if (e.type !== 'keydown') return true;
    if (ctrl && e.shiftKey && e.key.toLowerCase() === 'v') {
      navigator.clipboard
        .readText()
        .then((t) => sendPaste(t))
        .catch(() => {});
      return false;
    }
    if (ctrl && !e.shiftKey && e.key.toLowerCase() === 'c' && term?.hasSelection()) {
      copyText(term.getSelection());
      return false;
    }
    return true;
  }

  // Menu konteks klik-kanan di terminal.
  let ctxMenu = $state<{ x: number; y: number } | null>(null);

  function openCtxMenu(e: MouseEvent) {
    if (!activeId) return;
    e.preventDefault();
    ctxMenu = { x: Math.min(e.clientX, window.innerWidth - 180), y: Math.min(e.clientY, window.innerHeight - 160) };
  }

  async function ctxPaste() {
    ctxMenu = null;
    const text = await navigator.clipboard.readText().catch(() => '');
    await sendPaste(text);
  }

  async function ctxCopy() {
    if (!term?.hasSelection()) return;
    ctxMenu = null;
    await copyText(term.getSelection());
  }
</script>

<div class="h-full flex flex-col overflow-hidden">
  <!-- Header -->
  <div class="px-4 py-3 border-b border-slate-800 flex items-center justify-between flex-shrink-0">
    <div class="flex items-center space-x-2">
      <TerminalIcon class="w-4 h-4 text-emerald-400" />
      <h2 class="text-sm font-bold text-slate-100">SSH Manager</h2>
      <span class="text-[10px] font-mono text-slate-500">kredensial terenkripsi E2E</span>
    </div>
    {#if activeId}
      <button
        onclick={disconnectActive}
        class="flex items-center space-x-1.5 px-3 py-1.5 rounded-lg bg-rose-950/60 hover:bg-rose-900 border border-rose-800/60 text-rose-300 text-xs font-medium transition-colors cursor-pointer"
      >
        <Square class="w-3 h-3" />
        <span>Putuskan Sesi Aktif</span>
      </button>
    {/if}
  </div>

  {#if e2eState === 'none'}
    <div class="flex-1 flex items-center justify-center p-8">
      <div class="max-w-md text-center space-y-3">
        <Lock class="w-10 h-10 text-amber-400 mx-auto" />
        <h3 class="text-sm font-bold text-slate-100">Perlu Master Password</h3>
        <p class="text-xs text-slate-400 leading-relaxed">
          Kredensial SSH dienkripsi dengan kunci master password E2E. Atur master password terlebih dahulu
          di <strong class="text-slate-200">Pengaturan → Keamanan</strong>, lalu kembali ke sini.
        </p>
      </div>
    </div>
  {:else if e2eState === 'locked'}
    <div class="flex-1 flex items-center justify-center p-8">
      <div class="max-w-md text-center space-y-3">
        <Lock class="w-10 h-10 text-amber-400 mx-auto" />
        <h3 class="text-sm font-bold text-slate-100">Aplikasi Terkunci</h3>
        <p class="text-xs text-slate-400">Buka kunci dengan master password untuk mengakses kredensial SSH.</p>
      </div>
    </div>
  {:else}
    <div class="flex-1 flex overflow-hidden">
      <!-- Left: daftar koneksi -->
      <div class="w-72 flex-shrink-0 border-r border-slate-800 flex flex-col overflow-hidden">
        <div class="px-3 py-2 border-b border-slate-800/80 flex items-center justify-between">
          <span class="text-[11px] font-bold text-slate-300 uppercase tracking-wider">Koneksi Tersimpan</span>
          <button
            onclick={resetForm}
            title="Koneksi baru"
            class="p-1 rounded text-slate-400 hover:text-emerald-300 hover:bg-slate-800 transition-colors cursor-pointer"
          >
            <Plus class="w-3.5 h-3.5" />
          </button>
        </div>

        <div class="flex-1 overflow-y-auto p-2 space-y-1.5">
          {#if isLoading}
            <div class="flex justify-center py-4"><Loader2 class="w-4 h-4 animate-spin text-slate-500" /></div>
          {:else if connections.length === 0}
            <p class="text-[11px] text-slate-500 text-center py-4 px-2 leading-relaxed">
              Belum ada koneksi. Isi formulir di kanan untuk menyimpan kredensial SSH (terenkripsi E2E).
            </p>
          {:else}
            {#each connections as conn (conn.id)}
              <div class="rounded-lg border px-2.5 py-2 transition-colors {editingId === conn.id ? 'border-emerald-600/60 bg-emerald-950/20' : 'border-slate-800 bg-slate-900/60 hover:border-slate-700'}">
                <div class="flex items-center justify-between">
                  <button
                    onclick={() => connect(conn)}
                    disabled={connecting}
                    class="flex-1 text-left cursor-pointer min-w-0"
                  >
                    <p class="text-xs font-semibold text-slate-200 truncate">{conn.label}</p>
                    <p class="text-[10px] text-slate-500 truncate">
                      {#if connecting && activeId === conn.id}Menghubungkan…{:else}Klik untuk connect{/if}
                    </p>
                  </button>
                  <div class="flex items-center space-x-0.5 flex-shrink-0 ml-1">
                    <button
                      onclick={() => editConnection(conn)}
                      title="Ubah label"
                      class="p-1 rounded text-slate-500 hover:text-slate-200 hover:bg-slate-800 transition-colors cursor-pointer"
                    >
                      <Eye class="w-3 h-3" />
                    </button>
                    <button
                      onclick={() => deleteConnection(conn)}
                      title="Hapus"
                      class="p-1 rounded text-slate-500 hover:text-rose-300 hover:bg-slate-800 transition-colors cursor-pointer"
                    >
                      <Trash2 class="w-3 h-3" />
                    </button>
                  </div>
                </div>
              </div>
            {/each}
          {/if}
        </div>

        {#if sessions.length > 0}
          <div class="px-3 py-2 border-t border-slate-800/80 space-y-1">
            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Sesi Aktif</p>
            {#each sessions as s (s)}
              <button
                onclick={() => attachExisting(s)}
                class="w-full flex items-center space-x-1.5 px-2 py-1 rounded-lg bg-slate-900 border border-slate-800 hover:border-emerald-600/50 text-[10.5px] text-slate-300 transition-colors cursor-pointer"
              >
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
                <span class="truncate font-mono">{s.slice(0, 8)}…</span>
              </button>
            {/each}
          </div>
        {/if}
      </div>

      <!-- Right: form / terminal -->
      <div class="flex-1 flex flex-col overflow-hidden">
        {#if activeId}
          <!-- Terminal -->
          <div class="px-3 py-2 border-b border-slate-800 flex items-center justify-between flex-shrink-0 bg-slate-900/40">
            <span class="text-xs font-semibold text-emerald-300 flex items-center space-x-1.5">
              <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
              <span>{activeLabel}</span>
            </span>
            <button
              onclick={detachTerminal}
              class="text-[11px] text-slate-400 hover:text-slate-200 transition-colors cursor-pointer"
            >
              Lepas tampilan (sesi tetap hidup)
            </button>
          </div>
          <div class="flex-1 min-h-0 p-1 bg-[#0b0f19] relative">
            <div bind:this={terminalEl} class="h-full w-full"></div>
            {#if ctxMenu}
              <div
                class="fixed z-50 min-w-[150px] py-1 rounded-lg bg-slate-900 border border-slate-700 shadow-2xl text-xs text-slate-200"
                style="left: {ctxMenu.x}px; top: {ctxMenu.y}px;"
              >
                <button
                  onclick={ctxCopy}
                  disabled={!term?.hasSelection()}
                  class="w-full px-3 py-1.5 text-left hover:bg-slate-800 transition-colors cursor-pointer disabled:opacity-40 disabled:cursor-not-allowed"
                >
                  Salin (Ctrl+Shift+C)
                </button>
                <button
                  onclick={ctxPaste}
                  class="w-full px-3 py-1.5 text-left hover:bg-slate-800 transition-colors cursor-pointer"
                >
                  Tempel (Ctrl+Shift+V / klik kanan)
                </button>
                <div class="my-1 border-t border-slate-800"></div>
                <button
                  onclick={() => { term?.selectAll(); ctxMenu = null; }}
                  class="w-full px-3 py-1.5 text-left hover:bg-slate-800 transition-colors cursor-pointer"
                >
                  Pilih Semua
                </button>
                <button
                  onclick={() => { term?.clear(); ctxMenu = null; }}
                  class="w-full px-3 py-1.5 text-left hover:bg-slate-800 transition-colors cursor-pointer"
                >
                  Bersihkan Layar
                </button>
              </div>
            {/if}
          </div>
        {:else}
          <!-- Form koneksi -->
          <div class="flex-1 overflow-y-auto p-5">
            <div class="max-w-lg space-y-4">
              <h3 class="text-xs font-bold text-slate-200 uppercase tracking-wider">
                {editingId ? 'Ubah Koneksi' : 'Koneksi Baru'}
              </h3>

              {#if formError}
                <div class="flex items-start space-x-2 p-3 rounded-xl bg-rose-950/50 border border-rose-800/60 text-rose-200 text-xs">
                  <AlertTriangle class="w-4 h-4 flex-shrink-0 mt-0.5" />
                  <span>{formError}</span>
                </div>
              {/if}

              <div class="space-y-1.5">
                <label class="text-xs font-semibold text-slate-300" for="ssh-label">Label</label>
                <input
                  id="ssh-label"
                  type="text"
                  bind:value={label}
                  placeholder="VPS Production"
                  class="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-100 placeholder-slate-600 focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div class="grid grid-cols-[1fr_100px] gap-3">
                <div class="space-y-1.5">
                  <label class="text-xs font-semibold text-slate-300" for="ssh-host">Host</label>
                  <input
                    id="ssh-host"
                    type="text"
                    bind:value={host}
                    placeholder="1.2.3.4 / server.domain.com"
                    class="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-100 placeholder-slate-600 font-mono focus:outline-none focus:border-emerald-500"
                  />
                </div>
                <div class="space-y-1.5">
                  <label class="text-xs font-semibold text-slate-300" for="ssh-port">Port</label>
                  <input
                    id="ssh-port"
                    type="number"
                    bind:value={port}
                    min="1"
                    max="65535"
                    class="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-100 focus:outline-none focus:border-emerald-500"
                  />
                </div>
              </div>

              <div class="space-y-1.5">
                <label class="text-xs font-semibold text-slate-300" for="ssh-user">Username</label>
                <input
                  id="ssh-user"
                  type="text"
                  bind:value={username}
                  placeholder="root"
                  class="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-100 placeholder-slate-600 font-mono focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div class="space-y-1.5">
                <label class="text-xs font-semibold text-slate-300">Metode Autentikasi</label>
                <div class="grid grid-cols-2 gap-2">
                  <button
                    onclick={() => (authType = 'password')}
                    class="px-3 py-2 rounded-xl border text-xs font-medium transition-colors cursor-pointer {authType === 'password'
                      ? 'bg-emerald-600/10 border-emerald-500 text-white'
                      : 'bg-slate-900/60 border-slate-800 text-slate-300 hover:border-slate-700'}"
                  >
                    Password
                  </button>
                  <button
                    onclick={() => (authType = 'key')}
                    class="px-3 py-2 rounded-xl border text-xs font-medium transition-colors cursor-pointer {authType === 'key'
                      ? 'bg-emerald-600/10 border-emerald-500 text-white'
                      : 'bg-slate-900/60 border-slate-800 text-slate-300 hover:border-slate-700'}"
                  >
                    Private Key
                  </button>
                </div>
              </div>

              {#if authType === 'password'}
                <div class="space-y-1.5">
                  <label class="text-xs font-semibold text-slate-300" for="ssh-pass">Password</label>
                  <div class="relative">
                    <input
                      id="ssh-pass"
                      type={showSecret ? 'text' : 'password'}
                      bind:value={password}
                      placeholder={editingId ? 'kosongkan untuk mempertahankan' : 'password server'}
                      class="w-full px-3 py-2 pr-10 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-100 placeholder-slate-600 font-mono focus:outline-none focus:border-emerald-500"
                    />
                    <button
                      type="button"
                      onclick={() => (showSecret = !showSecret)}
                      class="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-500 hover:text-slate-200 transition-colors cursor-pointer"
                    >
                      {#if showSecret}<EyeOff class="w-3.5 h-3.5" />{:else}<Eye class="w-3.5 h-3.5" />{/if}
                    </button>
                  </div>
                </div>
              {:else}
                <div class="space-y-1.5">
                  <label class="text-xs font-semibold text-slate-300" for="ssh-key">Private Key (PEM)</label>
                  <textarea
                    id="ssh-key"
                    bind:value={privateKey}
                    rows="5"
                    placeholder={editingId ? 'kosongkan untuk mempertahankan' : '-----BEGIN OPENSSH PRIVATE KEY-----'}
                    class="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-[10.5px] text-slate-100 placeholder-slate-600 font-mono focus:outline-none focus:border-emerald-500 resize-none"
                  ></textarea>
                  <input
                    type="password"
                    bind:value={passphrase}
                    placeholder="Passphrase key (opsional)"
                    class="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-100 placeholder-slate-600 font-mono focus:outline-none focus:border-emerald-500"
                  />
                </div>
              {/if}

              <div class="flex items-center gap-2 pt-1">
                <button
                  onclick={saveConnection}
                  disabled={isSaving}
                  class="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white text-xs font-semibold transition-colors cursor-pointer"
                >
                  {#if isSaving}<Loader2 class="w-3.5 h-3.5 inline animate-spin mr-1" />{/if}
                  {editingId ? 'Perbarui Koneksi' : 'Simpan Koneksi'}
                </button>
                {#if editingId}
                  <button
                    onclick={resetForm}
                    class="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-200 text-xs font-medium transition-colors cursor-pointer"
                  >
                    Batal
                  </button>
                {/if}
              </div>

              <p class="text-[10.5px] text-slate-500 flex items-start space-x-1.5 leading-relaxed pt-1">
                <Lock class="w-3 h-3 flex-shrink-0 mt-0.5 text-emerald-500/70" />
                <span>
                  Kredensial dienkripsi dengan kunci master password (E2E) sebelum disimpan.
                  Sinkronisasi cloud via tabel <code class="font-mono">ssh_connections</code> menyimpan ciphertext saja.
                </span>
              </p>
            </div>
          </div>
        {/if}
      </div>
    </div>
  {/if}
</div>

<svelte:window onclick={() => (ctxMenu = null)} onkeydown={() => (ctxMenu = null)} />

{#if connecting}
  <div class="fixed inset-0 z-50 bg-black/50 flex items-center justify-center">
    <div class="flex items-center space-x-3 px-5 py-4 rounded-2xl bg-slate-900 border border-slate-700">
      <Loader2 class="w-5 h-5 animate-spin text-emerald-400" />
      <span class="text-xs text-slate-200">Menghubungkan…</span>
    </div>
  </div>
{/if}

{#if connectError}
  <div class="fixed bottom-4 right-4 z-50 max-w-md p-3.5 rounded-xl bg-rose-950/90 border border-rose-700/60 text-rose-100 text-xs flex items-start space-x-2">
    <Plug class="w-4 h-4 flex-shrink-0 mt-0.5" />
    <span class="break-all">{connectError}</span>
    <button onclick={() => (connectError = '')} class="ml-2 text-rose-300 hover:text-white cursor-pointer">✕</button>
  </div>
{/if}
