use rusqlite::limits::Limit;
use rusqlite::{Connection, OpenFlags};
use std::time::Instant;
use tauri::AppHandle;
use crate::db::DatabaseManager;
use crate::models::SqlResultDto;
use crate::services::path_guard;

/// DB internal aplikasi selalu boleh diinspeksi; DB lain harus dipilih
/// pengguna (dialog / drag-drop).
fn ensure_db_allowed(app: &AppHandle, db_path: &str) -> Result<(), String> {
    let is_internal = DatabaseManager::get_db_path()
        .ok()
        .and_then(|internal| Some((dunce::canonicalize(internal).ok()?, dunce::canonicalize(db_path).ok()?)))
        .is_some_and(|(a, b)| a == b);
    if is_internal {
        Ok(())
    } else {
        path_guard::ensure_file(app, db_path)
    }
}

/// Read-only, tanpa URI filename (path yang dicek = file yang dibuka), dan
/// tanpa ATTACH / VACUUM INTO agar query tidak bisa menyentuh file lain.
fn open_readonly(db_path: &str) -> Result<Connection, String> {
    let conn = Connection::open_with_flags(db_path, OpenFlags::SQLITE_OPEN_READ_ONLY)
        .map_err(|e| e.to_string())?;
    conn.set_limit(Limit::SQLITE_LIMIT_ATTACHED, 0);
    Ok(conn)
}

#[tauri::command]
pub async fn execute_sqlite_query(
    app: AppHandle,
    db_path: String,
    query: String,
    limit: Option<usize>,
) -> Result<SqlResultDto, String> {
    ensure_db_allowed(&app, &db_path)?;
    tokio::task::spawn_blocking(move || {
        let start_time = Instant::now();
        let conn = open_readonly(&db_path)?;

        let max_rows = limit.unwrap_or(500);
        let mut stmt = conn.prepare(&query).map_err(|e| e.to_string())?;
        
        let column_count = stmt.column_count();
        let mut columns = Vec::new();
        for i in 0..column_count {
            columns.push(stmt.column_name(i).unwrap_or("?").to_string());
        }

        let mut rows: Vec<Vec<serde_json::Value>> = Vec::new();
        let mut query_rows = stmt.query([]).map_err(|e| e.to_string())?;

        while let Some(row) = query_rows.next().map_err(|e| e.to_string())? {
            if rows.len() >= max_rows {
                break;
            }

            let mut row_values = Vec::new();
            for i in 0..column_count {
                let val_ref = row.get_ref(i).map_err(|e| e.to_string())?;
                let json_val = match val_ref {
                    rusqlite::types::ValueRef::Null => serde_json::Value::Null,
                    rusqlite::types::ValueRef::Integer(i) => serde_json::Value::from(i),
                    rusqlite::types::ValueRef::Real(r) => serde_json::Value::from(r),
                    rusqlite::types::ValueRef::Text(t) => serde_json::Value::from(String::from_utf8_lossy(t).into_owned()),
                    rusqlite::types::ValueRef::Blob(b) => serde_json::Value::from(format!("<BLOB {} bytes>", b.len())),
                };
                row_values.push(json_val);
            }
            rows.push(row_values);
        }

        let duration_ms = start_time.elapsed().as_millis() as u64;
        let affected_rows = rows.len();

        Ok(SqlResultDto {
            success: true,
            columns,
            rows,
            affected_rows,
            duration_ms,
            error_message: None,
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn format_sql_query(query: String) -> Result<String, String> {
    // Lightweight SQL beautifier (keyword capitalization and clean indents)
    let keywords = [
        "SELECT", "FROM", "WHERE", "GROUP BY", "ORDER BY", "HAVING", "LIMIT",
        "INSERT INTO", "VALUES", "UPDATE", "SET", "DELETE FROM", "JOIN", 
        "LEFT JOIN", "RIGHT JOIN", "INNER JOIN", "OUTER JOIN", "ON", "AND", "OR",
        "CREATE TABLE", "ALTER TABLE", "DROP TABLE", "PRIMARY KEY", "FOREIGN KEY",
        "UNION", "UNION ALL", "DISTINCT", "AS", "IN", "IS NULL", "IS NOT NULL"
    ];

    let mut formatted = query;
    for kw in keywords {
        let pattern = format!("(?i)\\b{}\\b", kw);
        if let Ok(re) = regex::Regex::new(&pattern) {
            formatted = re.replace_all(&formatted, kw).to_string();
        }
    }

    Ok(formatted)
}

#[tauri::command]
pub async fn inspect_sqlite_tables(
    app: AppHandle,
    db_path: String,
) -> Result<Vec<crate::models::TableSummaryDto>, String> {
    ensure_db_allowed(&app, &db_path)?;
    tokio::task::spawn_blocking(move || {
        let conn = open_readonly(&db_path)?;

        let mut stmt = conn.prepare(
            "SELECT name, type FROM sqlite_master WHERE type IN ('table', 'view') AND name NOT LIKE 'sqlite_%' ORDER BY name"
        ).map_err(|e| e.to_string())?;

        let table_rows = stmt.query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
        }).map_err(|e| e.to_string())?;

        let mut summaries = Vec::new();
        for item in table_rows {
            let (name, table_type) = item.map_err(|e| e.to_string())?;

            // Fetch columns via PRAGMA table_info
            let pragma_sql = format!("PRAGMA table_info(\"{}\")", name.replace('"', "\"\""));
            let mut pragma_stmt = conn.prepare(&pragma_sql).map_err(|e| e.to_string())?;
            let columns = pragma_stmt.query_map([], |r| {
                Ok(crate::models::TableColumnDto {
                    cid: r.get(0)?,
                    name: r.get(1)?,
                    col_type: r.get(2)?,
                    notnull: r.get::<_, i64>(3)? != 0,
                    dflt_value: r.get(4)?,
                    pk: r.get::<_, i64>(5)? != 0,
                })
            }).map_err(|e| e.to_string())?
            .filter_map(Result::ok)
            .collect();

            // Count rows
            let count_sql = format!("SELECT COUNT(*) FROM \"{}\"", name.replace('"', "\"\""));
            let total_rows: usize = conn.query_row(&count_sql, [], |r| r.get(0)).unwrap_or(0);

            summaries.push(crate::models::TableSummaryDto {
                name,
                table_type,
                total_rows,
                columns,
            });
        }

        Ok(summaries)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn get_internal_db_path() -> Result<String, String> {
    Ok(DatabaseManager::get_db_path()?.to_string_lossy().into_owned())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn readonly_conn_cannot_reach_other_files() {
        let dir = std::env::temp_dir().join(format!("valtera-sqlguard-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let db = dir.join("a.db");
        Connection::open(&db).unwrap().execute_batch("CREATE TABLE t(x);").unwrap();

        let conn = open_readonly(db.to_str().unwrap()).unwrap();
        let other = dir.join("b.db");
        let attach = format!("ATTACH DATABASE '{}' AS o", other.display());
        assert!(conn.execute_batch(&attach).is_err());
        let vacuum = format!("VACUUM INTO '{}'", other.display());
        assert!(conn.execute_batch(&vacuum).is_err());
        assert!(!other.exists());
        let _ = std::fs::remove_dir_all(&dir);
    }
}
