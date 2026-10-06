<div align="center">

<img src="public/logo.png" width="96" height="96" alt="Valtera Note Logo" />

# Valtera Note

**Ultra-lightweight desktop text editor, SQL scratchpad, Markdown workspace, Developer Tools suite — now with a privacy-first AI Assistant.**
*Engineered with Tauri v2 & Rust — Consuming under 40MB of RAM.*

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Tauri v2](https://img.shields.io/badge/Tauri-v2.0-24C8D8?logo=tauri&logoColor=white)](https://v2.tauri.app)
[![Rust](https://img.shields.io/badge/Rust-1.75+-DEA584?logo=rust&logoColor=white)](https://www.rust-lang.org)
[![Svelte 5](https://img.shields.io/badge/Svelte-v5.0-FF3E00?logo=svelte&logoColor=white)](https://svelte.dev)
[![RAM Footprint](https://img.shields.io/badge/RAM-~38MB-brightgreen)](#-why-valtera-note)
[![Latest Release](https://img.shields.io/github/v/release/danikz/valtera-note?color=orange&logo=github)](https://github.com/danikz/valtera-note/releases/latest)

<br />

<p align="center">
  <img src="docs/screenshots/preview-hero-light.png" width="95%" alt="Valtera Note Light Hero Preview - Live Markdown Split & Modern Light Mode" />
</p>

</div>

---

## 📥 Download (Latest)

Grab the official installer for your platform from the **[GitHub Releases Page](https://github.com/danikz/valtera-note/releases/latest)** — Windows `.exe` / `.msi`, macOS `.dmg`, Linux `.deb` / `.AppImage`.

> 🔄 **Automatic In-App Updates**: Valtera Note ships with a built-in cryptographic auto-updater. When a new version is released, you get an instant notification with a 1-click upgrade.

---

## ✨ Highlights

- 🤖 **Built-in AI Assistant** — chat sidebar that reads your active note & selection. Bring your own API key: **Anthropic Claude (native)** or **any OpenAI-compatible endpoint** (OpenAI, OpenRouter, Groq, local Ollama). It can even write back to your notes. → [AI Assistant Guide](docs/AI_ASSISTANT.md)
- 🔒 **End-to-End Encryption** — notes are encrypted with XChaCha20-Poly1305 (Argon2id key derivation) before touching local disk or the cloud, with a lock screen & auto-unlock via Windows Credential Manager / Keychain.
- ⚡ **Instant Cold Startup** — boot in `< 250ms`, idle footprint **under 40MB of RAM** (Tauri v2 + Rust, not Electron).
- 🛠️ **Developer Tools Suite** — JSON Formatter & Tree, SQLite Studio, Favicon Package Generator, MySQL Password Hash, URL & UUID tools. → [Features](docs/FEATURES.md)
- 📑 **Live Markdown Split** — GitHub Flavored Markdown with synchronized dual-pane scrolling.
- 🗄️ **SQL Scratchpad** — syntax highlighting, SQL beautifier, local SQLite execution with a result grid.
- 🌳 **Interactive JSON Tree & Table** — collapsible nodes, click-to-copy paths, CSV/Markdown export.
- ☁️ **Offline-First + Optional Cloud Sync** — fully functional offline; optional Supabase sync with strict Row Level Security. → [Supabase Setup](docs/SUPABASE_SETUP.md)
- 🎨 **Dark / Light / System Themes** — 6 editor palettes (Tokyo Night, Dracula, GitHub Light, …) plus a configurable display timezone (24-hour format).
- 🪟 **Windows Explorer Integration** — open files with 1-click from the context menu.

---

## 🤖 AI Assistant (Bring Your Own Key)

Press **`Ctrl+Shift+A`** (or the ✨ button in the titlebar) to open the AI chat sidebar:

- **Provider bebas**: Anthropic Claude (native) atau endpoint OpenAI-compatible apa pun — key & model diatur di *Pengaturan → AI Assistant*, tersimpan hanya di perangkatmu.
- **Context-aware**: aktifkan "Baca catatan aktif" agar AI mengerti isi catatan yang terbuka, dan "Sertakan teks terpilih" untuk bagian yang kamu blok.
- **Bisa menulis ke catatan**: minta AI menulis/mengubah isi catatan → terapkan dengan satu klik (konfirmasi dulu, aman).
- **Quick actions**: Ringkas, Perbaiki Tulisan, Translate, Jelaskan, Commit Message, dan prompt kustom.

> ⚠️ Catatan privasi: teks yang dikirim ke AI keluar dari perangkat sebagai plaintext. Enkripsi E2E melindungi penyimpanan lokal & cloud — bukan permintaan AI. Untuk konten super-sensitif, gunakan provider lokal (Ollama).

📖 Panduan lengkap (setup provider, troubleshooting, contoh perintah): **[docs/AI_ASSISTANT.md](docs/AI_ASSISTANT.md)**

---

## ☁️ Cloud Sync (Optional — Supabase)

Valtera Note is 100% offline-first. For multi-device sync, follow the guided order in-app:

1. **Kredensial Project** — masukkan *Project URL* & *Anon Key* (Pengaturan → Supabase).
2. **Siapkan Tabel** — jalankan skrip SQL resmi dari SyncModal (Row Level Security ketat: hanya akun yang login bisa mengakses).
3. **Masuk / Daftar Akun** — sync berjalan sebagai identitasmu, sesi ditahan otomatis.

Setelah itu semua catatan tersinkron otomatis (1,5 detik setelah mengetik + pull berkala 30 detik).

📖 Panduan lengkap termasuk skrip SQL & troubleshooting: **[docs/SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md)**

---

## ⌨️ Keyboard Shortcuts

| Action / Feature | Shortcut |
| :--- | :--- |
| **AI Chat Sidebar** | `Ctrl + Shift + A` |
| **Command Palette & Search** | `Ctrl + K` / `Ctrl + P` |
| **Pengaturan (Supabase, AI, Tema, Editor)** | `Ctrl + ,` |
| **Developer Tools (JSON)** | `Ctrl + Shift + J` |
| **SQLite Studio** | `Ctrl + Shift + D` |
| **Favicon Generator** | `Ctrl + Shift + F` |
| **MySQL Password Generator** | `Ctrl + Shift + P` |
| **Emoji & Icon Picker** | `Ctrl + Shift + E` |
| **New Note / Open / Save** | `Ctrl + N` / `Ctrl + O` / `Ctrl + S` |
| **Toggle Sidebar Navigation** | `Ctrl + B` |
| **Toggle Markdown Split View** | `Ctrl + \` |
| **Close Tab / All Tabs** | `Ctrl + W` / `Ctrl + Shift + W` |
| **Execute SQL Query** | `Ctrl + Enter` / `F5` |

---

## 🛠️ Building from Source

### Prerequisites
- [Node.js](https://nodejs.org) (v20+) & [pnpm](https://pnpm.io) (v10+)
- [Rust](https://www.rust-lang.org) (1.75+)
- Platform-specific Tauri v2 prerequisites:
  - **Windows**: Microsoft C++ Build Tools & WebView2
  - **macOS**: Xcode Command Line Tools
  - **Linux**: `libwebkit2gtk-4.1-dev`, `build-essential`, `curl`, `libssl-dev`, `libayatana-appindicator3-dev`

```bash
# 1. Clone repository
git clone https://github.com/danikz/valtera-note.git
cd valtera-note

# 2. Install dependencies & run development mode
pnpm install
pnpm tauri dev

# 3. Compile and build native installers
pnpm tauri build
```

---

## 📚 Documentation

| Document | Description |
| :--- | :--- |
| **[AI Assistant Guide](docs/AI_ASSISTANT.md)** | Setup provider (Claude / OpenAI-compatible / Ollama), chat sidebar, context toggles, write-to-note, troubleshooting. |
| **[Supabase Setup](docs/SUPABASE_SETUP.md)** | Skrip SQL resmi (RLS ketat), urutan setup, login akun, troubleshooting sync. |
| **[Features & Previews](docs/FEATURES.md)** | Tur lengkap semua fitur dengan screenshot. |
| **[Architecture](docs/ARCHITECTURE.md)** | Struktur teknis aplikasi (Tauri + Svelte + SQLite). |
| **[Database Schema](docs/DATABASE.md)** | Skema SQLite lokal & tabel cloud. |
| **[Changelog](CHANGELOG.md)** | Riwayat rilis per versi. |

## 📄 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for details.

<div align="center">
  <sub>Designed & Developed by <b>PT Valtera Teknologi Digital</b></sub>
</div>
