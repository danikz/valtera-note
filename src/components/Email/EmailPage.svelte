<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import {
    Mail,
    MailOpen,
    Plus,
    Trash2,
    Pencil,
    Loader2,
    Lock,
    AlertTriangle,
    RefreshCw,
    Paperclip,
    Eye,
    EyeOff,
    ImageOff,
    X,
    Inbox,
    Check,
    Minus
  } from 'lucide-svelte';
  import DOMPurify from 'dompurify';
  import { open as shellOpen } from '@tauri-apps/plugin-shell';
  import { ipc, type MailSummary, type MailMessage } from '../../services/ipc';
  import { formatDateTime, getDisplayTimezone } from '../../utils/time';

  // Halaman ini hanya untuk membaca dan menghapus email — tidak ada kirim,
  // balas, atau pindah folder. Membaca memakai mode read-only (EXAMINE +
  // BODY.PEEK) sehingga status "belum dibaca" di server tidak berubah.
  // Hapus = pindah ke folder Sampah (permanen hanya dengan konfirmasi).

  interface EmailAccount {
    id: string;
    label: string;
    payload: string; // ciphertext enc:v1:...
    updated_at: string;
  }

  interface EmailPayload {
    email: string;
    password: string;
    host: string;
    port: number;
  }

  // Server IMAP Hostinger berlaku untuk semua domain yang di-host di sana.
  const DEFAULT_HOST = 'imap.hostinger.com';
  const DEFAULT_PORT = 993;
  const PAGE_SIZE = 50;
  const AUTO_CHECK_MS = 2 * 60 * 1000;

  let e2eState = $state<'none' | 'locked' | 'ready'>('ready');
  let accounts = $state<EmailAccount[]>([]);
  // Alamat email per akun (dibaca dari payload terenkripsi) — untuk grup domain.
  let accountEmails = $state<Record<string, string>>({});
  let unseenCounts = $state<Record<string, number>>({});
  let accountErrors = $state<Record<string, string>>({});
  let isLoadingAccounts = $state(true);

  // Inbox akun terpilih
  let selectedId = $state<string | null>(null);
  let messages = $state<MailSummary[]>([]);
  let total = $state(0);
  let hasMore = $state(false);
  let isLoadingInbox = $state(false);
  let isLoadingMore = $state(false);
  let inboxError = $state('');
  // Status "dibuka" lokal saja — server tetap menganggap email belum dibaca.
  let openedUids = $state<Record<number, boolean>>({});

  // Tandai (checkbox) untuk hapus cepat
  let checked = $state<Record<number, boolean>>({});
  let lastCheckedIndex = $state<number | null>(null);
  let isDeleting = $state(false);
  let notice = $state('');
  let noticeTimer: ReturnType<typeof setTimeout> | null = null;
  const checkedUids = $derived(messages.filter((m) => checked[m.uid]).map((m) => m.uid));
  const allChecked = $derived(messages.length > 0 && checkedUids.length === messages.length);

  // Pembaca
  let selectedUid = $state<number | null>(null);
  let current = $state<MailMessage | null>(null);
  let isLoadingMessage = $state(false);
  let messageError = $state('');
  let allowRemote = $state(false);

  // Form akun
  let showForm = $state(false);
  let editingId = $state<string | null>(null);
  let formEmail = $state('');
  let formPassword = $state('');
  let formLabel = $state('');
  let formHost = $state(DEFAULT_HOST);
  let formPort = $state(DEFAULT_PORT);
  let showPassword = $state(false);
  let isSaving = $state(false);
  let formError = $state('');

  let autoCheckTimer: ReturnType<typeof setInterval> | null = null;
  // Respons inbox/pesan yang datang terlambat setelah pengguna berpindah diabaikan.
  let inboxRequest = 0;
  let messageRequest = 0;

  const selectedAccount = $derived(accounts.find((a) => a.id === selectedId) ?? null);

  // Akun dikelompokkan per domain email (mis. valtera.id, domainlain.com).
  const domainGroups = $derived.by(() => {
    const map = new Map<string, EmailAccount[]>();
    for (const a of accounts) {
      const email = accountEmails[a.id] ?? '';
      const domain = email.includes('@') ? email.split('@')[1].toLowerCase() : '';
      if (!map.has(domain)) map.set(domain, []);
      map.get(domain)!.push(a);
    }
    return [...map.entries()]
      .sort((a, b) => (a[0] || '~').localeCompare(b[0] || '~'))
      .map(([domain, items]) => ({ domain, items }));
  });

  onMount(async () => {
    e2eState = await ipc.e2eStatus();
    if (e2eState !== 'ready') {
      isLoadingAccounts = false;
      return;
    }
    await refreshAccounts();
    if (accounts.length === 0) {
      openNewForm();
    } else {
      selectAccount(accounts[0].id);
      refreshUnseenCounts();
    }
    window.addEventListener('keydown', handleKeyDown);
    autoCheckTimer = setInterval(() => {
      if (selectedId && !isLoadingInbox) checkNew();
    }, AUTO_CHECK_MS);
  });

  onDestroy(() => {
    if (autoCheckTimer) clearInterval(autoCheckTimer);
    if (noticeTimer) clearTimeout(noticeTimer);
    window.removeEventListener('keydown', handleKeyDown);
  });

  function errText(e: any): string {
    return typeof e === 'string' ? e : e?.message || String(e);
  }

  async function decryptPayload(payload: string): Promise<EmailPayload> {
    return JSON.parse(await ipc.decryptContent(payload));
  }

  async function refreshAccounts() {
    isLoadingAccounts = true;
    try {
      accounts = await ipc.emailAccountList();
      const emails: Record<string, string> = {};
      for (const a of accounts) {
        try {
          emails[a.id] = (await decryptPayload(a.payload)).email;
        } catch {
          emails[a.id] = '';
        }
      }
      accountEmails = emails;
    } catch (e) {
      console.warn('Gagal memuat akun email:', e);
    } finally {
      isLoadingAccounts = false;
    }
  }

  // Jumlah belum dibaca tiap akun (paralel, cukup 1 pesan per akun).
  function refreshUnseenCounts() {
    for (const a of accounts) {
      if (a.id === selectedId) continue; // akun aktif diisi oleh loadInbox
      ipc
        .emailInbox(a.id, null, 1)
        .then((page) => {
          unseenCounts[a.id] = page.unseen;
          delete accountErrors[a.id];
        })
        .catch((e) => {
          accountErrors[a.id] = errText(e);
        });
    }
  }

  function selectAccount(id: string) {
    if (selectedId === id && !showForm) return;
    showForm = false;
    selectedId = id;
    messages = [];
    total = 0;
    hasMore = false;
    openedUids = {};
    clearChecks();
    closeMessage();
    loadInbox();
  }

  async function loadInbox() {
    if (!selectedId) return;
    const id = selectedId;
    const req = ++inboxRequest;
    isLoadingInbox = true;
    inboxError = '';
    try {
      const page = await ipc.emailInbox(id, null, PAGE_SIZE);
      if (req !== inboxRequest) return;
      messages = page.messages;
      total = page.total;
      hasMore = page.hasMore;
      unseenCounts[id] = page.unseen;
      delete accountErrors[id];
    } catch (e) {
      if (req !== inboxRequest) return;
      inboxError = errText(e);
      accountErrors[id] = inboxError;
    } finally {
      if (req === inboxRequest) isLoadingInbox = false;
    }
  }

  async function loadMore() {
    if (!selectedId || messages.length === 0 || isLoadingMore) return;
    const id = selectedId;
    const req = inboxRequest;
    isLoadingMore = true;
    try {
      const lastUid = messages[messages.length - 1].uid;
      const page = await ipc.emailInbox(id, lastUid, PAGE_SIZE);
      if (req !== inboxRequest) return;
      messages = [...messages, ...page.messages];
      hasMore = page.hasMore;
      total = page.total;
    } catch (e) {
      if (req === inboxRequest) inboxError = errText(e);
    } finally {
      isLoadingMore = false;
    }
  }

  // Cek email baru tanpa mengganggu halaman yang sudah dimuat.
  async function checkNew() {
    if (!selectedId) return;
    const id = selectedId;
    const req = inboxRequest;
    try {
      const page = await ipc.emailInbox(id, null, PAGE_SIZE);
      if (req !== inboxRequest || id !== selectedId) return;
      const newest = messages[0]?.uid ?? 0;
      const fresh = page.messages.filter((m) => m.uid > newest);
      if (fresh.length > 0) messages = [...fresh, ...messages];
      total = page.total;
      unseenCounts[id] = page.unseen;
    } catch {
      /* cek otomatis gagal — dicoba lagi pada interval berikutnya */
    }
  }

  async function openMessage(m: MailSummary) {
    if (!selectedId) return;
    const id = selectedId;
    const req = ++messageRequest;
    selectedUid = m.uid;
    current = null;
    messageError = '';
    allowRemote = false;
    isLoadingMessage = true;
    try {
      const msg = await ipc.emailMessage(id, m.uid);
      if (req !== messageRequest) return;
      current = msg;
      openedUids[m.uid] = true;
    } catch (e) {
      if (req === messageRequest) messageError = errText(e);
    } finally {
      if (req === messageRequest) isLoadingMessage = false;
    }
  }

  function closeMessage() {
    messageRequest++;
    selectedUid = null;
    current = null;
    messageError = '';
    isLoadingMessage = false;
  }

  // ===== Tandai & hapus =====

  function clearChecks() {
    checked = {};
    lastCheckedIndex = null;
  }

  // Shift+klik menandai satu rentang sekaligus.
  function toggleCheck(index: number, shift: boolean) {
    const uid = messages[index].uid;
    const value = !checked[uid];
    if (shift && lastCheckedIndex !== null && lastCheckedIndex < messages.length) {
      const [from, to] = [Math.min(lastCheckedIndex, index), Math.max(lastCheckedIndex, index)];
      for (let i = from; i <= to; i++) checked[messages[i].uid] = value;
    } else {
      checked[uid] = value;
    }
    lastCheckedIndex = index;
  }

  function toggleAll() {
    if (allChecked) {
      clearChecks();
    } else {
      const next: Record<number, boolean> = {};
      for (const m of messages) next[m.uid] = true;
      checked = next;
    }
  }

  function showNotice(text: string) {
    notice = text;
    if (noticeTimer) clearTimeout(noticeTimer);
    noticeTimer = setTimeout(() => (notice = ''), 4000);
  }

  async function deleteUids(uids: number[]) {
    if (!selectedId || uids.length === 0 || isDeleting) return;
    const id = selectedId;
    isDeleting = true;
    inboxError = '';
    try {
      let res = await ipc.emailDelete(id, uids, false);
      if (res.needsPermanent) {
        const ok = confirm(
          `Folder Sampah tidak ditemukan di server.\n\nHapus PERMANEN ${uids.length} email? Tindakan ini tidak bisa dibatalkan.`
        );
        if (!ok) return;
        res = await ipc.emailDelete(id, uids, true);
      }
      if (id !== selectedId) return;
      const gone = new Set(uids);
      const removedUnseen = messages.filter((m) => gone.has(m.uid) && !m.seen).length;
      messages = messages.filter((m) => !gone.has(m.uid));
      total = Math.max(0, total - res.deleted);
      unseenCounts[id] = Math.max(0, (unseenCounts[id] ?? 0) - removedUnseen);
      for (const u of uids) delete checked[u];
      lastCheckedIndex = null;
      if (selectedUid !== null && gone.has(selectedUid)) closeMessage();
      showNotice(
        res.movedTo
          ? `${res.deleted} email dipindah ke ${res.movedTo}`
          : `${res.deleted} email dihapus permanen`
      );
      // Isi ulang daftar bila halaman yang tampil habis terhapus.
      if (messages.length === 0 && hasMore) loadInbox();
    } catch (e) {
      inboxError = errText(e);
    } finally {
      isDeleting = false;
    }
  }

  // Tombol Delete: hapus email yang ditandai, atau email yang sedang dibuka.
  function handleKeyDown(e: KeyboardEvent) {
    if (e.key !== 'Delete' || showForm || !selectedId) return;
    const t = e.target as HTMLElement | null;
    if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.isContentEditable)) return;
    const uids = checkedUids.length > 0 ? checkedUids : selectedUid !== null ? [selectedUid] : [];
    if (uids.length === 0) return;
    e.preventDefault();
    deleteUids(uids);
  }

  // ===== Form akun =====

  function openNewForm() {
    editingId = null;
    formEmail = '';
    formPassword = '';
    formLabel = '';
    formHost = DEFAULT_HOST;
    formPort = DEFAULT_PORT;
    showPassword = false;
    formError = '';
    showForm = true;
  }

  async function openEditForm(a: EmailAccount) {
    editingId = a.id;
    formPassword = ''; // kosong = pertahankan password tersimpan
    formLabel = a.label;
    showPassword = false;
    formError = '';
    try {
      const p = await decryptPayload(a.payload);
      formEmail = p.email;
      formHost = p.host || DEFAULT_HOST;
      formPort = p.port || DEFAULT_PORT;
    } catch {
      formEmail = accountEmails[a.id] ?? '';
      formHost = DEFAULT_HOST;
      formPort = DEFAULT_PORT;
      formError = 'Gagal membaca kredensial tersimpan — isi ulang password.';
    }
    showForm = true;
  }

  function cancelForm() {
    showForm = false;
    formError = '';
    if (!selectedId && accounts.length > 0) selectAccount(accounts[0].id);
  }

  async function saveAccount() {
    formError = '';
    const email = formEmail.trim();
    const host = formHost.trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      formError = 'Alamat email tidak valid.';
      return;
    }
    if (!host) {
      formError = 'Server IMAP wajib diisi.';
      return;
    }
    if (!formPassword && !editingId) {
      formError = 'Password wajib diisi.';
      return;
    }
    isSaving = true;
    try {
      let password = formPassword;
      if (!password && editingId) {
        const stored = accounts.find((a) => a.id === editingId);
        if (!stored) throw new Error('Akun tidak ditemukan.');
        password = (await decryptPayload(stored.payload)).password;
      }
      const port = Number(formPort) || DEFAULT_PORT;
      // Uji login dulu: gagal = error di form, kredensial TIDAK disimpan.
      await ipc.emailTest(email, password, host, port);

      const id = editingId ?? crypto.randomUUID();
      const payload = await ipc.encryptContent(JSON.stringify({ email, password, host, port } satisfies EmailPayload));
      await ipc.emailAccountSave(id, formLabel.trim() || email, payload);
      await refreshAccounts();
      showForm = false;
      selectedId = null; // paksa muat ulang inbox dengan kredensial baru
      selectAccount(id);
    } catch (e) {
      formError = errText(e);
    } finally {
      isSaving = false;
    }
  }

  async function deleteAccount(a: EmailAccount) {
    const email = accountEmails[a.id] || a.label;
    if (!confirm(`Hapus akun ${email} dari aplikasi?\n\nEmail di server tidak terpengaruh.`)) return;
    try {
      await ipc.emailAccountDelete(a.id);
      delete unseenCounts[a.id];
      delete accountErrors[a.id];
      await refreshAccounts();
      if (selectedId === a.id) {
        selectedId = null;
        messages = [];
        closeMessage();
        if (accounts.length > 0) selectAccount(accounts[0].id);
        else openNewForm();
      }
    } catch (e) {
      inboxError = errText(e);
    }
  }

  // ===== Tampilan =====

  function shortDate(ts: number | null): string {
    if (!ts) return '';
    const d = new Date(ts * 1000);
    const tz = getDisplayTimezone();
    const dayKey = (x: Date) => x.toLocaleDateString('en-CA', { timeZone: tz });
    if (dayKey(d) === dayKey(new Date())) {
      return d.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit', hourCycle: 'h23', timeZone: tz });
    }
    const sameYear = d.toLocaleDateString('en-CA', { year: 'numeric', timeZone: tz }) ===
      new Date().toLocaleDateString('en-CA', { year: 'numeric', timeZone: tz });
    return d.toLocaleDateString('id-ID', {
      day: 'numeric',
      month: 'short',
      ...(sameYear ? {} : { year: 'numeric' }),
      timeZone: tz
    });
  }

  function formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
    return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
  }

  const REMOTE_RE = /(?:src|background|poster)\s*=\s*["']?\s*(?:https?:)?\/\/|url\(\s*["']?\s*(?:https?:)?\/\//i;

  // HTML email: disanitasi DOMPurify, dirender di iframe sandbox tanpa script.
  // CSP di dalam dokumen memblokir semua muatan remote (pelacak/pixel) sampai
  // pengguna mengizinkan gambar eksternal.
  const rendered = $derived.by(() => {
    if (!current?.html) return null;
    const dom = DOMPurify.sanitize(current.html, {
      WHOLE_DOCUMENT: true,
      RETURN_DOM: true,
      FORBID_TAGS: ['form', 'input', 'button', 'textarea', 'select', 'iframe', 'frame', 'object', 'embed', 'base', 'meta', 'link', 'script']
    }) as HTMLElement;
    const headStyles = [...dom.querySelectorAll('head style')].map((s) => s.outerHTML).join('');
    const body = dom.querySelector('body')?.innerHTML ?? '';
    const hasRemote = REMOTE_RE.test(headStyles + body);
    const remote = allowRemote ? ' https: http:' : '';
    const csp = `default-src 'none'; img-src data:${remote}; style-src 'unsafe-inline'${remote}; font-src data:${remote}`;
    const doc = `<!doctype html><html><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="${csp}">` +
      `<style>html,body{background:#fff;color:#1f2937}body{margin:16px;font:14px/1.5 -apple-system,'Segoe UI',Roboto,Arial,sans-serif;word-wrap:break-word;overflow-wrap:anywhere}img{max-width:100%;height:auto}table{max-width:100%}a{color:#2563eb}</style>` +
      `${headStyles}</head><body>${body}</body></html>`;
    return { doc, hasRemote };
  });

  // Tautan di email dibuka di browser bawaan, bukan di dalam aplikasi.
  function wireFrameLinks(e: Event) {
    const frame = e.currentTarget as HTMLIFrameElement;
    const doc = frame.contentDocument;
    if (!doc) return;
    doc.addEventListener('click', (ev) => {
      const a = (ev.target as Element | null)?.closest?.('a[href]') as HTMLAnchorElement | null;
      if (!a) return;
      ev.preventDefault();
      const href = a.getAttribute('href') ?? '';
      if (/^(https?:|mailto:)/i.test(href)) {
        shellOpen(href).catch((err) => console.warn('Gagal membuka tautan:', err));
      }
    });
  }

  function displayFrom(m: { fromName: string; fromAddr: string }): string {
    return m.fromName || m.fromAddr || '(tanpa pengirim)';
  }
</script>

<!-- Kotak centang buatan sendiri: checkbox bawaan WebView sulit dilihat di tema gelap. -->
{#snippet checkBox(on: boolean, partial: boolean)}
  <span
    class="w-4 h-4 rounded flex items-center justify-center border transition-colors {on || partial ? 'bg-sky-500 border-sky-400' : 'border-slate-500 bg-slate-900 hover:border-sky-400'}"
  >
    {#if on}
      <Check class="w-3 h-3 text-white" strokeWidth={3.5} />
    {:else if partial}
      <Minus class="w-3 h-3 text-white" strokeWidth={3.5} />
    {/if}
  </span>
{/snippet}

<div class="h-full flex flex-col overflow-hidden">
  <!-- Header -->
  <div class="px-4 py-3 border-b border-slate-800 flex items-center justify-between flex-shrink-0">
    <div class="flex items-center space-x-2">
      <Mail class="w-4 h-4 text-sky-400" />
      <h2 class="text-sm font-bold text-slate-100">Inbox Email</h2>
      <span class="text-[10px] font-mono text-slate-500">IMAP · baca &amp; hapus · kredensial terenkripsi E2E</span>
    </div>
  </div>

  {#if e2eState === 'none'}
    <div class="flex-1 flex items-center justify-center p-8">
      <div class="max-w-md text-center space-y-3">
        <Lock class="w-10 h-10 text-amber-400 mx-auto" />
        <h3 class="text-sm font-bold text-slate-100">Perlu Master Password</h3>
        <p class="text-xs text-slate-400 leading-relaxed">
          Password email dienkripsi dengan kunci master password E2E. Atur master password terlebih dahulu
          di <strong class="text-slate-200">Pengaturan → Keamanan</strong>, lalu kembali ke sini.
        </p>
      </div>
    </div>
  {:else if e2eState === 'locked'}
    <div class="flex-1 flex items-center justify-center p-8">
      <div class="max-w-md text-center space-y-3">
        <Lock class="w-10 h-10 text-amber-400 mx-auto" />
        <h3 class="text-sm font-bold text-slate-100">Aplikasi Terkunci</h3>
        <p class="text-xs text-slate-400">Buka kunci dengan master password untuk membaca email.</p>
      </div>
    </div>
  {:else}
    <div class="flex-1 flex overflow-hidden">
      <!-- Kiri: akun per domain -->
      <div class="w-60 flex-shrink-0 border-r border-slate-800 flex flex-col overflow-hidden">
        <div class="px-3 py-2 border-b border-slate-800/80 flex items-center justify-between">
          <span class="text-[11px] font-bold text-slate-300 uppercase tracking-wider">Akun Email</span>
          <button
            onclick={openNewForm}
            title="Tambah akun email"
            class="p-1 rounded text-slate-400 hover:text-sky-300 hover:bg-slate-800 transition-colors cursor-pointer"
          >
            <Plus class="w-3.5 h-3.5" />
          </button>
        </div>
        <div class="flex-1 overflow-y-auto p-2 space-y-3">
          {#if isLoadingAccounts}
            <div class="flex items-center justify-center py-6 text-slate-500">
              <Loader2 class="w-4 h-4 animate-spin" />
            </div>
          {:else if accounts.length === 0}
            <p class="text-[11px] text-slate-500 px-1 py-2 leading-relaxed">
              Belum ada akun. Klik <strong class="text-slate-300">+</strong> untuk menambah email (mis. dari Hostinger).
            </p>
          {:else}
            {#each domainGroups as group (group.domain)}
              <div>
                <p class="px-1 pb-1 text-[10px] font-mono text-slate-500 uppercase tracking-wider truncate">
                  @{group.domain || 'lainnya'}
                </p>
                <div class="space-y-1">
                  {#each group.items as a (a.id)}
                    {@const unseen = unseenCounts[a.id] ?? 0}
                    {@const active = selectedId === a.id && !showForm}
                    <div
                      class="group rounded-lg border px-2.5 py-2 transition-colors {active ? 'border-sky-500/60 bg-sky-950/20' : editingId === a.id && showForm ? 'border-sky-600/40 bg-slate-900' : 'border-slate-800 bg-slate-900/60 hover:border-slate-700'}"
                    >
                      <div class="flex items-center justify-between gap-1">
                        <button onclick={() => selectAccount(a.id)} class="flex-1 min-w-0 text-left cursor-pointer">
                          <p class="text-xs font-semibold text-slate-200 truncate flex items-center gap-1.5">
                            {#if accountErrors[a.id]}
                              <span title={accountErrors[a.id]}><AlertTriangle class="w-3 h-3 text-rose-400 flex-shrink-0" /></span>
                            {/if}
                            <span class="truncate">{a.label}</span>
                          </p>
                          {#if accountEmails[a.id] && accountEmails[a.id] !== a.label}
                            <p class="text-[10px] text-slate-500 truncate">{accountEmails[a.id]}</p>
                          {/if}
                        </button>
                        {#if unseen > 0}
                          <span class="px-1.5 rounded-full bg-sky-600 text-[9.5px] font-bold text-white flex-shrink-0" title="{unseen} belum dibaca">{unseen > 999 ? '999+' : unseen}</span>
                        {/if}
                        <div class="hidden group-hover:flex items-center flex-shrink-0">
                          <button
                            onclick={() => openEditForm(a)}
                            title="Edit akun"
                            class="p-1 rounded text-slate-500 hover:text-slate-200 hover:bg-slate-800 transition-colors cursor-pointer"
                          >
                            <Pencil class="w-3 h-3" />
                          </button>
                          <button
                            onclick={() => deleteAccount(a)}
                            title="Hapus akun dari aplikasi"
                            class="p-1 rounded text-slate-500 hover:text-rose-300 hover:bg-slate-800 transition-colors cursor-pointer"
                          >
                            <Trash2 class="w-3 h-3" />
                          </button>
                        </div>
                      </div>
                    </div>
                  {/each}
                </div>
              </div>
            {/each}
          {/if}
        </div>
      </div>

      {#if showForm}
        <!-- Form tambah / edit akun -->
        <div class="flex-1 overflow-y-auto p-6">
          <div class="max-w-md space-y-4">
            <div class="flex items-center justify-between">
              <h3 class="text-sm font-bold text-slate-100">{editingId ? 'Edit Akun Email' : 'Tambah Akun Email'}</h3>
              {#if accounts.length > 0}
                <button onclick={cancelForm} title="Batal" class="p-1 rounded text-slate-500 hover:text-slate-200 hover:bg-slate-800 cursor-pointer">
                  <X class="w-4 h-4" />
                </button>
              {/if}
            </div>
            <p class="text-[11px] text-slate-400 leading-relaxed">
              Tiap akun berdiri sendiri — tambahkan satu per alamat email, boleh dari domain berbeda.
              Untuk email Hostinger, server <code class="text-sky-300">{DEFAULT_HOST}</code> port <code class="text-sky-300">{DEFAULT_PORT}</code> berlaku untuk semua domain.
            </p>

            <label class="block space-y-1">
              <span class="text-[11px] font-semibold text-slate-300">Alamat email</span>
              <input
                bind:value={formEmail}
                type="email"
                placeholder="nama@domainanda.com"
                autocomplete="off"
                class="w-full px-3 py-2 rounded-lg bg-slate-950 border border-slate-700 text-xs text-slate-100 placeholder-slate-600 focus:outline-none focus:border-sky-500"
              />
            </label>

            <label class="block space-y-1">
              <span class="text-[11px] font-semibold text-slate-300">Password email</span>
              <div class="relative">
                <input
                  bind:value={formPassword}
                  type={showPassword ? 'text' : 'password'}
                  placeholder={editingId ? 'Kosongkan untuk tetap memakai password tersimpan' : 'Password kotak masuk'}
                  autocomplete="new-password"
                  onkeydown={(e) => e.key === 'Enter' && !isSaving && saveAccount()}
                  class="w-full px-3 py-2 pr-9 rounded-lg bg-slate-950 border border-slate-700 text-xs text-slate-100 placeholder-slate-600 focus:outline-none focus:border-sky-500"
                />
                <button
                  type="button"
                  onclick={() => (showPassword = !showPassword)}
                  title={showPassword ? 'Sembunyikan' : 'Tampilkan'}
                  class="absolute right-2 top-1/2 -translate-y-1/2 p-0.5 text-slate-500 hover:text-slate-300 cursor-pointer"
                >
                  {#if showPassword}<EyeOff class="w-3.5 h-3.5" />{:else}<Eye class="w-3.5 h-3.5" />{/if}
                </button>
              </div>
            </label>

            <label class="block space-y-1">
              <span class="text-[11px] font-semibold text-slate-300">Nama tampilan <span class="font-normal text-slate-500">(opsional)</span></span>
              <input
                bind:value={formLabel}
                placeholder="mis. CS Valtera"
                class="w-full px-3 py-2 rounded-lg bg-slate-950 border border-slate-700 text-xs text-slate-100 placeholder-slate-600 focus:outline-none focus:border-sky-500"
              />
            </label>

            <div class="flex gap-2">
              <label class="block space-y-1 flex-1">
                <span class="text-[11px] font-semibold text-slate-300">Server IMAP</span>
                <input
                  bind:value={formHost}
                  class="w-full px-3 py-2 rounded-lg bg-slate-950 border border-slate-700 text-xs font-mono text-slate-100 focus:outline-none focus:border-sky-500"
                />
              </label>
              <label class="block space-y-1 w-24">
                <span class="text-[11px] font-semibold text-slate-300">Port SSL</span>
                <input
                  bind:value={formPort}
                  type="number"
                  min="1"
                  max="65535"
                  class="w-full px-3 py-2 rounded-lg bg-slate-950 border border-slate-700 text-xs font-mono text-slate-100 focus:outline-none focus:border-sky-500"
                />
              </label>
            </div>

            {#if formError}
              <div class="flex items-start gap-2 px-3 py-2 rounded-lg bg-rose-950/40 border border-rose-800/60 text-[11px] text-rose-300">
                <AlertTriangle class="w-3.5 h-3.5 flex-shrink-0 mt-0.5" />
                <span>{formError}</span>
              </div>
            {/if}

            <button
              onclick={saveAccount}
              disabled={isSaving}
              class="w-full flex items-center justify-center gap-2 px-3 py-2 rounded-lg bg-sky-600 hover:bg-sky-500 disabled:opacity-60 text-xs font-semibold text-white transition-colors cursor-pointer disabled:cursor-default"
            >
              {#if isSaving}
                <Loader2 class="w-3.5 h-3.5 animate-spin" /><span>Menguji login…</span>
              {:else}
                <span>Uji Login &amp; Simpan</span>
              {/if}
            </button>
            <p class="text-[10px] text-slate-500 leading-relaxed">
              Login diuji ke server sebelum disimpan. Password disimpan terenkripsi di perangkat ini saja.
            </p>
          </div>
        </div>
      {:else if selectedAccount}
        <!-- Tengah: daftar email -->
        <div class="w-96 flex-shrink-0 border-r border-slate-800 flex flex-col overflow-hidden">
          <div class="px-3 py-2 border-b border-slate-800/80 flex items-center justify-between gap-2">
            <button
              role="checkbox"
              aria-checked={allChecked ? 'true' : checkedUids.length > 0 ? 'mixed' : 'false'}
              onclick={toggleAll}
              disabled={messages.length === 0}
              title="Tandai semua email yang tampil"
              class="flex-shrink-0 cursor-pointer disabled:opacity-40 disabled:cursor-default"
            >
              {@render checkBox(allChecked, checkedUids.length > 0 && !allChecked)}
            </button>
            <div class="min-w-0 flex-1">
              <p class="text-xs font-semibold text-slate-200 truncate">{accountEmails[selectedAccount.id] || selectedAccount.label}</p>
              <p class="text-[10px] text-slate-500">
                INBOX · {total} email{#if (unseenCounts[selectedAccount.id] ?? 0) > 0} · <span class="text-sky-400">{unseenCounts[selectedAccount.id]} belum dibaca</span>{/if}
              </p>
            </div>
            <button
              onclick={() => { loadInbox(); refreshUnseenCounts(); }}
              disabled={isLoadingInbox}
              title="Muat ulang"
              class="p-1.5 rounded text-slate-400 hover:text-sky-300 hover:bg-slate-800 transition-colors cursor-pointer disabled:cursor-default"
            >
              <RefreshCw class="w-3.5 h-3.5 {isLoadingInbox ? 'animate-spin' : ''}" />
            </button>
          </div>

          {#if checkedUids.length > 0}
            <div class="px-3 py-1.5 border-b border-slate-800/80 bg-sky-950/30 flex items-center justify-between gap-2">
              <span class="text-[11px] text-sky-200">{checkedUids.length} ditandai</span>
              <div class="flex items-center gap-1">
                <button
                  onclick={clearChecks}
                  class="px-2 py-1 rounded text-[10.5px] text-slate-400 hover:text-slate-200 hover:bg-slate-800 cursor-pointer"
                >
                  Batal
                </button>
                <button
                  onclick={() => deleteUids(checkedUids)}
                  disabled={isDeleting}
                  title="Pindahkan ke Sampah (Delete)"
                  class="flex items-center gap-1 px-2 py-1 rounded bg-rose-600 hover:bg-rose-500 disabled:opacity-60 text-[10.5px] font-semibold text-white cursor-pointer disabled:cursor-default"
                >
                  {#if isDeleting}<Loader2 class="w-3 h-3 animate-spin" />{:else}<Trash2 class="w-3 h-3" />{/if}
                  <span>Hapus</span>
                </button>
              </div>
            </div>
          {/if}
          {#if notice}
            <div class="px-3 py-1.5 border-b border-slate-800/80 bg-emerald-950/30 text-[10.5px] text-emerald-300">{notice}</div>
          {/if}

          <div class="flex-1 overflow-y-auto">
            {#if isLoadingInbox && messages.length === 0}
              <div class="flex items-center justify-center gap-2 py-10 text-xs text-slate-500">
                <Loader2 class="w-4 h-4 animate-spin" /><span>Memuat inbox…</span>
              </div>
            {:else if inboxError && messages.length === 0}
              <div class="m-3 flex items-start gap-2 px-3 py-2 rounded-lg bg-rose-950/40 border border-rose-800/60 text-[11px] text-rose-300">
                <AlertTriangle class="w-3.5 h-3.5 flex-shrink-0 mt-0.5" />
                <span>{inboxError}</span>
              </div>
            {:else if messages.length === 0}
              <div class="flex flex-col items-center justify-center gap-2 py-10 text-xs text-slate-500">
                <Inbox class="w-6 h-6" /><span>Inbox kosong</span>
              </div>
            {:else}
              {#each messages as m, i (m.uid)}
                {@const unread = !m.seen && !openedUids[m.uid]}
                <div
                  class="flex items-stretch border-b border-l-2 transition-colors {checked[m.uid] ? 'bg-sky-900/40 border-l-sky-400 border-b-sky-900/60' : selectedUid === m.uid ? 'bg-slate-800/70 border-l-slate-500 border-b-slate-800/70' : 'border-l-transparent border-b-slate-800/70 hover:bg-slate-900'}"
                >
                <button
                  role="checkbox"
                  aria-checked={!!checked[m.uid]}
                  onclick={(e) => toggleCheck(i, e.shiftKey)}
                  title="Tandai (Shift+klik untuk rentang)"
                  class="flex items-center pl-2.5 pr-1 cursor-pointer"
                >
                  {@render checkBox(!!checked[m.uid], false)}
                </button>
                <button
                  onclick={() => openMessage(m)}
                  class="flex-1 min-w-0 text-left pl-2 pr-3 py-2.5 cursor-pointer"
                >
                  <div class="flex items-center justify-between gap-2">
                    <span class="flex items-center gap-1.5 min-w-0">
                      {#if unread}<span class="w-1.5 h-1.5 rounded-full bg-sky-400 flex-shrink-0"></span>{/if}
                      <span class="text-xs truncate {unread ? 'font-bold text-slate-100' : 'font-medium text-slate-300'}">{displayFrom(m)}</span>
                    </span>
                    <span class="flex items-center gap-1 flex-shrink-0 text-[10px] {unread ? 'text-sky-300' : 'text-slate-500'}">
                      {#if m.hasAttachment}<Paperclip class="w-3 h-3" />{/if}
                      {shortDate(m.date)}
                    </span>
                  </div>
                  <p class="text-[11.5px] truncate mt-0.5 {unread ? 'text-slate-200 font-semibold' : 'text-slate-400'}">
                    {m.subject || '(tanpa subjek)'}
                  </p>
                </button>
                </div>
              {/each}
              {#if hasMore}
                <button
                  onclick={loadMore}
                  disabled={isLoadingMore}
                  class="w-full flex items-center justify-center gap-2 py-3 text-[11px] text-sky-300 hover:bg-slate-900 cursor-pointer disabled:cursor-default"
                >
                  {#if isLoadingMore}<Loader2 class="w-3.5 h-3.5 animate-spin" />{/if}
                  <span>Muat email lebih lama</span>
                </button>
              {/if}
              {#if inboxError}
                <p class="px-3 py-2 text-[10.5px] text-rose-300">{inboxError}</p>
              {/if}
            {/if}
          </div>
        </div>

        <!-- Kanan: pembaca email -->
        <div class="flex-1 flex flex-col overflow-hidden min-w-0">
          {#if isLoadingMessage}
            <div class="flex-1 flex items-center justify-center gap-2 text-xs text-slate-500">
              <Loader2 class="w-4 h-4 animate-spin" /><span>Membuka email…</span>
            </div>
          {:else if messageError}
            <div class="m-4 flex items-start gap-2 px-3 py-2 rounded-lg bg-rose-950/40 border border-rose-800/60 text-[11px] text-rose-300">
              <AlertTriangle class="w-3.5 h-3.5 flex-shrink-0 mt-0.5" />
              <span>{messageError}</span>
            </div>
          {:else if current}
            <div class="px-5 py-4 border-b border-slate-800 space-y-2 flex-shrink-0">
              <div class="flex items-start justify-between gap-3">
                <h3 class="text-base font-bold text-slate-100 break-words">{current.subject || '(tanpa subjek)'}</h3>
                <button
                  onclick={() => current && deleteUids([current.uid])}
                  disabled={isDeleting}
                  title="Hapus email ini (Delete)"
                  class="flex items-center gap-1 px-2 py-1 rounded-lg border border-slate-800 text-[10.5px] text-slate-400 hover:text-rose-300 hover:border-rose-800/60 hover:bg-rose-950/30 cursor-pointer disabled:cursor-default flex-shrink-0"
                >
                  {#if isDeleting}<Loader2 class="w-3 h-3 animate-spin" />{:else}<Trash2 class="w-3 h-3" />{/if}
                  <span>Hapus</span>
                </button>
              </div>
              <div class="text-[11px] text-slate-400 space-y-0.5">
                <p>
                  <span class="text-slate-500">Dari:</span>
                  <span class="text-slate-200 font-medium">{current.fromName || current.fromAddr}</span>
                  {#if current.fromName && current.fromAddr}<span class="text-slate-500">&lt;{current.fromAddr}&gt;</span>{/if}
                </p>
                {#if current.to.length > 0}
                  <p class="break-words"><span class="text-slate-500">Kepada:</span> {current.to.join(', ')}</p>
                {/if}
                {#if current.cc.length > 0}
                  <p class="break-words"><span class="text-slate-500">Cc:</span> {current.cc.join(', ')}</p>
                {/if}
                {#if current.date}
                  <p><span class="text-slate-500">Tanggal:</span> {formatDateTime(new Date(current.date * 1000))}</p>
                {/if}
              </div>
              {#if current.attachments.length > 0}
                <div class="flex flex-wrap gap-1.5 pt-1">
                  {#each current.attachments as att}
                    <span class="flex items-center gap-1 px-2 py-0.5 rounded-md bg-slate-900 border border-slate-800 text-[10.5px] text-slate-300" title={att.mime}>
                      <Paperclip class="w-3 h-3 text-slate-500" />
                      <span class="max-w-[220px] truncate">{att.name}</span>
                      <span class="text-slate-500">{formatSize(att.size)}</span>
                    </span>
                  {/each}
                </div>
              {/if}
              {#if rendered?.hasRemote}
                <div class="flex items-center gap-2 pt-1 text-[10.5px]">
                  {#if allowRemote}
                    <span class="text-slate-500">Gambar eksternal ditampilkan.</span>
                  {:else}
                    <ImageOff class="w-3 h-3 text-amber-400" />
                    <span class="text-amber-300/90">Gambar eksternal diblokir untuk privasi.</span>
                    <button onclick={() => (allowRemote = true)} class="text-sky-300 hover:underline cursor-pointer">Tampilkan gambar</button>
                  {/if}
                </div>
              {/if}
            </div>
            <div class="flex-1 overflow-hidden bg-white">
              {#if rendered}
                {#key rendered.doc}
                  <iframe
                    title="Isi email"
                    sandbox="allow-same-origin"
                    srcdoc={rendered.doc}
                    onload={wireFrameLinks}
                    class="w-full h-full border-0 bg-white"
                  ></iframe>
                {/key}
              {:else}
                <pre class="h-full overflow-auto p-5 text-[13px] leading-relaxed text-slate-800 whitespace-pre-wrap break-words font-sans">{current.text || '(email tanpa isi teks)'}</pre>
              {/if}
            </div>
          {:else}
            <div class="flex-1 flex flex-col items-center justify-center gap-2 text-xs text-slate-500">
              <MailOpen class="w-8 h-8 text-slate-700" />
              <span>Pilih email untuk dibaca</span>
            </div>
          {/if}
        </div>
      {:else}
        <div class="flex-1 flex flex-col items-center justify-center gap-2 text-xs text-slate-500">
          <Mail class="w-8 h-8 text-slate-700" />
          <span>Pilih akun email di sebelah kiri</span>
        </div>
      {/if}
    </div>
  {/if}
</div>
