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

<p align="center">
  <a href="README.md">🇬🇧 English</a> · <a href="README.id.md">🇮🇩 Bahasa Indonesia</a>
</p>

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

- **Any provider you like**: Anthropic Claude (native) or any OpenAI-compatible endpoint — key & model are configured in *Settings → AI Assistant* and stored only on your device.
- **Context-aware**: enable "Read active note" so the AI understands the note you have open, and "Include selected text" for the exact block you've highlighted.
- **It can write to your notes**: ask the AI to write or edit the note's content, then apply it with one click (confirmation first, safe).
- **Quick actions**: Summarize, Improve Writing, Translate, Explain, Commit Message, and custom prompts.

> ⚠️ Privacy note: text sent to the AI leaves your device as plaintext. E2E encryption protects local storage & cloud sync — not AI requests. For highly sensitive content, use a local provider (Ollama).

📖 Full guide (provider setup, troubleshooting, example prompts): **[docs/AI_ASSISTANT.md](docs/AI_ASSISTANT.md)**

---

## ☁️ Cloud Sync (Optional — Supabase)

Valtera Note is 100% offline-first. For multi-device sync, follow the guided in-app order:

1. **Project credentials** — enter your *Project URL* & *Anon Key* (Settings → Supabase).
2. **Prepare the table** — run the official SQL script from the Sync Modal (strict Row Level Security: only your logged-in account can access it).
3. **Sign up / Sign in** — sync runs as your identity, with the session kept alive automatically.

After that, every note syncs automatically (1.5s after typing + a 30s background pull).

📖 Full guide including the SQL script & troubleshooting: **[docs/SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md)**

---

## 🔒 Security & End-to-End Encryption

Your notes are **zero-knowledge encrypted** — even your cloud provider cannot read them.

| Layer | What happens |
| :--- | :--- |
| **Local (SQLite)** | Note contents are stored as `enc:v1:...` ciphertext — encrypted **before** they touch the disk. |
| **Key derivation** | Your master password → **Argon2id** (OWASP parameters) → a 256-bit key. The password itself is never stored. |
| **Encryption** | **XChaCha20-Poly1305** authenticated encryption per note — confidentiality + integrity. |
| **Cloud sync (Supabase)** | The server only ever sees ciphertext. With strict RLS, only *your logged-in account* can access your rows. |
| **Lock screen** | Content is hidden while locked; "Remember on this device" stores the key in the OS keystore (Windows Credential Manager / macOS Keychain / Linux Secret Service) — **not** your password. |

**Honest limits** (we'd rather over-explain than over-promise):

- Losing your master password means the notes are **permanently unreadable** — there is no recovery backdoor by design.
- Note **titles** and folder names stay plaintext in the cloud (only contents are encrypted).
- Text sent to the **AI Assistant** leaves your device as plaintext — use a local provider (Ollama) for highly sensitive content.

---

## ⌨️ Keyboard Shortcuts

| Action / Feature | Shortcut |
| :--- | :--- |
| **AI Chat Sidebar** | `Ctrl + Shift + A` |
| **Command Palette & Search** | `Ctrl + K` / `Ctrl + P` |
| **Settings (Supabase, AI, Theme, Editor)** | `Ctrl + ,` |
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
| **[AI Assistant Guide](docs/AI_ASSISTANT.md)** | Provider setup (Claude / OpenAI-compatible / Ollama), chat sidebar, note context, write-to-note, troubleshooting. |
| **[Supabase Setup](docs/SUPABASE_SETUP.md)** | Official SQL script (strict RLS), ordered setup, account login, sync troubleshooting. |
| **[Features & Previews](docs/FEATURES.md)** | Full feature tour with screenshots. |
| **[Architecture](docs/ARCHITECTURE.md)** | Technical structure of the app (Tauri + Svelte + SQLite). |
| **[Database Schema](docs/DATABASE.md)** | Local SQLite schema & cloud table. |
| **[Changelog](CHANGELOG.md)** | Release notes per version. |

## 📄 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for details.

<div align="center">
  <sub>Designed & Developed by <b>PT Valtera Teknologi Digital</b></sub>
</div>
