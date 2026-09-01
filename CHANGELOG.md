# 📜 Changelog

All notable changes to the **Valtera Note** desktop application will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
