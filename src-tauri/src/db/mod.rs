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

        // Safely add missing columns for backward compatibility
        let _ = conn.execute("ALTER TABLE tabs_state ADD COLUMN supabase_id TEXT", []);
        let _ = conn.execute("ALTER TABLE tabs_state ADD COLUMN folder TEXT", []);
        let _ = conn.execute("ALTER TABLE workspaces ADD COLUMN supabase_id TEXT", []);
        let _ = conn.execute("ALTER TABLE documents ADD COLUMN supabase_id TEXT", []);
        let _ = conn.execute("ALTER TABLE snippets ADD COLUMN supabase_id TEXT", []);

        // Ensure value column exists if legacy table exists
        let _ = conn.execute("ALTER TABLE app_settings ADD COLUMN value TEXT", []);

        // Check if legacy value_json column exists (which has NOT NULL constraint without default)
        let has_legacy_value_json: bool = {
            if let Ok(mut stmt) = conn.prepare("PRAGMA table_info(app_settings)") {
                let col_names = stmt.query_map([], |row| row.get::<_, String>(1))
                    .map(|rows| rows.filter_map(Result::ok).collect::<Vec<_>>())
                    .unwrap_or_default();
                col_names.iter().any(|c| c == "value_json")
            } else {
                false
            }
        };

        if has_legacy_value_json {
            let _ = conn.execute_batch("
                CREATE TABLE IF NOT EXISTS app_settings_temp (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL DEFAULT '',
                    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                );
                INSERT OR REPLACE INTO app_settings_temp (key, value, updated_at)
                SELECT key, COALESCE(value, value_json, ''), updated_at FROM app_settings;
                DROP TABLE app_settings;
                ALTER TABLE app_settings_temp RENAME TO app_settings;
            ");
        }

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

    /// Enkripsi semua content plaintext (tanpa prefix enc:v1:) di tabs_state & snippets.
    /// Idempoten: baris yang sudah terenkripsi dilewati. Dipakai saat set_master_password.
    pub fn migrate_content<F>(&self, encrypt: F) -> Result<(usize, usize), String>
    where
        F: Fn(&str) -> Result<String, String>,
    {
        let conn = self.conn.lock().map_err(|e| e.to_string())?;
        let mut tabs_done = 0usize;

        {
            let mut stmt = conn
                .prepare(
                    "SELECT id, content FROM tabs_state
                     WHERE content IS NOT NULL AND content NOT LIKE 'enc:v1:%'",
                )
                .map_err(|e| e.to_string())?;
            let rows: Vec<(i64, String)> = stmt
                .query_map([], |row| Ok((row.get(0)?, row.get(1)?)))
                .map_err(|e| e.to_string())?
                .filter_map(|r| r.ok())
                .collect();
            drop(stmt);
            for (id, content) in rows {
                let enc = encrypt(&content)?;
                conn.execute(
                    "UPDATE tabs_state SET content = ?1 WHERE id = ?2",
                    params![enc, id],
                )
                .map_err(|e| e.to_string())?;
                tabs_done += 1;
            }
        }

        let mut snippets_done = 0usize;
        {
            let mut stmt = conn
                .prepare(
                    "SELECT id, content FROM snippets
                     WHERE content IS NOT NULL AND content NOT LIKE 'enc:v1:%' AND is_deleted = 0",
                )
                .map_err(|e| e.to_string())?;
            let rows: Vec<(i64, String)> = stmt
                .query_map([], |row| Ok((row.get(0)?, row.get(1)?)))
                .map_err(|e| e.to_string())?
                .filter_map(|r| r.ok())
                .collect();
            drop(stmt);
            for (id, content) in rows {
                let enc = encrypt(&content)?;
                conn.execute(
                    "UPDATE snippets SET content = ?1 WHERE id = ?2",
                    params![enc, id],
                )
                .map_err(|e| e.to_string())?;
                snippets_done += 1;
            }
        }

        Ok((tabs_done, snippets_done))
    }

    /// Decrypt dengan kunci lama lalu re-encrypt dengan kunci baru (semua baris terenkripsi).
    /// Dipakai saat change_password.
    pub fn reencrypt_all<D, E>(&self, decrypt: D, encrypt: E) -> Result<(usize, usize), String>
    where
        D: Fn(&str) -> Result<String, String>,
        E: Fn(&str) -> Result<String, String>,
    {
        let conn = self.conn.lock().map_err(|e| e.to_string())?;
        let mut tabs_done = 0usize;

        {
            let mut stmt = conn
                .prepare(
                    "SELECT id, content FROM tabs_state
                     WHERE content IS NOT NULL AND content LIKE 'enc:v1:%'",
                )
                .map_err(|e| e.to_string())?;
            let rows: Vec<(i64, String)> = stmt
                .query_map([], |row| Ok((row.get(0)?, row.get(1)?)))
                .map_err(|e| e.to_string())?
                .filter_map(|r| r.ok())
                .collect();
            drop(stmt);
            for (id, content) in rows {
                let plain = decrypt(&content)?;
                let enc = encrypt(&plain)?;
                conn.execute(
                    "UPDATE tabs_state SET content = ?1 WHERE id = ?2",
                    params![enc, id],
                )
                .map_err(|e| e.to_string())?;
                tabs_done += 1;
            }
        }

        let mut snippets_done = 0usize;
        {
            let mut stmt = conn
                .prepare(
                    "SELECT id, content FROM snippets
                     WHERE content IS NOT NULL AND content LIKE 'enc:v1:%' AND is_deleted = 0",
                )
                .map_err(|e| e.to_string())?;
            let rows: Vec<(i64, String)> = stmt
                .query_map([], |row| Ok((row.get(0)?, row.get(1)?)))
                .map_err(|e| e.to_string())?
                .filter_map(|r| r.ok())
                .collect();
            drop(stmt);
            for (id, content) in rows {
                let plain = decrypt(&content)?;
                let enc = encrypt(&plain)?;
                conn.execute(
                    "UPDATE snippets SET content = ?1 WHERE id = ?2",
                    params![enc, id],
                )
                .map_err(|e| e.to_string())?;
                snippets_done += 1;
            }
        }

        Ok((tabs_done, snippets_done))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    impl DatabaseManager {
        /// Insert snippet langsung via conn (tidak ada API write snippet publik).
        fn insert_snippet(&self, content: &str, is_deleted: i64) -> i64 {
            let conn = self.conn.lock().unwrap();
            conn.execute(
                "INSERT INTO snippets (title, language, category, content, is_deleted) VALUES ('t', 'sql', 'general', ?1, ?2)",
                params![content, is_deleted],
            )
            .unwrap();
            conn.last_insert_rowid()
        }

        fn get_tab_contents(&self) -> Vec<String> {
            let conn = self.conn.lock().unwrap();
            let mut stmt = conn.prepare("SELECT content FROM tabs_state ORDER BY id").unwrap();
            stmt.query_map([], |r| r.get(0)).unwrap().filter_map(Result::ok).collect()
        }

        fn get_snippet_content(&self, id: i64) -> String {
            let conn = self.conn.lock().unwrap();
            conn.query_row("SELECT content FROM snippets WHERE id = ?1", params![id], |r| r.get(0)).unwrap()
        }
    }

    fn fake_encrypt(s: &str) -> Result<String, String> {
        Ok(format!("enc:v1:FAKE({})", s))
    }

    fn fake_decrypt(s: &str) -> Result<String, String> {
        let inner = s.strip_prefix("enc:v1:FAKE(").ok_or("bad")?;
        let inner = inner.strip_suffix(')').ok_or("bad")?;
        Ok(inner.to_string())
    }

    fn tab_dto(title: &str, content: &str, is_active: bool) -> TabStateDto {
        TabStateDto {
            id: None,
            document_id: None,
            supabase_id: None,
            file_path: None,
            folder: None,
            title: title.into(),
            file_extension: "txt".into(),
            content: content.into(),
            is_active,
            is_dirty: false,
            is_scratchpad: true,
            cursor_line: 1,
            cursor_col: 1,
            split_mode: "editor-only".into(),
        }
    }

    #[test]
    fn migrate_content_encrypts_plaintext_and_is_idempotent() {
        let db = DatabaseManager::init_fallback();
        db.save_session_tabs(&[
            tab_dto("a", "rahasia satu", true),
            tab_dto("b", "enc:v1:SUDAH", false),
        ])
        .unwrap();
        let sid = db.insert_snippet("snippet rahasia", 0);

        let (tabs, snippets) = db.migrate_content(fake_encrypt).unwrap();
        assert_eq!((tabs, snippets), (1, 1));

        let contents = db.get_tab_contents();
        assert_eq!(contents[0], "enc:v1:FAKE(rahasia satu)");
        assert_eq!(contents[1], "enc:v1:SUDAH"); // tidak double-encrypt

        // idempoten: run kedua 0 baris
        assert_eq!(db.migrate_content(fake_encrypt).unwrap(), (0, 0));

        assert_eq!(db.get_snippet_content(sid), "enc:v1:FAKE(snippet rahasia)");
    }

    #[test]
    fn reencrypt_all_rotates_ciphertext() {
        let db = DatabaseManager::init_fallback();
        db.save_session_tabs(&[tab_dto("a", "rahasia", true)]).unwrap();
        db.migrate_content(fake_encrypt).unwrap();

        let rot_enc = |s: &str| Ok(format!("enc:v1:ROT({})", s));
        let rot_dec = |s: &str| -> Result<String, String> {
            let inner = s.strip_prefix("enc:v1:FAKE(").ok_or("bad")?;
            Ok(inner.strip_suffix(')').ok_or("bad")?.to_string())
        };

        let (tabs, snippets) = db.reencrypt_all(rot_dec, rot_enc).unwrap();
        assert_eq!((tabs, snippets), (1, 0));
        assert_eq!(db.get_tab_contents()[0], "enc:v1:ROT(rahasia)");
    }

    #[test]
    fn migrate_skips_soft_deleted_snippets() {
        let db = DatabaseManager::init_fallback();
        db.insert_snippet("terhapus", 1);
        let (tabs, snippets) = db.migrate_content(fake_encrypt).unwrap();
        assert_eq!((tabs, snippets), (0, 0));
    }
}
