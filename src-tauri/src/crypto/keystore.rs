use base64::{engine::general_purpose::STANDARD as B64, Engine};
use std::sync::Mutex;
use zeroize::Zeroizing;

use crate::crypto::Key;

const KEYRING_SERVICE: &str = "valtera-note";
const KEYRING_ACCOUNT: &str = "e2e-key";

pub struct KeyManager {
    key: Mutex<Option<Zeroizing<Key>>>,
}

impl Default for KeyManager {
    fn default() -> Self {
        Self::new()
    }
}

impl KeyManager {
    pub fn new() -> Self {
        Self {
            key: Mutex::new(None),
        }
    }

    pub fn set_key(&self, key: Key) {
        *self.key.lock().unwrap() = Some(Zeroizing::new(key));
    }

    pub fn clear(&self) {
        *self.key.lock().unwrap() = None;
    }

    pub fn is_unlocked(&self) -> bool {
        self.key.lock().unwrap().is_some()
    }

    /// Jalankan closure dengan kunci. None jika terkunci.
    pub fn with_key<R>(&self, f: impl FnOnce(&Key) -> R) -> Option<R> {
        let guard = self.key.lock().unwrap();
        guard.as_ref().map(|k| f(&**k))
    }

    pub fn save_to_keyring(key: &Key) -> Result<(), String> {
        let entry =
            keyring::Entry::new(KEYRING_SERVICE, KEYRING_ACCOUNT).map_err(|e| e.to_string())?;
        entry.set_password(&B64.encode(key)).map_err(|e| e.to_string())
    }

    pub fn load_from_keyring() -> Result<Key, String> {
        let entry =
            keyring::Entry::new(KEYRING_SERVICE, KEYRING_ACCOUNT).map_err(|e| e.to_string())?;
        let b64 = entry.get_password().map_err(|e| e.to_string())?;
        let raw = B64.decode(b64).map_err(|_| "keyring entry corrupt".to_string())?;
        raw.try_into()
            .map_err(|_| "keyring key length invalid".to_string())
    }

    pub fn delete_from_keyring() -> Result<(), String> {
        let entry =
            keyring::Entry::new(KEYRING_SERVICE, KEYRING_ACCOUNT).map_err(|e| e.to_string())?;
        match entry.delete_credential() {
            Ok(()) | Err(keyring::Error::NoEntry) => Ok(()),
            Err(e) => Err(e.to_string()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn set_clear_is_unlocked() {
        let km = KeyManager::new();
        assert!(!km.is_unlocked());
        km.set_key([9u8; 32]);
        assert!(km.is_unlocked());
        km.clear();
        assert!(!km.is_unlocked());
    }

    #[test]
    fn with_key_returns_none_when_locked() {
        let km = KeyManager::new();
        assert!(km.with_key(|k| *k).is_none());
        km.set_key([5u8; 32]);
        assert_eq!(km.with_key(|k| *k), Some([5u8; 32]));
    }

    /// Integrasi Credential Manager: butuh backend keyring platform yang aktif
    /// (windows-native / apple-native / sync-secret-service). Tanpa backend,
    /// Entry::new gagal di runtime dan fitur "ingat device" menjadi no-op.
    #[cfg(target_os = "windows")]
    #[test]
    fn keyring_roundtrip_real_credential_manager() {
        let key: Key = [7u8; 32];
        // bersihkan sisa test sebelumnya
        let _ = KeyManager::delete_from_keyring();
        KeyManager::save_to_keyring(&key).expect("save ke Windows Credential Manager");
        let loaded = KeyManager::load_from_keyring().expect("load dari Windows Credential Manager");
        assert_eq!(loaded, key);
        KeyManager::delete_from_keyring().expect("hapus entri test");
        assert!(KeyManager::load_from_keyring().is_err());
    }
}
