# Product Requirements Document (PRD) — Valtera Note

## 1. Overview & Vision
**Valtera Note** is an ultra-lightweight, lightning-fast desktop text editor, viewer, and scratchpad built for Windows and Linux. It combines the simplicity and low resource footprint of classic Notepad with modern developer-centric features: syntax highlighting, Markdown preview/viewer, SQL scratchpad/formatter, and **Open-Source Cloud Sync powered by Supabase**.

### Key Objectives
- **Memory Footprint**: Target idle RAM consumption under **40MB - 60MB** (compared to Electron-based editors consuming 400MB - 1GB+).
- **Startup Speed**: Cold startup time under **250ms**.
- **Cross-Platform**: First-class support for **Windows 10/11** and **Linux (X11 & Wayland)**.
- **Open-Source Cloud Sync (Supabase)**: Users can sync their notes, snippets, and settings to their own self-hosted Supabase instance or Supabase Cloud.
- **AI-Driven Extensibility**: Modular, type-safe architecture strictly documented so AI agents can independently build and maintain features.

---

## 2. Target Platforms & Distribution
| Platform | Target Runtime / Webview | Distribution Format |
| :--- | :--- | :--- |
| **Windows** | Windows 10/11 (64-bit, ARM64) via Microsoft Edge WebView2 | `.msi`, `.exe` (NSIS), Standalone Portable Zip |
| **Linux** | Ubuntu, Debian, Fedora, Arch via WebKitGTK 4.1 / 6.0 | `.AppImage`, `.deb`, `.rpm`, `.tar.gz` |

---

## 3. Core Personas & User Scenarios
1. **Developer / DBA on Low-Resource Machine**: Needs to quickly open a 20MB `.sql` dump or query scratchpad without freezing the machine.
2. **Technical Writer / Note Taker**: Needs a distraction-free Markdown editor with instant side-by-side rendering and multi-device sync via self-hosted Supabase.
3. **Open-Source Enthusiast & Privacy Advocate**: Wants full ownership of their cloud data by hosting their own Supabase backend via Docker.

---

## 4. Feature Specifications

### 4.1. Core Text Editing (Notepad Experience)
- **Instant Buffer**: Open single standalone files via command line (`valtera-note file.txt`) or drag-and-drop.
- **Tab & Multi-Window Management**: Seamless multi-tab interface with session restore.
- **Encoding & Line Endings**: UTF-8, UTF-16, ASCII, Windows (CRLF) and Unix (LF) line ending detection and conversion.
- **Find & Replace**: High-speed regex and plain text search with match highlights.
- **Autosave & Recovery**: Non-blocking background autosave to local cache (crash resilience).

### 4.2. Markdown Editing & Viewer Mode
- **Dual Mode**: Split-pane (Editor + Live Preview) or Pure Viewer Mode (distraction-free document reading).
- **Syntax**: CommonMark + GFM (GitHub Flavored Markdown) with code blocks, tables, task lists, and math.
- **Export**: Copy as HTML, Export to clean PDF (via webview print API).

### 4.3. SQL Scratchpad & Formatter
- **SQL Syntax Engine**: Highlighting for ANSI SQL, PostgreSQL, MySQL, SQLite, and T-SQL dialects.
- **Formatter**: Built-in fast SQL formatting / indentation.
- **Lightweight Query Runner**: Ability to open and query local `.db` / `.sqlite` files directly in a read-only scratchpad grid without launching heavy database GUIs.

### 4.4. Supabase Open-Source Sync Engine
- **Local-First**: Works 100% offline out-of-the-box using local SQLite.
- **Self-Hosted / Cloud Supabase**: Users input their custom Supabase Project URL and Anon Key in settings.
- **Bi-directional Sync**: Automatically syncs notes, snippets, workspaces, and user settings in the background using Rust async workers.
- **Conflict Resolution**: Timestamp-based Last-Write-Wins (LWW) with automated conflict file backup.

---

## 5. Non-Functional Requirements (NFR)

| Metric | Target Standard | Measurement Method |
| :--- | :--- | :--- |
| **Idle RAM (1 empty tab)** | `< 45 MB` | Task Manager / `htop` (RSS memory) |
| **Active RAM (5 tabs + MD Preview + Sync)** | `< 80 MB` | Task Manager / `htop` |
| **Cold Startup Time** | `< 250 ms` | System tracing / benchmark script |
| **Binary Package Size** | `< 15 MB` (installer) | Tauri release artifact |
| **File Load Time (10MB text)** | `< 100 ms` | Rust stream buffer |

---

## 6. AI Agent Development Roadmap
1. **Milestone 1**: Tauri v2 Scaffold + Rust FS IPC + CodeMirror 6 minimalist editor.
2. **Milestone 2**: Tab management + Local SQLite session persistence + Autosave.
3. **Milestone 3**: Markdown engine + Split Viewer + GFM rendering.
4. **Milestone 4**: SQL syntax dialect + Formatter + SQLite scratchpad viewer.
5. **Milestone 5**: Appwrite Client in Rust (Auth, Database collections sync, conflict handling).
6. **Milestone 6**: UI Sync Indicator, Settings Modal, and Cross-Platform Packaging.
