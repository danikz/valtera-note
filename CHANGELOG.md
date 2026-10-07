# 📜 Changelog

All notable changes to the **Valtera Note** desktop application will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.32] - 2026-10-07

### ✨ Fitur Baru: Drag & Drop Antar Workspace SSH
- **Pindahkan koneksi ke workspace cukup dengan drag & drop**: tarik koneksi dari daftar, lepas di header workspace tujuan (menyala hijau saat terlewati). Lepas di "Tanpa Workspace" untuk mengeluarkannya dari grup.
- Perpindahan ikut tersinkron ke cloud (workspace menumpang di payload E2E); klik-2x connect, edit, dan hapus tetap bekerja normal.

### ✨ Fitur Baru: View "Form Submit" di Tools JSON
- **Daftar semua field submit dari JSON**: path bertingkat notasi form (`user.email`, `items[0].qty`), tipe data, dan nilai contoh — dengan pencarian.
- **Generator HTML `<form>` otomatis**: string → text input, angka → number, boolean → checkbox, string panjang → textarea, semua dengan `name` sesuai path. Bisa disalin atau dibuka di tab catatan.
- Aksi cepat: Salin Field (daftar path+tipe+nilai), Salin HTML Form, Ke Tab Catatan. Array dienumerasi sampai 3 elemen dengan penanda "N elemen lain" (cap 500 field).

---

## [0.1.31] - 2026-10-07

### ✨ Fitur Baru: Tombol Buat Workspace di SSH Manager
- **Tombol gedung (🏢) di header daftar koneksi**: buat workspace langsung dari situ via input inline (Enter untuk buat, Esc untuk batal) — tidak lagi hanya lewat field di form koneksi.
- **Workspace kosong tetap tampil sebagai grup** dengan hitungan 0, siap diisi koneksi; nama baru langsung masuk daftar autocomplete di form.
- **Grup kosong bisa dihapus** lewat tombol X kecil di headernya; daftar workspace buatan tersimpan per perangkat.

---

## [0.1.30] - 2026-10-07

### ✨ Fitur Baru: Workspace & Sinkronisasi Kredensial SSH
- **Workspace per perusahaan/lokasi**: field baru di form koneksi dengan autocomplete nama yang sudah ada; daftar kiri terkelompok per workspace dengan header yang bisa di-collapse. Nama workspace tersimpan di dalam ciphertext E2E dan ikut tersinkron.
- **Kredensial SSH kini tersinkron ke Supabase**: pull/push otomatis saat membuka halaman SSH, setelah simpan, dan setelah hapus; konflik diselesaikan dengan timestamp terbaru menang. Yang pernah dikirim ke cloud hanya ciphertext E2E.
- **Hapus bersifat tombstone**: menghapus di satu perangkat ikut menghapus salinannya di perangkat lain saat pull.
- **Skema lengkap di semua jalur**: tabel `ssh_connections` ikut dibuat oleh tombol auto-create, SQL manual di Pengaturan, dan jalur fallback; status pengecekan tabel kini memverifikasi kedua tabel.
- **Badge status cloud** di header SSH Manager: waktu sinkron terakhir, status gagal, dan sync manual satu klik.

### ✨ Peningkatan: Sidebar Lebih Rapi
- **Judul catatan ~2x lebih lebar**: toolbar aksi (pindah folder/rename/hapus/tutup tab) menjadi overlay yang muncul saat hover dan tidak lagi mencadangkan 104px per baris; sidebar dilebarkan 256→288px.

---

## [0.1.29] - 2026-10-07

### ✨ Peningkatan UX: Daftar Koneksi SSH Lebih Aman & Bisa Diedit
- **Klik 2x untuk connect**: klik sekali di daftar koneksi hanya memilih (highlight), klik dua kali baru connect — tidak ada lagi koneksi tak sengaja. Pindah antar tab tetap satu klik.
- **Kredensial diuji sebelum disimpan**: tombol "Uji & Simpan Koneksi" melakukan connect sungguhan dulu — kalau gagal, error tampil di form dan tidak ada yang disimpan; kalau sukses, kredensial tersimpan dan tab-nya langsung terbuka sebagai bukti.
- **Edit koneksi sebenarnya**: ikon pensil menggantikan ikon mata yang membingungkan, dan form edit kini mengisi ulang host, port, username, serta metode autentikasi dari kredensial tersimpan — tidak perlu lagi hapus dan buat ulang. Password/key dikosongkan berarti mempertahankan yang lama.

---

## [0.1.28] - 2026-10-07

### 🐛 Perbaikan: Terminal Blank Saat Kembali ke Sesi SSH
- **Replay buffer 128 KB per sesi di Rust**: output sesi direkam terus-menerus (termasuk saat halaman SSH tidak dibuka), sehingga tab yang di-attach ulang tidak lagi tampil blank hitam.
- **Buka ulang halaman SSH kini melanjutkan layar**: prompt, output command terakhir, dan frame aplikasi full-screen dipulihkan dari buffer saat kembali dari halaman lain atau pindah tab.
- **Urutan output terjaga**: data live ditahan sebentar selama replay dituliskan, dan race prompt awal yang kadang hilang saat connect pertama ikut tertambal.

