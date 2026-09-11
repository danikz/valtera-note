<script lang="ts">
  import { X, RefreshCw } from 'lucide-svelte';
  import { APP_VERSION, APP_NAME, APP_DESCRIPTION, APP_COPYRIGHT } from '../../constants/app';

  let {
    isOpen = false,
    onClose,
    onCheckUpdates
  }: {
    isOpen: boolean;
    onClose: () => void;
    onCheckUpdates?: () => void;
  } = $props();

  function handleKeydown(e: KeyboardEvent) {
    if (isOpen && e.key === 'Escape') {
      onClose();
    }
  }
</script>

<svelte:window onkeydown={handleKeydown} />

{#if isOpen}
  <!-- Backdrop -->
  <div 
    class="fixed inset-0 bg-black/70 backdrop-blur-sm z-50 flex items-center justify-center p-4 select-none animate-in fade-in duration-150"
    onclick={onClose}
    role="presentation"
  >
    <!-- Modal Dialog Window -->
    <div 
      class="bg-slate-900 border border-slate-700/80 rounded-2xl shadow-2xl w-full max-w-sm overflow-hidden text-slate-200 flex flex-col relative animate-in zoom-in-95 duration-150"
      onclick={(e) => e.stopPropagation()}
      onkeydown={(e) => e.stopPropagation()}
      role="dialog"
      aria-modal="true"
      aria-labelledby="about-modal-title"
      tabindex="-1"
    >
      <!-- Close Button Top Right -->
      <button 
        onclick={onClose}
        class="absolute top-3 right-3 p-1.5 rounded-lg text-slate-400 hover:text-slate-100 hover:bg-slate-800/80 transition-colors cursor-pointer z-20"
        title="Tutup (Esc)"
      >
        <X class="w-4 h-4" />
      </button>

      <!-- Center Brand Content -->
      <div class="p-6 text-center flex flex-col items-center space-y-3 pt-8">
        <!-- Logo -->
        <div class="w-16 h-16 rounded-2xl bg-blue-600/15 border border-blue-500/25 p-2.5 shadow-lg shadow-blue-500/10 flex items-center justify-center">
          <img src="/logo.png" alt="Valtera Note Logo" class="w-11 h-11 object-contain drop-shadow" />
        </div>

        <!-- App Name & Version -->
        <div class="space-y-1">
          <h2 id="about-modal-title" class="text-lg font-bold text-white tracking-tight">
            Valtera Note
          </h2>
          <div class="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-mono font-medium bg-blue-500/10 text-blue-300 border border-blue-500/20">
            Versi {APP_VERSION}
          </div>
        </div>

        <!-- Description -->
        <p class="text-xs text-slate-400 leading-relaxed max-w-xs pt-1">
          Aplikasi catatan desktop yang cepat, ringan, dan aman untuk mengelola catatan dan produktivitas harian Anda.
        </p>

        <!-- Copyright & Publisher -->
        <div class="pt-3 text-[11px] text-slate-500 space-y-0.5">
          <div class="font-medium text-slate-400">PT Valtera Teknologi Digital</div>
          <div>© 2026 Hak cipta dilindungi undang-undang.</div>
        </div>
      </div>

      <!-- Footer Buttons -->
      <div class="px-5 py-3.5 border-t border-slate-800 bg-slate-950/60 flex items-center justify-between">
        {#if onCheckUpdates}
          <button 
            onclick={onCheckUpdates}
            class="px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white border border-slate-700 transition-colors flex items-center space-x-1.5 cursor-pointer text-xs font-medium"
          >
            <RefreshCw class="w-3.5 h-3.5 text-blue-400" />
            <span>Periksa Pembaruan</span>
          </button>
        {:else}
          <div></div>
        {/if}

        <button 
          onclick={onClose}
          class="px-4 py-1.5 rounded-lg bg-blue-600 hover:bg-blue-500 text-white font-medium transition-colors cursor-pointer text-xs shadow-sm"
        >
          Tutup
        </button>
      </div>
    </div>
  </div>
{/if}
