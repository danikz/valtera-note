use rusqlite::{params, Connection, Result};
use std::fs;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use crate::models::{SnippetDto, TabStateDto};

pub struct DatabaseManager {
    conn: Arc<Mutex<Connection>>,
}

impl DatabaseManager {
    pub fn init() -> Result<Self, String> {
        let db_path = Self::get_db_path()?;
        
        if let Some(parent) = db_path.parent() {
            fs::create_dir_all(parent).map_err(|e| e.to_string())?;
        }

        let conn = Connection::open(&db_path).map_err(|e| e.to_string())?;
        
        // Optimize SQLite performance & concurrency
        conn.execute_batch("
            PRAGMA journal_mode = WAL;
            PRAGMA synchronous = NORMAL;
            PRAGMA foreign_keys = ON;
            PRAGMA temp_store = MEMORY;
        ").map_err(|e| e.to_string())?;

        let db = DatabaseManager {
            conn: Arc::new(Mutex::new(conn)),
        };

        db.run_migrations()?;
        Ok(db)
    }

    fn get_db_path() -> Result<PathBuf, String> {
        let config_dir = dirs::config_dir()
            .or_else(|| dirs::data_local_dir())
            .ok_or_else(|| "Could not determine local data directory".to_string())?;
        Ok(config_dir.join("valtera-note").join("valtera_note.db"))
    }

    fn run_migrations(&self) -> Result<(), String> {
        let conn = self.conn.lock().map_err(|e| e.to_string())?;
        
        conn.execute_batch("
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

            CREATE TABLE IF NOT EXISTS app_settings (
                key TEXT PRIMARY KEY,
                value_json TEXT NOT NULL,
                is_synced INTEGER DEFAULT 0,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );
        ").map_err(|e| e.to_string())?;

        Ok(())
    }

    pub fn save_tabs_state(&self, tabs: &[TabStateDto]) -> Result<(), String> {
        let mut conn = self.conn.lock().map_err(|e| e.to_string())?;
        let tx = conn.transaction().map_err(|e| e.to_string())?;

        tx.execute("DELETE FROM tabs_state WHERE session_id = 'default'", []).map_err(|e| e.to_string())?;

        for (index, tab) in tabs.iter().enumerate() {
            tx.execute(
                "INSERT INTO tabs_state (
                    session_id, tab_order, is_active, title, file_path, 
                    file_extension, content, cursor_line, cursor_col, split_mode, is_dirty
                ) VALUES ('default', ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
                params![
                    index as i64,
                    tab.is_active as i64,
                    tab.title,
                    tab.file_path,
                    tab.file_extension,
                    tab.content,
                    tab.cursor_line as i64,
                    tab.cursor_col as i64,
                    tab.split_mode,
                    tab.is_dirty as i64,
                ],
            ).map_err(|e| e.to_string())?;
        }

        tx.commit().map_err(|e| e.to_string())?;
        Ok(())
    }

    pub fn load_tabs_state(&self) -> Result<Vec<TabStateDto>, String> {
        let conn = self.conn.lock().map_err(|e| e.to_string())?;
        let mut stmt = conn.prepare("
            SELECT id, document_id, file_path, title, file_extension, content, 
                   is_active, is_dirty, cursor_line, cursor_col, split_mode 
            FROM tabs_state 
            WHERE session_id = 'default' 
            ORDER BY tab_order ASC
        ").map_err(|e| e.to_string())?;

        let rows = stmt.query_map([], |row| {
            let file_path: Option<String> = row.get(2)?;
            let is_scratchpad = file_path.is_none();
            Ok(TabStateDto {
                id: row.get(0)?,
                document_id: row.get(1)?,
                file_path,
                title: row.get(3)?,
                file_extension: row.get(4)?,
                content: row.get(5)?,
                is_active: row.get::<_, i64>(6)? != 0,
                is_dirty: row.get::<_, i64>(7)? != 0,
                is_scratchpad,
                cursor_line: row.get::<_, i64>(8)? as usize,
                cursor_col: row.get::<_, i64>(9)? as usize,
                split_mode: row.get(10)?,
            })
        }).map_err(|e| e.to_string())?;

        let mut tabs = Vec::new();
        for row in rows {
            tabs.push(row.map_err(|e| e.to_string())?);
        }

        Ok(tabs)
    }

    pub fn get_setting(&self, key: &str) -> Result<Option<String>, String> {
        let conn = self.conn.lock().map_err(|e| e.to_string())?;
        let mut stmt = conn.prepare("SELECT value_json FROM app_settings WHERE key = ?1").map_err(|e| e.to_string())?;
        let mut rows = stmt.query(params![key]).map_err(|e| e.to_string())?;

        if let Some(row) = rows.next().map_err(|e| e.to_string())? {
            let val: String = row.get(0).map_err(|e| e.to_string())?;
            Ok(Some(val))
        } else {
            Ok(None)
        }
    }

    pub fn set_setting(&self, key: &str, value_json: &str) -> Result<(), String> {
        let conn = self.conn.lock().map_err(|e| e.to_string())?;
        conn.execute(
            "INSERT INTO app_settings (key, value_json, updated_at) 
             VALUES (?1, ?2, CURRENT_TIMESTAMP) 
             ON CONFLICT(key) DO UPDATE SET value_json = ?2, updated_at = CURRENT_TIMESTAMP",
            params![key, value_json],
        ).map_err(|e| e.to_string())?;
        Ok(())
    }

    pub fn list_snippets(&self) -> Result<Vec<SnippetDto>, String> {
        let conn = self.conn.lock().map_err(|e| e.to_string())?;
        let mut stmt = conn.prepare("
            SELECT id, appwrite_id, title, language, category, content, tags, is_favorite 
            FROM snippets 
            WHERE is_deleted = 0 
            ORDER BY is_favorite DESC, title ASC
        ").map_err(|e| e.to_string())?;

        let rows = stmt.query_map([], |row| {
            Ok(SnippetDto {
                id: row.get(0)?,
                appwrite_id: row.get(1)?,
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
