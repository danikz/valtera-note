<script lang="ts">
  import { editorStore } from '../../stores/editorStore.svelte';
  import { 
    X, 
    Database, 
    FileText, 
    FileCode,
    Code,
    Terminal,
    Copy, 
    PlusCircle, 
    Check, 
    Search, 
    BookOpen,
    Sparkles
  } from 'lucide-svelte';

  let { isOpen, onClose }: { isOpen: boolean; onClose: () => void } = $props();

  let searchQuery = $state('');
  let activeCategory = $state<'all' | 'markdown' | 'sql' | 'json' | 'regex' | 'git'>('all');
  let copiedId = $state<string | null>(null);

  interface KnowledgeItem {
    id: string;
    title: string;
    category: 'markdown' | 'sql' | 'json' | 'regex' | 'git';
    lang: 'md' | 'sql' | 'json' | 'text' | 'bash';
    badge: string;
    desc: string;
    keywords: string[];
    code: string;
  }

  const KNOWLEDGE_ITEMS: KnowledgeItem[] = [
    // ----------------------------------------------------
    // MARKDOWN & GFM CHEATSHEET
    // ----------------------------------------------------
    {
      id: 'md-callouts',
      title: 'Callout / Alert Box (GitHub Flavored)',
      category: 'markdown',
      lang: 'md',
      badge: 'GFM Callout',
      desc: 'Kotak catatan khusus resmi GFM: NOTE, TIP, IMPORTANT, WARNING, dan CAUTION.',
      keywords: ['alert', 'callout', 'note', 'tip', 'warning', 'caution', 'important', 'info', 'kotak'],
      code: `> [!NOTE]\n> Informasi penting atau konteks latar belakang yang perlu diketahui.\n\n> [!TIP]\n> Tips bermanfaat untuk meningkatkan efisiensi dan performa.\n\n> [!IMPORTANT]\n> Petunjuk krusial yang tidak boleh dilewatkan.\n\n> [!WARNING]\n> Peringatan risiko terjadinya kendala atau efek samping.\n\n> [!CAUTION]\n> Tindakan berbahaya yang dapat merusak data atau sistem.`
    },
    {
      id: 'md-table',
      title: 'Tabel Markdown dengan Perataan (Align)',
      category: 'markdown',
      lang: 'md',
      badge: 'Tabel & Kolom',
      desc: 'Sintaks tabel dengan perataan teks kiri (:---), tengah (:---:), dan angka kanan (---:).',
      keywords: ['table', 'tabel', 'kolom', 'align', 'rata kiri', 'rata kanan', 'baris'],
      code: `| Nama Kolom | Rata Kiri (:---) | Rata Tengah (:---:) | Rata Kanan (---:) |\n| :--------- | :--------------- | :-----------------: | ----------------: |\n| Baris 1    | Teks reguler     |       Status        |        Rp 125.000 |\n| Baris 2    | Teks lainnya     |         ✅          |        Rp 350.000 |\n| Baris 3    | Data ringkasan   |         ⏳          |      Rp 1.500.000 |`
    },
    {
      id: 'md-checklist',
      title: 'Daftar Tugas Interaktif (Task Checklist)',
      category: 'markdown',
      lang: 'md',
      badge: 'Interactive Todo',
      desc: 'Daftar centang interaktif yang dapat diklik langsung pada mode pratinjau (Reader Mode).',
      keywords: ['task', 'todo', 'checklist', 'centang', 'daftar tugas', 'rencana'],
      code: `### 📋 Daftar Rencana Kerja\n- [x] Rancang arsitektur database SQLite lokal\n- [x] Buat komponen antarmuka pengguna responsif\n- [ ] Integrasikan sinkronisasi Supabase Cloud\n- [ ] Pengujian performa dan rilis versi produksi`
    },
    {
      id: 'md-codeblocks',
      title: 'Blok Kode & Penyorotan Sintaks (Highlighting)',
      category: 'markdown',
      lang: 'md',
      badge: 'Code Block',
      desc: 'Menampilkan blok kode program dengan penanda bahasa (ts, js, sql, bash, json, dll).',
      keywords: ['code', 'kode', 'syntax', 'highlight', 'typescript', 'javascript', 'pre'],
      code: "```typescript\ninterface NoteItem {\n  id: string;\n  title: string;\n  tags: string[];\n  isPinned: boolean;\n}\n\nexport function formatNoteTitle(item: NoteItem): string {\n  return `[${item.tags.join(', ')}] ${item.title}`;\n}\n```"
    },
    {
      id: 'md-mermaid',
      title: 'Diagram Alur & Arsitektur (Mermaid JS)',
      category: 'markdown',
      lang: 'md',
      badge: 'Mermaid Diagram',
      desc: 'Membuat diagram alur (flowchart) langsung dari teks Markdown tanpa aplikasi pihak ketiga.',
      keywords: ['mermaid', 'diagram', 'flowchart', 'alur', 'arsitektur', 'grafik'],
      code: "```mermaid\nflowchart TD\n  A[Buka Aplikasi] --> B{Database Ada?}\n  B -- Ya --> C[Muat Catatan Lokal SQLite]\n  B -- Tidak --> D[Inisialisasi Tabel Baru]\n  D --> C\n  C --> E[Tampilkan Workspace Catatan]\n  E --> F[Auto-Sync Supabase di Background]\n```"
    },
    {
      id: 'md-math',
      title: 'Rumus Matematika & Persamaan (LaTeX / KaTeX)',
      category: 'markdown',
      lang: 'md',
      badge: 'Math KaTeX',
      desc: 'Persamaan matematika inline ($ ... $) dan blok rumus terpusat ($$ ... $$).',
      keywords: ['math', 'matematika', 'rumus', 'katex', 'latex', 'persamaan', 'sigma'],
      code: `Persamaan energi Einstein adalah $E = mc^2$.\n\nRumus kuadratik abc:\n$$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$$\n\nNotasi penjumlahan deret:\n$$\\sum_{i=1}^{n} i = \\frac{n(n + 1)}{2}$$`
    },
    {
      id: 'md-accordion',
      title: 'Konten Lipat / Akordeon (Details & Summary)',
      category: 'markdown',
      lang: 'md',
      badge: 'HTML Details',
      desc: 'Menyembunyikan log teknis atau penjelasan panjang agar dokumen tetap ringkas.',
      keywords: ['details', 'summary', 'accordion', 'lipat', 'collapse', 'sembunyi', 'toggle'],
      code: `<details>\n  <summary>🔍 Klik untuk melihat rincian konfigurasi teknis...</summary>\n\n  Berikut rincian lingkungan sistem:\n  - Driver: SQLite 3.45 (WAL Mode)\n  - Enkripsi: AES-256-GCM\n  - Editor Engine: CodeMirror 6\n</details>`
    },
    {
      id: 'md-formatting',
      title: 'Format Teks: Tebal, Miring, Coret, Stabilo & Keyboard',
      category: 'markdown',
      lang: 'md',
      badge: 'Text Styling',
      desc: 'Kombinasi format tebal, miring, coret, stabilo kuning, dan tombol shortcut keyboard.',
      keywords: ['bold', 'italic', 'strike', 'highlight', 'kbd', 'keyboard', 'tebal', 'miring', 'stabilo'],
      code: `**Teks Tebal** atau __Tebal Alternatif__\n*Teks Miring* atau _Miring Alternatif_\n~~Teks Dicoret (Strikethrough)~~\n==Teks Stabilo (Highlight)==\n\nPintasan cepat: <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>T</kbd>`
    },
    {
      id: 'md-footnotes',
      title: 'Catatan Kaki (Footnotes & Citations)',
      category: 'markdown',
      lang: 'md',
      badge: 'Footnotes',
      desc: 'Memberikan rujukan nomor catatan kaki yang otomatis ditautkan ke bagian bawah dokumen.',
      keywords: ['footnote', 'catatan kaki', 'sitasi', 'rujukan', 'referensi'],
      code: `Valtera Note dirancang dengan filosofi local-first[^1] demi kecepatan dan privasi pengguna[^2].\n\n[^1]: Seluruh data disimpan langsung di SQLite lokal komputer Anda.\n[^2]: Tidak ada pengumpulan data rahasia tanpa otorisasi.`
    },
    {
      id: 'md-meeting-template',
      title: 'Template Notulensi Rapat (Meeting Notes)',
      category: 'markdown',
      lang: 'md',
      badge: 'Dokumen Template',
      desc: 'Kerangka kerja siap pakai untuk mencatat agenda, peserta, kesepakatan, dan PIC tugas.',
      keywords: ['meeting', 'notulen', 'rapat', 'template', 'agenda', 'minutes'],
      code: `# 📅 Notulensi Rapat: [Topik / Proyek]\n\n- **Tanggal & Waktu:** 11 September 2026, 10:00 WIB\n- **Peserta:** @Nama1, @Nama2, @Nama3\n- **Tujuan Rapat:** Finalisasi rencana rilis v0.1.7\n\n---\n\n## 🎯 Poin Pembahasan Utama\n1. Evaluasi fitur sinkronisasi basis data Supabase.\n2. Implementasi Kamus Sintaks & Perintah jika lupa cara pakai.\n\n## 📌 Keputusan (Decisions Made)\n- Utamakan performa offline-first.\n- Rilis pembaruan ke repositori GitHub.\n\n## ✅ Tindakan Lanjutan (Action Items)\n- [ ] Uji coba build biner Windows (@Nama1)\n- [ ] Perbarui dokumentasi README (@Nama2)`
    },

    // ----------------------------------------------------
    // SQL & DATABASE CHEATSHEET
    // ----------------------------------------------------
    {
      id: 'sql-select',
      title: 'SELECT dengan Filter, Pengurutan & Paginasi',
      category: 'sql',
      lang: 'sql',
      badge: 'SELECT Query',
      desc: 'Struktur query baca data standar dengan WHERE, LIKE, IN, ORDER BY, LIMIT, dan OFFSET.',
      keywords: ['select', 'where', 'like', 'in', 'order by', 'limit', 'offset', 'paginasi', 'filter'],
      code: `SELECT \n  id,\n  title,\n  category,\n  is_pinned,\n  created_at\nFROM notes\nWHERE is_deleted = 0 \n  AND category IN ('proyek', 'referensi')\n  AND title LIKE '%valtera%'\nORDER BY is_pinned DESC, updated_at DESC\nLIMIT 25 OFFSET 0;`
    },
    {
      id: 'sql-create-table',
      title: 'CREATE TABLE & INDEX (SQLite Standard)',
      category: 'sql',
      lang: 'sql',
      badge: 'DDL Schema',
      desc: 'Definisi tabel SQLite lengkap dengan Primary Key, nilai default, constraint, dan indeks pencarian.',
      keywords: ['create table', 'index', 'primary key', 'skema', 'tabel', 'constraint', 'ddl'],
      code: `CREATE TABLE IF NOT EXISTS notes (\n  id TEXT PRIMARY KEY,\n  title TEXT NOT NULL DEFAULT 'Catatan Baru',\n  content TEXT DEFAULT '',\n  category TEXT DEFAULT 'Umum',\n  is_pinned INTEGER NOT NULL DEFAULT 0,\n  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,\n  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP\n);\n\n-- Indeks komposit untuk mempercepat filter dan urutan waktu\nCREATE INDEX IF NOT EXISTS idx_notes_category_updated \nON notes(category, updated_at DESC);`
    },
    {
      id: 'sql-upsert',
      title: 'UPSERT (Insert or Update on Conflict)',
      category: 'sql',
      lang: 'sql',
      badge: 'UPSERT',
      desc: 'Memasukkan baris baru atau otomatis memperbarui baris jika Primary Key sudah ada.',
      keywords: ['insert', 'upsert', 'conflict', 'update', 'on conflict', 'duplikat', 'replace'],
      code: `INSERT INTO app_settings (key, value, updated_at)\nVALUES ('theme_preset', 'nord', CURRENT_TIMESTAMP)\nON CONFLICT(key) DO UPDATE SET\n  value = excluded.value,\n  updated_at = CURRENT_TIMESTAMP;`
    },
    {
      id: 'sql-group-by',
      title: 'GROUP BY, Aggregasi & Filter HAVING',
      category: 'sql',
      lang: 'sql',
      badge: 'Aggregation',
      desc: 'Menghitung statistik data (COUNT, SUM, AVG, MAX) dan menyaring hasil agregat dengan HAVING.',
      keywords: ['group by', 'having', 'count', 'sum', 'avg', 'max', 'min', 'agregasi', 'rekap'],
      code: `SELECT \n  category,\n  COUNT(*) AS total_catatan,\n  SUM(CASE WHEN is_pinned = 1 THEN 1 ELSE 0 END) AS total_disematkan,\n  MAX(updated_at) AS terakhir_diubah\nFROM notes\nWHERE is_deleted = 0\nGROUP BY category\nHAVING COUNT(*) > 0\nORDER BY total_catatan DESC;`
    },
    {
      id: 'sql-joins',
      title: 'Relasi Antar Tabel (INNER JOIN & LEFT JOIN)',
      category: 'sql',
      lang: 'sql',
      badge: 'JOIN Relations',
      desc: 'Menggabungkan beberapa tabel berelasi dan menangani nilai null dengan fungsi COALESCE.',
      keywords: ['join', 'inner join', 'left join', 'foreign key', 'relasi', 'coalesce'],
      code: `SELECT \n  n.id AS note_id,\n  n.title,\n  u.username AS author,\n  COALESCE(c.name, 'Tanpa Kategori') AS category_name\nFROM notes n\nINNER JOIN users u ON u.id = n.user_id\nLEFT JOIN categories c ON c.id = n.category_id\nORDER BY n.updated_at DESC;`
    },
    {
      id: 'sql-pragma',
      title: 'Inspeksi Struktur & Metadata (PRAGMA SQLite)',
      category: 'sql',
      lang: 'sql',
      badge: 'PRAGMA Inspection',
      desc: 'Perintah inspeksi bawaan SQLite untuk melihat kolom tabel, daftar indeks, dan optimasi VACUUM.',
      keywords: ['pragma', 'metadata', 'table_info', 'index_list', 'vacuum', 'sqlite', 'cek'],
      code: `-- Melihat rincian kolom dan tipe data tabel\nPRAGMA table_info(notes);\n\n-- Melihat daftar semua indeks pada tabel\nPRAGMA index_list(notes);\n\n-- Memeriksa integritas fisik file database\nPRAGMA integrity_check;\n\n-- Defragmentasi dan kompresi ruang kosong database\nVACUUM;`
    },
    {
      id: 'sql-transaction',
      title: 'Transaksi Atomik (BEGIN, COMMIT, ROLLBACK)',
      category: 'sql',
      lang: 'sql',
      badge: 'ACID Transaction',
      desc: 'Menjalankan serangkaian query sekaligus; seluruh operasi dibatalkan otomatis jika timbul galat.',
      keywords: ['transaction', 'transaksi', 'commit', 'rollback', 'begin', 'acid', 'atomik'],
      code: `BEGIN TRANSACTION;\n\n-- Operasi 1: Simpan salinan cadangan ke tabel riwayat\nINSERT INTO note_history (note_id, old_content) \nSELECT id, content FROM notes WHERE id = 'doc-101';\n\n-- Operasi 2: Simpan perubahan baru\nUPDATE notes \nSET content = 'Konten terupdate...', updated_at = CURRENT_TIMESTAMP \nWHERE id = 'doc-101';\n\n-- Eksekusi permanen perubahan:\nCOMMIT;\n\n-- Catatan: Jika terjadi kegagalan, jalankan: ROLLBACK;`
    },
    {
      id: 'sql-cte',
      title: 'CTE (Common Table Expression / WITH)',
      category: 'sql',
      lang: 'sql',
      badge: 'CTE Subquery',
      desc: 'Membuat tabel virtual sementara yang bersih dan mudah dibaca untuk menyederhanakan query bertingkat.',
      keywords: ['with', 'cte', 'subquery', 'tabel virtual', 'kompleks', 'rekapitulasi'],
      code: `WITH catatan_terbaru AS (\n  SELECT id, title, category, updated_at\n  FROM notes\n  WHERE updated_at >= date('now', '-7 days')\n),\nrekap_kategori AS (\n  SELECT category, COUNT(*) AS jumlah \n  FROM catatan_terbaru \n  GROUP BY category\n)\nSELECT \n  r.category,\n  r.jumlah,\n  ROUND(r.jumlah * 100.0 / (SELECT COUNT(*) FROM catatan_terbaru), 1) AS persentase\nFROM rekap_kategori r\nORDER BY r.jumlah DESC;`
    },

    // ----------------------------------------------------
    // JSON & DATA STRUCTURES CHEATSHEET
    // ----------------------------------------------------
    {
      id: 'json-api-envelope',
      title: 'Standar Amplop Respons API RESTful',
      category: 'json',
      lang: 'json',
      badge: 'REST Response',
      desc: 'Struktur standar respons HTTP JSON lengkap dengan status, payload data, dan metadata paginasi.',
      keywords: ['api', 'response', 'rest', 'envelope', 'json', 'paginasi', 'status'],
      code: `{\n  "success": true,\n  "code": 200,\n  "message": "Data berhasil dimuat",\n  "data": [\n    {\n      "id": "doc_001",\n      "title": "Perencanaan Arsitektur",\n      "tags": ["tech", "sqlite"],\n      "is_pinned": true\n    }\n  ],\n  "pagination": {\n    "current_page": 1,\n    "per_page": 20,\n    "total_pages": 3,\n    "total_records": 52\n  },\n  "timestamp": "2026-09-11T15:30:00.000Z"\n}`
    },
    {
      id: 'json-rules',
      title: 'Aturan Sintaks JSON (Hal yang Sering Terlupa)',
      category: 'json',
      lang: 'json',
      badge: 'JSON Rules',
      desc: 'Ringkasan aturan wajib JSON murni: tanda kutip dua, tanpa trailing comma, dan tipe data sah.',
      keywords: ['rules', 'aturan', 'syntax', 'trailing comma', 'kutip dua', 'komentar', 'validasi'],
      code: `{\n  "aturan_1_tanda_kutip": "Wajib kutip dua (\\"), TIDAK boleh kutip satu (')",\n  "aturan_2_koma_terakhir": "Tidak boleh ada koma (trailing comma) sebelum kurung tutup }",\n  "aturan_3_komentar": "Komentar // atau /* */ TIDAK didukung pada standar JSON murni",\n  "tipe_data_yang_sah": {\n    "string": "Teks dalam tanda petik dua",\n    "angka": 42.5,\n    "boolean": true,\n    "nilai_kosong": null,\n    "array": ["satu", "dua", 3],\n    "objek": { "anak": "bercabang" }\n  }\n}`
    },
    {
      id: 'json-package',
      title: 'Template Konfigurasi package.json Modern',
      category: 'json',
      lang: 'json',
      badge: 'Node Manifest',
      desc: 'Kerangka dasar berkas manifest package.json untuk proyek JavaScript atau TypeScript modern.',
      keywords: ['package.json', 'npm', 'node', 'scripts', 'dependencies', 'manifest'],
      code: `{\n  "name": "valtera-note",\n  "version": "0.1.7",\n  "private": true,\n  "type": "module",\n  "scripts": {\n    "dev": "vite",\n    "build": "vite build",\n    "check": "svelte-check --tsconfig ./tsconfig.json"\n  },\n  "dependencies": {\n    "@tauri-apps/api": "^2.0.0",\n    "lucide-svelte": "^0.460.0"\n  },\n  "devDependencies": {\n    "@sveltejs/vite-plugin-svelte": "^5.0.0",\n    "typescript": "^5.6.0",\n    "vite": "^6.0.0"\n  }\n}`
    },
    {
      id: 'json-geojson',
      title: 'Format Data Spasial GeoJSON (Point Feature)',
      category: 'json',
      lang: 'json',
      badge: 'GeoJSON Spec',
      desc: 'Format standar internasional representasi koordinat geografis (Longitude, Latitude).',
      keywords: ['geojson', 'peta', 'koordinat', 'gis', 'lat', 'lng', 'point'],
      code: `{\n  "type": "FeatureCollection",\n  "features": [\n    {\n      "type": "Feature",\n      "geometry": {\n        "type": "Point",\n        "coordinates": [106.8456, -6.2088]\n      },\n      "properties": {\n        "nama_lokasi": "Monumen Nasional",\n        "kota": "Jakarta Pusat",\n        "kategori": "Landmark"\n      }\n    }\n  ]\n}`
    },

    // ----------------------------------------------------
    // REGEX / REGULAR EXPRESSIONS CHEATSHEET
    // ----------------------------------------------------
    {
      id: 'regex-common',
      title: 'Pola Validasi Umum (Email, URL, UUID, Slug)',
      category: 'regex',
      lang: 'text',
      badge: 'Pola Validasi',
      desc: 'Koleksi regex siap pakai untuk validasi alamat email, URL website, UUID v4, dan slug SEO.',
      keywords: ['regex', 'email', 'url', 'uuid', 'slug', 'validasi', 'pola', 'pattern'],
      code: `-- Validasi Email Standar:\n^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$\n\n-- Validasi URL Web (HTTP/HTTPS):\n^https?:\\/\\/(?:www\\.)?[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-zA-Z0-9()]{1,6}\\b(?:[-a-zA-Z0-9()@:%_\\+.~#?&\\/=]*)$\n\n-- Validasi UUID v4:\n^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$\n\n-- Validasi URL Slug (huruf kecil & strip):\n^[a-z0-9]+(?:-[a-z0-9]+)*$`
    },
    {
      id: 'regex-symbols',
      title: 'Kamus Karakter & Simbol Dasar Regex',
      category: 'regex',
      lang: 'text',
      badge: 'Simbol Regex',
      desc: 'Penjelasan arti simbol karakter penentu pola regular expression yang sering membingungkan.',
      keywords: ['regex', 'simbol', 'karakter', 'boundary', 'digit', 'word', 'whitespace'],
      code: `^       = Awal string atau baris\n$       = Akhir string atau baris\n.       = Karakter apa saja (kecuali baris baru newline)\n\\d / \\D = Digit angka [0-9] / Bukan angka\n\\w / \\W = Karakter kata [a-zA-Z0-9_] / Bukan kata\n\\s / \\S = Spasi atau whitespace / Bukan whitespace\n\\b      = Batas kata (word boundary)\n[abc]   = Karakter tunggal 'a', 'b', atau 'c'\n[^abc]  = Karakter APA SAJA KECUALI 'a', 'b', atau 'c'\na|b     = Cocokkan 'a' ATAU 'b'`
    },
    {
      id: 'regex-quantifiers',
      title: 'Kuantifier Pengulangan Karakter Regex',
      category: 'regex',
      lang: 'text',
      badge: 'Kuantifier',
      desc: 'Aturan penentu berapa kali sebuah karakter atau kelompok pola boleh berulang.',
      keywords: ['quantifier', 'pengulangan', 'greedy', 'lazy', 'regex', 'jumlah'],
      code: `*       = 0 atau lebih kali (rakus / greedy)\n*?      = 0 atau lebih kali (non-greedy / lazy / minimum)\n+       = 1 atau lebih kali\n?       = 0 atau 1 kali (opsional)\n{n}     = Tepat n kali (contoh: \\d{4} untuk 4 digit tahun)\n{n,}    = Minimal n kali\n{n,m}   = Minimal n kali dan maksimal m kali (contoh: \\w{3,16} untuk username)\n(?:abc) = Group non-capturing (hanya grup tanpa disimpan ke memori)`
    },

    // ----------------------------------------------------
    // GIT & TERMINAL CLI CHEATSHEET
    // ----------------------------------------------------
    {
      id: 'git-daily',
      title: 'Alur Kerja Harian Git (Daily Workflow)',
      category: 'git',
      lang: 'bash',
      badge: 'Daily Git',
      desc: 'Rangkaian perintah dasar Git untuk memeriksa berkas, commit perubahan, dan sinkronisasi branch.',
      keywords: ['git', 'commit', 'push', 'pull', 'status', 'add', 'terminal', 'branch'],
      code: `# 1. Periksa ringkasan berkas yang diubah\ngit status -s\n\n# 2. Tambahkan seluruh berkas ke staging\ngit add .\n\n# 3. Buat commit dengan pesan konvensional\ngit commit -m "feat: tambahkan kamus sintaks markdown dan sql"\n\n# 4. Ambil perubahan terbaru dan dorong ke remote\ngit pull --rebase origin main\ngit push origin main`
    },
    {
      id: 'git-lifesavers',
      title: 'Penyelamat Masalah Git (Undo, Stash & Reset)',
      category: 'git',
      lang: 'bash',
      badge: 'Git Undo',
      desc: 'Perintah penting untuk membatalkan perubahan atau menyimpan pekerjaan sementara tanpa commit.',
      keywords: ['stash', 'reset', 'checkout', 'undo', 'kembalikan', 'git', 'log'],
      code: `# Simpan pekerjaan belum selesai ke rak sementara (stash)\ngit stash push -m "sementara pindah branch"\ngit stash pop\n\n# Batalkan perubahan pada 1 berkas kembali seperti semula\ngit checkout -- nama_berkas.ts\n\n# Batalkan commit terakhir tetapi pertahankan semua berkas di lokal\ngit reset --soft HEAD~1\n\n# Tampilkan grafik riwayat commit 1 baris yang rapi\ngit log --oneline --graph -n 10`
    }
  ];

  const CATEGORIES = [
    { id: 'all', label: 'Semua', icon: BookOpen },
    { id: 'markdown', label: 'Markdown', icon: FileText },
    { id: 'sql', label: 'SQL', icon: Database },
    { id: 'json', label: 'JSON', icon: FileCode },
    { id: 'regex', label: 'Regex', icon: Code },
    { id: 'git', label: 'Git & CLI', icon: Terminal }
  ] as const;

  // Filter items based on active category and search query
  let filteredItems = $derived(
    KNOWLEDGE_ITEMS.filter(item => {
      const matchesCategory = activeCategory === 'all' || item.category === activeCategory;
      if (!matchesCategory) return false;

      if (!searchQuery.trim()) return true;
      const query = searchQuery.toLowerCase().trim();

      return (
        item.title.toLowerCase().includes(query) ||
        item.desc.toLowerCase().includes(query) ||
        item.badge.toLowerCase().includes(query) ||
        item.keywords.some(k => k.toLowerCase().includes(query)) ||
        item.code.toLowerCase().includes(query)
      );
    })
  );

  function getCategoryCount(catId: string) {
    if (catId === 'all') return KNOWLEDGE_ITEMS.length;
    return KNOWLEDGE_ITEMS.filter(i => i.category === catId).length;
  }

  function handleInsert(code: string, lang: 'md' | 'sql' | 'json' | 'text' | 'bash') {
    const tab = editorStore.activeTab;
    if (tab) {
      const current = tab.content;
      tab.content = current ? `${current}\n\n${code}` : code;
      editorStore.updateContent(tab.content);
    } else {
      const targetMode = (lang === 'sql' || lang === 'json' || lang === 'md') ? lang : 'md';
      editorStore.addTab(undefined, targetMode, code);
    }
    onClose();
  }

  async function handleCopy(id: string, code: string) {
    try {
      await navigator.clipboard.writeText(code);
      copiedId = id;
      setTimeout(() => {
        if (copiedId === id) copiedId = null;
      }, 1800);
    } catch (e) {
      console.warn('Copy failed:', e);
    }
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      e.preventDefault();
      onClose();
    }
  }
