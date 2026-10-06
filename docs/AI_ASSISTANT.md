# 🤖 AI Assistant Guide — Valtera Note

Valtera Note punya AI Assistant bawaan dengan model **Bring Your Own Key (BYO)**: tidak ada server perantara, tidak ada biaya langganan dari kami — kamu memakai API key sendiri dari provider pilihanmu. Permintaan dikirim **langsung dari backend Rust** ke provider (bebas CORS), dan konfigurasi tersimpan **hanya di perangkat ini**.

---

## 1. Provider yang Didukung

| Provider | Jenis | Base URL | Contoh Model |
| :--- | :--- | :--- | :--- |
| **Anthropic Claude** | Native Messages API | `https://api.anthropic.com` | `claude-sonnet-4-5` |
| **OpenAI** | OpenAI-compatible | `https://api.openai.com/v1` | `gpt-4o-mini` |
| **OpenRouter** | OpenAI-compatible | `https://openrouter.ai/api/v1` | `anthropic/claude-sonnet-4.5` |
| **Groq** | OpenAI-compatible | `https://api.groq.com/openai/v1` | `llama-3.3-70b-versatile` |
| **Ollama (lokal)** | OpenAI-compatible | `http://localhost:11434/v1` | `llama3.1` |

- Semua endpoint yang mengikuti standar **OpenAI-compatible** (`/chat/completions`) didukung otomatis — termasuk LM Studio, Together, dsb.
- **Ollama/LM Studio** = 100% offline. Cocok untuk konten super-sensitif karena teks tidak pernah keluar dari perangkat.
- Preset satu klik tersedia di layar pengaturan; cukup isi API key setelahnya.

---

## 2. Setup (Sekali Saja)

1. Buka **Pengaturan → AI Assistant** (atau `Ctrl+,`).
2. Klik salah satu **Preset Cepat** (OpenAI / Anthropic / OpenRouter / Groq / Ollama).
3. Isi **API Key** dari provider tersebut.
4. Klik **Test Koneksi** — selain validasi, aplikasi otomatis **memuat daftar model asli provider** dan kolom *Model* akan menampilkan saran dropdown.
5. Pilih model → **Simpan**. Selesai — indikator hijau muncul di sidebar Pengaturan.

> 💡 Key yang tersimpan tidak akan terhapus bila kamu menyimpan ulang konfigurasi tanpa mengisi kolom key (kosong = pertahankan key lama).

---

## 3. AI Chat Sidebar (Ngobrol)

Buka dengan **`Ctrl+Shift+A`** atau tombol **✨** di pojok kanan titlebar.

- **Multi-turn**: AI mengingat konteks percakapan selama panel terbuka; tombol 🗑️ untuk mulai ulang.
- **Baca catatan aktif** (toggle): isi catatan yang sedang terbuka dikirim sebagai konteks — AI tahu tentang apa kamu bicara.
- **Sertakan teks terpilih** (toggle): blok teks yang kamu seleksi di editor ikut dikirim — ideal untuk bertanya tentang potongan kode/konfigurasi tertentu.
- **Saran cepat**: ringkas catatan, tinjau potensi masalah, buat task list, atau suruh AI menulis.
- `Enter` = kirim, `Shift+Enter` = baris baru.

---

## 4. Menulis ke Catatan (Write-to-Note)

Minta AI mengubah catatan, misalnya:

> *"perbaiki typo di catatan ini lalu perbarui"*
> *"tambahkan section Ringkasan di akhir catatan"*

AI akan membalas dengan penjelasan singkat + blok **`valtera-write`** berisi catatan lengkap versi terbaru. Sidebar menampilkan kartu:

- **Ganti Seluruh Catatan** — setelah konfirmasi, isi editor langsung diperbarui (minimal diff, kursor tidak lompat) dan auto-sync cloud berjalan seperti biasa.
- **Salin Saja** — untuk direview manual terlebih dahulu.

Setelah diterapkan muncul tanda ✅ *Catatan berhasil diperbarui*.

> Protokol ini berbasis instruksi sistem sehingga **bekerja di semua provider** — termasuk model kecil tanpa dukungan tool-calling.

### Aksi Cepat di Editor (`Ctrl+Shift+A` → atau menu Edit)

Selain chat, ada aksi satu-klik yang bekerja pada **teks terpilih** (atau seluruh catatan bila tidak ada seleksi):

| Aksi | Hasil |
| :--- | :--- |
| **Ringkas** | Poin-poin ringkasan |
| **Perbaiki Tulisan** | Ejaan & tata bahasa diperbaiki |
| **→ English / → Indonesia** | Terjemahan |
| **Jelaskan** | Penjelasan bahasa sederhana |
| **Commit Msg** | Satu baris conventional commit |
| **Prompt kustom** | Instruksi bebas |

Hasil bisa **disalin**, **mengganti seleksi**, atau **disisipkan di kursor**.

---

## 5. Privasi

- API key & konfigurasi AI tersimpan **hanya di database lokal perangkat ini**.
- Permintaan dikirim langsung aplikasi → provider; **tanpa server perantara**.
- ⚠️ **Penting**: teks yang dikirim ke AI keluar dari perangkat sebagai **plaintext** — enkripsi E2E Valtera Note melindungi penyimpanan lokal & cloud sync, bukan permintaan AI. Untuk konten paling sensitif, gunakan **Ollama lokal**.

---

## 6. Troubleshooting

| Masalah | Penyebab & Solusi |
| :--- | :--- |
| `missing required key baseUrl` | Bug versi < 0.1.19 — update aplikasi (argumen kini dual-case). |
| `HTTP 401` saat test koneksi | API key salah/kedaluwarsa — periksa kembali key. |
| `HTTP 404` saat test koneksi | Base URL salah — OpenAI perlu akhiran `/v1`, Anthropic tidak. |
| Respon kosong / model not found | Nama model salah ketik — gunakan daftar model dari **Test Koneksi** (OpenRouter memakai format `vendor/model`). |
| `daftar model gagal dimuat` | Beberapa endpoint kompatibel tidak menyediakan `GET /models` — ketik nama model manual, fitur chat tetap berjalan. |
| AI menulis di luar blok / tidak membuat blok | Tekan kembali permintaan dengan kata "perbarui catatan" — protokol memerlukan instruksi yang jelas untuk menulis. |
