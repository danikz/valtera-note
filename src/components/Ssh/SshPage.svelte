<script lang="ts">
  import { onMount, onDestroy, tick } from 'svelte';
  import {
    Terminal as TerminalIcon,
    Plus,
    Trash2,
    Loader2,
    Plug,
    Pencil,
    Eye,
    EyeOff,
    Lock,
    AlertTriangle,
    Building2,
    ChevronDown,
    Cloud,
    RefreshCw,
    X
  } from 'lucide-svelte';
  import { Terminal } from '@xterm/xterm';
  import { FitAddon } from '@xterm/addon-fit';
  import { listen, type UnlistenFn } from '@tauri-apps/api/event';
  import { ipc } from '../../services/ipc';
  import { copyText } from '../../utils/clipboard';
  import { sshStore, consumeSshConnectRequest, sshSyncState, syncSshConnections, rememberSshDeletedId } from '../../stores/sshStore.svelte';
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
    workspace?: string; // pengelompokan (perusahaan/lokasi) — ikut payload E2E
  }

  // Satu tab = satu sesi hidup = satu instance terminal sendiri.
  // Pindah tab hanya show/hide DOM sehingga scrollback tiap sesi tetap utuh,
  // dan output sesi background tetap terekam ke buffernya masing-masing.
  interface SshTab {
    sessionId: string;
    label: string;
    closed: boolean; // sesi ditutup dari sisi server
    unread: boolean; // ada output baru di tab yang tidak aktif
  }

  let connections = $state<SshConnection[]>([]);
  let isLoading = $state(true);
  let e2eState = $state<'none' | 'locked' | 'ready'>('ready');

  // Workspace per koneksi (connId -> nama) — dibaca dari payload terenkripsi.
  let connWorkspaces = $state<Record<string, string>>({});
  let collapsedGroups = $state<Record<string, boolean>>({});

  // Form
  let editingId = $state<string | null>(null);
  let label = $state('');
  let host = $state('');
  let port = $state(22);
  let username = $state('');
  let workspace = $state('');
  let authType = $state<'password' | 'key'>('password');
  let password = $state('');
  let privateKey = $state('');
  let passphrase = $state('');
  let showSecret = $state(false);
  let isSaving = $state(false);
  let formError = $state('');

  // Tab & terminal
  let tabs = $state<SshTab[]>([]);
  let activeTabId = $state<string | null>(null);
  let selectedConnId = $state<string | null>(null);
  let showForm = $state(false);
  let connectingId = $state<string | null>(null);
  let connectError = $state('');
  let unlisteners: UnlistenFn[] = [];

  // Instance terminal per sesi — tidak perlu reaktif, cukup diakses via Map.
  // `ready` false sampai replay selesai ditulis; data live yang datang lebih
  // cepat ditahan di `queue` agar urutan output tetap benar.
  const terms = new Map<
    string,
    { term: Terminal; fitAddon: FitAddon; ready: boolean; queue: string[] }
  >();

  function activeTerm(): Terminal | null {
    return activeTabId ? (terms.get(activeTabId)?.term ?? null) : null;
  }

  // Pengelompokan koneksi per workspace (nama terurut; tanpa-workspace paling bawah).
  const workspaceGroups = $derived.by(() => {
    const named = new Map<string, SshConnection[]>();
    const ungrouped: SshConnection[] = [];
    for (const c of connections) {
      const ws = (connWorkspaces[c.id] ?? '').trim();
      if (ws) {
        if (!named.has(ws)) named.set(ws, []);
        named.get(ws)!.push(c);
      } else {
        ungrouped.push(c);
      }
    }
    const groups = [...named.entries()]
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([name, items]) => ({ name, items }));
    if (ungrouped.length > 0) groups.push({ name: '', items: ungrouped });
    return groups;
  });
  const hasWorkspaces = $derived(connections.some((c) => (connWorkspaces[c.id] ?? '').trim() !== ''));
  const workspaceNames = $derived(
    [...new Set(connections.map((c) => (connWorkspaces[c.id] ?? '').trim()).filter(Boolean))].sort((a, b) =>
      a.localeCompare(b)
    )
  );

  onMount(async () => {
    e2eState = await ipc.e2eStatus();
    await refreshList();
    await restoreTabs();
    // Sinkron ke cloud (pull koneksi perangkat lain + push yang belum terkirim),
    // lalu muat ulang daftar karena sync bisa menambah koneksi baru.
    if (e2eState === 'ready') {
      syncSshConnections()
        .then(() => refreshList())
        .catch(() => {});
    }
    unlisteners.push(
      await listen<{ id: string; data: string }>('ssh-data', (e) => {
        const entry = terms.get(e.payload.id);
        if (entry) {
          if (entry.ready) entry.term.write(e.payload.data);
          else entry.queue.push(e.payload.data);
          if (e.payload.id !== activeTabId) markUnread(e.payload.id);
        }
      })
    );
    unlisteners.push(
      await listen<{ id: string; status: string }>('ssh-status', (e) => {
        const tab = tabs.find((t) => t.sessionId === e.payload.id);
        if (!tab) return;
        if (e.payload.status === 'closed' || e.payload.status === 'disconnected') {
          tab.closed = true;
          terms.get(e.payload.id)?.term.writeln(`\r\n\x1b[33m[Sesi ditutup]\x1b[0m`);
        } else if (e.payload.status === 'connected') {
          tab.closed = false;
        }
      })
    );
  });

  onDestroy(() => {
    unlisteners.forEach((u) => u());
  });

  // Auto-connect dari menu SSH titlebar (pendingConnectId dikonsumsi sekali).
  $effect(() => {
    const pid = sshStore.pendingConnectId;
    if (!pid || isLoading || connectingId) return;
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
      // Workspace dibaca dari payload terenkripsi masing-masing koneksi.
      const map: Record<string, string> = {};
      for (const c of connections) {
        try {
          const p: SshPayload = JSON.parse(await ipc.decryptContent(c.payload));
          map[c.id] = (p.workspace ?? '').trim();
        } catch {
          map[c.id] = '';
        }
      }
      connWorkspaces = map;
    } catch (e) {
      console.warn('Gagal memuat koneksi SSH:', e);
    } finally {
      isLoading = false;
    }
  }

  // Sesi yang masih hidup di Rust (mis. karena sempat keluar dari halaman ini)
  // dikembalikan sebagai tab — terminalnya baru, tapi sesinya sama.
  async function restoreTabs() {
    let ids: string[] = [];
    try {
      ids = await ipc.sshActiveSessions();
    } catch {
      ids = [];
    }
    for (const sid of ids) {
      if (tabs.some((t) => t.sessionId === sid)) continue;
      const conn = connections.find((c) => c.id === sid);
      tabs.push({ sessionId: sid, label: conn?.label ?? `${sid.slice(0, 8)}…`, closed: false, unread: false });
    }
    if (!activeTabId && tabs.length > 0) activeTabId = tabs[0].sessionId;
    await tick();
    fitActive();
  }

  function resetForm() {
    editingId = null;
    label = '';
    host = '';
    port = 22;
    username = '';
    workspace = '';
    authType = 'password';
    password = '';
    privateKey = '';
    passphrase = '';
    formError = '';
    showForm = true;
  }

  function closeForm() {
    resetForm();
    showForm = false;
  }

  async function editConnection(conn: SshConnection) {
    editingId = conn.id;
    label = conn.label;
    password = '';
    privateKey = '';
    passphrase = '';
    // Host/port/username bukan rahasia — di-prefill agar edit nyaman.
    // Secret dibiarkan kosong: kosong = pertahankan yang tersimpan, hanya
    // didekrip di memori saat uji & simpan.
    try {
      const stored: SshPayload = JSON.parse(await ipc.decryptContent(conn.payload));
      host = stored.host;
      port = stored.port ?? 22;
      username = stored.username;
      workspace = stored.workspace ?? '';
      authType = stored.authType ?? 'password';
      formError = '';
    } catch {
      host = '';
      port = 22;
      username = '';
      formError = 'Gagal membaca kredensial tersimpan.';
    }
    showForm = true;
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
      const id = editingId ?? crypto.randomUUID();

      // Saat edit, field secret yang dikosongkan berarti tetap pakai yang tersimpan.
      // Workspace bukan rahasia dan selalu mengikuti nilai form (kosong = hapus).
      let creds: SshPayload;
      if (editingId) {
        const conn = connections.find((c) => c.id === editingId);
        if (!conn) throw new Error('Koneksi tidak ditemukan.');
        const stored: SshPayload = JSON.parse(await ipc.decryptContent(conn.payload));
        creds = {
          host: host.trim(),
          port,
          username: username.trim(),
          authType,
          ...(password || stored.password ? { password: password || stored.password } : {}),
          ...(privateKey || stored.privateKey ? { privateKey: privateKey || stored.privateKey } : {}),
          ...(passphrase || stored.passphrase ? { passphrase: passphrase || stored.passphrase } : {}),
          ...(workspace.trim() ? { workspace: workspace.trim() } : {})
        };
      } else {
        creds = {
          host: host.trim(),
          port,
          username: username.trim(),
          authType,
          ...(password ? { password } : {}),
          ...(privateKey ? { privateKey } : {}),
          ...(passphrase ? { passphrase } : {}),
          ...(workspace.trim() ? { workspace: workspace.trim() } : {})
        };
      }

      // Sesi yang masih hidup memakai kredensial lama — putuskan dulu supaya
      // pengujian benar-benar memverifikasi kredensial yang baru diisi.
      if (tabs.some((t) => t.sessionId === id)) await closeTab(id);

      // Uji koneksi sungguhan dulu: gagal = error di form, kredensial TIDAK disimpan.
      await openSessionAndTab(id, label.trim(), creds);

      // Koneksi terbukti hidup → baru simpan kredensialnya (E2E).
      const payload = await ipc.encryptContent(JSON.stringify(creds));
      await ipc.sshConnSave(id, label.trim(), payload);
      await refreshList();
      resetForm();
      showForm = false;
      if (e2eState === 'ready') syncSshConnections().catch(() => {});
    } catch (e: any) {
      formError = typeof e === 'string' ? e : e?.message || String(e);
    } finally {
      isSaving = false;
    }
  }

  async function deleteConnection(conn: SshConnection) {
    if (!confirm(`Hapus koneksi "${conn.label}"?`)) return;
    // Catat tombstone dulu agar sync ikut menghapus salinan cloud & perangkat lain.
    rememberSshDeletedId(conn.id);
    await ipc.sshConnDelete(conn.id);
    if (tabs.some((t) => t.sessionId === conn.id)) await closeTab(conn.id);
    await refreshList();
    if (e2eState === 'ready') syncSshConnections().catch(() => {});
  }

  // ===== Tab & terminal =====

  async function connect(conn: SshConnection) {
    if (e2eState !== 'ready' || connectingId) return;
    const existing = tabs.find((t) => t.sessionId === conn.id);
    if (existing && !existing.closed) {
      await activateTab(conn.id);
      return;
    }
    connectError = '';
    connectingId = conn.id;
    try {
      if (existing) {
        // Tab bekas sesi yang sudah mati — buang dulu agar tab barunya bersih.
        terms.get(conn.id)?.term.dispose();
        terms.delete(conn.id);
        tabs = tabs.filter((t) => t.sessionId !== conn.id);
        await tick();
      }
      const plain = await ipc.decryptContent(conn.payload);
      const payload: SshPayload = JSON.parse(plain);
      await openSessionAndTab(conn.id, conn.label, payload);
    } catch (e: any) {
      connectError = typeof e === 'string' ? e : e?.message || String(e);
    } finally {
      connectingId = null;
    }
  }

  // Connect sungguhan + buka/aktifkan tab-nya. Dipakai alur connect dari
  // daftar koneksi maupun alur "uji & simpan" dari form.
  async function openSessionAndTab(id: string, labelText: string, creds: SshPayload): Promise<string> {
    const at = activeTerm();
    const cols = at?.cols ?? 80;
    const rows = at?.rows ?? 24;
    const sessionId = await ipc.sshConnect({
      id,
      label: labelText,
      host: creds.host,
      port: creds.port,
      username: creds.username,
      authType: creds.authType,
      password: creds.password ?? null,
      privateKey: creds.privateKey ?? null,
      passphrase: creds.passphrase ?? null,
      cols,
      rows
    });
    if (tabs.some((t) => t.sessionId === sessionId)) {
      await activateTab(sessionId); // Rust re-attach — tab sudah ada
      return sessionId;
    }
    tabs.push({ sessionId, label: labelText, closed: false, unread: false });
    activeTabId = sessionId;
    showForm = false;
    await tick();
    fitActive();
    terms.get(sessionId)?.term.focus();
    return sessionId;
  }

  async function activateTab(sessionId: string) {
    activeTabId = sessionId;
    showForm = false;
    const tab = tabs.find((t) => t.sessionId === sessionId);
    if (tab) tab.unread = false;
    await tick();
    fitActive();
    terms.get(sessionId)?.term.focus();
  }

  async function closeTab(sessionId: string) {
    const tab = tabs.find((t) => t.sessionId === sessionId);
    if (tab && !tab.closed) {
      await ipc.sshDisconnect(sessionId).catch(() => {});
    }
    terms.get(sessionId)?.term.dispose();
    terms.delete(sessionId);
    const idx = tabs.findIndex((t) => t.sessionId === sessionId);
    tabs = tabs.filter((t) => t.sessionId !== sessionId);
    if (activeTabId === sessionId) {
      activeTabId = tabs[Math.min(Math.max(idx, 0), tabs.length - 1)]?.sessionId ?? null;
      await tick();
      fitActive();
    }
  }

  function markUnread(sessionId: string) {
    const tab = tabs.find((t) => t.sessionId === sessionId);
    if (tab && !tab.closed) tab.unread = true;
  }

  function fitActive() {
    if (!activeTabId || !terminalAreaVisible()) return;
    const entry = terms.get(activeTabId);
    if (!entry) return;
    try {
      entry.fitAddon.fit();
      ipc.sshResize(activeTabId, entry.term.cols, entry.term.rows);
    } catch {
      /* abaikan resize saat container 0 */
    }
  }

  function terminalAreaVisible(): boolean {
    const el = document.getElementById('ssh-terminal-area');
    return !!el && el.offsetParent !== null;
  }

  // Svelte action: area terminal — pasang observer resize sekali.
  function observeTerminalArea(el: HTMLDivElement) {
    const observer = new ResizeObserver(() => fitActive());
    observer.observe(el);
    return {
      destroy() {
        observer.disconnect();
      }
    };
  }

  // Svelte action: satu node div per tab; terminal dibuat saat node mount
  // dan dibuang saat tab ditutup / halaman ditinggalkan (sesi tetap di Rust).
  // Terminal baru dimulai kosong — isi layar terakhir sesi dipulihkan dari
  // replay buffer Rust supaya attach ulang terasa melanjutkan, bukan blank.
  function mountTerminal(el: HTMLDivElement, sessionId: string) {
    const term = new Terminal({
      fontFamily: 'ui-monospace, "Cascadia Mono", Consolas, monospace',
      fontSize: 13,
      cursorBlink: true,
      theme: { background: '#0b0f19', foreground: '#e2e8f0' }
    });
    const fitAddon = new FitAddon();
    term.loadAddon(fitAddon);
    term.attachCustomKeyEventHandler(customKeyHandler);
    term.open(el);
    fitAddon.fit();
    term.onData((data) => {
      ipc.sshWrite(sessionId, data);
    });
    el.addEventListener('contextmenu', openCtxMenu);
    const entry = { term, fitAddon, ready: false, queue: [] as string[] };
    terms.set(sessionId, entry);
    ipc
      .sshReplay(sessionId)
      .then((replay) => {
        if (replay && !entry.ready) term.write(replay);
      })
      .catch(() => {})
      .finally(() => {
        entry.ready = true;
        for (const chunk of entry.queue) term.write(chunk);
        entry.queue.length = 0;
      });
    return {
      destroy() {
        el.removeEventListener('contextmenu', openCtxMenu);
        // closeTab/connect mungkin sudah membuang & menghapus entry —
        // jangan dispose dua kali terminal yang sama.
        const entry = terms.get(sessionId);
        if (entry && entry.term === term) {
          term.dispose();
          terms.delete(sessionId);
        }
      }
    };
  }

  // ===== Paste & clipboard terminal =====

  // Clipboard Windows pakai CRLF; terminal mengharapkan CR per baris.
  function normalizePaste(text: string): string {
    return text.replace(/\r\n/g, '\r').replace(/\n/g, '\r');
  }

  async function sendPaste(text: string) {
    if (!text || !activeTabId) return;
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
      await ipc.sshWrite(activeTabId, normalized.slice(i, i + CHUNK));
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
    if (ctrl && !e.shiftKey && e.key.toLowerCase() === 'c' && activeTerm()?.hasSelection()) {
      copyText(activeTerm()!.getSelection());
      return false;
    }
    return true;
  }

  // Menu konteks klik-kanan di terminal.
  let ctxMenu = $state<{ x: number; y: number } | null>(null);

  function openCtxMenu(e: MouseEvent) {
    if (!activeTabId) return;
    e.preventDefault();
    ctxMenu = { x: Math.min(e.clientX, window.innerWidth - 180), y: Math.min(e.clientY, window.innerHeight - 160) };
  }

  async function ctxPaste() {
    ctxMenu = null;
    const text = await navigator.clipboard.readText().catch(() => '');
    await sendPaste(text);
  }

  async function ctxCopy() {
    const term = activeTerm();
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
    {#if sshSyncState.status !== 'unconfigured'}
      <button
        onclick={() => e2eState === 'ready' && syncSshConnections().then(() => refreshList()).catch(() => {})}
        disabled={sshSyncState.status === 'syncing' || e2eState !== 'ready'}
        title={sshSyncState.message || 'Sinkronkan koneksi ke cloud'}
        class="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg border text-[10.5px] font-medium transition-colors cursor-pointer disabled:cursor-default
        {sshSyncState.status === 'error'
          ? 'bg-rose-950/50 border-rose-800/60 text-rose-300 hover:bg-rose-900/60'
          : sshSyncState.status === 'syncing'
          ? 'bg-slate-900 border-slate-800 text-slate-400'
          : sshSyncState.status === 'ok'
          ? 'bg-emerald-950/30 border-emerald-800/50 text-emerald-300/90 hover:bg-emerald-900/40'
          : 'bg-slate-900 border-slate-800 text-slate-500 hover:text-slate-300'}"
      >
        {#if sshSyncState.status === 'syncing'}
          <Loader2 class="w-3 h-3 animate-spin" />
        {:else if sshSyncState.status === 'error'}
          <AlertTriangle class="w-3 h-3" />
        {:else}
          <Cloud class="w-3 h-3" />
        {/if}
        <span class="max-w-[280px] truncate">
          {#if sshSyncState.status === 'syncing'}Sinkron…{:else if sshSyncState.status === 'ok' && sshSyncState.lastSyncAt}Cloud {sshSyncState.lastSyncAt}{:else if sshSyncState.status === 'error'}Sync gagal{:else}Sinkron ke cloud{/if}
        </span>
        {#if sshSyncState.status !== 'syncing'}
          <RefreshCw class="w-2.5 h-2.5 opacity-60" />
        {/if}
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

  {#snippet connectionRow(conn: SshConnection)}
    {@const tab = tabs.find((t) => t.sessionId === conn.id)}
    <div class="rounded-lg border px-2.5 py-2 transition-colors {tab && !tab.closed ? 'border-emerald-600/40 bg-emerald-950/10' : selectedConnId === conn.id ? 'border-emerald-500/60 bg-slate-900' : editingId === conn.id ? 'border-emerald-600/60 bg-emerald-950/20' : 'border-slate-800 bg-slate-900/60 hover:border-slate-700'}">
      <div class="flex items-center justify-between">
        <button
          onclick={() => (selectedConnId = conn.id)}
          ondblclick={() => connect(conn)}
          disabled={connectingId !== null}
          title="Klik 2x untuk connect"
          class="flex-1 text-left cursor-pointer min-w-0"
        >
          <p class="text-xs font-semibold text-slate-200 truncate">{conn.label}</p>
          <p class="text-[10px] text-slate-500 truncate">
            {#if connectingId === conn.id}Menghubungkan…{:else if tab && !tab.closed}● aktif — klik 2x untuk buka{:else}Klik 2x untuk connect{/if}
          </p>
        </button>
        <div class="flex items-center space-x-0.5 flex-shrink-0 ml-1">
          <button
            onclick={() => editConnection(conn)}
            title="Edit koneksi"
            class="p-1 rounded text-slate-500 hover:text-slate-200 hover:bg-slate-800 transition-colors cursor-pointer"
          >
            <Pencil class="w-3 h-3" />
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
  {/snippet}

        <div class="flex-1 overflow-y-auto p-2 space-y-1.5">
          {#if isLoading}
            <div class="flex justify-center py-4"><Loader2 class="w-4 h-4 animate-spin text-slate-500" /></div>
          {:else if connections.length === 0}
            <p class="text-[11px] text-slate-500 text-center py-4 px-2 leading-relaxed">
              Belum ada koneksi. Klik <Plus class="w-3 h-3 inline" /> untuk menyimpan kredensial SSH (terenkripsi E2E).
            </p>
          {:else if hasWorkspaces}
            {#each workspaceGroups as g (g.name || '__ungrouped')}
              <div>
                <button
                  onclick={() => (collapsedGroups[g.name] = !collapsedGroups[g.name])}
                  class="w-full flex items-center gap-1.5 px-1.5 py-1 rounded text-[10px] font-bold uppercase tracking-wider text-slate-400 hover:text-slate-200 hover:bg-slate-800/60 transition-colors cursor-pointer"
                  title={collapsedGroups[g.name] ? 'Buka grup' : 'Tutup grup'}
                >
                  <ChevronDown class="w-3 h-3 flex-shrink-0 transition-transform {collapsedGroups[g.name] ? '-rotate-90' : ''}" />
                  <Building2 class="w-3 h-3 text-emerald-400/80 flex-shrink-0" />
                  <span class="truncate text-left {g.name ? '' : 'italic normal-case tracking-normal'}">{g.name || 'Tanpa Workspace'}</span>
                  <span class="ml-auto font-mono text-[9px] font-normal text-slate-500 flex-shrink-0">{g.items.length}</span>
                </button>
                {#if !collapsedGroups[g.name]}
                  <div class="space-y-1.5 mt-1">
                    {#each g.items as conn (conn.id)}
                      {@render connectionRow(conn)}
                    {/each}
                  </div>
                {/if}
              </div>
            {/each}
          {:else}
            {#each connections as conn (conn.id)}
              {@render connectionRow(conn)}
            {/each}
          {/if}
        </div>
      </div>

      <!-- Right: tab terminal / form -->
      <div class="flex-1 flex flex-col overflow-hidden">
        <!-- Tab strip ala browser -->
        <div
          class="h-9 flex items-stretch border-b border-slate-800 bg-slate-900/40 flex-shrink-0 overflow-x-auto scrollbar-none {tabs.length === 0 || showForm ? 'hidden' : ''}"
        >
          {#each tabs as t (t.sessionId)}
            <div
              role="tab"
              tabindex="0"
              onclick={() => activateTab(t.sessionId)}
              onkeydown={(e) => e.key === 'Enter' && activateTab(t.sessionId)}
              class="group flex items-center gap-1.5 pl-3 pr-1.5 border-r border-slate-800 cursor-pointer text-xs select-none max-w-[220px] transition-colors {activeTabId === t.sessionId && !showForm ? 'bg-[#0b0f19] text-slate-100' : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'}"
            >
              {#if t.closed}
                <span class="w-1.5 h-1.5 rounded-full bg-slate-600 flex-shrink-0"></span>
              {:else if t.unread && activeTabId !== t.sessionId}
                <span class="w-1.5 h-1.5 rounded-full bg-amber-400 flex-shrink-0"></span>
              {:else}
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse flex-shrink-0"></span>
              {/if}
              <span class="truncate font-medium">{t.label}</span>
              <button
                onclick={(e) => { e.stopPropagation(); closeTab(t.sessionId); }}
                title={t.closed ? 'Tutup tab' : 'Tutup tab (putuskan sesi)'}
                class="p-0.5 rounded text-slate-500 hover:text-rose-300 hover:bg-slate-800 transition-colors cursor-pointer flex-shrink-0"
              >
                <X class="w-3 h-3" />
              </button>
            </div>
          {/each}
        </div>

        <!-- Terminal per tab: semua div selalu ter-mount (hidden saja) agar
             buffer xterm tiap sesi tidak hilang saat pindah tab / buka form. -->
        <div
          id="ssh-terminal-area"
          use:observeTerminalArea
          class="flex-1 min-h-0 p-1 bg-[#0b0f19] relative {tabs.length === 0 || showForm ? 'hidden' : ''}"
        >
          {#each tabs as t (t.sessionId)}
            <div class="absolute inset-0 {activeTabId === t.sessionId ? '' : 'hidden'}" use:mountTerminal={t.sessionId}></div>
          {/each}
          {#if ctxMenu}
            <div
              class="fixed z-50 min-w-[150px] py-1 rounded-lg bg-slate-900 border border-slate-700 shadow-2xl text-xs text-slate-200"
              style="left: {ctxMenu.x}px; top: {ctxMenu.y}px;"
            >
              <button
                onclick={ctxCopy}
                disabled={!activeTerm()?.hasSelection()}
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
                onclick={() => { activeTerm()?.selectAll(); ctxMenu = null; }}
                class="w-full px-3 py-1.5 text-left hover:bg-slate-800 transition-colors cursor-pointer"
              >
                Pilih Semua
              </button>
              <button
                onclick={() => { activeTerm()?.clear(); ctxMenu = null; }}
                class="w-full px-3 py-1.5 text-left hover:bg-slate-800 transition-colors cursor-pointer"
              >
                Bersihkan Layar
              </button>
            </div>
          {/if}
        </div>

        <!-- Form koneksi (overlay: selalu tampil saat dipanggil / belum ada tab) -->
        <div class="flex-1 overflow-y-auto {tabs.length === 0 || showForm ? '' : 'hidden'}">
          <div class="p-5">
            <div class="max-w-lg space-y-4">
              <div class="flex items-center justify-between">
                <h3 class="text-xs font-bold text-slate-200 uppercase tracking-wider">
                  {editingId ? 'Ubah Koneksi' : 'Koneksi Baru'}
                </h3>
                {#if tabs.length > 0}
                  <button
                    onclick={closeForm}
                    class="text-[11px] text-slate-400 hover:text-slate-200 transition-colors cursor-pointer"
                  >
                    Tutup formulir
                  </button>
                {/if}
              </div>

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
                <label class="text-xs font-semibold text-slate-300" for="ssh-workspace">Workspace (perusahaan / lokasi)</label>
                <input
                  id="ssh-workspace"
                  type="text"
                  bind:value={workspace}
                  placeholder="PT Contoh Jaya — opsional"
                  list="ssh-workspace-datalist"
                  class="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-100 placeholder-slate-600 focus:outline-none focus:border-emerald-500"
                />
                <datalist id="ssh-workspace-datalist">
                  {#each workspaceNames as name (name)}
                    <option value={name}></option>
                  {/each}
                </datalist>
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
                  {editingId ? 'Uji & Perbarui Koneksi' : 'Uji & Simpan Koneksi'}
                </button>
                {#if editingId || tabs.length > 0}
                  <button
                    onclick={closeForm}
                    class="px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-200 text-xs font-medium transition-colors cursor-pointer"
                  >
                    Batal
                  </button>
                {/if}
              </div>

              <p class="text-[10.5px] text-slate-500 flex items-start space-x-1.5 leading-relaxed pt-1">
                <Lock class="w-3 h-3 flex-shrink-0 mt-0.5 text-emerald-500/70" />
                <span>
                  Kredensial diuji dengan connect sungguhan dulu — kalau gagal, tidak ada yang disimpan.
                  Setelah terbukti tersambung, kredensial dienkripsi dengan kunci master password (E2E);
                  sinkronisasi cloud via tabel <code class="font-mono">ssh_connections</code> hanya menyimpan ciphertext.
                </span>
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  {/if}
</div>

<svelte:window onclick={() => (ctxMenu = null)} onkeydown={() => (ctxMenu = null)} />

{#if connectingId}
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
