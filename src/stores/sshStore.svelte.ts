// Jembatan antara menu SSH di titlebar dan halaman SSH Manager.
// Titlebar meminta connect koneksi tertentu; SshPage mengonsumsi permintaan
// ini setelah daftar koneksinya termuat.

import { ipc } from '../services/ipc';
import type { RemoteSshConnection } from '../types';

export const sshStore = $state({
  pendingConnectId: null as string | null
});

export function requestSshConnect(id: string): void {
  sshStore.pendingConnectId = id;
}

export function consumeSshConnectRequest(): string | null {
  const id = sshStore.pendingConnectId;
  sshStore.pendingConnectId = null;
  return id;
}

// ===== Sinkronisasi kredensial SSH ke Supabase =====
// Payload tersimpan lokal sudah ciphertext E2E — yang dikirim ke cloud hanya
// ciphertext itu, jadi server tidak pernah melihat kredensial plaintext.
// Pola sama dengan sync notes: pull (merge) + push + heal tombstone hapus.

const DELETED_IDS_KEY = 'valtera_ssh_deleted_ids';
const DELETED_IDS_CAP = 500;

export const sshSyncState = $state({
  status: 'idle' as 'idle' | 'unconfigured' | 'syncing' | 'ok' | 'error',
  message: '',
  lastSyncAt: ''
});

function loadDeletedIds(): string[] {
  try {
    const raw = localStorage.getItem(DELETED_IDS_KEY);
    const arr = raw ? (JSON.parse(raw) as string[]) : [];
    return Array.isArray(arr) ? arr : [];
  } catch {
    return [];
  }
}

function rememberDeletedId(id: string): void {
  const ids = loadDeletedIds().filter((x) => x !== id);
  ids.push(id);
  while (ids.length > DELETED_IDS_CAP) ids.shift();
  try {
    localStorage.setItem(DELETED_IDS_KEY, JSON.stringify(ids));
  } catch {
    /* storage penuh — tombstone hilang, sync tetap jalan */
  }
}

function parseTs(ts?: string | null): Date | null {
  if (!ts) return null;
  const t = ts.trim();
  if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/.test(t)) {
    // Format CURRENT_TIMESTAMP SQLite — UTC.
    const d = new Date(t.replace(' ', 'T') + 'Z');
    return isNaN(d.getTime()) ? null : d;
  }
  const d = new Date(t);
  return isNaN(d.getTime()) ? null : d;
}

// Bila waktu tak terbanding, remote dianggap lebih baru (aman untuk data lama).
function remoteNewer(remoteTs: string | null | undefined, localTs: string): boolean {
  const r = parseTs(remoteTs);
  const l = parseTs(localTs);
  if (!r || !l) return true;
  return r.getTime() > l.getTime();
}

async function pushOne(
  cfg: { url: string; anon_key: string; access_token?: string | null },
  local: { id: string; label: string; payload: string }
): Promise<void> {
  await ipc.upsertRemoteSshConnection(
    cfg.url,
    cfg.anon_key,
    { id: local.id, label: local.label, payload: local.payload },
    cfg.access_token || undefined
  );
}

export async function syncSshConnections(): Promise<void> {
  if (sshSyncState.status === 'syncing') return;
  let cfg: { url: string; anon_key: string; is_configured: boolean; access_token?: string | null };
  try {
    cfg = await ipc.getSupabaseConfig();
  } catch {
    sshSyncState.status = 'unconfigured';
    sshSyncState.message = '';
    return;
  }
  if (!cfg.is_configured) {
    sshSyncState.status = 'unconfigured';
    sshSyncState.message = '';
    return;
  }
  const e2e = await ipc.e2eStatus();
  if (e2e === 'locked') {
    sshSyncState.status = 'error';
    sshSyncState.message = 'Sync dijeda: aplikasi terkunci';
    return;
  }

  sshSyncState.status = 'syncing';
  sshSyncState.message = 'Menyinkronkan koneksi SSH…';
  try {
    const remote = await ipc.fetchRemoteSshConnections(cfg.url, cfg.anon_key, cfg.access_token || undefined);
    const locals = await ipc.sshConnList();
    const deletedIds = loadDeletedIds();

    let pulled = 0;
    let pushed = 0;
    let removed = 0;

    // 1. Heal tombstone + pull koneksi remote.
    const remoteActiveIds = new Set<string>();
    for (const r of remote as RemoteSshConnection[]) {
      if (!r.id) continue;
      if (r.is_deleted || deletedIds.includes(r.id)) {
        const local = locals.find((l) => l.id === r.id);
        if (local) {
          await ipc.sshConnDelete(r.id);
          removed++;
        }
        continue;
      }
      remoteActiveIds.add(r.id);

      const local = locals.find((l) => l.id === r.id);
      if (!local) {
        await ipc.sshConnSave(r.id, r.label || 'SSH', r.payload);
        pulled++;
      } else if (local.payload !== r.payload && remoteNewer(r.updated_at, local.updated_at)) {
        // Konflik konten: versi yang lebih baru menang.
        await ipc.sshConnSave(r.id, r.label || local.label, r.payload);
        pulled++;
      }
    }

    // 2. Push koneksi lokal: belum ada di cloud, atau payload lebih baru dari remote.
    const remoteList = remote as RemoteSshConnection[];
    for (const l of locals) {
      if (deletedIds.includes(l.id)) continue;
      const r = remoteList.find((x) => x.id === l.id);
      const remoteHasNewer = r && r.payload !== l.payload && remoteNewer(r.updated_at, l.updated_at);
      if (!r || r.is_deleted || (r.payload !== l.payload && !remoteHasNewer)) {
        await pushOne(cfg, l);
        pushed++;
      }
    }

    sshSyncState.status = 'ok';
    sshSyncState.lastSyncAt = new Date().toLocaleTimeString();
    sshSyncState.message =
      pulled || pushed || removed
        ? `Sinkron — ${pulled} ditarik, ${pushed} dikirim${removed ? `, ${removed} dihapus` : ''}`
        : 'Sinkron — sudah sama semua';
  } catch (e: any) {
    sshSyncState.status = 'error';
    sshSyncState.message = typeof e === 'string' ? e : e?.message || 'Gagal sinkronisasi';
  }
}

// Dipanggil SshPage sebelum menghapus koneksi — memastikan tombstone ikut
// terkirim ke cloud saat sync berikutnya (hapus di satu perangkat = hapus semua).
export function rememberSshDeletedId(id: string): void {
  rememberDeletedId(id);
}
