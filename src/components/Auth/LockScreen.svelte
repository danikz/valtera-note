<script lang="ts">
  import { Lock, ShieldCheck, Loader2, Eye, EyeOff, AlertTriangle, Delete, KeyRound } from 'lucide-svelte';
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

  // ===== Quick PIN (layar terkunci saja) =====
  let pinEnabled = $state(false);
  let usePin = $state(false);
  let pin = $state('');
  let checkedPin = $state(false);

  $effect(() => {
    if (mode !== 'locked' || checkedPin) return;
    checkedPin = true;
    ipc
      .quickPinStatus()
      .then((enabled) => {
        pinEnabled = enabled;
        usePin = enabled;
      })
      .catch(() => {});
  });

  function pressDigit(d: string) {
    if (isWorking) return;
    if (pin.length < 6) pin += d;
    if (pin.length === 6) handlePinUnlock();
  }

  function pressDelete() {
    pin = pin.slice(0, -1);
  }

  function clearPin() {
    pin = '';
    error = '';
  }

  async function handlePinUnlock() {
    if (pin.length !== 6 || isWorking) return;
    error = '';
    isWorking = true;
    try {
      await ipc.unlockWithPin(pin);
      await editorStore.reloadSession();
      onDone();
    } catch (e: any) {
      error = typeof e === 'string' ? e : e?.message || 'PIN salah';
      pin = '';
      // Fitur PIN bisa dimatikan otomatis oleh backend setelah 5x salah.
      ipc.quickPinStatus().then((enabled) => {
        if (!enabled) usePin = false;
      });
    } finally {
      isWorking = false;
    }
  }

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
      await ipc.unlockMasterPassword(password, rememberDevice);
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
      {:else if usePin}
        <div class="rounded-xl bg-blue-600/20 p-3">
          <KeyRound class="h-8 w-8 text-blue-400" />
        </div>
        <h2 class="text-lg font-semibold text-slate-100">Masukkan PIN</h2>
        <p class="text-xs text-slate-400">PIN cepat 6 digit untuk device ini.</p>
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

    {#if mode === 'locked' && usePin}
      <!-- ===== PIN pad 6 digit ===== -->
      <div class="space-y-4">
        <div class="flex items-center justify-center gap-2.5" aria-label="PIN yang dimasukkan">
          {#each Array(6) as _, i (i)}
            <div
              class="h-11 w-9 rounded-lg border text-center text-xl font-mono flex items-center justify-center transition-colors {pin.length > i
                ? 'border-blue-500 bg-blue-600/10 text-blue-200'
                : 'border-slate-700 bg-slate-800 text-slate-500'}"
            >
              {pin.length > i ? '•' : ''}
            </div>
          {/each}
        </div>

        {#if error}
          <p class="rounded-lg border border-red-800/50 bg-red-900/20 px-3 py-2 text-xs text-red-300 text-center">
            {error}
          </p>
        {/if}

        <div class="grid grid-cols-3 gap-2">
          {#each ['1', '2', '3', '4', '5', '6', '7', '8', '9'] as d (d)}
            <button
              type="button"
              onclick={() => pressDigit(d)}
              class="h-11 rounded-xl bg-slate-800 hover:bg-slate-700 text-lg font-mono font-semibold text-slate-100 transition-colors cursor-pointer active:scale-95"
            >
              {d}
            </button>
          {/each}
          <button
            type="button"
            onclick={clearPin}
            class="h-11 rounded-xl bg-slate-800/50 hover:bg-slate-700 text-[11px] text-slate-400 hover:text-slate-200 transition-colors cursor-pointer"
            title="Bersihkan"
          >
            C
          </button>
          <button
            type="button"
            onclick={() => pressDigit('0')}
            class="h-11 rounded-xl bg-slate-800 hover:bg-slate-700 text-lg font-mono font-semibold text-slate-100 transition-colors cursor-pointer active:scale-95"
          >
            0
          </button>
          <button
            type="button"
            onclick={pressDelete}
            class="h-11 rounded-xl bg-slate-800/50 hover:bg-slate-700 flex items-center justify-center text-slate-400 hover:text-slate-200 transition-colors cursor-pointer"
            title="Hapus satu digit"
          >
            <Delete class="h-4 w-4" />
          </button>
        </div>

        {#if isWorking}
          <div class="flex items-center justify-center gap-2 text-xs text-slate-400">
            <Loader2 class="h-3.5 w-3.5 animate-spin" />
            <span>Memverifikasi…</span>
          </div>
        {/if}

        <button
          type="button"
          onclick={() => { usePin = false; error = ''; pin = ''; }}
          class="w-full text-center text-xs text-slate-500 transition-colors hover:text-slate-300 cursor-pointer"
        >
          Gunakan master password saja
        </button>
      </div>
    {:else}
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
        {:else}
          <label class="flex cursor-pointer items-center gap-2 text-xs text-slate-300">
            <input type="checkbox" bind:checked={rememberDevice} class="accent-blue-600" />
            Ingat di device ini — tidak perlu password lagi saat berikutnya
          </label>

          {#if pinEnabled}
            <button
              type="button"
              onclick={() => { usePin = true; error = ''; password = ''; }}
              class="w-full text-center text-xs text-blue-400 transition-colors hover:text-blue-300 cursor-pointer"
            >
              Gunakan PIN cepat 6 digit
            </button>
          {/if}
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
    {/if}
  </div>
</div>
