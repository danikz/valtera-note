use rusqlite::{params, Connection};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use crate::models::{SessionStateDto, TabStateDto, SnippetDto};

pub struct DatabaseManager {
    conn: Arc<Mutex<Connection>>,
}

impl DatabaseManager {
    pub fn init() -> Result<Self, String> {
        let conn = match Self::open_db_connection() {
            Ok(c) => c,
            Err(e) => {
                eprintln!("Warning: Failed to open disk database: {}, falling back to in-memory DB", e);
                Connection::open_in_memory().map_err(|err| err.to_string())?
            }
        };

        // Optimize SQLite Performance & Concurrency (WAL Mode + busy_timeout)
        let _ = conn.execute_batch("
            PRAGMA journal_mode = WAL;
            PRAGMA synchronous = NORMAL;
            PRAGMA foreign_keys = ON;
            PRAGMA busy_timeout = 5000;
            PRAGMA temp_store = MEMORY;
            PRAGMA cache_size = -4000;
        ");

        let db = Self {
            conn: Arc::new(Mutex::new(conn)),
        };

        let _ = db.run_migrations();
        Ok(db)
    }

    pub fn init_fallback() -> Self {
        let conn = Connection::open_in_memory().unwrap_or_else(|_| {
            panic!("Critical: Failed to create in-memory database");
        });
        let db = Self {
            conn: Arc::new(Mutex::new(conn)),
        };
        let _ = db.run_migrations();
        db
    }

    fn open_db_connection() -> Result<Connection, String> {
        let db_path = Self::get_db_path()?;
        if let Some(parent) = db_path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        Connection::open(&db_path).map_err(|e| e.to_string())
    }

    fn get_db_path() -> Result<PathBuf, String> {
        let config_dir = dirs::config_dir()
            .or_else(|| dirs::data_local_dir())
            .unwrap_or_else(|| std::env::temp_dir());
        Ok(config_dir.join("valtera-note").join("valtera_note.db"))
    }

    fn run_migrations(&self) -> Result<(), String> {
        let conn = self.conn.lock().map_err(|e| e.to_string())?;
        
        conn.execute_batch("
            CREATE TABLE IF NOT EXISTS workspaces (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                supabase_id TEXT UNIQUE,
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

            CREATE TABLE IF NOT EXISTS documents (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                supabase_id TEXT UNIQUE,
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
                sync_status TEXT DEFAULT 'local',
                is_deleted INTEGER DEFAULT 0,
                synced_at DATETIME,
                last_opened_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS tabs_state (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                document_id INTEGER REFERENCES documents(id) ON DELETE CASCADE,
                supabase_id TEXT,
                session_id TEXT DEFAULT 'default',
                tab_order INTEGER NOT NULL DEFAULT 0,
                is_active INTEGER DEFAULT 0,
                title TEXT NOT NULL DEFAULT 'Untitled',
                file_path TEXT,
                file_extension TEXT DEFAULT 'txt',
                content TEXT DEFAULT '',
                cursor_line INTEGER DEFAULT 1,
                cursor_col INTEGER DEFAULT 1,
                split_mode TEXT DEFAULT 'none',
                is_dirty INTEGER DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS snippets (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                supabase_id TEXT UNIQUE,
                title TEXT NOT NULL,
                language TEXT NOT NULL DEFAULT 'sql',
                category TEXT NOT NULL DEFAULT 'general',
                content TEXT NOT NULL,
                tags TEXT,
                is_favorite INTEGER DEFAULT 0,
                is_deleted INTEGER DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS app_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );
        ").map_err(|e| e.to_string())?;

        // Safely add supabase_id and folder columns if table was created previously without them
        let _ = conn.execute("ALTER TABLE tabs_state ADD COLUMN supabase_id TEXT", []);
        let _ = conn.execute("ALTER TABLE tabs_state ADD COLUMN folder TEXT", []);

        Ok(())
    }

    pub fn get_setting(&self, key: &str) -> Result<Option<String>, String> {
        let conn = self.conn.lock().map_err(|e| e.to_string())?;
        let mut stmt = conn.prepare("SELECT value FROM app_settings WHERE key = ?").map_err(|e| e.to_string())?;
        let mut rows = stmt.query(params![key]).map_err(|e| e.to_string())?;

        if let Some(row) = rows.next().map_err(|e| e.to_string())? {
            let val: String = row.get(0).map_err(|e| e.to_string())?;
            Ok(Some(val))
        } else {
            Ok(None)
        }
    }

    pub fn set_setting(&self, key: &str, value: &str) -> Result<(), String> {
        let conn = self.conn.lock().map_err(|e| e.to_string())?;
        conn.execute("
            INSERT INTO app_settings (key, value, updated_at) 
            VALUES (?1, ?2, CURRENT_TIMESTAMP)
            ON CONFLICT(key) DO UPDATE SET value = ?2, updated_at = CURRENT_TIMESTAMP
        ", params![key, value]).map_err(|e| e.to_string())?;
        Ok(())
    }

    pub fn save_session_tabs(&self, tabs: &[TabStateDto]) -> Result<(), String> {
        let mut conn = self.conn.lock().map_err(|e| e.to_string())?;
        let tx = conn.transaction().map_err(|e| e.to_string())?;

        tx.execute("DELETE FROM tabs_state WHERE session_id = 'default'", []).map_err(|e| e.to_string())?;

        for (idx, tab) in tabs.iter().enumerate() {
            tx.execute("
                INSERT INTO tabs_state (
                    session_id, tab_order, is_active, supabase_id, title, file_path, folder, 
                    file_extension, content, cursor_line, cursor_col, split_mode, is_dirty
                ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13)
            ", params![
                "default",
                idx as i64,
                if tab.is_active { 1 } else { 0 },
                &tab.supabase_id,
                &tab.title,
                &tab.file_path,
                &tab.folder,
                &tab.file_extension,
                &tab.content,
                tab.cursor_line as i64,
                tab.cursor_col as i64,
                &tab.split_mode,
                if tab.is_dirty { 1 } else { 0 },
            ]).map_err(|e| e.to_string())?;
        }

        tx.commit().map_err(|e| e.to_string())?;
        Ok(())
    }

    pub fn load_session_tabs(&self) -> Result<SessionStateDto, String> {
        let conn = self.conn.lock().map_err(|e| e.to_string())?;
        let mut stmt = conn.prepare("
            SELECT id, document_id, supabase_id, file_path, folder, title, file_extension, content, 
                   is_active, is_dirty, cursor_line, cursor_col, split_mode 
            FROM tabs_state 
            WHERE session_id = 'default' 
            ORDER BY tab_order ASC
        ").map_err(|e| e.to_string())?;

        let rows = stmt.query_map([], |row| {
            Ok(TabStateDto {
                id: row.get(0)?,
                document_id: row.get(1)?,
                supabase_id: row.get(2)?,
                file_path: row.get(3)?,
                folder: row.get(4)?,
                title: row.get(5)?,
                file_extension: row.get(6)?,
                content: row.get(7)?,
                is_active: row.get::<_, i64>(8)? != 0,
                is_dirty: row.get::<_, i64>(9)? != 0,
                is_scratchpad: row.get::<_, Option<String>>(3)?.is_none(),
                cursor_line: row.get::<_, usize>(10)?,
                cursor_col: row.get::<_, usize>(11)?,
                split_mode: row.get::<_, String>(12)?,
            })
        }).map_err(|e| e.to_string())?;

        let mut tabs = Vec::new();
        let mut active_tab_index = 0;

        for (idx, r) in rows.enumerate() {
            let tab = r.map_err(|e| e.to_string())?;
            if tab.is_active {
                active_tab_index = idx;
            }
            tabs.push(tab);
        }

        Ok(SessionStateDto {
            tabs,
            active_tab_index,
        })
    }

    pub fn list_snippets(&self) -> Result<Vec<SnippetDto>, String> {
        let conn = self.conn.lock().map_err(|e| e.to_string())?;
        let mut stmt = conn.prepare("
            SELECT id, supabase_id, title, language, category, content, tags, is_favorite 
            FROM snippets 
            WHERE is_deleted = 0 
            ORDER BY is_favorite DESC, title ASC
        ").map_err(|e| e.to_string())?;

        let rows = stmt.query_map([], |row| {
            Ok(SnippetDto {
                id: row.get(0)?,
                supabase_id: row.get(1)?,
                title: row.get(2)?,
                language: row.get(3)?,
                category: row.get(4)?,
                content: row.get(5)?,
                tags: row.get(6)?,
                is_favorite: row.get::<_, i64>(7)? != 0,
            })
        }).map_err(|e| e.to_string())?;

        let mut list = Vec::new();
        for r in rows {
            list.push(r.map_err(|e| e.to_string())?);
        }
        Ok(list)
    }
}
