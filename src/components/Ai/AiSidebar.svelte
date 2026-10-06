<script lang="ts">
  import { tick } from 'svelte';
  import {
    X,
    Sparkles,
    Loader2,
    Trash2,
    FileText,
    TextQuote,
    AlertTriangle,
    SendHorizonal,
    Settings2
  } from 'lucide-svelte';
  import { editorStore } from '../../stores/editorStore.svelte';
  import { ipc } from '../../services/ipc';

  let { isOpen, onClose, onOpenSettings }: { isOpen: boolean; onClose: () => void; onOpenSettings?: () => void } = $props();

  interface ChatMsg {
    role: 'user' | 'assistant';
    content: string;
  }

  const MAX_NOTE_CHARS = 12000;
  const MAX_SEL_CHARS = 4000;

  let messages = $state<ChatMsg[]>([]);
  let chatInput = $state('');
  let busy = $state(false);
  let includeNote = $state(true);
  let includeSelection = $state(true);
  let listEl: HTMLDivElement | null = null;
  let cfg = $state<{ kind: string; base_url: string; has_api_key: boolean; model: string } | null>(null);

  const tab = $derived(editorStore.activeTab);
  const selection = $derived(editorStore.selectionText || '');
  const isConfigured = $derived(!!cfg && cfg.has_api_key && !!cfg.base_url && !!cfg.model);

  $effect(() => {
    if (isOpen) {
      ipc.aiGetConfig().then((c) => (cfg = c));
    }
  });

  // Scroll ke bawah setiap ada pesan baru / status berubah.
  $effect(() => {
    void messages.length;
    void busy;
    if (listEl) {
      tick().then(() => {
        if (listEl) listEl.scrollTop = listEl.scrollHeight;
      });
    }
  });

  function buildSystem(): string {
    let system =
      'Kamu asisten AI dalam Valtera Note, aplikasi catatan desktop. Jawab padat, akurat, dan dalam Bahasa Indonesia kecuali user meminta bahasa lain. Gunakan markdown bila membantu.';
    const note = tab?.content || '';
    if (includeNote && tab && note.trim()) {
      const body = note.length > MAX_NOTE_CHARS ? note.slice(0, MAX_NOTE_CHARS) + '\n[...terpotong]' : note;
      system += `\n\n[Catatan aktif user: "${tab.title}"]\nIsi catatan:\n${body}`;
    }
    if (includeSelection && selection.trim()) {
      const sel = selection.length > MAX_SEL_CHARS ? selection.slice(0, MAX_SEL_CHARS) + '[...]' : selection;
      system += `\n\n[Teks yang sedang dipilih user di catatan itu]:\n${sel}`;
    }
    return system;
  }

  const canSend = $derived(!!chatInput.trim() && !busy);

  async function send() {
    const text = chatInput.trim();
    if (!text || busy) return;
    if (!isConfigured) {
      messages = [...messages, { role: 'assistant', content: '⚠️ AI belum dikonfigurasi. Buka Pengaturan → AI Assistant untuk mengatur provider, API key, dan model.' }];
      return;
    }

    const history = messages.map((m) => ({ role: m.role, content: m.content }));
    messages = [...messages, { role: 'user', content: text }];
    chatInput = '';
    busy = true;
    try {
      const reply = await ipc.aiComplete(buildSystem(), text, undefined, history);
      messages = [...messages, { role: 'assistant', content: reply }];
    } catch (e: any) {
      const msg = typeof e === 'string' ? e : e?.message || String(e);
      messages = [...messages, { role: 'assistant', content: `⚠️ ${msg}` }];
    } finally {
      busy = false;
    }
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      send();
    }
  }

  function clearChat() {
    messages = [];
    chatInput = '';
  }

  // Saran cepat saat obrolan masih kosong.
  function quick(prompt: string) {
    chatInput = prompt;
    send();
  }
</script>

