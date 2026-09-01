import { check, type Update } from '@tauri-apps/plugin-updater';
import { relaunch } from '@tauri-apps/plugin-process';

const isTauri = typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;

export interface UpdateProgress {
  downloaded: number;
  total: number | null;
  percentage: number;
}

class UpdaterService {
  isChecking = $state<boolean>(false);
  updateAvailable = $state<boolean>(false);
  isDownloading = $state<boolean>(false);
  downloadProgress = $state<UpdateProgress>({ downloaded: 0, total: null, percentage: 0 });
  currentUpdate = $state<Update | null>(null);
  newVersion = $state<string>('');
  currentVersion = $state<string>('0.1.0');
  releaseNotes = $state<string>('');
  releaseDate = $state<string>('');
  errorMessage = $state<string | null>(null);
  showUpdateModal = $state<boolean>(false);
  isMandatory = $state<boolean>(true);

  async checkForUpdates(manual = false): Promise<boolean> {
    if (!isTauri) {
      if (manual) {
        alert('Fitur pembaruan otomatis aktif pada aplikasi desktop Valtera Note.');
      }
      return false;
    }

    try {
      this.isChecking = true;
      this.errorMessage = null;

      const update = await check();

      if (update && update.available) {
        this.currentUpdate = update;
        this.newVersion = update.version || '';
        this.currentVersion = update.currentVersion || '0.1.0';
        this.releaseNotes = update.body || 'Pembaruan ini mencakup perbaikan bug dan peningkatan performa sistem.';
        this.releaseDate = update.date ? new Date(update.date).toLocaleDateString('id-ID', { dateStyle: 'medium' }) : '';
        this.updateAvailable = true;
        this.showUpdateModal = true;
        return true;
      } else {
        this.updateAvailable = false;
        if (manual) {
          alert('Aplikasi Valtera Note Anda sudah dalam versi terbaru!');
        }
        return false;
      }
    } catch (err: any) {
      console.warn('Gagal memeriksa pembaruan:', err);
      this.errorMessage = typeof err === 'string' ? err : err?.message || 'Gagal terhubung ke server pembaruan';
      if (manual) {
        alert(`Gagal memeriksa pembaruan: ${this.errorMessage}`);
      }
      return false;
    } finally {
      this.isChecking = false;
    }
  }

  async downloadAndInstall(): Promise<void> {
    if (!this.currentUpdate) return;

    try {
      this.isDownloading = true;
      this.errorMessage = null;
      this.downloadProgress = { downloaded: 0, total: null, percentage: 0 };

      let totalBytes = 0;
      let downloadedBytes = 0;

      await this.currentUpdate.downloadAndInstall((event) => {
        if (event.event === 'Started') {
          totalBytes = event.data.contentLength || 0;
          this.downloadProgress = {
            downloaded: 0,
            total: totalBytes > 0 ? totalBytes : null,
            percentage: 0
          };
        } else if (event.event === 'Progress') {
          downloadedBytes += event.data.chunkLength;
          const percentage = totalBytes > 0 ? Math.min(100, Math.round((downloadedBytes / totalBytes) * 100)) : 0;
          this.downloadProgress = {
            downloaded: downloadedBytes,
            total: totalBytes > 0 ? totalBytes : null,
            percentage
          };
        } else if (event.event === 'Finished') {
          this.downloadProgress = {
            downloaded: totalBytes,
            total: totalBytes,
            percentage: 100
          };
        }
      });

      await relaunch();
    } catch (err: any) {
      console.error('Gagal mengunduh dan memasang pembaruan:', err);
      this.errorMessage = typeof err === 'string' ? err : err?.message || 'Gagal menginstal pembaruan';
    } finally {
      this.isDownloading = false;
    }
  }

  closeModal() {
    if (!this.isDownloading) {
      this.showUpdateModal = false;
    }
  }
}

export const updaterService = new UpdaterService();
