<script lang="ts">
  import { Lock, Loader2, ShieldCheck, ShieldOff, KeyRound, MonitorSmartphone, Fingerprint } from 'lucide-svelte';
  import { ipc } from '../../services/ipc';
  import { editorStore } from '../../stores/editorStore.svelte';

  let status = $state<'none' | 'locked' | 'ready' | 'unknown'>('unknown');
  let oldPassword = $state('');
  let newPassword = $state('');
  let confirmPassword = $state('');
  let rememberDevice = $state(true);
  let isWorking = $state(false);
  let message = $state<{ text: string; type: 'success' | 'error' } | null>(null);

  // Quick PIN 6 digit
  let pinEnabled = $state(false);
  let pin = $state('');
  let pinConfirm = $state('');
  let pinWorking = $state(false);
  let pinMessage = $state<{ text: string; type: 'success' | 'error' } | null>(null);

  async function refreshStatus() {
    status = await ipc.e2eStatus();
    if (status === 'ready') {
      pinEnabled = await ipc.quickPinStatus();
    } else {
      pinEnabled = false;
    }
  }

  refreshStatus();

  function validPin(p: string): boolean {
    return p.length === 6 && /^\d{6}$/.test(p);
  }

  async function handleSetupPin() {
    pinMessage = null;
    if (!validPin(pin) || !validPin(pinConfirm)) {
      pinMessage = { text: 'PIN harus tepat 6 digit angka', type: 'error' };
      return;
    }
    if (pin !== pinConfirm) {
      pinMessage = { text: 'Konfirmasi PIN tidak cocok', type: 'error' };
      return;
    }
    pinWorking = true;
    try {
      await ipc.setupQuickPin(pin);
      pinEnabled = true;
      pin = pinConfirm = '';
      pinMessage = {
        text: 'PIN cepat aktif — saat app dibuka, cukup masukkan PIN ini. Auto-unlock password dinonaktifkan.',
        type: 'success'
      };
    } catch (e: any) {
      pinMessage = { text: typeof e === 'string' ? e : e?.message || 'Gagal mengatur PIN', type: 'error' };
    } finally {
      pinWorking = false;
    }
  }

  async function handleDisablePin() {
    pinWorking = true;
    try {
      await ipc.disableQuickPin();
      pinEnabled = false;
      pin = pinConfirm = '';
      pinMessage = { text: 'PIN cepat dimatikan. App kembali memakai master password / auto-unlock.', type: 'success' };
    } catch (e: any) {
      pinMessage = { text: typeof e === 'string' ? e : e?.message || 'Gagal mematikan PIN', type: 'error' };
    } finally {
      pinWorking = false;
    }
  }

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
      await ipc.changeMasterPassword(oldPassword, newPassword, rememberDevice);
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

  async function handleEnable() {
    // Hapus flag decline lalu reload — App.svelte akan menampilkan layar setup.
    await ipc.setAppSetting('e2e_declined', '0');
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
        <p class="text-xs text-slate-400">Catatan masih disimpan dalam bentuk terbaca.</p>
      </div>
    {/if}
  </div>

  {#if status !== 'ready'}
    <div class="space-y-3 rounded-xl border border-slate-700/60 bg-slate-800/40 p-4">
      <button
        onclick={handleEnable}
        class="flex items-center gap-2 rounded-lg bg-emerald-600 px-4 py-2 text-xs font-medium text-white hover:bg-emerald-500"
      >
        <ShieldCheck class="h-4 w-4" /> Aktifkan Enkripsi
      </button>
      <p class="text-[11px] text-slate-500">
        Layar setup enkripsi akan muncul. Lupa master password = data tidak bisa dipulihkan.
      </p>
    </div>
  {/if}

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

        <label class="flex cursor-pointer items-center gap-2 text-xs text-slate-300">
          <input type="checkbox" bind:checked={rememberDevice} class="accent-blue-600" />
          Ingat password baru di device ini (Windows Credential Manager)
        </label>

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
        Semua catatan lokal akan dienkripsi ulang dengan kunci baru. PIN cepat (jika aktif) ikut dimatikan — aktifkan kembali setelah ganti password.
      </p>
    </div>

    <div class="space-y-3 rounded-xl border border-slate-700/60 bg-slate-800/40 p-4">
      <h4 class="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-slate-300">
        <Fingerprint class="h-4 w-4" /> PIN Cepat (6 digit)
      </h4>
      {#if pinEnabled}
        <p class="text-[11px] text-emerald-400">
          Aktif — saat app dibuka di device ini, cukup masukkan PIN 6 digit (dengan keypad di layar kunci).
        </p>
        <button
          onclick={handleDisablePin}
          disabled={pinWorking}
          class="flex items-center gap-2 rounded-lg bg-red-900/40 px-4 py-2 text-xs font-medium text-red-300 hover:bg-red-900/60 disabled:opacity-50"
        >
          {#if pinWorking}<Loader2 class="h-4 w-4 animate-spin" />{/if}
          Matikan PIN Cepat
        </button>
      {:else}
        <p class="text-[11px] text-slate-500 leading-relaxed">
          Buka app cukup dengan PIN 6 digit — master password tetap kunci utamanya
          (kunci disimpan terbungkus PIN di Windows Credential Manager, bukan di database).
          PIN menggantikan auto-unlock password di device ini. 5x salah = PIN dimatikan otomatis.
        </p>
        <form class="space-y-2" onsubmit={(e) => { e.preventDefault(); handleSetupPin(); }}>
          <input
            type="password"
            inputmode="numeric"
            maxlength="6"
            bind:value={pin}
            placeholder="PIN baru (6 digit)"
            class="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm font-mono tracking-[0.4em] text-slate-100 placeholder:tracking-normal placeholder:text-slate-500 focus:border-blue-500 focus:outline-none"
          />
          <input
            type="password"
            inputmode="numeric"
            maxlength="6"
            bind:value={pinConfirm}
            placeholder="Ulangi PIN"
            class="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm font-mono tracking-[0.4em] text-slate-100 placeholder:tracking-normal placeholder:text-slate-500 focus:border-blue-500 focus:outline-none"
          />
          {#if pinMessage}
            <p class="text-xs {pinMessage.type === 'success' ? 'text-emerald-400' : 'text-red-400'}">
              {pinMessage.text}
            </p>
          {/if}
          <button
            type="submit"
            disabled={pinWorking || !validPin(pin) || !validPin(pinConfirm)}
            class="flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2 text-xs font-medium text-white hover:bg-blue-500 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {#if pinWorking}<Loader2 class="h-4 w-4 animate-spin" />{/if}
            Aktifkan PIN Cepat
          </button>
        </form>
      {/if}
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