---

## [0.1.27] - 2026-10-07

### ✨ Fitur Baru: Tab SSH ala Browser
- **Setiap koneksi SSH terbuka sebagai tab**: pindah antar sesi semudah pindah tab browser — instance terminal per tab tetap hidup, scrollback tidak pernah hilang saat berpindah.
- **Output tab background tetap terekam** dan ditandai titik kuning (unread) ala browser, jadi tidak ada lagi output yang hilang saat sesi tidak sedang dilihat.
- **Tombol X di tab = putuskan sesi**; sesi yang ditutup dari sisi server tampil dengan titik abu-abu dan status `[Sesi ditutup]`.
- **"Lepas tampilan" & chip "Sesi Aktif" dihapus** — digantikan sepenuhnya oleh tab; kembali ke halaman SSH mengembalikan sesi yang masih hidup sebagai tab.
- **Form koneksi kini overlay** di atas terminal — membuka/menutup formulir tidak membuang tab yang sedang terbuka.

---

## [0.1.26] - 2026-10-07

### 🐛 Perbaikan: Koneksi SSH Gagal Terhubung
- **Fix error "missing field auth_type"**: koneksi SSH gagal karena mismatch penamaan field antara frontend (`authType`, `privateKey`, `passphrase`) dan command Rust `ssh_connect` yang menuntut snake_case. Struct params kini menerima camelCase via serde `rename_all`.
- **Auth private key kembali berfungsi penuh**: dampak dari mismatch yang sama, `privateKey` dan `passphrase` sebelumnya diam-diam terkirim sebagai kosong saat koneksi metode key.
- **Build lokal lebih stabil**: versi `@tauri-apps/api` di-pin 2.12.1 agar sejajar dengan crate `tauri`, sehingga Tauri CLI tidak lagi menolak build karena version mismatch.

---

## [0.1.25] - 2026-10-06

### ✨ Fitur Baru: Menu SSH di Titlebar
- **Menu "SSH" kini ada di titlebar** (di antara Edit dan Tools): akses cepat ke SSH Manager dan seluruh koneksi tersimpan tanpa membuka Pengaturan.
- **Daftar koneksi dengan status live**: titik hijau + label `● live` untuk sesi yang sedang hidup, lingkaran kosong untuk yang belum terhubung. Daftar di-refresh setiap kali menu dibuka.
- **Klik = langsung connect**: memilih koneksi di menu membuka halaman SSH Manager dan auto-connect via permintaan yang dikonsumsi setelah daftar termuat (store `pendingConnectId`).

---

## [0.1.24] - 2026-10-06

### ✨ Fitur Baru: SSH Manager — Terminal & Kredensial Tersimpan
- **SSH Manager di Developer Tools**: koneksi ke VPS/server langsung dari app — daftar koneksi tersimpan (klik = connect), formulir kredensial, dan terminal interaktif penuh (xterm.js + PTY `xterm-256color`) dengan resize tersinkron ke server.
- **Kredensial terenkripsi E2E**: host/user/password/private key dienkripsi dengan kunci master password sebelum disimpan di SQLite lokal; didekripsi hanya saat connect. Butuh master password terpasang & app dalam kondisi unlocked.
- **Auth password & private key** (+passphrase) via `russh` (pure Rust — tanpa dependensi binary eksternal, portable semua platform).
- **Paste & clipboard terminal lengkap**: normalisasi CRLF Windows, Ctrl+C cerdas (salin saat ada seleksi, SIGINT saat tidak), klik kanan → menu konteks (Salin/Tempel/Pilih Semua/Bersihkan), Ctrl+Shift+V, dan pengiriman terchunk untuk paste besar. Bracketed paste lewat end-to-end sehingga multi-baris aman di shell modern.
- **Sesi tetap hidup di Rust**: menutup tampilan / minimize tidak memutus koneksi; chips "Sesi Aktif" untuk re-attach.
- Masuk lewat **Tools → tab SSH Manager** atau Command Palette.

### 🎨 Perbaikan: Sidebar Explorer Sejajar
- Row file explorer (Tree & Flat) kini tinggi tetap (36px) dengan zona aksi kanan lebar tetap (104px): slot status tercadang (dirty dot + cloud/sync) + tombol seragam 16×16 — kolom icon, nama, status, dan aksi sejajar sempurna antar row; nama panjang ellipsis, path dipindah ke tooltip.

---

## [0.1.23] - 2026-10-06

### ✨ AI Chat Kini Bisa MENULIS ke Catatan
- **Protokol `valtera-write`**: saat diminta menulis/mengubah/menambah isi catatan, AI menghasilkan versi lengkap catatan di dalam blok `valtera-write`, dan sidebar menampilkan kartu **"Ganti Seluruh Catatan"** (dengan konfirmasi) + **"Salin Saja"** — setelah diterapkan muncul konfirmasi "Catatan berhasil diperbarui".
- Bekerja di **semua provider** tanpa perlu dukungan tool-calling (protokol berbasis instruksi sistem), termasuk model kecil di Groq/Ollama.
- Pesan assistant kini punya aksi cepat saat hover: **Salin** dan **Sisipkan di kursor/akhir catatan**.
- Saran chip baru: "✍️ Suruh AI menulis ke catatan ini".

