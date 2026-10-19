// Registry instance xterm per sesi SSH, hidup di level modul — BUKAN di
// komponen SshPage. Halaman SSH di-unmount saat pengguna pindah ke Catatan /
// tool lain; kalau terminal ikut dibuang lalu dibangun ulang dari replay
// output mentah, escape sequence (posisi kursor, scroll region, alternate
// screen) yang dibuat untuk ukuran/state lama membuat layar berantakan.
// Dengan registry ini terminal yang sama cukup dipasang ulang ke DOM, dan
// output sesi selama halaman ditinggal tetap ditulis ke buffernya.

import { Terminal } from '@xterm/xterm';
import { FitAddon } from '@xterm/addon-fit';
import { listen } from '@tauri-apps/api/event';
import { ipc } from '../../services/ipc';

// pending   = terminal belum pernah tampil ber-ukuran benar; data live dibuang
//             karena toh sudah tercakup snapshot replay yang diambil nanti.
// replaying = snapshot sedang diambil; data live ditahan agar urutan benar.
// ready     = data live langsung ditulis.
type ReplayState = 'pending' | 'replaying' | 'ready';

export interface SshTermEntry {
  term: Terminal;
  fitAddon: FitAddon;
  host: HTMLDivElement; // wadah tetap milik xterm, dipindah antar mount
  state: ReplayState;
  queue: string[];
}

const terms = new Map<string, SshTermEntry>();
let listening: Promise<void> | null = null;

function writeLive(entry: SshTermEntry, data: string) {
  if (entry.state === 'ready') entry.term.write(data);
  else if (entry.state === 'replaying') entry.queue.push(data);
}

// Listener global — dipasang sekali dan tidak pernah dilepas, supaya output
// sesi tetap masuk ke terminalnya walau halaman SSH sedang tidak tampil.
export function ensureSshTermListeners(): Promise<void> {
  if (!listening) {
    listening = Promise.all([
      listen<{ id: string; data: string }>('ssh-data', (e) => {
        const entry = terms.get(e.payload.id);
        if (entry) writeLive(entry, e.payload.data);
      }),
      listen<{ id: string; status: string }>('ssh-status', (e) => {
        if (e.payload.status !== 'closed' && e.payload.status !== 'disconnected') return;
        const entry = terms.get(e.payload.id);
        if (entry) writeLive(entry, `\r\n\x1b[33m[Sesi ditutup]\x1b[0m\r\n`);
      })
    ]).then(
      () => {},
      (err) => {
        listening = null;
        throw err;
      }
    );
  }
  return listening;
}

export function getSshTerm(sessionId: string): SshTermEntry | undefined {
  return terms.get(sessionId);
}

export function sshTermIds(): string[] {
  return [...terms.keys()];
}

// Pasang terminal sesi ke `el`: pakai instance yang sudah ada bila ada,
// atau buat baru (xterm butuh wadah yang sudah ada di DOM saat open()).
export function attachSshTerm(el: HTMLDivElement, sessionId: string): SshTermEntry {
  const existing = terms.get(sessionId);
  if (existing) {
    el.appendChild(existing.host);
    // Renderer xterm berhenti menggambar selama elemennya lepas dari DOM.
    requestAnimationFrame(() => existing.term.refresh(0, existing.term.rows - 1));
    return existing;
  }
  const host = document.createElement('div');
  host.style.width = '100%';
  host.style.height = '100%';
  el.appendChild(host);
  const term = new Terminal({
    fontFamily: 'ui-monospace, "Cascadia Mono", Consolas, monospace',
    fontSize: 13,
    cursorBlink: true,
    theme: { background: '#0b0f19', foreground: '#e2e8f0' }
  });
  const fitAddon = new FitAddon();
  term.loadAddon(fitAddon);
  term.open(host);
  term.onData((data) => {
    ipc.sshWrite(sessionId, data);
  });
  const entry: SshTermEntry = { term, fitAddon, host, state: 'pending', queue: [] };
  terms.set(sessionId, entry);
  return entry;
}

// Lepas dari DOM tanpa membuang terminalnya (halaman ditinggalkan).
export function detachSshTerm(el: HTMLDivElement, sessionId: string) {
  const entry = terms.get(sessionId);
  if (entry && entry.host.parentElement === el) el.removeChild(entry.host);
}

// Buang terminal sepenuhnya (tab ditutup / sesi sudah mati).
export function disposeSshTerm(sessionId: string) {
  const entry = terms.get(sessionId);
  if (!entry) return;
  entry.term.dispose();
  entry.host.remove();
  terms.delete(sessionId);
}

// Isi layar terakhir sesi dipulihkan dari replay buffer Rust — hanya sekali,
// dan baru setelah terminal tampil dengan ukuran sebenarnya. Replay pada
// ukuran default (wadah tersembunyi) membuat output yang memakai posisi
// kursor absolut tergambar di tempat yang salah.
export function beginSshReplay(sessionId: string) {
  const entry = terms.get(sessionId);
  if (!entry || entry.state !== 'pending') return;
  entry.state = 'replaying';
  ipc
    .sshReplay(sessionId)
    .then((replay) => {
      if (replay) entry.term.write(replay);
    })
    .catch(() => {})
    .finally(() => {
      entry.state = 'ready';
      for (const chunk of entry.queue) entry.term.write(chunk);
      entry.queue.length = 0;
    });
}
