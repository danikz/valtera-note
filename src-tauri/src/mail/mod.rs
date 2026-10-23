// Inbox email via IMAP — baca + hapus saja (tidak ada kirim/balas).
// Membaca memakai EXAMINE (read-only) dan BODY.PEEK, sehingga membuka email
// di aplikasi tidak mengubah apa pun di server (status "belum dibaca" utuh).
// Satu-satunya operasi tulis adalah hapus: email dipindah ke folder Sampah,
// atau dihapus permanen hanya bila pengguna mengonfirmasinya.
//
// Satu sesi IMAP di-cache per akun supaya berpindah pesan tidak login ulang;
// sesi basi (diputus server karena idle) otomatis diganti sekali.

use std::collections::{HashMap, HashSet};
use std::sync::Arc;
use std::time::Duration;

use async_imap::types::{Fetch, Flag, Name, NameAttribute};
use async_imap::Session;
use base64::Engine;
use futures_util::TryStreamExt;
use mail_parser::{Address, MessageParser, MimeHeaders, PartType};
use serde::{Deserialize, Serialize};
use tokio::net::TcpStream;
use tokio::sync::Mutex;
use tokio::time::timeout;
use tokio_rustls::client::TlsStream;
use tokio_rustls::rustls::{self, pki_types::ServerName};
use tokio_rustls::TlsConnector;

type ImapSession = Session<TlsStream<TcpStream>>;
type ImapResult<T> = Result<T, async_imap::error::Error>;

const CONNECT_TIMEOUT: Duration = Duration::from_secs(20);
const OP_TIMEOUT: Duration = Duration::from_secs(90);
const MAX_PAGE: usize = 100;
// Gambar inline (cid:) di atas ukuran ini tidak di-embed ke HTML.
const MAX_INLINE_IMAGE: usize = 3 * 1024 * 1024;

