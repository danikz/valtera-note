# AI Development & Prompting Guide — Valtera Note

This guide provides structured instructions, modular milestones, and ready-to-use prompt templates for AI agents to develop **Valtera Note** with Appwrite integration step-by-step.

---

## 1. AI Implementation Principles
1. **Low-Memory First**: Never introduce heavy libraries. Offload network sync and heavy calculations to Rust.
2. **Local-First & Offline Resilience**: The app must operate perfectly even without an internet connection or Appwrite backend configured.
3. **Strict IPC Contracts**: Rust backend commands and Frontend TypeScript types must match 1:1.
4. **No Unsanitized HTML**: All Markdown preview rendering must pass through DOMPurify.

---

## 2. Milestone Breakdown & Prompt Blueprints

### 🚀 Milestone 1: Project Initialization & Tauri Scaffold
**Goal**: Initialize Tauri v2 + Svelte 5 + Tailwind CSS v4 + basic window configuration.

```markdown
### Prompt for AI:
"Initialize the Valtera Note project structure according to docs/ARCHITECTURE.md.
1. Configure `src-tauri/Cargo.toml` with `tauri v2`, `serde`, `serde_json`, `tokio`, `rusqlite`, `encoding_rs`, `reqwest` (with rustls), and `notify`.
2. Configure `package.json` with Svelte 5, Vite, TypeScript, Tailwind CSS v4, and `@codemirror/view`, `@codemirror/state`.
3. Create `src-tauri/tauri.conf.json` with a minimalist frameless window supporting Linux and Windows.
4. Verify the dev server builds cleanly."
```

---

### 🚀 Milestone 2: Native File I/O & Encoding Engine (Rust Core)
**Goal**: Implement Rust services for high-speed file reading/writing, encoding detection, and IPC handlers.

```markdown
### Prompt for AI:
"Implement the Native File I/O service and Tauri commands in `src-tauri/src/services/fs_service.rs` and `src-tauri/src/commands/fs.rs`:
1. Use `encoding_rs` to detect file encoding (UTF-8, UTF-16, ASCII) and line endings (LF vs CRLF).
2. Create `read_file_content` and atomic `write_file_content` commands.
3. Implement TypeScript IPC bindings in `src/services/ipcFs.ts`."
```

---

### 🚀 Milestone 3: Local SQLite Cache & Session Recovery
**Goal**: Implement SQLite schema from `docs/DATABASE.md` using `rusqlite`.

```markdown
### Prompt for AI:
"Implement the local database layer for Valtera Note based on `docs/DATABASE.md` and `docs/SCHEMA.dbml`:
1. In `src-tauri/src/db/`, create database connection manager that initializes `valtera_note.db` with WAL mode.
2. Run migrations to create `workspaces`, `documents`, `tabs_state`, `snippets`, `app_settings`, and `sql_history`.
3. Implement session persistence to restore open tabs, active document, and cursor positions."
```

---

### 🚀 Milestone 4: CodeMirror 6 Editor & Tab Buffer Manager
**Goal**: Build the primary editor UI with multi-tab support and instant response.

```markdown
### Prompt for AI:
"Build the frontend Editor and Tab management UI in `src/components/`:
1. Create `Tabs/TabBar.svelte` supporting multiple open tabs, close button, dirty dot indicator, and click to switch.
2. Create `Editor/CodeEditor.svelte` using CodeMirror 6 with line numbers, bracket matching, and themes.
3. Hook into `tabStore.svelte.ts` (Svelte 5 runes) to manage buffer changes and trigger non-blocking autosave."
```

---

### 🚀 Milestone 5: Markdown Viewer & SQL Scratchpad
**Goal**: Build synchronized side-by-side Markdown editor & SQL execution runner.

```markdown
### Prompt for AI:
"Implement the Markdown Viewer and SQL Scratchpad modules:
1. In `src/components/Viewer/MarkdownViewer.svelte`, use `markdown-it` + `DOMPurify` for GFM rendering with split-scroll sync.
2. In `src/components/Editor/extensions/sql.ts`, add `@codemirror/lang-sql` for dialect highlighting and formatting.
3. In `src/components/Viewer/SqlResultsViewer.svelte`, add a virtualized table grid for local SQLite query results."
```

---

### 🚀 Milestone 6: Appwrite Open-Source Sync Engine
**Goal**: Implement Appwrite authentication and bidirectional background cloud sync in Rust.

```markdown
### Prompt for AI:
"Implement the Appwrite Sync Engine according to `docs/APPWRITE_SETUP.md` and `docs/ARCHITECTURE.md`:
1. In `src-tauri/src/appwrite/`, implement an asynchronous HTTP client using `reqwest` for Appwrite Account & Databases REST API.
2. Implement Tauri commands in `src-tauri/src/commands/appwrite.rs`:
   - `configure_appwrite(endpoint, project_id)`
   - `appwrite_login(email, password)` / `appwrite_register` / `appwrite_logout`
   - `appwrite_trigger_sync()`
3. In `src-tauri/src/services/sync_service.rs`, implement background sync logic that pushes `sync_status = 'pending'` documents/snippets and pulls remote changes with Last-Write-Wins conflict resolution.
4. In `src/components/Sync/SyncModal.svelte`, create the settings UI to configure Appwrite endpoint, login, and show sync status indicator."
```

---

### 🚀 Milestone 7: Cross-Platform Packaging & RAM Benchmarks
**Goal**: Build Linux and Windows packages and verify memory consumption under 60MB.

```markdown
### Prompt for AI:
"Configure packaging and verification scripts:
1. Set up GitHub Actions workflow `.github/workflows/build.yml` to compile:
   - Windows: NSIS installer (`.exe`) and Portable Zip
   - Linux: AppImage and `.deb`
2. Write a verification script to measure cold startup time (< 250ms) and idle RAM (< 45MB)."
```
