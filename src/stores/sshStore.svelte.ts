// Jembatan antara menu SSH di titlebar dan halaman SSH Manager.
// Titlebar meminta connect koneksi tertentu; SshPage mengonsumsi permintaan
// ini setelah daftar koneksinya termuat.

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
