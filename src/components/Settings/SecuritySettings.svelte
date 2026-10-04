<script lang="ts">
  import { Lock, Loader2, ShieldCheck, ShieldOff, KeyRound, MonitorSmartphone } from 'lucide-svelte';
  import { ipc } from '../../services/ipc';
  import { editorStore } from '../../stores/editorStore.svelte';

  let status = $state<'none' | 'locked' | 'ready' | 'unknown'>('unknown');
  let oldPassword = $state('');
  let newPassword = $state('');
  let confirmPassword = $state('');
  let isWorking = $state(false);
  let message = $state<{ text: string; type: 'success' | 'error' } | null>(null);

  async function refreshStatus() {
    status = await ipc.e2eStatus();
  }

  refreshStatus();

  async function handleChangePassword() {
    message = null;
    if (newPassword.length < 8) {
      message = { text: 'Password baru minimal 8 karakter', type: 'error' };
      return;
    }
    if (newPassword !== confirmPassword) {
      message = { text: 'Konfirmasi password tidak cocok', type: 'error' };
      return;
    }
    isWorking = true;
    try {
      await ipc.changeMasterPassword(oldPassword, newPassword, true);
      message = { text: 'Password berhasil diganti. Semua data dienkripsi ulang.', type: 'success' };
      oldPassword = newPassword = confirmPassword = '';
    } catch (e: any) {
      message = { text: typeof e === 'string' ? e : e?.message || 'Gagal ganti password', type: 'error' };
    } finally {
      isWorking = false;
    }
  }

  async function handleLockNow() {
    await ipc.lockApp();
    window.location.reload();
  }

  async function handleForgetDevice() {
    await ipc.forgetDevice();
    await ipc.lockApp();
    window.location.reload();
  }
</script>

<div class="space-y-6">
  <div class="flex items-center gap-3">
    {#if status === 'ready'}
      <div class="rounded-xl bg-emerald-600/20 p-2.5">
        <ShieldCheck class="h-5 w-5 text-emerald-400" />
      </div>
      <div>
        <h3 class="text-sm font-semibold text-slate-100">Enkripsi End-to-End Aktif</h3>
        <p class="text-xs text-slate-400">Catatan dienkripsi sebelum disimpan lokal & cloud.</p>
      </div>
    {:else}
      <div class="rounded-xl bg-slate-700/40 p-2.5">
        <ShieldOff class="h-5 w-5 text-slate-400" />
      </div>
      <div>
        <h3 class="text-sm font-semibold text-slate-100">Enkripsi Belum Aktif</h3>
        <p class="text-xs text-slate-400">Aktifkan via layar setup saat app dibuka.</p>
      </div>
    {/if}
  </div>

  {#if status === 'ready'}
    <div class="space-y-3 rounded-xl border border-slate-700/60 bg-slate-800/40 p-4">
      <h4 class="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-slate-300">
        <KeyRound class="h-4 w-4" /> Ganti Master Password
      </h4>
      <form class="space-y-3" onsubmit={(e) => { e.preventDefault(); handleChangePassword(); }}>
        <input
          type="password"
          bind:value={oldPassword}
          placeholder="Password lama"
          class="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-100 placeholder:text-slate-500 focus:border-blue-500 focus:outline-none"
        />
        <input
          type="password"
          bind:value={newPassword}
          placeholder="Password baru (min. 8 karakter)"
          class="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-100 placeholder:text-slate-500 focus:border-blue-500 focus:outline-none"
        />
        <input
          type="password"
          bind:value={confirmPassword}
          placeholder="Ulangi password baru"
          class="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-100 placeholder:text-slate-500 focus:border-blue-500 focus:outline-none"
        />
        {#if message}
          <p class="text-xs {message.type === 'success' ? 'text-emerald-400' : 'text-red-400'}">
            {message.text}
          </p>
        {/if}
        <button
          type="submit"
          disabled={isWorking || !oldPassword || !newPassword}
          class="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-xs font-medium text-white hover:bg-blue-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {#if isWorking}<Loader2 class="h-4 w-4 animate-spin" />{/if}
          Ganti Password
        </button>
      </form>
      <p class="text-[11px] text-slate-500">
        Semua catatan lokal akan dienkripsi ulang dengan kunci baru.
      </p>
    </div>

    <div class="space-y-2 rounded-xl border border-slate-700/60 bg-slate-800/40 p-4">
      <h4 class="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-slate-300">
        <Lock class="h-4 w-4" /> Kunci & Device
      </h4>
      <div class="flex flex-wrap gap-2">
        <button
          onclick={handleLockNow}
          class="flex items-center gap-2 rounded-lg bg-slate-700 px-4 py-2 text-xs font-medium text-slate-100 hover:bg-slate-600"
        >
          <Lock class="h-4 w-4" /> Kunci Sekarang
        </button>
        <button
          onclick={handleForgetDevice}
          class="flex items-center gap-2 rounded-lg bg-red-900/40 px-4 py-2 text-xs font-medium text-red-300 hover:bg-red-900/60"
        >
          <MonitorSmartphone class="h-4 w-4" /> Lupakan Password di Device Ini
        </button>
      </div>
      <p class="text-[11px] text-slate-500">
        "Lupakan Device" menghapus kunci tersimpan — app akan minta password setiap dibuka.
      </p>
    </div>
  {/if}
</div>