</script>

<svelte:window onkeydown={handleKeyDown} />

{#if isOpen}
  <!-- Backdrop -->
  <div 
    class="fixed inset-0 z-50 flex items-center justify-end bg-black/60 backdrop-blur-xs select-none animate-in fade-in duration-150"
    onclick={onClose}
    role="dialog"
    aria-modal="true"
    tabindex="-1"
  >
    <!-- Drawer Container -->
    <div 
      class="bg-slate-900 border-l border-slate-800 shadow-2xl h-full w-full max-w-xl md:max-w-2xl flex flex-col text-slate-200 overflow-hidden"
      onclick={(e) => e.stopPropagation()}
      role="document"
    >
      
      <!-- Drawer Header -->
      <div class="h-14 bg-slate-950 border-b border-slate-800 flex items-center justify-between px-5 flex-shrink-0">
        <div class="flex items-center space-x-2.5 min-w-0">
          <div class="w-8 h-8 rounded-lg bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400 flex-shrink-0">
            <BookOpen class="w-4 h-4" />
          </div>
          <div class="min-w-0">
            <div class="flex items-center space-x-2">
              <h2 class="text-sm font-bold text-slate-100 truncate">Kamus Sintaks & Perintah</h2>
              <span class="px-1.5 py-0.2 rounded text-[10px] font-semibold bg-blue-500/10 text-blue-300 border border-blue-500/20">Cheatsheet</span>
            </div>
            <p class="text-[11px] text-slate-400 truncate">Referensi cepat Markdown, SQL, JSON, Regex, dan Git jika lupa cara pakai.</p>
          </div>
        </div>

        <button 
          onclick={onClose}
          class="p-1.5 rounded-lg hover:bg-slate-800 text-slate-400 hover:text-slate-100 transition-colors cursor-pointer flex-shrink-0 ml-2"
          title="Tutup (Esc)"
          aria-label="Tutup Kamus"
        >
          <X class="w-4 h-4" />
        </button>
      </div>

      <!-- Search Box & Category Filters -->
      <div class="p-3.5 bg-slate-950/60 border-b border-slate-800 space-y-2.5 flex-shrink-0">
        <!-- Search Input -->
        <div class="relative">
          <Search class="w-4 h-4 absolute left-3 top-2.5 text-slate-500" />
          <input 
            type="text" 
            bind:value={searchQuery} 
            placeholder="Cari perintah (contoh: alert, tabel, select, pragma, regex, stash)..."
            class="w-full bg-slate-950 border border-slate-800 rounded-xl pl-9 pr-8 py-2 text-xs text-slate-200 placeholder-slate-500 focus:outline-none focus:border-amber-500/60 focus:ring-1 focus:ring-amber-500/30 transition-all"
          />
          {#if searchQuery}
            <button 
              onclick={() => (searchQuery = '')}
              class="absolute right-2.5 top-2.5 p-0.5 rounded text-slate-500 hover:text-slate-300 transition-colors cursor-pointer"
              title="Hapus pencarian"
            >
              <X class="w-3.5 h-3.5" />
            </button>
          {/if}
        </div>

        <!-- Categories Pill Bar -->
        <div class="flex items-center space-x-1.5 overflow-x-auto scrollbar-none py-0.5">
          {#each CATEGORIES as cat}
            {@const IconComponent = cat.icon}
            {@const isActive = activeCategory === cat.id}
            {@const count = getCategoryCount(cat.id)}
            <button 
              onclick={() => (activeCategory = cat.id)}
              class="px-2.5 py-1 rounded-lg text-xs font-medium flex items-center space-x-1.5 transition-all cursor-pointer whitespace-nowrap {isActive ? 'bg-amber-500/20 text-amber-300 border border-amber-500/40 shadow-xs' : 'bg-slate-900 border border-slate-800/80 text-slate-400 hover:text-slate-200 hover:border-slate-700'}"
            >
              <IconComponent class="w-3.5 h-3.5" />
              <span>{cat.label}</span>
              <span class="text-[10px] opacity-60 font-mono">({count})</span>
            </button>
          {/each}
        </div>
      </div>

      <!-- Knowledge Cards List -->
      <div class="flex-1 overflow-y-auto p-3.5 space-y-3.5 select-text">
        {#each filteredItems as item (item.id)}
          <div class="bg-slate-950/80 border border-slate-800/90 hover:border-slate-700/90 rounded-xl p-3.5 transition-all space-y-2.5 group shadow-xs">
            
            <!-- Card Header -->
            <div class="flex items-start justify-between gap-3">
              <div class="space-y-1 min-w-0">
                <div class="flex items-center space-x-2 flex-wrap gap-y-1">
                  <span class="px-2 py-0.5 rounded text-[10px] font-semibold uppercase tracking-wider
                    {item.category === 'markdown' ? 'bg-amber-500/10 text-amber-300 border border-amber-500/20' : ''}
                    {item.category === 'sql' ? 'bg-blue-500/10 text-blue-300 border border-blue-500/20' : ''}
                    {item.category === 'json' ? 'bg-emerald-500/10 text-emerald-300 border border-emerald-500/20' : ''}
                    {item.category === 'regex' ? 'bg-purple-500/10 text-purple-300 border border-purple-500/20' : ''}
                    {item.category === 'git' ? 'bg-cyan-500/10 text-cyan-300 border border-cyan-500/20' : ''}
                  ">
                    {item.badge}
                  </span>
                  <h3 class="text-xs font-bold text-slate-100">{item.title}</h3>
                </div>
                <p class="text-[11.5px] text-slate-400 leading-relaxed">{item.desc}</p>
              </div>
              
              <!-- Card Action Buttons -->
              <div class="flex items-center space-x-1.5 flex-shrink-0 select-none">
                <button 
                  onclick={() => handleCopy(item.id, item.code)}
                  class="px-2.5 py-1 rounded-lg border text-[11px] font-medium flex items-center space-x-1.5 transition-all cursor-pointer {copiedId === item.id ? 'bg-emerald-600/20 text-emerald-300 border-emerald-500/40' : 'bg-slate-900 border-slate-800 text-slate-300 hover:text-white hover:bg-slate-800'}"
                  title="Salin ke Clipboard"
                >
                  {#if copiedId === item.id}
                    <Check class="w-3.5 h-3.5 text-emerald-400" />
                    <span>Tersalin!</span>
                  {:else}
                    <Copy class="w-3.5 h-3.5 text-slate-400" />
                    <span>Salin</span>
                  {/if}
                </button>

                <button 
                  onclick={() => handleInsert(item.code, item.lang)}
                  class="px-2.5 py-1 rounded-lg bg-blue-600/20 hover:bg-blue-600 text-blue-300 hover:text-white border border-blue-500/30 text-[11px] font-semibold flex items-center space-x-1.5 transition-all cursor-pointer shadow-xs"
                  title="Sisipkan langsung ke dalam editor catatan"
                >
                  <PlusCircle class="w-3.5 h-3.5" />
                  <span>Sisipkan</span>
                </button>
              </div>
            </div>

            <!-- Code / Syntax Preview Box -->
            <div class="relative bg-slate-900/90 border border-slate-800 rounded-lg overflow-hidden">
              <pre class="p-3 font-mono text-[11px] text-slate-300 leading-relaxed overflow-x-auto max-h-48 scrollbar-thin select-text whitespace-pre"><code>{item.code}</code></pre>
            </div>

          </div>
        {:else}
          <div class="h-48 flex flex-col items-center justify-center text-center p-6 space-y-2 border border-dashed border-slate-800 rounded-2xl bg-slate-950/40">
            <BookOpen class="w-8 h-8 text-slate-600" />
            <p class="text-xs font-medium text-slate-300">Tidak ada sintaks atau perintah yang cocok</p>
            <p class="text-[11px] text-slate-500">Coba kata kunci lain atau pilih tab kategori di atas.</p>
          </div>
        {/each}
      </div>

      <!-- Drawer Footer Info -->
      <div class="h-10 bg-slate-950 border-t border-slate-800 flex items-center justify-between px-4 text-[11px] text-slate-400 flex-shrink-0">
        <div class="flex items-center space-x-1.5">
          <Sparkles class="w-3.5 h-3.5 text-amber-400" />
          <span>Tekan <kbd class="px-1 py-0.5 rounded bg-slate-900 border border-slate-800 text-[10px] font-mono text-slate-300">Ctrl+Shift+T</kbd> untuk buka/tutup cepat.</span>
        </div>
        <span class="text-slate-500 font-mono text-[10.5px]">{filteredItems.length} referensi tersedia</span>
      </div>

    </div>
  </div>
{/if}
