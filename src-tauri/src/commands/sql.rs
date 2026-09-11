use rusqlite::Connection;
use std::time::Instant;
use crate::models::SqlResultDto;

#[tauri::command]
pub async fn execute_sqlite_query(
    db_path: String,
    query: String,
    limit: Option<usize>,
) -> Result<SqlResultDto, String> {
    tokio::task::spawn_blocking(move || {
        let start_time = Instant::now();
        let conn = Connection::open_with_flags(
            &db_path,
            rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY | rusqlite::OpenFlags::SQLITE_OPEN_URI,
        ).map_err(|e| e.to_string())?;

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
pub async fn inspect_sqlite_tables(db_path: String) -> Result<Vec<crate::models::TableSummaryDto>, String> {
    tokio::task::spawn_blocking(move || {
        let conn = Connection::open_with_flags(
            &db_path,
            rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY | rusqlite::OpenFlags::SQLITE_OPEN_URI,
        ).map_err(|e| e.to_string())?;

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
    let config_dir = dirs::config_dir()
        .or_else(|| dirs::data_local_dir())
        .unwrap_or_else(|| std::env::temp_dir());
    let path = config_dir.join("valtera-note").join("valtera_note.db");
    Ok(path.to_string_lossy().into_owned())
}