---

## [0.1.22] - 2026-10-06

### 🎨 Perbaikan: Window Controls Seperti Native Windows 11
- **Hover kini memenuhi seluruh area tombol** (44×36px, setinggi titlebar) — sebelumnya hanya kotak kecil di sekitar icon. Akar masalah: wrapper "Quick Action Groups" di titlebar tidak punya tinggi sehingga rantai `h-full` tombol patah dan tombol ikut ukuran isi (~26px) mengambang di tengah.
- Wrapper kini `h-full self-stretch` dan keempat tombol (AI, Minimize, Maximize/Restore, Close) memakai `self-stretch w-11` dengan tinggi seragam, icon tetap presisi di tengah (flex center).
- Close button tetap hover merah khas Windows, tombol lain hover abu; area klik = area visual. Tidak ada perubahan layout titlebar, icon, atau konfigurasi `decorations: false`.

---

## [0.1.21] - 2026-10-06

### ✨ Fitur Baru: AI Chat Sidebar — Ngobrol Langsung dengan AI
- **Panel chat di sisi kanan editor** (dock 360px): bisa di-show/hide lewat tombol ✨ di titlebar atau **Ctrl+Shift+A**. Riwayat obrolan dipertahankan selama panel dibuka-tutup; tombol hapus untuk mulai ulang.
- **AI membaca file yang dipilih**: toggle "Baca catatan aktif" mengirim isi catatan yang sedang terbuka sebagai konteks (judul + konten), dan toggle "Teks terpilih" menyertakan blok teks yang kamu blok di editor — AI tahu persis bagian mana yang dibicarakan.
- **Chat multi-turn sejati**: riwayat giliran dikirim sebagai messages array ke provider (bukan dijebol jadi satu prompt) — didukung OpenAI-compatible dan Anthropic.
- Saran prompt cepat saat obrolan kosong (ringkas catatan, tinjau masalah, buat task list), Enter untuk kirim / Shift+Enter baris baru, dan indikator "Mengetik…".

---

## [0.1.20] - 2026-10-06

### ✨ AI Assistant: Daftar Model Otomatis dari Provider
- **Test Koneksi kini sekaligus memuat daftar model** langsung dari provider (OpenAI-compatible: `GET /models`, Anthropic: `GET /v1/models`) dan menampilkan jumlahnya di status.
- Kolom **Model** kini punya saran dropdown (datalist) berisi model asli provider — tetap bisa ketik manual untuk model yang belum terdaftar.

---

## [0.1.19] - 2026-10-06

### 🐛 Perbaikan: Gagal Menyimpan Konfigurasi AI
- `ai_save_config` menolak argumen `base_url`/`api_key` karena Tauri v2 mencocokkan argumen JS dalam camelCase (`baseUrl`/`apiKey`). Kini kedua ejaan dikirim, mengikuti pola defensif command lain.

---

## [0.1.18] - 2026-10-05

### ✨ Fitur Baru: AI Assistant (BYO API Key, Provider Bebas)
- **Provider bebas**: dukungan native **Anthropic Claude** (Messages API) dan **semua endpoint OpenAI-compatible** — OpenAI, OpenRouter, Groq, hingga Ollama/LM Studio lokal (100% offline). Preset satu klik di Pengaturan → AI Assistant.
- **Aksi AI di editor** (Ctrl+Shift+A atau menu Edit → AI Assistant): Ringkas, Perbaiki Tulisan, terjemahkan → English/Indonesia, Jelaskan, Commit Msg, dan prompt kustom. Bekerja pada teks terpilih (otomatis) atau seluruh catatan; hasil bisa disalin, mengganti seleksi, atau disisipkan di posisi kursor.
- **API key tersimpan hanya di perangkat** (database lokal app); permintaan dikirim langsung dari backend Rust ke provider — tanpa server perantara, bebas masalah CORS.
- **Peringatan privasi eksplisit**: konten yang dikirim ke AI keluar sebagai plaintext — enkripsi E2E melindungi penyimpanan lokal & cloud, bukan permintaan AI.
- **Bonus**: sinkronisasi konten eksternal ke editor kini memakai minimal diff (prefix/suffix) sehingga kursor tidak lagi melompat ke awal dokumen saat teks disisipkan dari luar (mis. hasil AI).

---

## [0.1.17] - 2026-10-05

