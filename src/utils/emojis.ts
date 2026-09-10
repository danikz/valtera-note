import type { CompletionContext, CompletionResult, Completion } from '@codemirror/autocomplete';

export interface EmojiItem {
  char: string;
  name: string;
  title: string;
  category: 'dev' | 'status' | 'docs' | 'symbols' | 'smileys';
  keywords: string[];
}

export const EMOJI_CATEGORIES = [
  { id: 'all', label: 'Semua' },
  { id: 'dev', label: '💻 Dev & DB' },
  { id: 'status', label: '✅ Status & Task' },
  { id: 'docs', label: '📝 Dokumen & Kerja' },
  { id: 'symbols', label: '⭐ Simbol & Panah' },
  { id: 'smileys', label: '😀 Ekspresi' }
] as const;

export const EMOJI_LIST: EmojiItem[] = [
  // --- DEVELOPER & DATABASE ---
  { char: '🚀', name: 'rocket', title: 'Rocket / Peluncuran', category: 'dev', keywords: ['roket', 'launch', 'deploy', 'cepat', 'speed', 'release'] },
  { char: '🔥', name: 'fire', title: 'Fire / Api / Populer', category: 'dev', keywords: ['api', 'hot', 'bug', 'burn', 'panas', 'danger'] },
  { char: '⚡', name: 'zap', title: 'Zap / Kilat / Cepat', category: 'dev', keywords: ['kilat', 'listrik', 'fast', 'performa', 'speed', 'quick', 'energy'] },
  { char: '🐛', name: 'bug', title: 'Bug / Masalah / Kutu', category: 'dev', keywords: ['kutu', 'error', 'issue', 'bugfix', 'masalah', 'defect'] },
  { char: '💻', name: 'laptop', title: 'Laptop / Komputer', category: 'dev', keywords: ['komputer', 'pc', 'dev', 'coding', 'koding', 'program'] },
  { char: '🖥️', name: 'desktop', title: 'Desktop / Monitor', category: 'dev', keywords: ['layar', 'monitor', 'computer', 'screen'] },
  { char: '🗄️', name: 'database', title: 'Database / Basis Data', category: 'dev', keywords: ['db', 'sql', 'storage', 'data', 'table', 'query', 'basisdata'] },
  { char: '📊', name: 'chart', title: 'Bar Chart / Statistik', category: 'dev', keywords: ['grafik', 'diagram', 'data', 'analytics', 'statistik', 'report'] },
  { char: '📈', name: 'trending_up', title: 'Trending Up / Meningkat', category: 'dev', keywords: ['naik', 'pertumbuhan', 'profit', 'stats', 'growth'] },
  { char: '📉', name: 'trending_down', title: 'Trending Down / Penurunan', category: 'dev', keywords: ['turun', 'penurunan', 'loss', 'drop'] },
  { char: '🔍', name: 'search', title: 'Search / Cari', category: 'dev', keywords: ['cari', 'temukan', 'find', 'query', 'filter', 'kaca pembesar'] },
  { char: '⚙️', name: 'gear', title: 'Gear / Pengaturan', category: 'dev', keywords: ['setting', 'pengaturan', 'config', 'tools', 'roda', 'opsi'] },
  { char: '🛠️', name: 'tools', title: 'Tools / Perkakas', category: 'dev', keywords: ['alat', 'maintenance', 'perbaikan', 'fix', 'setting', 'perkakas'] },
  { char: '🔧', name: 'wrench', title: 'Wrench / Kunci Pas', category: 'dev', keywords: ['kunci pas', 'tune', 'reparasi', 'repair'] },
  { char: '📦', name: 'package', title: 'Package / Kotak Paket', category: 'dev', keywords: ['paket', 'bundle', 'npm', 'module', 'release', 'box'] },
  { char: '🔒', name: 'lock', title: 'Lock / Terkunci', category: 'dev', keywords: ['kunci', 'gembok', 'secure', 'auth', 'rahasia', 'enkripsi', 'aman'] },
  { char: '🔓', name: 'unlock', title: 'Unlock / Terbuka', category: 'dev', keywords: ['buka kunci', 'open', 'public', 'akses'] },
  { char: '🔑', name: 'key', title: 'Key / Kunci Akses', category: 'dev', keywords: ['kunci', 'apikey', 'secret', 'token', 'sandi', 'password'] },
  { char: '🌐', name: 'globe', title: 'Globe / Internet / Web', category: 'dev', keywords: ['web', 'internet', 'network', 'jaringan', 'url', 'http', 'dunia'] },
  { char: '📡', name: 'satellite', title: 'Satellite / API Endpoint', category: 'dev', keywords: ['api', 'endpoint', 'sinyal', 'socket', 'server', 'komunikasi'] },
  { char: '☁️', name: 'cloud', title: 'Cloud / Awan', category: 'dev', keywords: ['awan', 'supabase', 'server', 'hosting', 'sync'] },
  { char: '🤖', name: 'robot', title: 'Robot / AI', category: 'dev', keywords: ['ai', 'bot', 'otomatis', 'agent', 'llm', 'machine'] },
  { char: '🧠', name: 'brain', title: 'Brain / Otak / Logika', category: 'dev', keywords: ['otak', 'cerdas', 'pikir', 'memory', 'ai', 'logic', 'ingatan'] },
  { char: '🧪', name: 'test', title: 'Test / Tabung Uji', category: 'dev', keywords: ['tabung', 'eksperimen', 'qa', 'unittest', 'testing', 'uji'] },
  { char: '🏷️', name: 'tag', title: 'Tag / Label Versi', category: 'dev', keywords: ['label', 'kategori', 'versi', 'release', 'badge'] },
  { char: '🔗', name: 'link', title: 'Link / Tautan', category: 'dev', keywords: ['tautan', 'hubungan', 'referensi', 'url', 'rantai'] },
  { char: '📁', name: 'folder', title: 'Folder / Map Berkas', category: 'dev', keywords: ['berkas', 'direktori', 'map', 'arsip'] },
  { char: '📂', name: 'folder_open', title: 'Open Folder / Buka Map', category: 'dev', keywords: ['buka folder', 'direktori', 'arsip terbuka'] },
  { char: '📄', name: 'document', title: 'Document / Dokumen', category: 'dev', keywords: ['dokumen', 'file', 'berkas', 'kertas', 'halaman'] },
  { char: '📜', name: 'scroll', title: 'Scroll / Log / Riwayat', category: 'dev', keywords: ['log', 'riwayat', 'naskah', 'history'] },
  { char: '💾', name: 'floppy', title: 'Floppy / Simpan', category: 'dev', keywords: ['simpan', 'save', 'disket', 'disk'] },
  { char: '🗑️', name: 'trash', title: 'Trash / Hapus', category: 'dev', keywords: ['sampah', 'hapus', 'delete', 'buang'] },

  // --- STATUS, TASKS, & INDICATORS ---
  { char: '✅', name: 'check', title: 'Check / Centang Hijau', category: 'status', keywords: ['centang', 'sukses', 'done', 'selesai', 'ok', 'benar', 'pass', 'success'] },
  { char: '☑️', name: 'checkbox', title: 'Checkbox / Kotak Centang', category: 'status', keywords: ['centang box', 'todo', 'checklist', 'tugas'] },
  { char: '✔️', name: 'heavy_check', title: 'Heavy Check / Centang Tebal', category: 'status', keywords: ['centang tebal', 'verified', 'valid', 'terverifikasi'] },
  { char: '❌', name: 'cross', title: 'Cross / Silang Merah', category: 'status', keywords: ['silang', 'batal', 'gagal', 'fail', 'error', 'salah', 'cancel'] },
  { char: '❎', name: 'cross_box', title: 'Cross Box / Kotak Silang', category: 'status', keywords: ['kotak silang', 'reject', 'tolak'] },
  { char: '⚠️', name: 'warning', title: 'Warning / Peringatan', category: 'status', keywords: ['peringatan', 'bahaya', 'alert', 'hati-hati', 'caution', 'warn'] },
  { char: '🚨', name: 'siren', title: 'Siren / Darurat', category: 'status', keywords: ['darurat', 'emergency', 'alarm', 'urgent', 'kritis'] },
  { char: '💡', name: 'idea', title: 'Idea / Ide / Solusi', category: 'status', keywords: ['ide', 'lampu', 'tips', 'solusi', 'insight', 'bulb'] },
  { char: '📌', name: 'pin', title: 'Pin / Sematan', category: 'status', keywords: ['semat', 'bookmark', 'tancap', 'penting', 'notice', 'paku'] },
  { char: '📍', name: 'round_pin', title: 'Round Pin / Lokasi', category: 'status', keywords: ['lokasi', 'titik', 'target', 'posisi'] },
  { char: '🎯', name: 'target', title: 'Target / Sasaran', category: 'status', keywords: ['sasaran', 'goal', 'objektif', 'tujuan', 'fokus'] },
  { char: '🚩', name: 'flag', title: 'Flag / Bendera', category: 'status', keywords: ['bendera', 'mark', 'milestone', 'tandai'] },
  { char: '⏳', name: 'hourglass', title: 'Hourglass / Menunggu', category: 'status', keywords: ['menunggu', 'pending', 'proses', 'delay', 'waktu', 'antri'] },
  { char: '⏰', name: 'alarm', title: 'Alarm / Jam Dinding', category: 'status', keywords: ['jam', 'waktu', 'deadline', 'pengingat', 'timer'] },
  { char: '⏱️', name: 'stopwatch', title: 'Stopwatch / Pengukur Waktu', category: 'status', keywords: ['timer', 'kecepatan', 'benchmark', 'durasi'] },
  { char: '🟢', name: 'green_circle', title: 'Green Circle / Aktif', category: 'status', keywords: ['online', 'aktif', 'sukses', 'hidup', 'berjalan'] },
  { char: '🔴', name: 'red_circle', title: 'Red Circle / Mati', category: 'status', keywords: ['offline', 'mati', 'bahaya', 'stop', 'berhenti'] },
  { char: '🟡', name: 'yellow_circle', title: 'Yellow Circle / Siaga', category: 'status', keywords: ['siaga', 'pending', 'warning', 'menunggu'] },
  { char: '🔵', name: 'blue_circle', title: 'Blue Circle / Info', category: 'status', keywords: ['info', 'normal', 'proses', 'biru'] },
  { char: '⚪', name: 'white_circle', title: 'White Circle / Netral', category: 'status', keywords: ['netral', 'idle', 'putih'] },
  { char: '⚫', name: 'black_circle', title: 'Black Circle / Gelap', category: 'status', keywords: ['gelap', 'mati', 'hitam'] },
  { char: '❓', name: 'question', title: 'Question / Tanya', category: 'status', keywords: ['tanya', 'bingung', 'faq', 'help', 'bantuan', 'ragu'] },
  { char: '❗', name: 'exclamation', title: 'Exclamation / Tanda Seru', category: 'status', keywords: ['seru', 'perhatian', 'penting', 'notice', 'awas'] },
  { char: '💯', name: '100', title: '100 / Sempurna', category: 'status', keywords: ['sempurna', 'perfect', 'lulus', 'mantap', 'skor'] },

  // --- DOCS, NOTES & WORK ---
  { char: '📝', name: 'memo', title: 'Memo / Catatan', category: 'docs', keywords: ['catatan', 'note', 'tulis', 'draft', 'pensil', 'teks'] },
  { char: '✏️', name: 'pencil', title: 'Pencil / Pensil Edit', category: 'docs', keywords: ['pensil', 'tulis', 'edit', 'ubah'] },
  { char: '🖋️', name: 'pen', title: 'Pen / Pena Tanda Tangan', category: 'docs', keywords: ['pena', 'tanda tangan', 'sign', 'pulpen'] },
  { char: '📋', name: 'clipboard', title: 'Clipboard / Papan Tugas', category: 'docs', keywords: ['papan klip', 'tugas', 'copy', 'paste', 'daftar'] },
  { char: '📅', name: 'calendar', title: 'Calendar / Kalender', category: 'docs', keywords: ['kalender', 'tanggal', 'jadwal', 'agenda'] },
  { char: '📆', name: 'calendar_page', title: 'Calendar Page / Agenda Hari', category: 'docs', keywords: ['jadwal hari ini', 'appointment', 'pertemuan'] },
  { char: '📎', name: 'paperclip', title: 'Paperclip / Lampiran', category: 'docs', keywords: ['lampiran', 'attach', 'klip', 'file'] },
  { char: '🎨', name: 'palette', title: 'Palette / Desain & Tema', category: 'docs', keywords: ['warna', 'ui', 'desain', 'tema', 'seni', 'artistik'] },
  { char: '💼', name: 'briefcase', title: 'Briefcase / Koper Kerja', category: 'docs', keywords: ['koper', 'kerja', 'bisnis', 'job', 'portfolio'] },
  { char: '🏢', name: 'office', title: 'Office / Kantor', category: 'docs', keywords: ['kantor', 'perusahaan', 'valtera', 'enterprise', 'gedung'] },
  { char: '📢', name: 'megaphone', title: 'Megaphone / Pengumuman', category: 'docs', keywords: ['pengumuman', 'broadcast', 'info', 'halo', 'speaker'] },
  { char: '💬', name: 'speech', title: 'Speech Bubble / Komentar', category: 'docs', keywords: ['pesan', 'obrolan', 'chat', 'komentar', 'diskusi'] },
  { char: '✉️', name: 'mail', title: 'Mail / Surat & Email', category: 'docs', keywords: ['email', 'surat', 'pesan', 'inbox', 'kontak'] },

  // --- SYMBOLS & ARROWS ---
  { char: '⭐', name: 'star', title: 'Star / Bintang', category: 'symbols', keywords: ['bintang', 'favorit', 'bookmark', 'rating', 'utama'] },
  { char: '🌟', name: 'glowing_star', title: 'Glowing Star / Fitur Spesial', category: 'symbols', keywords: ['bintang terang', 'fitur', 'highlight', 'istimewa'] },
  { char: '✨', name: 'sparkles', title: 'Sparkles / Kilauan / AI', category: 'symbols', keywords: ['kilau', 'ajaib', 'ai', 'baru', 'spesial', 'bersih'] },
  { char: '💎', name: 'gem', title: 'Gem / Berlian Premium', category: 'symbols', keywords: ['berlian', 'permata', 'premium', 'berharga', 'pro'] },
  { char: '🔔', name: 'bell', title: 'Bell / Lonceng Notifikasi', category: 'symbols', keywords: ['lonceng', 'notifikasi', 'alert', 'pemberitahuan'] },
  { char: '🔕', name: 'bell_off', title: 'Bell Off / Senyap', category: 'symbols', keywords: ['silent', 'senyap', 'tanpa notif', 'hening'] },
  { char: '➡️', name: 'arrow_right', title: 'Arrow Right / Panah Kanan', category: 'symbols', keywords: ['panah kanan', 'next', 'selanjutnya', 'ke', 'maju'] },
  { char: '⬅️', name: 'arrow_left', title: 'Arrow Left / Panah Kiri', category: 'symbols', keywords: ['panah kiri', 'back', 'kembali', 'mundur'] },
  { char: '⬆️', name: 'arrow_up', title: 'Arrow Up / Panah Atas', category: 'symbols', keywords: ['panah atas', 'naik', 'unggah', 'upload'] },
  { char: '⬇️', name: 'arrow_down', title: 'Arrow Down / Panah Bawah', category: 'symbols', keywords: ['panah bawah', 'turun', 'unduh', 'download'] },
  { char: '🔄', name: 'reload', title: 'Reload / Sinkronisasi', category: 'symbols', keywords: ['muat ulang', 'refresh', 'sync', 'loop', 'putar'] },
  { char: '➕', name: 'plus', title: 'Plus / Tambah', category: 'symbols', keywords: ['tambah', 'add', 'positif'] },
  { char: '➖', name: 'minus', title: 'Minus / Kurang', category: 'symbols', keywords: ['kurang', 'subtract', 'negatif'] },
  { char: '💲', name: 'dollar', title: 'Dollar / Biaya', category: 'symbols', keywords: ['uang', 'harga', 'cost', 'bayar', 'finance', 'dolar'] },
  { char: '💰', name: 'moneybag', title: 'Moneybag / Pundi Cuan', category: 'symbols', keywords: ['kantong uang', 'cuan', 'revenue', 'kas'] },
  { char: '🛡️', name: 'shield', title: 'Shield / Perlindungan', category: 'symbols', keywords: ['perisai', 'keamanan', 'proteksi', 'firewall', 'aman'] },
  { char: '❤️', name: 'heart', title: 'Heart / Hati Merah', category: 'symbols', keywords: ['hati', 'suka', 'cinta', 'love', 'like'] },
  { char: '💙', name: 'blue_heart', title: 'Blue Heart / Hati Biru', category: 'symbols', keywords: ['hati biru', 'valtera', 'suka'] },

  // --- SMILEYS & EXPRESSIONS ---
  { char: '😀', name: 'grinning', title: 'Grinning / Senyum Bahagia', category: 'smileys', keywords: ['senyum lebar', 'senang', 'hepi', 'gembira'] },
  { char: '😃', name: 'smiley', title: 'Smiley / Senyum Ceria', category: 'smileys', keywords: ['senyum', 'gembira', 'senang'] },
  { char: '😎', name: 'cool', title: 'Cool / Santai & Keren', category: 'smileys', keywords: ['keren', 'kacamata', 'santai', 'pro'] },
  { char: '🤔', name: 'thinking', title: 'Thinking / Berpikir', category: 'smileys', keywords: ['berpikir', 'mikir', 'ragu', 'analisis'] },
  { char: '🧐', name: 'monocle', title: 'Monocle / Memeriksa', category: 'smileys', keywords: ['menganalisis', 'teliti', 'inspeksi', 'riset'] },
  { char: '🤩', name: 'star_struck', title: 'Star Struck / Takjub', category: 'smileys', keywords: ['takjub', 'kagum', 'wow', 'terpukau'] },
  { char: '🎉', name: 'tada', title: 'Tada / Perayaan & Sukses', category: 'smileys', keywords: ['selamat', 'sukses', 'hore', 'confetti', 'pesta', 'celebrate'] },
  { char: '👍', name: 'thumbs_up', title: 'Thumbs Up / Jempol Bagus', category: 'smileys', keywords: ['jempol', 'like', 'setuju', 'mantap', 'sip', 'bagus'] },
  { char: '👎', name: 'thumbs_down', title: 'Thumbs Down / Kurang Setuju', category: 'smileys', keywords: ['jempol bawah', 'dislike', 'tidak setuju', 'buruk'] },
  { char: '👏', name: 'clap', title: 'Clap / Tepuk Tangan', category: 'smileys', keywords: ['tepuk tangan', 'apresiasi', 'hebat', 'bravo'] },
  { char: '🙌', name: 'raised_hands', title: 'Raised Hands / Angkat Tangan', category: 'smileys', keywords: ['angkat tangan', 'hore', 'syukur', 'selamat'] },
  { char: '🤝', name: 'handshake', title: 'Handshake / Jabat Tangan', category: 'smileys', keywords: ['jabat tangan', 'deal', 'sepakat', 'kerja sama', 'mitra'] },
  { char: '🙏', name: 'pray', title: 'Pray / Terima Kasih', category: 'smileys', keywords: ['terima kasih', 'tolong', 'maaf', 'please', 'thanks'] },
  { char: '💪', name: 'muscle', title: 'Muscle / Semangat Kuat', category: 'smileys', keywords: ['kuat', 'semangat', 'hebat', 'flex', 'power'] },
  { char: '☕', name: 'coffee', title: 'Coffee / Kopi Istirahat', category: 'smileys', keywords: ['kopi', 'istirahat', 'break', 'dev', 'kafein', 'ngopi'] },
  { char: '🏆', name: 'trophy', title: 'Trophy / Piala Juara', category: 'smileys', keywords: ['piala', 'juara', 'penghargaan', 'win', 'menang'] },
  { char: '👑', name: 'crown', title: 'Crown / Mahkota Pemimpin', category: 'smileys', keywords: ['mahkota', 'raja', 'terbaik', 'leader', 'champion'] }
];

