// Format waktu tampilan aplikasi dengan zona waktu yang bisa diatur user
// (Pengaturan → Tampilan → Zona Waktu; default Asia/Jakarta = GMT+7).
//
// toLocaleTimeString() tanpa opsi mengikuti locale sistem (bisa 12 jam AM/PM)
// dan tidak mencantumkan zona waktu. Di sini format dikunci 24 jam, dengan
// suffix offset GMT yang dihitung dari zona aktif.

const isTauri = typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;

export const SETTING_DISPLAY_TIMEZONE = 'display_timezone';

// Zona populer untuk dropdown Pengaturan; label GMT dihitung dinamis karena
// sebagian zona punya DST.
export const TIMEZONE_OPTIONS: Array<{ value: string; label: string }> = [
  { value: 'Asia/Jakarta', label: 'Jakarta (WIB)' },
  { value: 'Asia/Makassar', label: 'Makassar (WITA)' },
  { value: 'Asia/Jayapura', label: 'Jayapura (WIT)' },
  { value: 'Asia/Singapore', label: 'Singapura' },
  { value: 'Asia/Tokyo', label: 'Tokyo' },
  { value: 'Asia/Dubai', label: 'Dubai' },
  { value: 'UTC', label: 'UTC' },
  { value: 'Europe/London', label: 'London' },
  { value: 'Europe/Berlin', label: 'Berlin' },
  { value: 'America/New_York', label: 'New York' },
  { value: 'America/Los_Angeles', label: 'Los Angeles' }
];

let displayTimezone = 'Asia/Jakarta';

export function getDisplayTimezone(): string {
  return displayTimezone;
}

export function setDisplayTimezone(tz: string): void {
  if (tz) displayTimezone = tz;
}

// Muat zona tersimpan dari app settings; dipanggil sekali saat app init.
export async function loadDisplayTimezone(): Promise<void> {
  if (!isTauri) return;
  try {
    const { ipc } = await import('../services/ipc');
    const saved = await ipc.getAppSetting(SETTING_DISPLAY_TIMEZONE);
    if (saved) setDisplayTimezone(saved);
  } catch (err) {
    console.warn('Gagal memuat zona waktu tampilan:', err);
  }
}

export function gmtOffsetLabel(tz: string = displayTimezone, date: Date = new Date()): string {
  try {
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: tz,
      timeZoneName: 'shortOffset'
    }).formatToParts(date);
    return parts.find(p => p.type === 'timeZoneName')?.value || '';
  } catch {
    return '';
  }
}

export function formatTime(date: Date = new Date()): string {
  const time = date.toLocaleTimeString('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
    timeZone: displayTimezone
  });
  const gmt = gmtOffsetLabel();
  return gmt ? `${time} ${gmt}` : time;
}

export function formatDateTime(date: Date = new Date()): string {
  const day = date.toLocaleDateString('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    timeZone: displayTimezone
  });
  return `${day} ${formatTime(date)}`;
}
