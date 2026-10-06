# ✨ Features & Previews — Valtera Note

A full tour of Valtera Note's features with screenshots (Light Mode, rendered automatically via Playwright).

---

## 1. 🛠️ Dedicated Developer Tools Suite & SQLite Studio (`v0.1.9`)

Access full-page developer utilities directly via the Titlebar button, Command Palette (`Ctrl+K`), or keyboard shortcuts:

- **JSON Formatter & Tree Inspector** (`Ctrl+Shift+J`): Beautify, minify, and inspect JSON payloads with interactive tree navigation or dynamic table grids. Export to **CSV (RFC 4180)** and **Markdown Tables** with 1 click.
- **SQLite Reader & Database Explorer (SQLite Studio)** (`Ctrl+Shift+D`): Open and browse SQLite database files (`.db`, `.sqlite`, `.sqlite3`) from your computer or Valtera Note's internal database with 1 click. List tables & views, count rows, sort columns, real-time row search filtering, run custom SQL queries, and export to CSV, JSON, or Markdown Table.
- **Favicon & Web Icon Package Generator** (`Ctrl+Shift+F`): Drag and drop any image or SVG to generate `favicon.ico` (multi-res 16/32/48), `apple-touch-icon.png`, `android-chrome-192/512`, `manifest.json`, `browserconfig.xml`, and a ready-to-download ZIP archive.
- **MySQL Password Hash Generator** (`Ctrl+Shift+P`): Compute MySQL Native Password (`mysql_native_password` double-SHA1) and legacy hashes for quick database administration.
- **Base64 & URL Tools**: Bilateral Base64 encoding/decoding and URL query parameter inspector.
- **Bulk UUID v4 Generator**: Fast bulk UUID generation with capitalization and format options.

<p align="center">
  <img src="screenshots/preview-tools-light.png" width="92%" alt="Valtera Note Developer Tools Suite - JSON Formatter & Table Grid" />
</p>

---

## 2. 🤖 AI Assistant & Chat Sidebar (`v0.1.18+`)

Chat with an AI right inside your editor:

- **Any provider (BYO key)**: Anthropic Claude (native), OpenAI, OpenRouter, Groq, or local Ollama. The key is stored only on your device.
- **Context-aware**: the AI reads the active note and/or the text you've selected in the editor.
- **Write-to-note**: ask the AI to write or edit the note's content — apply it with one click.
- **Quick actions**: Summarize, Improve Writing, Translate, Explain, Commit Message, custom prompts.

<p align="center">
  <em>AI Chat Sidebar — active note & selection context</em>
</p>

📖 Full guide: **[AI_ASSISTANT.md](AI_ASSISTANT.md)**

---

## 3. 🔒 End-to-End Encryption & Lock Screen (`v0.1.11+`)

- Note contents are encrypted with **XChaCha20-Poly1305** (key derived from the master password via **Argon2id**, OWASP parameters) before being stored in the local SQLite database or synced to Supabase.
- A **Lock Screen** appears when the app opens; "Remember on this Device" stores the key in the **Windows Credential Manager** (macOS Keychain / Linux Secret Service) for auto-unlock.
- Cloud sync uses **strict Row Level Security** — only your logged-in account can access its rows.

**Honest limits** (we'd rather over-explain than over-promise):

- Losing your master password means the notes are **permanently unreadable** — no recovery backdoor, by design.
- Note **titles** & folder names stay plaintext in the cloud (only contents are encrypted as `enc:v1:...`).
- Text sent to the **AI Assistant** leaves your device as plaintext — use a local provider (Ollama) for highly sensitive content. See [AI_ASSISTANT.md](AI_ASSISTANT.md).

---

## 4. 🗄️ SQL Scratchpad & Local SQLite Execution

Run queries against local SQLite databases, format messy SQL code, and explore query results in a responsive data grid viewer:

<p align="center">
  <img src="screenshots/preview-sql-light.png" width="92%" alt="Valtera Note SQL Scratchpad Preview in Light Mode" />
</p>

---

## 5. 📑 Live Markdown Split & Inline Emoji Autocomplete

Write documentation with dual-pane real-time rendering. Type `:` to trigger inline emoji autocomplete (`:rocket:`, `:star:`, `:check:`, `:warn:`, `:db:`), or press `Ctrl+Shift+E` for the visual emoji picker modal:

<p align="center">
  <img src="screenshots/preview-hero-light.png" width="92%" alt="Valtera Note Markdown Split and Inline Emoji Autocomplete" />
</p>

---

## 6. ⚙️ Unified Settings Workspace & Multi-Theme (`Ctrl+,`)

A unified configuration center with a clean, elegant navigation sidebar:

- **Supabase Cloud Sync**: Credentials → Table Status → Account, with numbered setup steps, the official SQL script (strict RLS), and 1-click auto-setup.
- **AI Assistant**: provider (Claude / OpenAI-compatible / Ollama), API key, and model with an automatic model list fetched from the provider.
- **Appearance & Theme (Dark / Light / System)**: 6 coding palettes (*Valtera Slate*, *Tokyo Night*, *Dracula*, *Forest Emerald*, *Nordic Frost*, *GitHub Light*) with a live CodeMirror preview, plus a **configurable display timezone** (24-hour format).
- **Editor Typography Preferences**: dynamic font size, coding fonts (*JetBrains Mono, Fira Code, Cascadia Code, Menlo*), tab indent size, and auto-save delay.
- **About & Updates**: system information and a 1-click release checker.

<p align="center">
  <img src="screenshots/preview-settings-light.png" width="92%" alt="Valtera Note Unified Settings Workspace" />
</p>

---

## 7. 🌐 Interactive Feature Documentation & Showcase Page

Valtera Note includes a dedicated, responsive feature showcase page located at [`docs/index.html`](index.html):

<p align="center">
  <img src="screenshots/preview-showcase-light.png" width="92%" alt="Valtera Note Interactive Feature Showcase Page" />
</p>

---

## 📸 Automated Screenshot Capture

Screenshots are automatically captured in high-resolution Light Mode using Playwright:

```bash
node scripts/capture-light-screenshots.mjs
```

Output images are saved to `docs/screenshots/` at 2x device scale for high-DPI displays.