### 🌕 Perbaikan Menyeluruh Mode Light
- **Nama aplikasi terlihat lagi**: badge "Valtera Note" di titlebar memakai teks biru muda (`text-blue-300`) yang jatuh di latar putih saat mode light — kini semua aksen teks terang (blue/emerald/amber/rose/sky/dll.) otomatis dipetakan ke versi gelapnya saat mode light.
- **Editor kembali bisa dibaca di mode light**: sebelumnya tema light memaksa semua teks editor jadi satu warna gelap via `!important` (warna sintaks hilang) di atas tema gelap inline — hasilnya kacau. Kini tema editor dikontrol compartment yang mengikuti mode: light memakai skema terang + warna sintaks bawaan CodeMirror, dark tetap One Dark, dan peralihan mode langsung berlaku tanpa buka ulang tab.
- **Cakupan override light diperluas**: varian background/border (slate-700, slate-800/90-30, border /30-/70, divide), state hover (bg-slate-700/800/900, border), teks putih yang menempel di permukaan terang (menu terbuka di titlebar), dan placeholder — menutup celah-celah yang membuat mode light tampak "tempang".

---

## [0.1.16] - 2026-10-05

### 🧭 Alur Setup Urut: Kredensial → Tabel → Akun
- Kartu di Pengaturan → Supabase kini bernomor sesuai urutan setup yang benar: **1. Kredensial Project → 2. Status Skema Tabel → 3. Akun Supabase** (sebelumnya kartu Akun berada di atas Kredensial — kebalik).
- SyncModal diurutkan ulang mengikuti alur yang sama: form kredensial di atas, lalu status tabel & panduan SQL di bawahnya.

### 🎨 Polish UI
- **Scrollbar lebih tebal & terlihat**: 6px → 11px dengan thumb lebih kontras dan hover lebih terang — scrollbar vertikal/horizontal di editor dan panel tidak lagi nyaris hitam dan susah dipegang.
- **Hover tombol jendela diperhalus**: minimize/maximize memakai abu terang (bukan nyaris hitam), close tetap merah khas Windows dengan transisi lebih halus.

---

## [0.1.15] - 2026-10-05

### ✨ Fitur: Format Waktu 24 Jam + Zona Waktu Bisa Diatur
- Waktu tersimpan & status sinkronisasi kini **selalu format 24 jam** dengan label zona eksplisit (contoh: `21.30.05 GMT+7`) — sebelumnya mengikuti locale sistem yang bisa tampil 12 jam AM/PM tanpa keterangan zona.
- **Pengaturan → Tampilan & Tema → Zona Waktu Tampilan**: pilih zona (default Jakarta/WIB; tersedia WITA, WIT, UTC, Singapura, Tokyo, dll.). Tersimpan per-device di app settings dan berlaku langsung tanpa restart.

### 🐛 Perbaikan: Tombol Copy "Bohong" di Semua Tools
- **Clipboard kini benar-benar berisi data**: `navigator.clipboard` di WebView2 sering gagal diam-diam (window tidak fokus / gesture tidak dikenali), tapi toast "tersalin!" tetap muncul — JSON tool (copy path/value/CSV/Markdown), SQL script, SQLite, Base64, URL, UUID, MySQL password, Favicon, Emoji picker, dan Snippets semuanya terpengaruh.
- **Plugin clipboard resmi Tauri** (`clipboard-manager`) ditambahkan sebagai jalur utama, dengan fallback `navigator.clipboard` → `execCommand`. Semua tombol copy kini memakai util bersama yang mengembalikan keberhasilan nyata: toast "tersalin" hanya muncul kalau data benar-benar masuk clipboard, selain itu muncul "Gagal menyalin".
- Tombol "Paste" di JSON/Base64/URL tool kini juga membaca lewat plugin clipboard (readText) dengan pesan jelas kalau clipboard kosong.

---

## [0.1.14] - 2026-10-05

### 🐛 Perbaikan: Ganti Project Supabase Membuat Sync Mati (401)
- **Sesi lama kini dibersihkan saat ganti project**: mengganti Project URL tidak menghapus token sesi lama, sehingga sync terus memakai JWT terbitan project lama di project baru — dijamin 401 (issuer beda) dan refresh token juga selalu gagal, sync mati dengan pesan peringatan samar "Sinkronisasi selesai dengan peringatan". `save_supabase_config` kini menghapus access/refresh token + expiry + email user saat URL berubah, termasuk salinannya di localStorage.
- **Logout benar-benar menghapus sesi**: command baru `supabase_logout` menghapus token & identitas dari database; sebelumnya logout hanya membersihkan state frontend dan token di DB tetap dipakai sync berikutnya.

---

## [0.1.13] - 2026-10-05

### 🐛 Perbaikan: Note Tidak Pernah Ter-Push ke Cloud
- **Note yang "hilang" dari cloud kini pulih otomatis**: catatan lama yang membawa `supabase_id` lokal dari era sync rusak (ID pernah di-assign tapi push-nya gagal) dilewati selamanya oleh auto-sync karena dianggap sudah ada di cloud — Supabase terlihat tidak pernah berubah. `autoSyncAll` kini membandingkan ID lokal dengan ID yang benar-benar ada di cloud (hasil pull) lalu men-push yang belum ada; pulih dalam satu siklus sync (≤30 detik) dan kasus serupa tidak terulang.
- `fetch_notes` tidak lagi memfilter `is_deleted=eq.false`: heal logic perlu melihat tombstone remote agar note yang sudah dihapus di cloud tidak dihidupkan kembali. Jalur pull tetap aman karena sudah memiliki guard `remote.is_deleted` sendiri.

