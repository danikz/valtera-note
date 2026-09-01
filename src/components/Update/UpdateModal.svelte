<script lang="ts">
  import { 
    Sparkles, 
    ArrowUpCircle, 
    Download, 
    RefreshCw, 
    CheckCircle2, 
    AlertTriangle, 
    ShieldCheck, 
    Flame,
    X
  } from 'lucide-svelte';
  import { updaterService } from '../../services/updater';

  function formatBytes(bytes: number): string {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
  }
</script>

{#if updaterService.showUpdateModal}
  <div class="fixed inset-0 bg-black/75 backdrop-blur-md z-50 flex items-center justify-center p-4 select-none animate-in fade-in duration-200">
    <div 
      class="bg-slate-900 border border-slate-700/80 rounded-2xl shadow-2xl w-full max-w-md overflow-hidden text-slate-200 flex flex-col relative animate-in zoom-in-95 duration-200"
      role="dialog"
      aria-modal="true"
    >
      <!-- Glowing Background Accent -->
      <div class="absolute -top-24 -right-24 w-48 h-48 bg-blue-500/20 rounded-full blur-3xl pointer-events-none"></div>
      <div class="absolute -bottom-24 -left-24 w-48 h-48 bg-emerald-500/15 rounded-full blur-3xl pointer-events-none"></div>

      <!-- Header Banner -->
      <div class="p-5 border-b border-slate-800 bg-gradient-to-r from-slate-950 via-slate-900 to-slate-950 flex items-start justify-between relative z-10">
        <div class="flex items-start space-x-3.5">
          <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-blue-500 to-indigo-600 p-0.5 shadow-lg shadow-blue-500/25 flex-shrink-0 flex items-center justify-center">
            <div class="w-full h-full bg-slate-950/40 rounded-[10px] flex items-center justify-center text-white">
              <ArrowUpCircle class="w-5 h-5 animate-bounce" />
            </div>
          </div>
          <div class="space-y-1">
            <div class="flex items-center space-x-2">
              <h3 class="text-sm font-bold text-white tracking-tight">Pembaruan Versi Baru</h3>
              <span class="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-amber-500/15 border border-amber-500/30 text-amber-300 flex items-center space-x-1">
                <Flame class="w-2.5 h-2.5" />
                <span>Pembaruan Penting</span>
              </span>
            </div>
            <p class="text-xs text-slate-400">
              Versi baru telah dirilis untuk stabilitas dan keamanan catatan Anda.
            </p>
          </div>
        </div>

        {#if !updaterService.isMandatory && !updaterService.isDownloading}
          <button 
            onclick={() => updaterService.closeModal()}
            class="p-1 rounded-lg text-slate-500 hover:text-slate-200 hover:bg-slate-800/80 transition-colors"
            title="Tutup"
          >
            <X class="w-4 h-4" />
          </button>
        {/if}
      </div>

      <!-- Content Body -->
      <div class="p-5 space-y-4 relative z-10 text-xs">
        <!-- Version Pills Comparison -->
        <div class="flex items-center justify-between p-3 rounded-xl bg-slate-950/70 border border-slate-800">
          <div class="space-y-0.5">
            <span class="text-[10px] text-slate-500 font-mono uppercase tracking-wider">Versi Saat Ini</span>
            <div class="font-semibold text-slate-300 text-xs font-mono">v{updaterService.currentVersion}</div>
          </div>
          
          <div class="px-2 py-1 rounded bg-slate-800/80 border border-slate-700 text-blue-400 font-bold text-xs">
            ➔
          </div>

          <div class="space-y-0.5 text-right">
            <span class="text-[10px] text-emerald-400 font-mono uppercase tracking-wider">Versi Tersedia</span>
            <div class="font-bold text-emerald-300 text-xs font-mono">v{updaterService.newVersion}</div>
          </div>
        </div>

        <!-- Release Notes / Changelog Box -->
        <div class="space-y-1.5">
          <div class="flex items-center justify-between text-[11px] text-slate-400">
            <span class="font-semibold text-slate-300 flex items-center space-x-1">
              <Sparkles class="w-3 h-3 text-amber-400" />
              <span>Catatan Pembaruan:</span>
            </span>
            {#if updaterService.releaseDate}
              <span class="text-slate-500 font-mono">{updaterService.releaseDate}</span>
            {/if}
          </div>

          <div class="max-h-32 overflow-y-auto p-3 rounded-xl bg-slate-950/60 border border-slate-800/80 text-slate-300 text-xs leading-relaxed space-y-1.5 scrollbar-thin">
            {#if updaterService.releaseNotes}
              <p class="whitespace-pre-line">{updaterService.releaseNotes}</p>
            {:else}
              <ul class="list-disc list-inside space-y-1 text-slate-300">
                <li>Perbaikan otomatisasi pembuatan file saat tambah folder.</li>
                <li>Perbaikan tombol tutup tab agar dokumen tidak terhapus.</li>
                <li>Peningkatan performa dan kestabilan sinkronisasi cloud.</li>
              </ul>
            {/if}
          </div>
        </div>

        <!-- Mandatory Notice Alert -->
        <div class="p-2.5 rounded-xl bg-amber-500/10 border border-amber-500/20 text-amber-200/90 text-[11px] flex items-start space-x-2">
          <ShieldCheck class="w-4 h-4 text-amber-400 flex-shrink-0 mt-0.5" />
          <p class="leading-relaxed">
            Pembaruan ini sangat disarankan agar terhindar dari bug kehilangan data dan menjamin kompatibilitas fitur terbaru.
          </p>
        </div>

        <!-- Download Progress Bar (When downloading) -->
        {#if updaterService.isDownloading}
          <div class="space-y-2 p-3 rounded-xl bg-blue-950/30 border border-blue-800/50 animate-in fade-in duration-150">
            <div class="flex items-center justify-between text-[11px]">
              <span class="text-blue-300 font-semibold flex items-center space-x-1.5">
                <RefreshCw class="w-3 h-3 animate-spin text-blue-400" />
                <span>Mengunduh dan memasang pembaruan...</span>
              </span>
              <span class="font-mono text-blue-400 font-bold">{updaterService.downloadProgress.percentage}%</span>
            </div>

            <!-- Progress Bar Track -->
            <div class="w-full h-2.5 rounded-full bg-slate-950 overflow-hidden p-0.5 border border-slate-800">
              <div 
                class="h-full rounded-full bg-gradient-to-r from-blue-500 to-emerald-400 transition-all duration-200 shadow-lg shadow-blue-500/50"
                style="width: {updaterService.downloadProgress.percentage}%"
              ></div>
            </div>

            <div class="flex justify-between text-[10px] text-slate-400 font-mono">
              <span>{formatBytes(updaterService.downloadProgress.downloaded)}</span>
              {#if updaterService.downloadProgress.total}
                <span>dari {formatBytes(updaterService.downloadProgress.total)}</span>
              {/if}
            </div>
          </div>
        {/if}

        <!-- Error Message (If any) -->
        {#if updaterService.errorMessage}
          <div class="p-2.5 rounded-xl bg-red-950/50 border border-red-800 text-red-200 text-[11px] flex items-center space-x-2">
            <AlertTriangle class="w-4 h-4 text-red-400 flex-shrink-0" />
            <span class="flex-1">{updaterService.errorMessage}</span>
          </div>
        {/if}
      </div>

      <!-- Action Footer -->
      <div class="p-4 border-t border-slate-800 bg-slate-950/80 flex items-center justify-end space-x-2.5 relative z-10">
        {#if !updaterService.isDownloading}
          <button 
            type="button"
            onclick={() => updaterService.downloadAndInstall()}
            class="w-full py-2.5 px-4 rounded-xl text-xs font-semibold bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white shadow-lg shadow-blue-600/30 flex items-center justify-center space-x-2 transition-all active:scale-[0.99] cursor-pointer"
          >
            <Download class="w-4 h-4" />
            <span>Perbarui & Mulai Ulang Sekarang</span>
          </button>
        {:else}
          <div class="w-full py-2.5 text-center text-xs text-blue-300 font-medium animate-pulse">
            Aplikasi akan otomatis dimulai ulang setelah instalasi selesai...
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}
