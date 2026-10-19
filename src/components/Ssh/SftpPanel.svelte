<script lang="ts">
  import { onMount } from 'svelte';
  import {
    Folder,
    File as FileIcon,
    ArrowUp,
    House,
    RefreshCw,
    Upload,
    Download,
    X,
    Loader2,
    FolderOpen,
    Link2,
    AlertTriangle,
    CircleCheck
  } from 'lucide-svelte';
  import { open } from '@tauri-apps/plugin-dialog';
  import { getCurrentWindow } from '@tauri-apps/api/window';
  import type { UnlistenFn } from '@tauri-apps/api/event';
  import { ipc, type SftpEntry } from '../../services/ipc';
  import {
    sftpState,
    sftpLastPath,
    startSftpDownload,
    startSftpUpload,
    cancelSftpTransfer,
    clearFinishedSftpTransfers,
    onSftpUploadDone
  } from './sftpTransfers.svelte';

  let { sessionId, onclose }: { sessionId: string; onclose: () => void } = $props();

  const DL_DIR_KEY = 'valtera_sftp_download_dir';

  let path = $state('');
  let entries = $state<SftpEntry[]>([]);
  let loading = $state(false);
  let error = $state('');
  let editingPath = $state(false);
  let pathInput = $state('');
  let selected = $state<string | null>(null);
  let dropActive = $state(false);
  let downloadDir = $state<string | null>(null); // null = folder Downloads
  let defaultDownloadDir = $state<string | null>(null);
  let panelEl: HTMLDivElement | undefined = $state();

  const transfers = $derived(sftpState.transfers.filter((t) => t.sessionId === sessionId));
  const hasFinished = $derived(transfers.some((t) => t.status !== 'running'));
  const crumbs = $derived.by(() => {
    const parts = path.split('/').filter(Boolean);
    return parts.map((name, i) => ({ name, path: '/' + parts.slice(0, i + 1).join('/') }));
  });

  function errText(e: unknown): string {
    return typeof e === 'string' ? e : (e as any)?.message || String(e);
  }

  function joinPath(dir: string, name: string): string {
    return dir === '/' ? `/${name}` : `${dir}/${name}`;
  }

  function parentPath(p: string): string {
    const up = p.replace(/\/[^/]+\/?$/, '');
    return up || '/';
  }

  async function load(target: string) {
    loading = true;
    error = '';
    try {
      const listing = await ipc.sftpList(sessionId, target);
      path = listing.path;
      entries = listing.entries;
      selected = null;
      sftpLastPath.set(sessionId, listing.path);
    } catch (e) {
      error = errText(e);
    } finally {
      loading = false;
    }
  }

  function openEntry(entry: SftpEntry) {
    if (entry.isDir) load(joinPath(path, entry.name));
    else download(entry);
  }

  function download(entry: SftpEntry) {
    startSftpDownload(sessionId, path, entry.name, downloadDir);
  }

  async function uploadPaths(paths: string[]) {
    if (!path || paths.length === 0) return;
    const existing = new Set(entries.filter((e) => !e.isDir).map((e) => e.name));
    const clashes = paths
      .map((p) => p.split(/[\\/]/).pop() || p)
      .filter((n) => existing.has(n));
    if (
      clashes.length > 0 &&
      !confirm(`File berikut sudah ada di ${path} dan akan ditimpa:\n\n${clashes.join('\n')}\n\nLanjutkan upload?`)
    ) {
      return;
    }
    for (const p of paths) startSftpUpload(sessionId, path, p);
  }

  async function pickUpload() {
    const picked = await open({ multiple: true, directory: false, title: `Upload ke ${path}` }).catch(() => null);
    if (!picked) return;
    uploadPaths(Array.isArray(picked) ? picked : [picked]);
  }

  async function pickDownloadDir() {
    const picked = await open({ directory: true, title: 'Folder tujuan download' }).catch(() => null);
    if (typeof picked !== 'string') return;
    downloadDir = picked;
    try {
      localStorage.setItem(DL_DIR_KEY, picked);
    } catch {
      /* tidak fatal */
    }
  }

  function resetDownloadDir() {
    downloadDir = null;
    try {
      localStorage.removeItem(DL_DIR_KEY);
    } catch {
      /* tidak fatal */
    }
  }

  function startEditPath() {
    pathInput = path;
    editingPath = true;
  }

  function submitPath() {
    editingPath = false;
    const target = pathInput.trim();
    if (target && target !== path) load(target);
  }

  function formatSize(n: number): string {
    if (n < 1024) return `${n} B`;
    const units = ['KB', 'MB', 'GB', 'TB'];
    let v = n / 1024;
    let i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return `${v < 10 ? v.toFixed(1) : Math.round(v)} ${units[i]}`;
  }

  function formatDate(secs: number | null): string {
    if (!secs) return '';
    const d = new Date(secs * 1000);
    const sameYear = d.getFullYear() === new Date().getFullYear();
    return d.toLocaleString('id-ID', {
      day: '2-digit',
      month: 'short',
      ...(sameYear ? { hour: '2-digit', minute: '2-digit' } : { year: 'numeric' })
    });
  }

  function dirName(p: string | null): string {
    if (!p) return 'Downloads';
    return p.split(/[\\/]/).filter(Boolean).pop() || p;
  }

  // Posisi drag-drop dari Tauri dalam piksel fisik; cocokkan dengan kotak panel.
  function insidePanel(pos: { x: number; y: number } | undefined): boolean {
    if (!panelEl || !pos) return false;
    const r = panelEl.getBoundingClientRect();
    const x = pos.x / window.devicePixelRatio;
    const y = pos.y / window.devicePixelRatio;
    return x >= r.left && x <= r.right && y >= r.top && y <= r.bottom;
  }

  onMount(() => {
    try {
      downloadDir = localStorage.getItem(DL_DIR_KEY);
    } catch {
      downloadDir = null;
    }
    ipc.sftpDefaultDownloadDir().then((d) => (defaultDownloadDir = d)).catch(() => {});
    load(sftpLastPath.get(sessionId) ?? '');

    const offUpload = onSftpUploadDone((sid, dir) => {
      if (sid === sessionId && dir === path) load(path);
    });

    let unlistenDrop: UnlistenFn | null = null;
    let disposed = false;
    if ('__TAURI_INTERNALS__' in window) {
      getCurrentWindow()
        .onDragDropEvent((event) => {
          const p = event.payload;
          if (p.type === 'enter' || p.type === 'over') {
            dropActive = insidePanel(p.position);
          } else if (p.type === 'leave') {
            dropActive = false;
          } else if (p.type === 'drop') {
            const inside = insidePanel(p.position);
            dropActive = false;
            if (inside && p.paths.length > 0) uploadPaths(p.paths);
          }
        })
        .then((un) => {
          if (disposed) un();
          else unlistenDrop = un;
        })
        .catch((err) => console.warn('onDragDropEvent registration failed:', err));
    }

    return () => {
      disposed = true;
      offUpload();
      unlistenDrop?.();
    };
  });
