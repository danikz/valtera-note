import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class CryptoService {
  static const String encPrefix = 'enc:v1:';
  static const String verifierPlaintext = 'valtera-e2e-verifier';

  final Argon2id _argon2id;
  final Xchacha20 _cipher;

  CryptoService({
    Argon2id? argon2id,
    Xchacha20? cipher,
  })  : _argon2id = argon2id ??
            Argon2id(
              memory: 19456, // 19 MiB (OWASP parameter matching Rust)
              iterations: 2,
              parallelism: 1,
              hashLength: 32,
            ),
        _cipher = cipher ?? Xchacha20.poly1305Aead();

  bool isEncrypted(String? value) {
    if (value == null) return false;
    return value.startsWith(encPrefix);
  }

  Future<List<int>> deriveKey(String password, List<int> salt) async {
    final secretKey = SecretKey(utf8.encode(password));
    final derived = await _argon2id.deriveKey(
      secretKey: secretKey,
      nonce: salt,
    );
    return await derived.extractBytes();
  }

  Future<String> encrypt(List<int> keyBytes, String plaintext) async {
    final secretKey = SecretKey(keyBytes);
    final nonce = _cipher.newNonce(); // 24 bytes

    final box = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );

    // Format matching Rust XChaCha20Poly1305: nonce (24 bytes) + ciphertext + mac (16 bytes)
    final buffer = <int>[
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ];

    return '$encPrefix${base64Encode(buffer)}';
  }

  Future<String> decrypt(List<int> keyBytes, String ciphertext) async {
    if (!isEncrypted(ciphertext)) {
      return ciphertext;
    }

    final base64Part = ciphertext.substring(encPrefix.length);
    final rawBytes = base64Decode(base64Part);

    if (rawBytes.length < 24 + 16) {
      throw const FormatException('Ciphertext is too short');
    }

    final nonce = rawBytes.sublist(0, 24);
    final ciphertextWithMac = rawBytes.sublist(24);
    final macBytes = ciphertextWithMac.sublist(ciphertextWithMac.length - 16);
    final actualCiphertext = ciphertextWithMac.sublist(0, ciphertextWithMac.length - 16);

    final box = SecretBox(
      actualCiphertext,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final secretKey = SecretKey(keyBytes);
    final decryptedBytes = await _cipher.decrypt(box, secretKey: secretKey);
    return utf8.decode(decryptedBytes);
  }

  Future<bool> verifyMasterPassword({
    required List<int> keyBytes,
    required String verifierCiphertext,
  }) async {
    try {
      final decrypted = await decrypt(keyBytes, verifierCiphertext);
      return decrypted == verifierPlaintext;
    } catch (_) {
      return false;
    }
  }
}
