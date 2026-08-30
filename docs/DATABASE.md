# Database & Persistence Specification — Valtera Note

## 1. Storage Strategy & Architecture
To achieve sub-50MB RAM footprint, instant startup, and seamless open-source cloud sync:
1. **Local-First Always**: The app works 100% offline immediately using embedded **SQLite 3** (`rusqlite`).
2. **Appwrite Cloud Sync Layer**:
   - Physical filesystem files (`.txt`, `.md`, `.sql` opened from disk) remain on the local disk.
   - Cloud notes, scratchpads, snippets, workspaces, and user settings sync bidirectionally with a self-hosted or cloud Appwrite instance.
   - Sync tracking uses `appwrite_id`, `sync_status` (`local`, `pending`, `synced`, `conflict`), `is_deleted` (soft-delete), and `synced_at`.
3. **Database Engine**: Embedded **SQLite 3** in Rust with `WAL` mode and `PRAGMA synchronous = NORMAL`.

---

## 2. SQLite Database DDL (Schema with Appwrite Sync)

```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA foreign_keys = ON;
PRAGMA temp_store = MEMORY;

-- 1. Workspaces / Folder Projects
CREATE TABLE IF NOT EXISTS workspaces (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    appwrite_id TEXT UNIQUE,
    name TEXT NOT NULL,
    root_path TEXT UNIQUE,
    icon TEXT DEFAULT 'folder',
    settings_json TEXT,
    sync_status TEXT DEFAULT 'synced',
    is_deleted INTEGER DEFAULT 0,
    synced_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_opened_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 2. Document Registry & Scratchpad Cache
CREATE TABLE IF NOT EXISTS documents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    appwrite_id TEXT UNIQUE,
    workspace_id INTEGER REFERENCES workspaces(id) ON DELETE SET NULL,
    file_path TEXT UNIQUE,
    file_name TEXT NOT NULL DEFAULT 'Untitled',
    file_extension TEXT DEFAULT 'txt',
    file_hash TEXT,
    encoding TEXT DEFAULT 'UTF-8',
    line_ending TEXT DEFAULT 'LF',
    is_pinned INTEGER DEFAULT 0,
    is_scratchpad INTEGER DEFAULT 0,
    scratchpad_content TEXT,
    sync_status TEXT DEFAULT 'local', -- local, pending, synced, conflict, error
    is_deleted INTEGER DEFAULT 0,
    synced_at DATETIME,
    last_opened_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_documents_path ON documents(file_path);
CREATE INDEX IF NOT EXISTS idx_documents_sync ON documents(sync_status, is_deleted);
CREATE INDEX IF NOT EXISTS idx_documents_appwrite ON documents(appwrite_id);

-- 3. Tabs State & Crash Recovery Buffer
CREATE TABLE IF NOT EXISTS tabs_state (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER REFERENCES documents(id) ON DELETE CASCADE,
    session_id TEXT DEFAULT 'default',
    tab_order INTEGER NOT NULL DEFAULT 0,
    is_active INTEGER DEFAULT 0,
    cursor_line INTEGER DEFAULT 1,
    cursor_col INTEGER DEFAULT 1,
    scroll_top REAL DEFAULT 0.0,
    split_mode TEXT DEFAULT 'none',
    is_dirty INTEGER DEFAULT 0,
    unsaved_buffer TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tabs_session ON tabs_state(session_id, tab_order);

-- 4. Code & Query Snippets
CREATE TABLE IF NOT EXISTS snippets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    appwrite_id TEXT UNIQUE,
    title TEXT NOT NULL,
    language TEXT NOT NULL DEFAULT 'sql',
    category TEXT DEFAULT 'general',
    content TEXT NOT NULL,
    tags TEXT,
    is_favorite INTEGER DEFAULT 0,
    sync_status TEXT DEFAULT 'local',
    is_deleted INTEGER DEFAULT 0,
    synced_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 5. Key-Value App Settings & Appwrite Config
CREATE TABLE IF NOT EXISTS app_settings (
    key TEXT PRIMARY KEY,
    value_json TEXT NOT NULL,
    is_synced INTEGER DEFAULT 0,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 6. SQL Query History (Local Only)
CREATE TABLE IF NOT EXISTS sql_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    query_text TEXT NOT NULL,
    dialect TEXT DEFAULT 'sqlite',
    execution_duration_ms INTEGER,
    row_count INTEGER,
    status TEXT DEFAULT 'draft',
    error_message TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sql_history_created ON sql_history(created_at DESC);
```

---

## 3. Appwrite Sync Flow & Conflict Resolution
- **Sync Trigger**: Debounced 3 seconds after user stops typing, on tab switch, or manual click on sync icon.
- **Conflict Resolution Strategy**: **Timestamp-based Last-Write-Wins (LWW)** with a duplicate conflict backup (`Untitled (Conflict from Device X).md`) if simultaneous edits occur offline.
- **Payload Compression**: Text contents synced over HTTPS are gzip/brotli compressed automatically.
