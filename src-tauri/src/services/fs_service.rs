use std::fs::{self, File};
use std::io::{Read, Write};
use std::path::Path;
use sha2::{Digest, Sha256};
use crate::models::{FilePayloadDto, FileSaveResultDto};

pub struct FsService;

impl FsService {
    pub fn read_file(path_str: &str) -> Result<FilePayloadDto, String> {
        let path = Path::new(path_str);
        if !path.exists() {
            return Err(format!("File does not exist: {}", path_str));
        }

        let metadata = fs::metadata(path).map_err(|e| e.to_string())?;
        let file_size = metadata.len();
        let is_readonly = metadata.permissions().readonly();

        let file_name = path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("Untitled")
            .to_string();

        let file_extension = path
            .extension()
            .and_then(|e| e.to_str())
            .unwrap_or("txt")
            .to_lowercase();

        let mut file = File::open(path).map_err(|e| e.to_string())?;
        let mut buffer = Vec::new();
        file.read_to_end(&mut buffer).map_err(|e| e.to_string())?;

        // Detect encoding using encoding_rs
        let (encoding, content) = Self::decode_bytes(&buffer);

        // Detect line ending
        let line_ending = if content.contains("\r\n") {
            "CRLF".to_string()
        } else {
            "LF".to_string()
        };

        Ok(FilePayloadDto {
            file_path: Some(path_str.to_string()),
            file_name,
            file_extension,
            content,
            encoding,
            line_ending,
            file_size,
            is_readonly,
        })
    }

    pub fn write_file(
        path_str: &str,
        content: &str,
        line_ending: Option<String>,
    ) -> Result<FileSaveResultDto, String> {
        let path = Path::new(path_str);

        // Adjust line endings if specified
        let normalized_content = match line_ending.as_deref() {
            Some("CRLF") => content.replace("\r\n", "\n").replace('\n', "\r\n"),
            Some("LF") => content.replace("\r\n", "\n"),
            _ => content.to_string(),
        };

        // Atomic write via temporary file
        let temp_path = format!("{}.tmp_valtera", path_str);
        {
            let mut temp_file = File::create(&temp_path).map_err(|e| e.to_string())?;
            temp_file
                .write_all(normalized_content.as_bytes())
                .map_err(|e| e.to_string())?;
            temp_file.flush().map_err(|e| e.to_string())?;
        }

        // Rename temp file to target path
        fs::rename(&temp_path, path).map_err(|e| {
            let _ = fs::remove_file(&temp_path);
            e.to_string()
        })?;

        // Calculate SHA-256 hash
        let mut hasher = Sha256::new();
        hasher.update(normalized_content.as_bytes());
        let hash = format!("{:x}", hasher.finalize());

        let saved_at = chrono::Utc::now().to_rfc3339();

        Ok(FileSaveResultDto {
            success: true,
            file_path: path_str.to_string(),
            file_hash: hash,
            saved_at,
        })
    }

    fn decode_bytes(bytes: &[u8]) -> (String, String) {
        // Quick check for UTF-8
        if let Ok(utf8_str) = std::str::from_utf8(bytes) {
            return ("UTF-8".to_string(), utf8_str.to_string());
        }

        // Check BOMs
        if bytes.starts_with(&[0xEF, 0xBB, 0xBF]) {
            let (cow, _, _) = encoding_rs::UTF_8.decode(&bytes[3..]);
            return ("UTF-8 (BOM)".to_string(), cow.into_owned());
        } else if bytes.starts_with(&[0xFF, 0xFE]) {
            let (cow, _, _) = encoding_rs::UTF_16LE.decode(&bytes[2..]);
            return ("UTF-16 LE".to_string(), cow.into_owned());
        } else if bytes.starts_with(&[0xFE, 0xFF]) {
            let (cow, _, _) = encoding_rs::UTF_16BE.decode(&bytes[2..]);
            return ("UTF-16 BE".to_string(), cow.into_owned());
        }

        // Fallback to Windows-1252 / ISO-8859-1
        let (cow, _, had_errors) = encoding_rs::WINDOWS_1252.decode(bytes);
        if !had_errors {
            return ("Windows-1252".to_string(), cow.into_owned());
        }

        // Lossy UTF-8 fallback
        ("UTF-8 (Lossy)".to_string(), String::from_utf8_lossy(bytes).into_owned())
    }
}
