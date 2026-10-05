<script lang="ts">
  import {
    X,
    Sparkles,
    Loader2,
    Copy,
    Check,
    Replace,
    CornerDownRight,
    AlertTriangle,
    Settings2,
    Wand2
  } from 'lucide-svelte';
  import { editorStore } from '../../stores/editorStore.svelte';
  import { ipc } from '../../services/ipc';
  import { copyText } from '../../utils/clipboard';

  let {
    isOpen,
    onClose,
    onOpenSettings
  }: { isOpen: boolean; onClose: () => void; onOpenSettings?: () => void } = $props();

  const MAX_SOURCE_CHARS = 24000;

  interface AiAction {
    id: string;
    label: string;
    system: string;
    user: (t: string) => string;
  }

  const ACTIONS: AiAction[] = [
    {
      id: 'summarize',
      label: 'Ringkas',
      system: 'Kamu asisten editor catatan teknis. Jawab dalam Bahasa Indonesia, ringkas dan terstruktur.',
      user: (t: string) => `Ringkas teks berikut dalam poin-poin padat:\n\n${t}`
    },
    {
      id: 'improve',
      label: 'Perbaiki Tulisan',
      system:
        'Kamu editor profesional. Perbaiki ejaan, tata bahasa, dan kejelasan teks tanpa mengubah makna. Kembalikan HANYA teks hasil perbaikan tanpa komentar apa pun.',
      user: (t: string) => t
    },
    {
      id: 'to-en',
      label: '→ English',
      system: 'You are a translator. Translate the text to natural English. Return ONLY the translation, nothing else.',
      user: (t: string) => t
    },
    {
      id: 'to-id',
      label: '→ Indonesia',
      system: 'Kamu penerjemah. Terjemahkan teks ke Bahasa Indonesia yang natural. Kembalikan HANYA hasil terjemahan, tanpa komentar.',
      user: (t: string) => t
    },
    {
      id: 'explain',
      label: 'Jelaskan',
      system: 'Kamu asisten teknis. Jelaskan teks berikut dengan bahasa sederhana dan terstruktur.',
      user: (t: string) => `Jelaskan isi teks berikut:\n\n${t}`
    },
    {
      id: 'commit',
      label: 'Commit Msg',
      system:
        'Kamu menulis conventional commit messages. Balas HANYA satu baris commit message dengan format type(scope): subject, berdasarkan konteks berikut.',
      user: (t: string) => t
    }
  ];

  let isRunning = $state(false);
  let activeAction = $state<string>('');
  let result = $state('');
  let errorMsg = $state('');
  let copied = $state(false);
  let customPrompt = $state('');
  let hadSelection = $state(false);
  let cfg = $state<{ kind: string; base_url: string; has_api_key: boolean; model: string } | null>(null);

  const providerLabel = $derived(
    cfg?.kind === 'anthropic' ? 'Anthropic Claude' : 'OpenAI-compatible'
  );
  const isConfigured = $derived(!!cfg && cfg.has_api_key && !!cfg.base_url && !!cfg.model);

  $effect(() => {
    if (isOpen) {
      result = '';
      errorMsg = '';
      activeAction = '';
      customPrompt = '';
      ipc.aiGetConfig().then((c) => (cfg = c));
    }
  });

  function sourceText(): { text: string; fromSelection: boolean } {
    const sel = (editorStore.selectionText || '').trim();
    if (sel) return { text: sel, fromSelection: true };
    return { text: editorStore.activeTab?.content || '', fromSelection: false };
  }

  async function run(system: string, userFn: (t: string) => string, actionId: string) {
    const { text: raw, fromSelection } = sourceText();
    if (!raw.trim()) {
      errorMsg = 'Tidak ada teks — catatan kosong.';
      return;
    }
    const truncated = raw.length > MAX_SOURCE_CHARS
      ? raw.slice(0, MAX_SOURCE_CHARS) + '\n\n[...terpotong]'
      : raw;
    hadSelection = fromSelection;
    isRunning = true;
    activeAction = actionId;
    errorMsg = '';
    result = '';
    try {
      result = await ipc.aiComplete(system, userFn(truncated));
    } catch (e: any) {
      errorMsg = typeof e === 'string' ? e : e?.message || String(e);
    } finally {
      isRunning = false;
      activeAction = '';
    }
  }

  async function runAction(id: string) {
    const a = ACTIONS.find((x) => x.id === id);
    if (!a) return;
    await run(a.system, a.user, id);
  }

  async function runCustom() {
    if (!customPrompt.trim()) return;
    const instruction = customPrompt.trim();
    await run(
      'Kamu asisten AI dalam editor catatan. Ikuti instruksi user terkait teks yang diberikan. Kembalikan hasilnya langsung tanpa pembukaan.',
      (t) => `${instruction}\n\n${t}`,
      'custom'
    );
  }

  async function handleCopy() {
    if (!result) return;
    copied = await copyText(result);
    if (copied) setTimeout(() => (copied = false), 1500);
  }

  function applyReplace() {
    if (!result) return;
    editorStore.applyAiText(result);
    onClose();
  }

  function applyInsert() {
    if (!result) return;
    const range = editorStore.selectionRange;
    if (range) {
      // Geser titik sisip ke akhir seleksi agar teks ditambahkan setelahnya.
      editorStore.selectionRange = { from: range.to, to: range.to };
    }
    editorStore.applyAiText(`\n${result}\n`);
    onClose();
  }