### 🔒 Keamanan: SQL Migration Disamakan dengan Auto-Create (RLS Ketat)
- Skrip "Copy SQL Script" di SyncModal masih membuat policy permisif `Allow all for anon and authenticated` — kontradiksi dengan changelog 0.1.12; pengguna yang menjalankannya mendapat tabel terbuka untuk anon. Skrip kini identik dengan auto-create 1-klik: `revoke all from anon` + policy `Owner full access` untuk `authenticated`.
- Policy kini `using/with check (auth.uid() = user_id or user_id is null)`: note yang dibuat sebelum era login (user_id NULL) tetap bisa di-update pemiliknya setelah login; baris baru selalu terisi `auth.uid()` via default kolom.
- Panduan setup mencantumkan langkah 4 (Daftar/Masuk akun), dan SyncModal menampilkan peringatan "Mode Anonim — Data Belum Terkunci ke Akun" saat aplikasi tersambung tanpa sesi login.

---

## [0.1.12] - 2026-10-05

### 🐛 Perbaikan Kritis: Sinkronisasi Cloud Tidak Jalan
- **User yang menolak E2E kini bisa sync lagi**: `encrypt_content` gagal total untuk pengguna yang menekan "Lewati" di layar setup enkripsi (tidak ada kunci di memori), membuat SEMUA push ke Supabase gagal dengan "App terkunci - tidak bisa mengenkripsi". Kini plaintext passthrough sesuai pilihan user; sebelum memilih (setup awal) tetap fail-closed.
- **Auto-refresh token Supabase**: `supabase_login`/`supabase_register` kini menyimpan `refresh_token` + waktu kedaluwarsa. Command sync (`fetch`/`upsert`/`delete`) me-refresh token proaktif 2 menit sebelum kadaluarsa dan retry sekali saat kena 401 — sync tidak lagi mati sejam setelah login.
- **Sync saat app terkunci tidak lagi diam-diam**: StatusBar menampilkan "Sync Dijeda (Terkunci)" dan pesan alasan; error sync kini menampilkan penyebab aslinya di tooltip (bukan cuma "Sync failed").
- **Error pull/delete tidak lagi ditelan**: fallback browser `fetchRemoteNotes` yang gagal kini melempar error (sebelumnya terlihat seperti "cloud kosong"); `delete_note` Rust mengembalikan error nyata bila hard-delete dan soft-delete sama-sama gagal.
- **UI Login Supabase**: kartu "Akun Supabase" di Settings (Masuk/Daftar/Keluar) — sebelumnya command login/registrasi ada tapi tidak pernah bisa diakses user.

### 🔒 Keamanan: Row Level Security Per-Pengguna
- Skema auto-create & SQL migration kini menambah kolom `user_id uuid default auth.uid()` dan policy `to authenticated` (`auth.uid() = user_id`) — menggantikan policy lama `to anon, authenticated using (true)` yang membuka seluruh tabel ke siapa pun yang memegang anon key, tanpa pemisahan data antar user.
- `revoke all ... from anon` + drop policy publik bawaan dashboard. Tabel lama tetap kompatibel: baris lama ber-`user_id` NULL tetap terlihat setelah login (panduan backfill tersedia di skrip SQL).

---

## [0.1.11] - 2026-10-04

### 🔐 Fitur Baru: Enkripsi End-to-End (Dua Arah: Lokal & Cloud)
- **Master Password End-to-End**: Konten catatan dienkripsi dengan **XChaCha20-Poly1305** (kunci diturunkan dari master password via **Argon2id**, parameter OWASP) sebelum disimpan ke database lokal maupun disinkronkan ke Supabase Cloud. Hanya pemilik password yang bisa membaca isinya.
- **Lock Screen & Setup Wizard**: Layar kunci muncul saat app dibuka (input password, peringatan "lupa password = data hilang permanen", opsi ingat device).
- **Ingat di Device Ini**: Kunci disimpan aman di **Windows Credential Manager** (macOS Keychain / Linux Secret Service) — auto-unlock saat app dibuka ulang, tanpa menyimpan password.
- **Migrasi Otomatis**: Seluruh catatan lama (lokal & cloud) dienkripsi otomatis sekali saat password pertama di-set — transaksional (gagal di tengah jalan = rollback penuh, tanpa data campuran).
- **Ganti Master Password**: Semua catatan lokal & cloud dienkripsi ulang dengan kunci baru dalam satu transaksi.
- **Tab Keamanan di Settings**: Status enkripsi, ganti password, "Kunci Sekarang", dan "Lupakan Password di Device Ini".
- **Proteksi Fail-Closed**: Save & sync ditolak di sisi Rust saat app terkunci — catatan tidak pernah tersimpan plaintext tanpa sengaja; sinkronisasi berhenti dengan error yang terlihat jika ciphertext tidak bisa didekripsi (tidak pernah menimpa catatan lokal).

### 🛠 Perbaikan
- **Backend Keyring Platform**: Crate `keyring` v3 tanpa fitur default — backend `windows-native` / `apple-native` / `sync-secret-service` kini diaktifkan eksplisit (diverifikasi roundtrip nyata ke Windows Credential Manager), sehingga fitur "ingat device" benar-benar persisten.
- CI Linux: tambah `libdbus-1-dev` untuk build backend Secret Service.