/// Isi payload akun (didekripsi dari kolom E2E `email_accounts.payload`).
#[derive(Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct MailCredentials {
    pub email: String,
    pub password: String,
    pub host: String,
    pub port: u16,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MailSummary {
    pub uid: u32,
    pub subject: String,
    pub from_name: String,
    pub from_addr: String,
    pub date: Option<i64>, // unix detik
    pub seen: bool,
    pub has_attachment: bool,
    pub size: u32,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct InboxPage {
    pub total: usize,
    pub unseen: usize,
    pub messages: Vec<MailSummary>,
    pub has_more: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MailAttachment {
    pub name: String,
    pub mime: String,
    pub size: usize,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MailMessage {
    pub uid: u32,
    pub subject: String,
    pub from_name: String,
    pub from_addr: String,
    pub to: Vec<String>,
    pub cc: Vec<String>,
    pub date: Option<i64>,
    pub html: Option<String>, // belum disanitasi — frontend wajib sanitasi
    pub text: Option<String>,
    pub attachments: Vec<MailAttachment>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DeleteResult {
    pub deleted: usize,
    pub moved_to: Option<String>, // None = dihapus permanen
    /// Folder Sampah tidak ditemukan — tidak ada yang dihapus; UI perlu
    /// konfirmasi hapus permanen.
    pub needs_permanent: bool,
}

#[derive(Default)]
pub struct MailManager {
    sessions: Mutex<HashMap<String, Arc<Mutex<Option<ImapSession>>>>>,
}

// Jalankan operasi pada sesi cache akun; bila sesi lama gagal (biasanya
// diputus server), buang lalu ulangi sekali dengan sesi baru.
macro_rules! with_session {
    ($self:ident, $id:expr, $creds:expr, |$s:ident| $op:expr) => {{
        let slot = $self.slot($id).await;
        let mut guard = slot.lock().await;
        let mut attempt = 0;
        loop {
            let fresh = guard.is_none();
            if fresh {
                *guard = Some(connect($creds).await?);
            }
            let $s = guard.as_mut().expect("sesi baru saja diisi");
            match timeout(OP_TIMEOUT, $op).await {
                Ok(Ok(v)) => break Ok(v),
                Ok(Err(e)) => {
                    *guard = None;
                    if fresh || attempt > 0 {
                        break Err(imap_error(e));
                    }
                }
                Err(_) => {
                    *guard = None;
                    break Err("Server email tidak merespons (timeout)".to_string());
                }
            }
            attempt += 1;
        }
    }};
}

impl MailManager {
    async fn slot(&self, id: &str) -> Arc<Mutex<Option<ImapSession>>> {
        let mut map = self.sessions.lock().await;
        Arc::clone(map.entry(id.to_string()).or_default())
    }

    /// Tutup & lupakan sesi akun (dipanggil saat akun diedit/dihapus).
    pub async fn forget(&self, id: &str) {
        let slot = self.sessions.lock().await.remove(id);
        if let Some(slot) = slot {
            tokio::spawn(async move {
                if let Some(mut s) = slot.lock().await.take() {
                    let _ = timeout(Duration::from_secs(5), s.logout()).await;
                }
            });
        }
    }

    pub async fn inbox(
        &self,
        id: &str,
        creds: &MailCredentials,
        before_uid: Option<u32>,
        limit: usize,
    ) -> Result<InboxPage, String> {
        let limit = limit.clamp(1, MAX_PAGE);
        with_session!(self, id, creds, |s| fetch_page(s, before_uid, limit))
    }

    pub async fn message(
        &self,
        id: &str,
        creds: &MailCredentials,
        uid: u32,
    ) -> Result<MailMessage, String> {
        let raw = with_session!(self, id, creds, |s| fetch_raw(s, uid))?;
        let raw = raw.ok_or_else(|| "Email tidak ditemukan (mungkin sudah dihapus)".to_string())?;
        parse_message(uid, &raw)
    }

    pub async fn delete(
        &self,
        id: &str,
        creds: &MailCredentials,
        uids: &[u32],
        permanent: bool,
    ) -> Result<DeleteResult, String> {
        if uids.is_empty() {
            return Ok(DeleteResult { deleted: 0, moved_to: None, needs_permanent: false });
        }
        with_session!(self, id, creds, |s| delete_uids(s, uids, permanent))
    }
}

/// Uji login (dipakai sebelum akun disimpan). Mengembalikan jumlah email di INBOX.
pub async fn test_login(creds: &MailCredentials) -> Result<u32, String> {
    let mut session = connect(creds).await?;
    let result = timeout(OP_TIMEOUT, session.examine("INBOX")).await;
    let _ = timeout(Duration::from_secs(5), session.logout()).await;
    match result {
        Ok(Ok(mbox)) => Ok(mbox.exists),
        Ok(Err(e)) => Err(imap_error(e)),
        Err(_) => Err("Server email tidak merespons (timeout)".to_string()),
    }
}

async fn connect(creds: &MailCredentials) -> Result<ImapSession, String> {
    let host = creds.host.trim();
    let port = creds.port;
    if host.is_empty() {
        return Err("Server IMAP wajib diisi".to_string());
    }

    let tcp = timeout(CONNECT_TIMEOUT, TcpStream::connect((host, port)))
        .await
        .map_err(|_| format!("Timeout menghubungi {host}:{port}"))?
        .map_err(|e| format!("Gagal menghubungi {host}:{port}: {e}"))?;

    let mut roots = rustls::RootCertStore::empty();
    roots.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());
    let config = rustls::ClientConfig::builder_with_provider(Arc::new(
        rustls::crypto::ring::default_provider(),
    ))
    .with_safe_default_protocol_versions()
    .map_err(|e| e.to_string())?
    .with_root_certificates(roots)
    .with_no_client_auth();
    let server_name =
        ServerName::try_from(host.to_string()).map_err(|_| "Server IMAP tidak valid".to_string())?;
    // Hanya implicit TLS (port 993) — kredensial tidak pernah lewat koneksi polos.
    let tls = timeout(
        CONNECT_TIMEOUT,
        TlsConnector::from(Arc::new(config)).connect(server_name, tcp),
    )
    .await
    .map_err(|_| "Timeout saat handshake TLS".to_string())?
    .map_err(|e| format!("Koneksi TLS gagal (pastikan port SSL/TLS, mis. 993): {e}"))?;

    let mut client = async_imap::Client::new(tls);
    timeout(CONNECT_TIMEOUT, client.read_response())
        .await
        .map_err(|_| "Server IMAP tidak mengirim salam (timeout)".to_string())?
        .map_err(|e| e.to_string())?
        .ok_or_else(|| "Server IMAP menutup koneksi".to_string())?;

    timeout(CONNECT_TIMEOUT, client.login(creds.email.trim(), &creds.password))
        .await
        .map_err(|_| "Timeout saat login".to_string())?
        .map_err(|(e, _)| match e {
            async_imap::error::Error::No(_) | async_imap::error::Error::Bad(_) => {
                "Login ditolak — periksa alamat email dan password".to_string()
            }
            other => imap_error(other),
        })
}

fn imap_error(e: async_imap::error::Error) -> String {
    match e {
        async_imap::error::Error::ConnectionLost => "Koneksi ke server email terputus".to_string(),
        other => format!("Kesalahan IMAP: {other}"),
    }
}

async fn fetch_page(
    s: &mut ImapSession,
    before_uid: Option<u32>,
    limit: usize,
) -> ImapResult<InboxPage> {
    s.examine("INBOX").await?;
    let mut uids: Vec<u32> = s.uid_search("ALL").await?.into_iter().collect();
    let unseen = s.uid_search("UNSEEN").await?.len();
    let total = uids.len();
    uids.sort_unstable_by(|a, b| b.cmp(a)); // terbaru dulu
    let rest: Vec<u32> = uids
        .into_iter()
        .filter(|u| before_uid.map_or(true, |b| *u < b))
        .collect();
    let has_more = rest.len() > limit;
    let page: Vec<u32> = rest.into_iter().take(limit).collect();
    if page.is_empty() {
        return Ok(InboxPage { total, unseen, messages: Vec::new(), has_more: false });
    }

    let set = page.iter().map(u32::to_string).collect::<Vec<_>>().join(",");
    let fetches: Vec<Fetch> = s
        .uid_fetch(&set, "(UID FLAGS INTERNALDATE RFC822.SIZE BODY.PEEK[HEADER])")
        .await?
        .try_collect()
        .await?;
    let mut messages: Vec<MailSummary> = fetches.iter().filter_map(summarize).collect();
    messages.sort_unstable_by(|a, b| b.uid.cmp(&a.uid));
    Ok(InboxPage { total, unseen, messages, has_more })
}

async fn fetch_raw(s: &mut ImapSession, uid: u32) -> ImapResult<Option<Vec<u8>>> {
    s.examine("INBOX").await?;
    let fetches: Vec<Fetch> = s
        .uid_fetch(uid.to_string(), "(UID BODY.PEEK[])")
        .await?
        .try_collect()
        .await?;
    Ok(fetches
        .iter()
        .find(|f| f.uid == Some(uid))
        .and_then(|f| f.body())
        .map(<[u8]>::to_vec))
}

// Nama folder Sampah yang lazim bila server tidak menandai \Trash (RFC 6154).
const TRASH_NAMES: &[&str] = &[
    "Trash",
    "INBOX.Trash",
    "Deleted Items",
    "INBOX.Deleted Items",
    "Deleted Messages",
    "Deleted",
    "Sampah",
];

async fn find_trash(s: &mut ImapSession) -> ImapResult<Option<String>> {
    let names: Vec<Name> = s.list(Some(""), Some("*")).await?.try_collect().await?;
    let selectable = |n: &&Name| !n.attributes().iter().any(|a| matches!(a, NameAttribute::NoSelect));
    if let Some(n) = names
        .iter()
        .filter(selectable)
        .find(|n| n.attributes().iter().any(|a| matches!(a, NameAttribute::Trash)))
    {
        return Ok(Some(n.name().to_string()));
    }
    Ok(TRASH_NAMES.iter().find_map(|cand| {
        names
            .iter()
            .filter(selectable)
            .find(|n| n.name().eq_ignore_ascii_case(cand))
            .map(|n| n.name().to_string())
    }))
}

async fn delete_uids(s: &mut ImapSession, uids: &[u32], permanent: bool) -> ImapResult<DeleteResult> {
    let trash = if permanent { None } else { find_trash(s).await? };
    if !permanent && trash.is_none() {
        return Ok(DeleteResult { deleted: 0, moved_to: None, needs_permanent: true });
    }

    s.select("INBOX").await?;
    let set = uids.iter().map(u32::to_string).collect::<Vec<_>>().join(",");
    let caps = s.capabilities().await?;
    match &trash {
        Some(folder) if caps.has_str("MOVE") => s.uid_mv(&set, folder).await?,
        _ => {
            if let Some(folder) = &trash {
                s.uid_copy(&set, folder).await?;
            }
            s.uid_store(&set, r"+FLAGS.SILENT (\Deleted)")
                .await?
                .try_collect::<Vec<_>>()
                .await?;
            if caps.has_str("UIDPLUS") {
                s.uid_expunge(&set).await?.try_collect::<Vec<_>>().await?;
            } else {
                s.expunge().await?.try_collect::<Vec<_>>().await?;
            }
        }
    }
    // Kembali ke mode baca-saja untuk operasi berikutnya.
    s.examine("INBOX").await?;
    Ok(DeleteResult { deleted: uids.len(), moved_to: trash, needs_permanent: false })
}

fn summarize(f: &Fetch) -> Option<MailSummary> {
    let uid = f.uid?;
    let parsed = f.header().and_then(|h| MessageParser::default().parse_headers(h));
    let (from_name, from_addr) = parsed
        .as_ref()
        .and_then(|m| m.from())
        .map(first_addr)
        .unwrap_or_default();
    let has_attachment = parsed
        .as_ref()
        .and_then(|m| m.root_part().content_type())
        .map(|ct| {
            ct.ctype().eq_ignore_ascii_case("multipart")
                && ct.subtype().is_some_and(|st| st.eq_ignore_ascii_case("mixed"))
        })
        .unwrap_or(false);
    Some(MailSummary {
        uid,
        subject: parsed
            .as_ref()
            .and_then(|m| m.subject())
            .unwrap_or_default()
            .trim()
            .to_string(),
        from_name,
        from_addr,
        date: parsed
            .as_ref()
            .and_then(|m| m.date())
            .map(|d| d.to_timestamp())
            .or_else(|| f.internal_date().map(|d| d.timestamp())),
        seen: f.flags().any(|fl| matches!(fl, Flag::Seen)),
        has_attachment,
        size: f.size.unwrap_or(0),
    })
}

fn first_addr(a: &Address<'_>) -> (String, String) {
    a.first()
        .map(|x| {
            (
                x.name().unwrap_or_default().trim().to_string(),
                x.address().unwrap_or_default().trim().to_string(),
            )
        })
        .unwrap_or_default()
}

fn all_addrs(a: Option<&Address<'_>>) -> Vec<String> {
    a.map(|a| {
        a.iter()
            .map(|x| match (x.name(), x.address()) {
                (Some(n), Some(e)) if !n.trim().is_empty() => format!("{} <{}>", n.trim(), e),
                (_, Some(e)) => e.to_string(),
                (Some(n), None) => n.to_string(),
                _ => String::new(),
            })
            .filter(|s| !s.is_empty())
            .collect()
    })
    .unwrap_or_default()
}

fn parse_message(uid: u32, raw: &[u8]) -> Result<MailMessage, String> {
    let msg = MessageParser::default()
        .parse(raw)
        .ok_or_else(|| "Format email tidak dapat dibaca".to_string())?;
    let (from_name, from_addr) = msg.from().map(first_addr).unwrap_or_default();

    let mut html = msg
        .html_bodies()
        .find(|p| matches!(p.body, PartType::Html(_)))
        .and_then(|p| p.text_contents())
        .map(str::to_string);
    let text = if html.is_none() {
        msg.text_bodies()
            .find(|p| matches!(p.body, PartType::Text(_)))
            .and_then(|p| p.text_contents())
            .map(str::to_string)
    } else {
        None
    };

    // Gambar inline (cid:) di-embed sebagai data URI — gambar remote tetap
    // diblokir di tampilan sampai pengguna mengizinkan.
    let mut inlined: HashSet<usize> = HashSet::new();
    if let Some(h) = html.as_mut() {
        for (idx, part) in msg.parts.iter().enumerate() {
            let (Some(cid), Some(ct)) = (part.content_id(), part.content_type()) else {
                continue;
            };
            if !ct.ctype().eq_ignore_ascii_case("image") || part.len() > MAX_INLINE_IMAGE {
                continue;
            }
            let needle = format!("cid:{}", cid.trim_matches(|c| c == '<' || c == '>'));
            if !h.contains(&needle) {
                continue;
            }
            let data = format!(
                "data:image/{};base64,{}",
                ct.subtype().unwrap_or("png"),
                base64::engine::general_purpose::STANDARD.encode(part.contents())
            );
            *h = h.replace(&needle, &data);
            inlined.insert(idx);
        }
    }

    let attachments = msg
        .attachments()
        .filter(|p| {
            !msg.parts
                .iter()
                .enumerate()
                .any(|(i, q)| inlined.contains(&i) && std::ptr::eq(*p, q))
        })
        .map(|p| MailAttachment {
            name: p
                .attachment_name()
                .map(str::to_string)
                .or_else(|| p.message().and_then(|m| m.subject()).map(|s| format!("{s}.eml")))
                .unwrap_or_else(|| "lampiran".to_string()),
            mime: p
                .content_type()
                .map(|ct| match ct.subtype() {
                    Some(st) => format!("{}/{}", ct.ctype(), st),
                    None => ct.ctype().to_string(),
                })
                .unwrap_or_else(|| "application/octet-stream".to_string()),
            size: p.len(),
        })
        .collect();

    Ok(MailMessage {
        uid,
        subject: msg.subject().unwrap_or_default().trim().to_string(),
        from_name,
        from_addr,
        to: all_addrs(msg.to()),
        cc: all_addrs(msg.cc()),
        date: msg.date().map(|d| d.to_timestamp()),
        html,
        text,
        attachments,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_html_with_inline_image_and_attachment() {
        let raw = concat!(
            "From: =?UTF-8?B?QnVkaQ==?= <budi@contoh.id>\r\n",
            "To: Admin <admin@valtera.id>, cs@valtera.id\r\n",
            "Subject: Laporan\r\n",
            "Date: Fri, 23 Oct 2026 10:00:00 +0700\r\n",
            "MIME-Version: 1.0\r\n",
            "Content-Type: multipart/mixed; boundary=\"B1\"\r\n\r\n",
            "--B1\r\n",
            "Content-Type: multipart/related; boundary=\"B2\"\r\n\r\n",
            "--B2\r\n",
            "Content-Type: text/html; charset=utf-8\r\n\r\n",
            "<p>Halo</p><img src=\"cid:logo@x\">\r\n",
            "--B2\r\n",
            "Content-Type: image/png\r\n",
            "Content-ID: <logo@x>\r\n",
            "Content-Transfer-Encoding: base64\r\n\r\n",
            "iVBORw0KGgo=\r\n",
            "--B2--\r\n",
            "--B1\r\n",
            "Content-Type: application/pdf; name=\"faktur.pdf\"\r\n",
            "Content-Disposition: attachment; filename=\"faktur.pdf\"\r\n",
            "Content-Transfer-Encoding: base64\r\n\r\n",
            "JVBERi0=\r\n",
            "--B1--\r\n",
        );
        let m = parse_message(7, raw.as_bytes()).unwrap();
        assert_eq!(m.uid, 7);
        assert_eq!(m.subject, "Laporan");
        assert_eq!((m.from_name.as_str(), m.from_addr.as_str()), ("Budi", "budi@contoh.id"));
        assert_eq!(m.to, vec!["Admin <admin@valtera.id>", "cs@valtera.id"]);
        let html = m.html.unwrap();
        assert!(html.contains("data:image/png;base64,"));
        assert!(!html.contains("cid:logo@x"));
        assert!(m.text.is_none());
        let names: Vec<_> = m.attachments.iter().map(|a| a.name.as_str()).collect();
        assert_eq!(names, vec!["faktur.pdf"]);
    }

    #[test]
    fn plain_text_message_has_text_body() {
        let raw = "From: a@b.id\r\nSubject: Hai\r\n\r\nIsi polos\r\n";
        let m = parse_message(1, raw.as_bytes()).unwrap();
        assert!(m.html.is_none());
        assert_eq!(m.text.as_deref().map(str::trim), Some("Isi polos"));
        assert!(m.attachments.is_empty());
    }
}
