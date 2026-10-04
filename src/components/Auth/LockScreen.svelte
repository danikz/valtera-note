<script lang="ts">
  import { Lock, ShieldCheck, Loader2, Eye, EyeOff, AlertTriangle } from 'lucide-svelte';
  import { ipc } from '../../services/ipc';
  import { editorStore } from '../../stores/editorStore.svelte';

  let { mode, onDone }: { mode: 'setup' | 'locked'; onDone: () => void } = $props();

  let password = $state('');
  let confirmPassword = $state('');
  let rememberDevice = $state(true);
  let showPassword = $state(false);
  let isWorking = $state(false);
  let error = $state('');
  let isMigrating = $state(false);

  async function handleSetup() {
    error = '';
    if (password.length < 8) {
      error = 'Password minimal 8 karakter';
      return;
    }
    if (password !== confirmPassword) {
      error = 'Konfirmasi password tidak cocok';
      return;
    }
    isWorking = true;
    try {
      await ipc.setMasterPassword(password, rememberDevice);
      isMigrating = true;
      await editorStore.migrateCloudNotes();
      onDone();
    } catch (e: any) {
      error = typeof e === 'string' ? e : e?.message || 'Gagal mengatur password';
    } finally {
      isWorking = false;
      isMigrating = false;
    }
  }

  async function handleUnlock() {
    error = '';
    isWorking = true;
    try {
      await ipc.unlockMasterPassword(password);
      await editorStore.reloadSession();
      onDone();
    } catch (e: any) {
      error = typeof e === 'string' ? e : e?.message || 'Password salah';
    } finally {
      isWorking = false;
    }
  }

  function handleSkip() {
    ipc.setAppSetting('e2e_declined', '1');
    onDone();
  }
</script>

<div class="fixed inset-0 z-[9999] flex items-center justify-center bg-slate-950/95 backdrop-blur-sm">
  <div class="w-full max-w-md rounded-2xl border border-slate-800 bg-slate-900 p-8 shadow-2xl">
    <div class="mb-6 flex flex-col items-center gap-3 text-center">
      {#if mode === 'setup'}
        <div class="rounded-xl bg-emerald-600/20 p-3">
          <ShieldCheck class="h-8 w-8 text-emerald-400" />
        </div>
        <h2 class="text-lg font-semibold text-slate-100">Aktifkan Enkripsi End-to-End</h2>
        <p class="text-xs leading-relaxed text-slate-400">
          Catatan Anda akan dienkripsi dengan XChaCha20-Poly1305 sebelum disimpan ke database lokal
          dan cloud. Hanya Anda yang bisa membacanya.
        </p>
      {:else}
        <div class="rounded-xl bg-blue-600/20 p-3">
          <Lock class="h-8 w-8 text-blue-400" />
        </div>
        <h2 class="text-lg font-semibold text-slate-100">App Terkunci</h2>
        <p class="text-xs text-slate-400">Masukkan master password untuk membuka catatan Anda.</p>
      {/if}
    </div>

    {#if mode === 'setup'}
      <div class="mb-4 flex items-start gap-2 rounded-lg border border-amber-700/50 bg-amber-900/20 p-3">
        <AlertTriangle class="mt-0.5 h-4 w-4 shrink-0 text-amber-400" />
        <p class="text-[11px] leading-relaxed text-amber-200">
          Lupa password = data tidak bisa dipulihkan. Tidak ada reset. Simpan password baik-baik.
        </p>
      </div>
    {/if}

    <form
      class="space-y-4"
      onsubmit={(e) => { e.preventDefault(); mode === 'setup' ? handleSetup() : handleUnlock(); }}
    >
      <div class="relative">
        <input
          type={showPassword ? 'text' : 'password'}
          bind:value={password}
          placeholder="Master password"
          autofocus
          class="w-full rounded-xl border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-slate-100 placeholder:text-slate-500 focus:border-blue-500 focus:outline-none"
        />
        <button
          type="button"
          onclick={() => (showPassword = !showPassword)}
          class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-500 hover:text-slate-300"
        >
          {#if showPassword}<EyeOff class="h-4 w-4" />{:else}<Eye class="h-4 w-4" />{/if}
        </button>
      </div>

      {#if mode === 'setup'}
        <input
          type={showPassword ? 'text' : 'password'}
          bind:value={confirmPassword}
          placeholder="Ulangi password"
          class="w-full rounded-xl border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-slate-100 placeholder:text-slate-500 focus:border-blue-500 focus:outline-none"
        />

        <label class="flex cursor-pointer items-center gap-2 text-xs text-slate-300">
          <input type="checkbox" bind:checked={rememberDevice} class="accent-blue-600" />
          Ingat password di device ini (Windows Credential Manager)
        </label>
      {/if}

      {#if error}
        <p class="rounded-lg border border-red-800/50 bg-red-900/20 px-3 py-2 text-xs text-red-300">
          {error}
        </p>
      {/if}

      <button
        type="submit"
        disabled={isWorking || isMigrating || !password}
        class="flex w-full items-center justify-center gap-2 rounded-xl bg-blue-600 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-blue-500 disabled:cursor-not-allowed disabled:opacity-50"
      >
        {#if isWorking || isMigrating}
          <Loader2 class="h-4 w-4 animate-spin" />
          {isMigrating ? 'Mengenkripsi data...' : 'Memproses...'}
        {:else}
          {mode === 'setup' ? 'Aktifkan Enkripsi' : 'Buka Kunci'}
        {/if}
      </button>
    </form>

    {#if mode === 'setup'}
      <button
        onclick={handleSkip}
        class="mt-4 w-full text-center text-xs text-slate-500 transition-colors hover:text-slate-300"
      >
        Lewati untuk sekarang
      </button>
    {/if}
  </div>
</div>
