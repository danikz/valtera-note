// Clipboard util untuk Tauri WebView2.
//
// navigator.clipboard di WebView2 sering gagal diam-diam (tanpa user gesture
// yang dikenali, atau window kehilangan focus), sehingga tombol "copy" yang
// hanya memanggil writeText lalu menampilkan toast terlihat "bohong".
// Urutan prioritas di sini: plugin clipboard Tauri (paling andal) →
// navigator.clipboard → fallback execCommand. Semua fungsi mengembalikan
// keberhasilan NYATA; pemanggil wajib menampilkan toast berdasarkan nilai ini.

const isTauri = typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;

export async function copyText(text: string): Promise<boolean> {
  if (!text) return false;

  if (isTauri) {
    try {
      const { writeText } = await import('@tauri-apps/plugin-clipboard-manager');
      await writeText(text);
      return true;
    } catch (err) {
      console.warn('clipboard plugin writeText failed:', err);
    }
  }

  try {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(text);
      return true;
    }
  } catch (err) {
    console.warn('navigator.clipboard.writeText failed:', err);
  }

  // Fallback terakhir: textarea tersembunyi + execCommand, harus dipanggil
  // sinkron di dalam gesture user agar browser mengizinkan copy.
  try {
    const ta = document.createElement('textarea');
    ta.value = text;
    ta.setAttribute('readonly', '');
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.focus();
    ta.select();
    const ok = document.execCommand('copy');
    document.body.removeChild(ta);
    return ok;
  } catch (err) {
    console.warn('execCommand copy failed:', err);
    return false;
  }
}

export async function readClipboardText(): Promise<string> {
  if (isTauri) {
    try {
      const { readText } = await import('@tauri-apps/plugin-clipboard-manager');
      return (await readText()) ?? '';
    } catch (err) {
      console.warn('clipboard plugin readText failed:', err);
    }
  }
  try {
    return await navigator.clipboard.readText();
  } catch (err) {
    console.warn('navigator.clipboard.readText failed:', err);
    return '';
  }
}