// Pre-computed completions for CodeMirror
// Generates standard :name: plus common Indonesian/English aliases
function buildCompletions(): Completion[] {
  const result: Completion[] = [];
  const seenLabels = new Set<string>();

  for (const item of EMOJI_LIST) {
    // 1. Primary label e.g. :rocket:
    const primaryLabel = `:${item.name}:`;
    if (!seenLabels.has(primaryLabel)) {
      seenLabels.add(primaryLabel);
      result.push({
        label: primaryLabel,
        displayLabel: `${item.char}  :${item.name}:`,
        detail: item.title,
        apply: item.char,
        type: 'text',
        boost: 20
      });
    }

    // 2. High-value keyword aliases (e.g. :roket:, :db:, :sql:, :api:, :centang:, :peringatan:)
    for (const kw of item.keywords) {
      const cleanKw = kw.toLowerCase().replace(/[^a-z0-9_\-+]/g, '');
      if (cleanKw.length >= 2 && cleanKw !== item.name) {
        const aliasLabel = `:${cleanKw}:`;
        if (!seenLabels.has(aliasLabel)) {
          seenLabels.add(aliasLabel);
          result.push({
            label: aliasLabel,
            displayLabel: `${item.char}  :${cleanKw}:`,
            detail: item.title,
            apply: item.char,
            type: 'text',
            boost: 10
          });
        }
      }
    }
  }

  return result;
}

export const EMOJI_COMPLETIONS = buildCompletions();

/**
 * Autocompletion source function for CodeMirror 6
 * Matches when user types : followed by characters (e.g. :rock, :db, :api, :star)
 */
export function emojiCompletionSource(context: CompletionContext): CompletionResult | null {
  // Match :word starting with a colon
  const match = context.matchBefore(/:[a-zA-Z0-9_\-+]{1,}/);
  if (!match && !context.explicit) return null;

  return {
    from: match ? match.from : context.pos,
    options: EMOJI_COMPLETIONS,
    validFor: /^:[a-zA-Z0-9_\-+]*$/
  };
}