</script>

<div
  bind:this={panelEl}
  class="w-[360px] flex-shrink-0 flex flex-col min-h-0 border-l border-slate-800 bg-slate-950 text-xs text-slate-200 relative"
>
  <!-- Header -->
  <div class="h-9 px-2 flex items-center gap-1 border-b border-slate-800 flex-shrink-0">
    <FolderOpen class="w-3.5 h-3.5 text-amber-400 ml-1" />
    <span class="font-semibold text-slate-100 mr-auto">File (SFTP)</span>
    <button onclick={() => load(parentPath(path))} disabled={!path || path === '/'} title="Folder atas" class="p-1.5 rounded hover:bg-slate-800 text-slate-400 hover:text-slate-200 disabled:opacity-30 cursor-pointer disabled:cursor-default">
      <ArrowUp class="w-3.5 h-3.5" />
    </button>
    <button onclick={() => load('')} title="Folder home" class="p-1.5 rounded hover:bg-slate-800 text-slate-400 hover:text-slate-200 cursor-pointer">
      <House class="w-3.5 h-3.5" />
    </button>
    <button onclick={() => load(path)} disabled={loading} title="Muat ulang" class="p-1.5 rounded hover:bg-slate-800 text-slate-400 hover:text-slate-200 cursor-pointer">
      <RefreshCw class="w-3.5 h-3.5 {loading ? 'animate-spin' : ''}" />
    </button>
    <button onclick={pickUpload} disabled={!path} title="Upload file ke folder ini" class="ml-1 flex items-center gap-1 px-2 py-1 rounded-md bg-blue-600 hover:bg-blue-500 text-white font-medium cursor-pointer disabled:opacity-40">
      <Upload class="w-3.5 h-3.5" /> Upload
    </button>
    <button onclick={onclose} title="Tutup panel file" class="p-1.5 rounded hover:bg-slate-800 text-slate-400 hover:text-slate-200 cursor-pointer">
      <X class="w-3.5 h-3.5" />
    </button>
  </div>

  <!-- Path -->
  <div class="px-2 py-1.5 border-b border-slate-800 flex-shrink-0">
    {#if editingPath}
      <!-- svelte-ignore a11y_autofocus -->
      <input
        bind:value={pathInput}
        autofocus
        onkeydown={(e) => {
          if (e.key === 'Enter') submitPath();
          else if (e.key === 'Escape') editingPath = false;
        }}
        onblur={() => (editingPath = false)}
        spellcheck="false"
        class="w-full px-2 py-1 rounded bg-slate-900 border border-blue-600 font-mono text-[11px] text-slate-100 outline-none"
      />
    {:else}
      <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
      <div
        ondblclick={startEditPath}
        title="Klik dua kali untuk mengetik path"
        class="flex items-center flex-wrap gap-0.5 font-mono text-[11px] text-slate-400 min-h-[22px]"
      >
        <button onclick={() => load('/')} class="px-1 rounded hover:bg-slate-800 hover:text-slate-200 cursor-pointer">/</button>
        {#each crumbs as c, i}
          <button onclick={() => load(c.path)} class="px-1 rounded hover:bg-slate-800 hover:text-slate-200 cursor-pointer truncate max-w-[160px] {i === crumbs.length - 1 ? 'text-slate-200' : ''}">{c.name}</button>
          {#if i < crumbs.length - 1}<span class="text-slate-600">/</span>{/if}
        {/each}
      </div>
    {/if}
  </div>

  <!-- Daftar file -->
  <div class="flex-1 min-h-0 overflow-auto">
    {#if error}
      <div class="m-2 flex gap-2 px-2.5 py-2 rounded-lg bg-rose-950/50 border border-rose-800/60 text-rose-200">
        <AlertTriangle class="w-3.5 h-3.5 flex-shrink-0 mt-px" />
        <span class="break-words min-w-0">{error}</span>
      </div>
    {/if}
    {#if loading && entries.length === 0}
      <div class="flex items-center justify-center gap-2 py-8 text-slate-500">
        <Loader2 class="w-4 h-4 animate-spin" /> Memuat…
      </div>
    {:else if !error && entries.length === 0}
      <div class="py-8 text-center text-slate-500">Folder kosong</div>
    {:else}
      {#each entries as entry (entry.name)}
        <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
        <div
          onclick={() => (selected = entry.name)}
          ondblclick={() => openEntry(entry)}
          title={entry.isDir ? 'Klik dua kali untuk membuka' : 'Klik dua kali untuk download'}
          class="group flex items-center gap-2 px-2 py-1 cursor-default select-none {selected === entry.name ? 'bg-blue-600/20' : 'hover:bg-slate-900'}"
        >
          {#if entry.isDir}
            <Folder class="w-3.5 h-3.5 flex-shrink-0 text-amber-400" />
          {:else}
            <FileIcon class="w-3.5 h-3.5 flex-shrink-0 text-slate-500" />
          {/if}
          <span class="truncate flex-1 min-w-0 {entry.isDir ? 'text-slate-100' : 'text-slate-300'}">{entry.name}</span>
          {#if entry.isLink}
            <Link2 class="w-3 h-3 flex-shrink-0 text-slate-500" />
          {/if}
          {#if !entry.isDir}
            <span class="text-[10.5px] text-slate-500 tabular-nums flex-shrink-0 group-hover:hidden">{formatSize(entry.size)}</span>
            <button
              onclick={(e) => { e.stopPropagation(); download(entry); }}
              title="Download"
              class="hidden group-hover:block p-0.5 rounded text-slate-400 hover:text-white hover:bg-slate-700 cursor-pointer flex-shrink-0"
            >
              <Download class="w-3.5 h-3.5" />
            </button>
          {/if}
          <span class="w-[86px] text-right text-[10.5px] text-slate-600 tabular-nums flex-shrink-0">{formatDate(entry.modified)}</span>
        </div>
      {/each}
    {/if}
  </div>

  <!-- Tujuan download -->
  <div class="px-2 py-1.5 border-t border-slate-800 flex items-center gap-1.5 text-[11px] text-slate-500 flex-shrink-0">
    <Download class="w-3 h-3 flex-shrink-0" />
    <span class="flex-shrink-0">Simpan ke</span>
    <button onclick={pickDownloadDir} title={downloadDir ?? defaultDownloadDir ?? 'Folder Downloads'} class="truncate text-slate-300 hover:text-white hover:underline cursor-pointer min-w-0">
      {dirName(downloadDir)}
    </button>
    {#if downloadDir}
      <button onclick={resetDownloadDir} title="Kembali ke folder Downloads" class="text-slate-500 hover:text-slate-300 cursor-pointer flex-shrink-0">(reset)</button>
    {/if}
  </div>

  <!-- Transfer -->
  {#if transfers.length > 0}
    <div class="border-t border-slate-800 max-h-[38%] flex flex-col flex-shrink-0">
      <div class="px-2 py-1 flex items-center text-[10.5px] uppercase tracking-wide text-slate-500">
        <span class="mr-auto">Transfer</span>
        {#if hasFinished}
          <button onclick={() => clearFinishedSftpTransfers(sessionId)} class="normal-case tracking-normal hover:text-slate-300 cursor-pointer">Bersihkan</button>
        {/if}
      </div>
      <div class="overflow-auto pb-1">
        {#each transfers as t (t.id)}
          <div class="px-2 py-1.5">
            <div class="flex items-center gap-1.5">
              {#if t.kind === 'upload'}
                <Upload class="w-3 h-3 flex-shrink-0 text-blue-400" />
              {:else}
                <Download class="w-3 h-3 flex-shrink-0 text-emerald-400" />
              {/if}
              <span class="truncate flex-1 min-w-0 text-slate-300" title={t.name}>{t.name}</span>
              {#if t.status === 'running'}
                <span class="text-[10.5px] text-slate-500 tabular-nums flex-shrink-0">
                  {formatSize(t.done)}{t.total ? ` / ${formatSize(t.total)}` : ''}
                </span>
                <button onclick={() => cancelSftpTransfer(t.id)} title="Batalkan" class="p-0.5 rounded text-slate-500 hover:text-rose-300 hover:bg-slate-800 cursor-pointer flex-shrink-0">
                  <X class="w-3 h-3" />
                </button>
              {:else if t.status === 'done'}
                <CircleCheck class="w-3.5 h-3.5 flex-shrink-0 text-emerald-400" />
                {#if t.localPath}
                  <button onclick={() => ipc.revealInFolder(t.localPath!).catch(() => {})} class="text-[10.5px] text-blue-400 hover:underline cursor-pointer flex-shrink-0">Tampilkan</button>
                {/if}
              {:else}
                <span class="text-[10.5px] flex-shrink-0 {t.status === 'cancelled' ? 'text-slate-500' : 'text-rose-400'}">{t.status === 'cancelled' ? 'Dibatalkan' : 'Gagal'}</span>
              {/if}
            </div>
            {#if t.status === 'running'}
              <div class="mt-1 h-1 rounded-full bg-slate-800 overflow-hidden">
                {#if t.total}
                  <div class="h-full bg-blue-500 transition-[width] duration-150" style="width: {Math.min(100, (t.done / t.total) * 100)}%"></div>
                {:else}
                  <div class="h-full w-1/3 bg-blue-500/70 animate-pulse"></div>
                {/if}
              </div>
            {:else if t.status === 'error' && t.error}
              <div class="mt-0.5 text-[10.5px] text-rose-300/80 break-words">{t.error}</div>
            {/if}
          </div>
        {/each}
      </div>
    </div>
  {/if}

  {#if dropActive}
    <div class="absolute inset-0 z-10 flex flex-col items-center justify-center gap-2 bg-blue-950/80 border-2 border-dashed border-blue-500 text-blue-100 pointer-events-none">
      <Upload class="w-6 h-6" />
      <span class="font-semibold">Lepas untuk upload</span>
      <span class="font-mono text-[11px] text-blue-200/80 px-4 text-center break-all">{path}</span>
    </div>
  {/if}
</div>
