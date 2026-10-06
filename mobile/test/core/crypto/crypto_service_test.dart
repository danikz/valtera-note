import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:valtera_note/core/crypto/crypto_service.dart';

void main() {
  group('CryptoService Tests', () {
    late CryptoService crypto;

    setUp(() {
      crypto = CryptoService();
    });

    test('isEncrypted identifies prefix correctly', () {
      expect(crypto.isEncrypted('enc:v1:abc123=='), isTrue);
      expect(crypto.isEncrypted('plain text note'), isFalse);
      expect(crypto.isEncrypted(null), isFalse);
      expect(crypto.isEncrypted(''), isFalse);
    });

    test('Roundtrip encrypt and decrypt produces original plaintext', () async {
      const password = 'mySecretPassword123!';
      final salt = List<int>.generate(16, (i) => i * 7);

      final keyBytes = await crypto.deriveKey(password, salt);
      expect(keyBytes.length, 32);

      const plaintext = 'Catatan rahasia dengan simbol @#% & newline\nBaris kedua';
      final encrypted = await crypto.encrypt(keyBytes, plaintext);

      expect(crypto.isEncrypted(encrypted), isTrue);
      expect(encrypted.startsWith('enc:v1:'), isTrue);

      final decrypted = await crypto.decrypt(keyBytes, encrypted);
      expect(decrypted, plaintext);
    });

    test('verifyMasterPassword succeeds with correct password and fails with wrong', () async {
      const correctPass = 'correctMasterPass123';
      const wrongPass = 'wrongMasterPass456';
      final salt = List<int>.generate(16, (i) => (i + 3) * 5 % 256);

      final correctKey = await crypto.deriveKey(correctPass, salt);
      final wrongKey = await crypto.deriveKey(wrongPass, salt);

      final verifierCiphertext = await crypto.encrypt(correctKey, CryptoService.verifierPlaintext);

      final isCorrectValid = await crypto.verifyMasterPassword(
        keyBytes: correctKey,
        verifierCiphertext: verifierCiphertext,
      );
      expect(isCorrectValid, isTrue);

      final isWrongValid = await crypto.verifyMasterPassword(
        keyBytes: wrongKey,
        verifierCiphertext: verifierCiphertext,
      );
      expect(isWrongValid, isFalse);
    });

    test('decrypt returns plaintext as-is if string is not encrypted', () async {
      final dummyKey = List<int>.filled(32, 0);
      const plain = 'Catatan biasa yang belum dienkripsi';
      final res = await crypto.decrypt(dummyKey, plain);
      expect(res, plain);
    });
  });
}
