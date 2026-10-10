use argon2::{Algorithm, Argon2, Params, Version};
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use chacha20poly1305::aead::{Aead, AeadCore, KeyInit, OsRng};
use chacha20poly1305::{XChaCha20Poly1305, XNonce};

pub mod keystore;

pub const ENC_PREFIX: &str = "enc:v1:";
pub const SETTING_SALT: &str = "e2e_salt";
pub const SETTING_VERIFIER: &str = "e2e_verifier";
pub const SETTING_DECLINED: &str = "e2e_declined";
pub const VERIFIER_PLAINTEXT: &str = "valtera-e2e-verifier";

const ARGON2_M_KIB: u32 = 19456; // 19 MiB (OWASP)
const ARGON2_T: u32 = 2;
const ARGON2_P: u32 = 1;

// Kunci pembungkus quick PIN: ruang PIN hanya 10^6, jadi tiap tebakan offline
// dibuat jauh lebih mahal daripada KDF master password.
const PIN_ARGON2_M_KIB: u32 = 65536; // 64 MiB
const PIN_ARGON2_T: u32 = 4;

pub type Key = [u8; 32];

pub fn is_encrypted(value: &str) -> bool {
    value.starts_with(ENC_PREFIX)
}

pub fn generate_salt() -> [u8; 16] {
    use chacha20poly1305::aead::rand_core::RngCore;
    let mut salt = [0u8; 16];
    OsRng.fill_bytes(&mut salt);
    salt
}

pub fn derive_key(password: &str, salt: &[u8; 16]) -> Result<Key, String> {
    derive_key_with(password, salt, ARGON2_M_KIB, ARGON2_T)
}

/// KDF untuk kunci pembungkus quick PIN (blob v2).
pub fn derive_pin_key(pin: &str, salt: &[u8; 16]) -> Result<Key, String> {
    derive_key_with(pin, salt, PIN_ARGON2_M_KIB, PIN_ARGON2_T)
}

fn derive_key_with(password: &str, salt: &[u8; 16], m_kib: u32, t: u32) -> Result<Key, String> {
    let params = Params::new(m_kib, t, ARGON2_P, Some(32)).map_err(|e| e.to_string())?;
    let argon = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);
    let mut key = [0u8; 32];
    argon
        .hash_password_into(password.as_bytes(), salt, &mut key)
        .map_err(|e| e.to_string())?;
    Ok(key)
}

pub fn encrypt(key: &Key, plaintext: &str) -> Result<String, String> {
    let cipher = XChaCha20Poly1305::new(key.into());
    let nonce = XChaCha20Poly1305::generate_nonce(&mut OsRng);
    let ciphertext = cipher
        .encrypt(&nonce, plaintext.as_bytes())
        .map_err(|e| e.to_string())?;
    let mut buf = Vec::with_capacity(24 + ciphertext.len());
    buf.extend_from_slice(nonce.as_slice());
    buf.extend_from_slice(&ciphertext);
    Ok(format!("{}{}", ENC_PREFIX, B64.encode(buf)))
}

pub fn decrypt(key: &Key, value: &str) -> Result<String, String> {
    let encoded = value
        .strip_prefix(ENC_PREFIX)
        .ok_or_else(|| "not encrypted".to_string())?;
    let raw = B64.decode(encoded).map_err(|_| "ciphertext base64 invalid".to_string())?;
    if raw.len() < 24 {
        return Err("ciphertext too short".to_string());
    }
    let (nonce_bytes, ciphertext) = raw.split_at(24);
    let nonce = XNonce::from_slice(nonce_bytes);
    let cipher = XChaCha20Poly1305::new(key.into());
    let plaintext = cipher
        .decrypt(nonce, ciphertext)
        .map_err(|_| "Decryption failed (password salah atau data korup)".to_string())?;
    String::from_utf8(plaintext).map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip_encrypt_decrypt() {
        let key = derive_key("password123", &[0u8; 16]).unwrap();
        let ct = encrypt(&key, " isi catatan rahasia\nmultiline").unwrap();
        assert!(ct.starts_with("enc:v1:"));
        assert_eq!(decrypt(&key, &ct).unwrap(), " isi catatan rahasia\nmultiline");
    }

    #[test]
    fn derive_key_deterministic() {
        let salt = [7u8; 16];
        assert_eq!(derive_key("abc", &salt).unwrap(), derive_key("abc", &salt).unwrap());
        assert_ne!(derive_key("abc", &salt).unwrap(), derive_key("abd", &salt).unwrap());
    }

    #[test]
    fn tamper_detected() {
        let key = derive_key("password123", &[1u8; 16]).unwrap();
        let ct = encrypt(&key, "rahasia").unwrap();
        // flip satu byte di bagian base64
        let mut chars: Vec<char> = ct.chars().collect();
        let last = chars.len() - 1;
        chars[last] = if chars[last] == 'A' { 'B' } else { 'A' };
        let tampered: String = chars.into_iter().collect();
        assert!(decrypt(&key, &tampered).is_err());
    }

    #[test]
    fn wrong_key_fails() {
        let key1 = derive_key("password123", &[2u8; 16]).unwrap();
        let key2 = derive_key("password456", &[2u8; 16]).unwrap();
        let ct = encrypt(&key1, "rahasia").unwrap();
        assert!(decrypt(&key2, &ct).is_err());
    }

    #[test]
    fn is_encrypted_prefix() {
        assert!(is_encrypted("enc:v1:AAAA"));
        assert!(!is_encrypted("plaintext biasa"));
        assert!(!is_encrypted(""));
    }

    #[test]
    fn decrypt_rejects_plaintext() {
        let key = derive_key("x", &[3u8; 16]).unwrap();
        assert!(decrypt(&key, "bukan ciphertext").is_err());
    }

    #[test]
    fn pin_key_differs_from_master_kdf() {
        let salt = [4u8; 16];
        let pin_key = derive_pin_key("123456", &salt).unwrap();
        assert_eq!(pin_key, derive_pin_key("123456", &salt).unwrap());
        assert_ne!(pin_key, derive_key("123456", &salt).unwrap());
    }
}