---

## [0.1.10] - 2026-09-11

### 🔄 Pembaruan Otomatis & Konsistensi Tampilan Versi
- **Aktivasi Pembaruan Otomatis ke v0.1.10**: Rilis pembaruan untuk memicu auto-updater Tauri bagi pengguna yang sudah terpasang versi `0.1.9`.
- **Integrasi Tampilan Dinamis**: Pengaturan (`SettingsWorkspace`), Status Bar footer, Titlebar, dan About Modal kini 100% membaca versi terbaru secara dinamis.
- **CodeGraph Knowledge Base**: Repositori resmi terindeks CodeGraph untuk pemetaan dependensi kode.

---

## [0.1.9] - 2026-09-11

### 🗄️ Fitur Baru: Pembaca SQLite & Studio Explorer (`Ctrl+Shift+D`)
- **Pembaca Database SQLite Dedicated**:
  - Dukungan membuka berkas database SQLite lokal (`.db`, `.sqlite`, `.sqlite3`, `.db3`) dengan drag-and-drop atau dialog berkas.
  - 1-Klik membuka database SQLite internal Valtera Note (`valtera_note.db`).
  - Read-only safety murni (`rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY`) mencegah penguncian berkas atau korupsi database.
  - Sidebar tabel & view dengan hitungan total baris (*live row count*) dan filter pencarian real-time.
  - **Jelajahi Data**: Grid data tabel interaktif dengan sorting kolom, pencarian baris real-time, paginasi, dan 1-click copy value.
  - **SQL Query Console**: Konsol kueri SQL dengan template cepat, statistik eksekusi milidetik, dan pesan diagnostik kesalahan.
  - **Inspektor Skema & DDL**: Menampilkan struktur kolom (tipe data, Primary Key, nullability, default value) dan generator DDL `CREATE TABLE`.
  - **Ekspor Data**: CSV (RFC 4180), JSON, Markdown Table, dan ekspor langsung ke tab editor baru.

### 🔄 Sentralisasi Versi & Metadata Aplikasi
- **Single Source of Truth (`src/constants/app.ts`)**: Seluruh tampilan versi aplikasi (Settings Workspace, StatusBar footer, About Modal, dan Titlebar) kini terhubung langsung secara dinamis ke satu sumber data pusat sehingga versi selalu konsisten.

---

## [0.1.8] - 2026-09-11

### 📖 Fitur Baru: Kamus Sintaks & Perintah (Cheatsheet & Knowledge Base)
- **Kamus Sintaks Lengkap (`Ctrl+Shift+T`)**: Menggantikan drawer template standar dengan 27 referensi sintaks siap pakai yang interaktif:
  - **Markdown & GFM**: GitHub Alerts (`> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`), tabel dengan alignment (`:---`, `:---:`), task checklist, blok kode, diagram alur Mermaid (`flowchart TD`), rumus matematika LaTeX/KaTeX, accordion `<details>`, format teks stabilo & `<kbd>`, footnotes, dan template notulensi rapat.
  - **SQL & Database**: Query `SELECT` dengan filter & paginasi, `CREATE TABLE` SQLite, `UPSERT` on conflict, aggregasi `GROUP BY` & `HAVING`, `JOIN`, inspeksi `PRAGMA` SQLite, transaksi ACID, dan CTE (`WITH`).
  - **JSON**: Amplop respons RESTful, aturan wajib JSON murni, konfigurasi `package.json`, dan skema `GeoJSON`.
  - **Regex**: Pola validasi umum (Email, URL, UUID, Slug), kamus arti simbol karakter, dan kuantifier pengulangan.
  - **Git & CLI**: Alur kerja harian Git dan perintah undo/stash.
- **Fitur Interaktif**: Pencarian real-time, filter pill kategori, tombol salin ke clipboard instan, dan tombol sisipkan langsung ke catatan.

### ⚙️ Pengaturan Terpusat (Unified Settings Workspace)
- **Dedicated Settings Page (`Ctrl+,`)**: Halaman pengaturan terpadu dengan sidebar navigasi:
  - **Kredensial Supabase**: URL & Anon Key dengan pengujian koneksi live dan status auto-sync.
  - **Tampilan & Tema**: Preset tema Slate Modern, Obsidian Dark, Dracula, Cyberpunk Neon, GitHub Light, dan Nord Frost, dilengkapi switch Dark / Light mode.
  - **Preferensi Editor**: Ukuran font, tab size, line wrap, dan opsi konfigurasi CodeMirror.
  - **Tentang & Pembaruan**: Informasi versi, spesifikasi teknis (Tauri v2 + Rust), dan tombol cek pembaruan aplikasi.
- **Pembersihan Menu Tools**: Menghilangkan opsi pengaturan dari menu dropdown Tools agar menu Tools 100% fokus untuk developer tools.