{#if isOpen}
  <aside class="w-[360px] flex-shrink-0 h-full flex flex-col bg-slate-950 border-l border-slate-800 overflow-hidden">
    <!-- Header -->
    <div class="px-3.5 py-2.5 border-b border-slate-800 flex items-center justify-between bg-slate-900/60">
      <div class="flex items-center space-x-2 min-w-0">
        <Sparkles class="w-4 h-4 text-violet-400 flex-shrink-0" />
        <span class="text-xs font-bold text-slate-100">AI Chat</span>
        {#if isConfigured}
          <span class="text-[9.5px] font-mono text-slate-500 truncate">{cfg?.model}</span>
        {/if}
      </div>
      <div class="flex items-center space-x-1">
        {#if messages.length > 0}
          <button
            onclick={clearChat}
            title="Hapus obrolan"
            class="p-1.5 rounded-lg text-slate-400 hover:text-rose-300 hover:bg-slate-800 transition-colors cursor-pointer"
          >
            <Trash2 class="w-3.5 h-3.5" />
          </button>
        {/if}
        <button
          onclick={onClose}
          title="Tutup panel AI"
          class="p-1.5 rounded-lg text-slate-400 hover:text-slate-200 hover:bg-slate-800 transition-colors cursor-pointer"
        >
          <X class="w-3.5 h-3.5" />
        </button>
      </div>
    </div>

    <!-- Context toggles -->
    <div class="px-3.5 py-2 border-b border-slate-800/80 space-y-1.5 bg-slate-900/30">
      <label
        class="flex items-center space-x-2 text-[10.5px] {tab ? 'text-slate-300 cursor-pointer' : 'text-slate-600 cursor-not-allowed'}"
      >
        <input type="checkbox" bind:checked={includeNote} disabled={!tab} class="accent-violet-500 w-3 h-3" />
        <FileText class="w-3 h-3 text-blue-400 flex-shrink-0" />
        <span class="truncate">
          {tab ? `Baca catatan aktif: ${tab.title}` : 'Tidak ada catatan aktif'}
        </span>
      </label>
      <label
        class="flex items-center space-x-2 text-[10.5px] {selection.trim() ? 'text-slate-300 cursor-pointer' : 'text-slate-600 cursor-not-allowed'}"
      >
        <input type="checkbox" bind:checked={includeSelection} disabled={!selection.trim()} class="accent-violet-500 w-3 h-3" />
        <TextQuote class="w-3 h-3 text-amber-400 flex-shrink-0" />
        <span class="truncate">
          {selection.trim() ? `Sertakan teks terpilih (${selection.length} karakter)` : 'Tidak ada teks terpilih'}
        </span>
      </label>
    </div>

    <!-- Messages -->
    <div bind:this={listEl} class="flex-1 overflow-y-auto p-3 space-y-3">
      {#if !isConfigured}
        <div class="p-3 rounded-xl bg-amber-950/40 border border-amber-800/60 text-amber-200 text-[11px] space-y-2">
          <div class="flex items-center space-x-2 font-semibold">
            <Settings2 class="w-3.5 h-3.5" />
            <span>AI belum dikonfigurasi</span>
          </div>
          <p class="text-amber-200/80">Atur provider (Claude / OpenAI-compatible) dan API key terlebih dahulu.</p>
          {#if onOpenSettings}
            <button
              onclick={() => { onClose(); onOpenSettings(); }}
              class="px-3 py-1.5 rounded-lg bg-amber-600 hover:bg-amber-500 text-white text-[11px] font-semibold transition-colors cursor-pointer"
            >
              Buka Pengaturan AI
            </button>
          {/if}
        </div>
      {:else if messages.length === 0}
        <div class="pt-6 space-y-3 text-center">
          <Sparkles class="w-6 h-6 text-violet-500/60 mx-auto" />
          <p class="text-[11px] text-slate-500 px-4 leading-relaxed">
            Ngobrol bebas dengan AI. Aktifkan "Baca catatan aktif" agar AI mengerti isi catatan yang sedang kamu buka.
          </p>
          <div class="space-y-1.5 px-2">
            <button
              onclick={() => quick('Ringkas catatan aktif ini dalam poin-poin.')}
              class="w-full text-left px-3 py-2 rounded-lg bg-slate-900 border border-slate-800 text-[11px] text-slate-300 hover:border-violet-600/50 hover:text-white transition-colors cursor-pointer"
            >
              💡 Ringkas catatan aktif ini
            </button>
            <button
              onclick={() => quick('Tinjau catatan ini dan tunjukkan potensi masalah atau error yang kamu temukan.')}
              class="w-full text-left px-3 py-2 rounded-lg bg-slate-900 border border-slate-800 text-[11px] text-slate-300 hover:border-violet-600/50 hover:text-white transition-colors cursor-pointer"
            >
              🔍 Tinjau & cari potensi masalah
            </button>
            <button
              onclick={() => quick('Buat daftar task (checkbox) dari isi catatan ini.')}
              class="w-full text-left px-3 py-2 rounded-lg bg-slate-900 border border-slate-800 text-[11px] text-slate-300 hover:border-violet-600/50 hover:text-white transition-colors cursor-pointer"
            >
              ✅ Buat task list dari catatan
            </button>
          </div>
        </div>
      {:else}
        {#each messages as m, i (i)}
          <div class="flex {m.role === 'user' ? 'justify-end' : 'justify-start'}">
            <div
              class="max-w-[85%] px-3 py-2 rounded-2xl text-[11.5px] leading-relaxed whitespace-pre-wrap break-words {m.role === 'user'
                ? 'bg-violet-600 text-white rounded-br-md'
                : 'bg-slate-900 border border-slate-800 text-slate-200 rounded-bl-md'}"
            >
              {#if m.role === 'assistant' && busy && i === messages.length - 1}
                <span class="flex items-center space-x-2"><Loader2 class="w-3.5 h-3.5 animate-spin text-violet-400" /> <span>Mengetik…</span></span>
              {:else}
                {m.content}
              {/if}
            </div>
          </div>
        {/each}
      {/if}
    </div>

    <!-- Input -->
    <div class="p-3 border-t border-slate-800">
      <div class="flex items-end space-x-2">
        <textarea
          bind:value={chatInput}
          onkeydown={handleKeydown}
          rows="2"
          placeholder={isConfigured ? 'Tanya apa saja… (Enter kirim, Shift+Enter baris baru)' : 'Konfigurasi AI terlebih dahulu'}
          disabled={!isConfigured}
          class="flex-1 resize-none px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-xs text-slate-100 placeholder-slate-600 focus:outline-none focus:border-violet-500 transition-colors disabled:opacity-50"
        ></textarea>
        <button
          onclick={send}
          disabled={!canSend}
          class="px-3 py-2.5 rounded-xl bg-violet-600 hover:bg-violet-500 disabled:opacity-40 text-white transition-colors cursor-pointer flex-shrink-0"
          aria-label="Kirim"
        >
          {#if busy}
            <Loader2 class="w-4 h-4 animate-spin" />
          {:else}
            <SendHorizonal class="w-4 h-4" />
          {/if}
        </button>
      </div>
      <p class="text-[9.5px] text-slate-600 mt-1.5 flex items-center space-x-1">
        <AlertTriangle class="w-2.5 h-2.5 text-amber-500/70" />
        <span>Konten yang dikirim ke AI keluar dari perangkat sebagai plaintext.</span>
      </p>
    </div>
  </aside>
{/if}
