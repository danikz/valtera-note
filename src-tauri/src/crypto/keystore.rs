use base64::{engine::general_purpose::STANDARD as B64, Engine};
use std::sync::Mutex;
use zeroize::Zeroizing;

use crate::crypto::Key;

const KEYRING_SERVICE: &str = "valtera-note";
const KEYRING_ACCOUNT: &str = "e2e-key";
const KEYRING_QUICKPIN_ACCOUNT: &str = "e2e-quickpin";
/// Hitungan PIN salah disimpan di keychain (bukan DB yang bisa ditulis
/// frontend lewat set_app_setting) agar tidak ter-reset saat app di-restart.
const KEYRING_PIN_FAILS_ACCOUNT: &str = "e2e-quickpin-fails";

pub struct KeyManager {
    key: Mutex<Option<Zeroizing<Key>>>,
    /// Hitungan PIN salah beruntun untuk quick unlock (reset saat sukses).
    pin_attempts: Mutex<u32>,
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
            pin_attempts: Mutex::new(0),
        }
    }

    /// Jumlah PIN salah beruntun — maksimum dari hitungan persisten (keychain)
    /// dan hitungan memori (cadangan bila keychain gagal ditulis).
    pub fn pin_attempts(&self) -> u32 {
        let mem = *self.pin_attempts.lock().unwrap();
        mem.max(Self::load_pin_fails())
    }

    /// Naikkan hitungan PIN salah, kembalikan jumlah kegagalan beruntun.
    pub fn fail_pin(&self) -> u32 {
        let n = self.pin_attempts() + 1;
        *self.pin_attempts.lock().unwrap() = n;
        if let Err(e) = Self::save_pin_fails(n) {
            eprintln!("Warning: gagal menyimpan hitungan PIN salah: {}", e);
        }
        n
    }

    pub fn reset_pin_attempts(&self) {
        *self.pin_attempts.lock().unwrap() = 0;
        if let Err(e) = Self::delete_entry(KEYRING_PIN_FAILS_ACCOUNT) {
            eprintln!("Warning: gagal mereset hitungan PIN salah: {}", e);
        }
    }

    fn load_pin_fails() -> u32 {
        keyring::Entry::new(KEYRING_SERVICE, KEYRING_PIN_FAILS_ACCOUNT)
            .and_then(|e| e.get_password())
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or(0)
    }

    fn save_pin_fails(n: u32) -> Result<(), String> {
        let entry = keyring::Entry::new(KEYRING_SERVICE, KEYRING_PIN_FAILS_ACCOUNT)
            .map_err(|e| e.to_string())?;
        entry.set_password(&n.to_string()).map_err(|e| e.to_string())
    }

    fn delete_entry(account: &str) -> Result<(), String> {
        let entry = keyring::Entry::new(KEYRING_SERVICE, account).map_err(|e| e.to_string())?;
        match entry.delete_credential() {
            Ok(()) | Err(keyring::Error::NoEntry) => Ok(()),
            Err(e) => Err(e.to_string()),
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
        Self::delete_entry(KEYRING_ACCOUNT)
    }

    // ===== Quick PIN: blob kunci yang dibungkus kunci turunan PIN 6 digit =====

    pub fn save_quickpin_blob(blob: &str) -> Result<(), String> {
        let entry = keyring::Entry::new(KEYRING_SERVICE, KEYRING_QUICKPIN_ACCOUNT)
            .map_err(|e| e.to_string())?;
        entry.set_password(blob).map_err(|e| e.to_string())
    }

    pub fn load_quickpin_blob() -> Result<String, String> {
        let entry = keyring::Entry::new(KEYRING_SERVICE, KEYRING_QUICKPIN_ACCOUNT)
            .map_err(|e| e.to_string())?;
        entry.get_password().map_err(|e| e.to_string())
    }

    pub fn delete_quickpin() -> Result<(), String> {
        let _ = Self::delete_entry(KEYRING_PIN_FAILS_ACCOUNT);
        Self::delete_entry(KEYRING_QUICKPIN_ACCOUNT)
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