### 🪟 Peningkatan Antarmuka & Kontrol Jendela
- **Frameless Windows 11 Controls**: Menonaktifkan titlebar ganda native OS (`decorations: false`) dengan kontrol jendela modern (Minimize, Maximize/Restore dinamis, dan Close).
- **Pembersihan Bar Kanan**: Menghilangkan tombol Tools di sebelah tombol Settings agar quick action bar lebih bersih dan rapi.

---

## [0.1.7] - 2026-09-11

### 🛠️ Fitur Baru: Dedicated Developer Tools Suite & About Modal
- **Full-Page Developer Tools Workspace**: Suite perkakas pengembang lengkap dan terintegrasi yang dapat dibuka via tombol **Tools** di Titlebar, Command Palette (`Ctrl+K`), atau shortcut keyboard langsung:
  - **JSON Formatter, Validator & Tree Inspector** (`Ctrl+Shift+J`):
    - Format (Indented) & Minify JSON instan.
    - Interactive Tree Viewer dengan toggle expand/collapse dan live key-path copying.
    - Ekspor data JSON ke tabel **CSV (RFC 4180)** dan tabel **Markdown (GitHub Flavored)** otomatis.
    - Visual Table Grid dengan pencarian real-time dan pemilihan sumber array objek.
  - **Favicon & Web Icon Package Generator** (`Ctrl+Shift+F`):
    - Generator paket favicon lengkap standar web dari berkas gambar/SVG (drag-and-drop).
    - Menghasilkan `favicon.ico` (multi-resolusi 16x16, 32x32, 48x48), `apple-touch-icon.png`, `android-chrome-192/512`, `manifest.json`, dan `browserconfig.xml`.
    - Unduh seluruh aset terkompresi dalam berkas ZIP sekali klik serta salin snippet tag `<head>` HTML.
  - **MySQL Password Hash Generator** (`Ctrl+Shift+P`):
    - Komputasi hash otentikasi MySQL Native Password (`mysql_native_password` SHA1 double-hash) dan format legacy password untuk administrasi basis data.
  - **Base64 Encoder / Decoder**: Konversi teks dan data biner secara dua arah dengan live character counting dan validasi.
  - **URL Encoder / Decoder & Query Inspector**: URL encoding/decoding instan dengan antarmuka builder query params.
  - **UUID Generator (v4)**: Pembuatan bulk UUID v4 dengan opsi format huruf kapital, tanpa strip (-), dan output format Plain, SQL, JSON, atau CSV.
- **About Modal**:
  - Modal informasi aplikasi resmi Valtera Note lengkap dengan nomor versi, lisensi, informasi pengembang, dan tombol periksa pembaruan manual.
- **Peningkatan Titlebar & Navigasi**:
  - Tombol akses cepat Developer Tools pada Titlebar dengan penanda status aktif.
  - Integrasi perintah developer tools langsung ke dalam Command Palette.

---

## [0.1.6] - 2026-09-10

### ✨ Fitur Baru: Dukungan Icon & Emoji Saat Menulis & Manajemen Multi-Tab
- **Inline Emoji & Icon Autocomplete**: Mengetik `:` langsung di editor CodeMirror memicu autocomplete cerdas (cth: `:rocket:`, `:fire:`, `:star:`, `:check:`, `:warn:`, `:db:`, `:sql:`, `:koding:`, dll) dengan dukungan alias bahasa Indonesia dan Inggris. Menekan `Enter` atau `Tab` langsung mengganti tag menjadi karakter emoji asli.
- **Visual Emoji & Icon Picker Modal**: Popup visual pencarian icon lengkap dengan filter kategori (*Dev & DB*, *Status & Task*, *Dokumen*, *Simbol & Panah*, *Ekspresi*), preview hover, salin karakter, serta tombol sisipkan langsung ke kursor aktif. Dapat dibuka via tombol Titlebar, Command Palette, atau shortcut `Ctrl+Shift+E`.
- **Fitur Tutup Semua Tab (Close All Tabs)**:
  - Menutup seluruh tab terbuka sekaligus tanpa perlu mengklik silang satu per satu via shortcut `Ctrl+Shift+W` atau tombol dedicated **Tutup Semua** di TabBar saat tab > 1.
  - Aman dan non-destruktif: catatan yang telah tersimpan tetap utuh di Sidebar dan Supabase Cloud, hanya tab scratchpad kosong yang dibersihkan.
- **Tab Right-Click Context Menu**: Klik kanan pada sembarang tab kini menampilkan menu konteks profesional:
  - 📌 **Tutup Tab Ini** (`Ctrl+W`)
  - 🗂️ **Tutup Tab Lainnya**
  - ❌ **Tutup Semua Tab** (`Ctrl+Shift+W`)
  - 💾 **Simpan Catatan** (`Ctrl+S`)
- **Pintasan Keyboard & Command Palette**: Menambahkan perintah dan shortcut `Ctrl+W` (tutup tab aktif), `Ctrl+Shift+W` (tutup semua tab), dan `Ctrl+Shift+E` (picker emoji).

---

## [0.1.5] - 2026-09-10