</script>

{#if isOpen}
  <div class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm" role="dialog" aria-modal="true">
    <div class="w-full max-w-3xl max-h-[85vh] flex flex-col bg-slate-950 border border-slate-800 rounded-2xl shadow-2xl overflow-hidden">
      <!-- Header -->
      <div class="flex items-center justify-between px-5 py-3.5 border-b border-slate-800">
        <div class="flex items-center space-x-2">
          <Sparkles class="w-4 h-4 text-violet-400" />
          <span class="font-semibold text-slate-100 text-sm">AI Assistant</span>
          {#if isConfigured}
            <span class="text-[10px] font-mono text-slate-500">{providerLabel} · {cfg?.model}</span>
          {/if}
        </div>
        <button
          onclick={onClose}
          class="p-1.5 rounded-lg text-slate-400 hover:text-slate-200 hover:bg-slate-800 transition-colors cursor-pointer"
          aria-label="Tutup"
        >
          <X class="w-4 h-4" />
        </button>
      </div>

      <!-- Body -->
      <div class="flex-1 overflow-y-auto p-5 space-y-4">
        {#if !isConfigured}
          <div class="p-4 rounded-xl bg-amber-950/40 border border-amber-800/60 text-amber-200 space-y-2 text-xs">
            <div class="flex items-center space-x-2 font-semibold">
              <Settings2 class="w-4 h-4" />
              <span>AI belum dikonfigurasi</span>
            </div>
            <p class="text-amber-200/80">
              Atur provider (Claude / OpenAI-compatible), API key, dan model di Pengaturan → AI Assistant.
            </p>
            {#if onOpenSettings}
              <button
                onclick={() => { onClose(); onOpenSettings(); }}
                class="px-3 py-1.5 rounded-lg bg-amber-600 hover:bg-amber-500 text-white text-xs font-semibold transition-colors cursor-pointer"
              >
                Buka Pengaturan AI
              </button>
            {/if}
          </div>
        {:else}
          <!-- Actions -->
          <div class="flex flex-wrap gap-2">
            {#each ACTIONS as a (a.id)}
              <button
                onclick={() => runAction(a.id)}
                disabled={isRunning}
                class="px-3 py-1.5 rounded-lg text-xs font-medium border transition-colors cursor-pointer disabled:opacity-50 {activeAction === a.id
                  ? 'bg-violet-600 border-violet-500 text-white'
                  : 'bg-slate-900 border-slate-800 text-slate-300 hover:border-violet-600/50 hover:text-white'}"
              >
                {#if activeAction === a.id}
                  <Loader2 class="w-3 h-3 inline animate-spin mr-1" />
                {:else}
                  <Wand2 class="w-3 h-3 inline mr-1 text-violet-400" />
                {/if}
                {a.label}
              </button>
            {/each}
          </div>

          <!-- Custom prompt -->
          <div class="flex space-x-2">
            <input
              type="text"
              bind:value={customPrompt}
              placeholder="Instruksi kustom… (mis. 'buatkan langkah deploy dari catatan ini')"
              class="flex-1 px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-xs text-slate-100 placeholder-slate-600 focus:outline-none focus:border-violet-500 transition-colors"
              onkeydown={(e) => { if (e.key === 'Enter' && !isRunning) runCustom(); }}
            />
            <button
              onclick={runCustom}
              disabled={isRunning || !customPrompt.trim()}
              class="px-3 py-2 rounded-xl bg-violet-600 hover:bg-violet-500 disabled:opacity-50 text-white text-xs font-semibold transition-colors cursor-pointer"
            >
              Kirim
            </button>
          </div>

          <p class="text-[10.5px] text-slate-500">
            Sumber: {hadSelection ? 'teks terpilih' : 'seluruh catatan'}
            {#if sourceText().text.length > MAX_SOURCE_CHARS}
              — catatan sangat panjang, hanya {MAX_SOURCE_CHARS} karakter pertama yang dikirim.
            {/if}
          </p>

          {#if errorMsg}
            <div class="p-3 rounded-xl bg-rose-950/50 border border-rose-800/60 text-rose-200 text-xs flex items-start space-x-2">
              <AlertTriangle class="w-4 h-4 flex-shrink-0 mt-0.5" />
              <span class="break-all">{errorMsg}</span>
            </div>
          {:else if result}
            <!-- Result -->
            <div class="rounded-xl border border-slate-800 bg-slate-900/60 overflow-hidden">
              <div class="px-3 py-2 border-b border-slate-800 flex items-center justify-between">
                <span class="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">Hasil</span>
                <button
                  onclick={handleCopy}
                  class="flex items-center space-x-1 text-[11px] text-slate-400 hover:text-slate-200 transition-colors cursor-pointer"
                >
                  {#if copied}
                    <Check class="w-3.5 h-3.5 text-emerald-400" /><span>Tersalin</span>
                  {:else}
                    <Copy class="w-3.5 h-3.5" /><span>Salin</span>
                  {/if}
                </button>
              </div>
              <pre class="p-3 text-xs text-slate-200 whitespace-pre-wrap leading-relaxed max-h-72 overflow-y-auto font-sans">{result}</pre>
            </div>

            <!-- Apply buttons -->
            <div class="flex flex-wrap items-center gap-2">
              <button
                onclick={applyReplace}
                disabled={!hadSelection}
                title={hadSelection ? 'Ganti teks yang terpilih dengan hasil AI' : 'Hanya aktif saat ada teks terpilih'}
                class="flex items-center space-x-1.5 px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 disabled:opacity-40 text-white text-xs font-semibold transition-colors cursor-pointer"
              >
                <Replace class="w-3.5 h-3.5" />
                <span>Ganti Seleksi</span>
              </button>
              <button
                onclick={applyInsert}
                class="flex items-center space-x-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-200 text-xs font-medium transition-colors cursor-pointer"
              >
                <CornerDownRight class="w-3.5 h-3.5" />
                <span>Sisipkan di Kursor</span>
              </button>
            </div>
          {:else if isRunning}
            <div class="flex items-center space-x-2 text-xs text-slate-400 py-8 justify-center">
              <Loader2 class="w-4 h-4 animate-spin text-violet-400" />
              <span>Memproses…</span>
            </div>
          {/if}
        {/if}
      </div>

      <!-- Footer warning -->
      <div class="px-5 py-2.5 border-t border-slate-800 flex items-center space-x-2 text-[10.5px] text-slate-500">
        <AlertTriangle class="w-3 h-3 text-amber-500 flex-shrink-0" />
        <span>
          Konten yang dikirim ke AI keluar dari perangkat sebagai teks biasa — tidak tercakup enkripsi E2E.
          API key & konfigurasi tersimpan hanya di perangkat ini.
        </span>
      </div>
    </div>
  </div>
{/if}
