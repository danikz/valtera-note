// State transfer SFTP di level modul — tetap hidup walau panel file ditutup,
// tab berganti, atau halaman SSH ditinggalkan selama transfer berjalan.

import { listen } from '@tauri-apps/api/event';
import { ipc } from '../../services/ipc';

export interface SftpTransfer {
  id: string;
  sessionId: string;
  kind: 'upload' | 'download';
  name: string;
  remoteDir: string; // folder remote terkait (tujuan upload / asal download)
  done: number;
  total: number | null;
  status: 'running' | 'done' | 'error' | 'cancelled';
  error?: string;
  localPath?: string; // hasil download
}

export const sftpState = $state<{ transfers: SftpTransfer[] }>({ transfers: [] });

// Folder terakhir yang dibuka per sesi — panel dibuka lagi di tempat yang sama.
export const sftpLastPath = new Map<string, string>();

// Dipanggil saat upload ke sebuah folder selesai, supaya panel yang sedang
// menampilkan folder itu bisa memuat ulang isinya.
type UploadDoneHandler = (sessionId: string, remoteDir: string) => void;
const uploadDoneHandlers = new Set<UploadDoneHandler>();
export function onSftpUploadDone(fn: UploadDoneHandler): () => void {
  uploadDoneHandlers.add(fn);
  return () => uploadDoneHandlers.delete(fn);
}

let listening: Promise<void> | null = null;

function ensureListener(): Promise<void> {
  if (!listening) {
    listening = listen<{ id: string; done: number; total: number | null }>('sftp-progress', (e) => {
      const t = sftpState.transfers.find((x) => x.id === e.payload.id);
      if (!t || t.status !== 'running') return;
      t.done = e.payload.done;
      if (e.payload.total != null) t.total = e.payload.total;
    }).then(
      () => {},
      (err) => {
        listening = null;
        throw err;
      }
    );
  }
  return listening;
}

function errText(e: unknown): string {
  return typeof e === 'string' ? e : (e as any)?.message || String(e);
}

async function run(t: SftpTransfer, job: () => Promise<string>) {
  await ensureListener().catch(() => {});
  sftpState.transfers.unshift(t);
  // Ambil proxy reaktifnya — mutasi lewat objek asli tidak memicu update UI.
  const tr = sftpState.transfers.find((x) => x.id === t.id)!;
  try {
    const result = await job();
    tr.status = 'done';
    if (tr.total != null) tr.done = tr.total;
    if (tr.kind === 'download') tr.localPath = result;
    else uploadDoneHandlers.forEach((fn) => fn(tr.sessionId, tr.remoteDir));
  } catch (e) {
    const msg = errText(e);
    tr.status = msg === 'Dibatalkan' ? 'cancelled' : 'error';
    tr.error = msg;
  }
}

export function startSftpDownload(sessionId: string, remoteDir: string, name: string, localDir: string | null) {
  const id = crypto.randomUUID();
  const remotePath = remoteDir === '/' ? `/${name}` : `${remoteDir}/${name}`;
  return run(
    { id, sessionId, kind: 'download', name, remoteDir, done: 0, total: null, status: 'running' },
    () => ipc.sftpDownload(sessionId, id, remotePath, localDir)
  );
}

export function startSftpUpload(sessionId: string, remoteDir: string, localPath: string) {
  const id = crypto.randomUUID();
  const name = localPath.split(/[\\/]/).pop() || localPath;
  return run(
    { id, sessionId, kind: 'upload', name, remoteDir, done: 0, total: null, status: 'running' },
    () => ipc.sftpUpload(sessionId, id, localPath, remoteDir)
  );
}

export function cancelSftpTransfer(id: string) {
  ipc.sftpCancel(id).catch(() => {});
}

export function clearFinishedSftpTransfers(sessionId: string) {
  sftpState.transfers = sftpState.transfers.filter((t) => t.sessionId !== sessionId || t.status === 'running');
}