### ☁️ Supabase Cloud Sync & CI Build Pipeline Optimization
- **Local-to-Cloud Sync Fix**: Resolved issue where locally saved notes failed to sync to Supabase Cloud due to PostgREST `on_conflict=id` requirement when notes lacked assigned remote IDs.
- **Dynamic Upserting**: New notes are now posted cleanly to `/rest/v1/notes` or provisioned with a client UUID, returning the generated record and setting `tab.supabase_id` seamlessly.
- **Visual Cloud Indicators**: Added clear emerald `<Cloud>` status badges and 1-click cloud sync buttons on unsynced notes in both tab bar and sidebar.
- **Accurate Error Reporting**: Fixed false positive "Sync Succeeded" notification when remote upsert encounters permission or network issues.
- **CI Build Speedup (80-90% faster)**: Integrated `swatinem/rust-cache@v2` and `pnpm` store caching into GitHub Actions cross-platform workflow, eliminating redundant full recompilations.

---

## [0.1.4] - 2026-09-09

### 🛠️ SQLite Migration & Supabase Configuration Persistence Fix
- **Automatic SQLite Migration**: Added automatic migration in Rust database engine to fix legacy `app_settings` table constraint (`NOT NULL constraint failed: app_settings.value_json`), resolving issue where Supabase URL and API Key were lost after restart.
- **IPC Self-Healing**: Enhanced IPC Supabase configuration loader with automatic recovery from local storage cache to SQLite.
- **Auto-Persist Sync Settings**: Supabase credentials are now automatically saved upon successful connection tests and on closing the sync configuration modal.

---

## [0.1.3] - 2026-09-02

### 🔄 In-App Auto-Updater Artifacts Fix
- **Enabled Updater Bundles**: Configured `createUpdaterArtifacts: true` in Tauri v2 bundle configuration to automatically generate cryptographic signature `.sig` files and `latest.json` manifests during GitHub Actions builds.
- **Direct 1-Click Update**: Enabled automatic update notifications and 1-click in-app update for all installed desktop clients.

---

## [0.1.2] - 2026-09-02

### 🛠️ Fixes & Supabase Connection Test
- **Supabase Connection Ping**: Updated test ping endpoint to use `/auth/v1/health` and `/rest/v1/notes` instead of root schema endpoint, resolving `HTTP 401 Only the service_role API key can be used for this endpoint`.
- **Seamless Anon Key Authentication**: Enabled instant validation with standard Supabase `anon_key`.

---

## [0.1.1] - 2026-09-02

### 🔄 Supabase Cloud Sync & Auto-Updater Enhancement
- **Full Schema Sync**: Added `folder` column support in Supabase `notes` table and migration script.
- **Enhanced RLS Security Policy**: Comprehensive CRUD permission configuration for seamless `anon_key` and authenticated sync.
- **Auto-Updater Integration**: Configured dedicated Minisign cryptographic keys for in-app 1-click updates.

---

## [0.1.0] - 2026-09-01

### 🚀 Initial Production Release

#### ✨ Core Editor & Workspace
- **Ultra-Lightweight Rust Engine**: Cold boot in `< 250ms` and `< 40MB` idle RAM usage powered by Tauri v2.
- **CodeMirror 6 Virtualized Buffer**: High performance with syntax highlighting for Markdown, SQL, JSON, CSV, Rust, TypeScript, and Plain Text.
- **Multi-Tab & Split Views**: Support for side-by-side editing, live markdown sync-scroll, and full reader mode.
- **Organized Folders & Sidebar**: Automatic initial note creation when making new folders, inline folder collapsing, and custom tagging.

#### 🗄️ SQL Scratchpad & JSON Visualizer
- **SQLite Query Runner**: Direct `.db` / `.sqlite` execution with tabbed data grid viewer, sorting, and row counting.
- **Collapsible JSON Tree Viewer**: Interactive node expansion, path copying (`parent.child[0]`), and format beautifier.
- **Quick Snippets & Templates**: Instant code snippets drawer accessible via `Ctrl+Shift+S`.

#### ☁️ Supabase Cloud Sync & Security
- **Local-First Offline Architecture**: Embedded SQLite 3 cache with WAL mode ensuring zero data loss during network drops.
- **Background Sync**: Non-blocking asynchronous Supabase sync using native Rust threads (`tokio`).
- **Tombstone Sync Safety**: Clear distinction between closing a tab view and permanent note deletion.

#### 🔄 Automatic In-App Updates
- **Tauri v2 Auto-Updater**: Instant in-app update checks connected to GitHub Releases.
- **Mandatory Bugfix Alerts**: Interactive update modal with live download progress tracking and seamless automatic restart.
- **Digital Code Signing**: Ed25519 cryptographic signatures on all release packages (`latest.json`).

#### 🪟 Windows System Integration
- **Shell Context Menu**: Built-in 1-click registration for *"Open with Valtera Note"* in Windows File Explorer.
- **Single-Instance Enforcement**: Smoothly routes newly clicked files into existing application tabs.
- **Packaging**: Dual distribution via WiX MSI (`.msi`) and NSIS Setup (`.exe`).

---

<sub>Maintained by <b>PT Valtera Teknologi Digital</b></sub>
