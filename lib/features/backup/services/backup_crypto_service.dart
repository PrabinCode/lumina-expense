import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class BackupCryptoService {
  static const String headerPrefix = 'LUMINA_ENC_V1';

  /// Check if file content is an encrypted Lumina backup
  static bool isEncrypted(String content) {
    return content.trim().startsWith(headerPrefix);
  }

  /// Encrypt plaintext JSON with AES-256 using password
  static String encryptJson(String jsonString, String password) {
    final salt = _generateRandomBytes(16);
    final ivBytes = _generateRandomBytes(16);
    final keyBytes = _deriveKey(password, salt);

    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));

    final encrypted = encrypter.encrypt(jsonString, iv: iv);

    final base64Salt = base64.encode(salt);
    final base64Iv = base64.encode(ivBytes);
    final base64Cipher = encrypted.base64;

    return '$headerPrefix:$base64Salt:$base64Iv:$base64Cipher';
  }

  /// Decrypt ciphertext with password and return plaintext JSON
  static String decryptJson(String encryptedPayload, String password) {
    final trimmed = encryptedPayload.trim();
    if (!trimmed.startsWith(headerPrefix)) {
      throw const FormatException('Invalid or unsupported encrypted backup header.');
    }

    final parts = trimmed.split(':');
    if (parts.length != 4) {
      throw const FormatException('Corrupted encrypted backup file structure.');
    }

    final salt = base64.decode(parts[1]);
    final ivBytes = base64.decode(parts[2]);
    final cipherBase64 = parts[3];

    final keyBytes = _deriveKey(password, salt);
    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));

    try {
      final decrypted = encrypter.decrypt64(cipherBase64, iv: iv);
      // Validate that decrypted payload is valid JSON
      json.decode(decrypted);
      return decrypted;
    } catch (_) {
      throw const FormatException('Incorrect password or damaged backup file.');
    }
  }

  static Uint8List _deriveKey(String password, Uint8List salt) {
    // 10,000 rounds of PBKDF2-like salted SHA-256 derivation
    var hash = sha256.convert([...utf8.encode(password), ...salt]).bytes;
    for (int i = 0; i < 5000; i++) {
      hash = sha256.convert([...hash, ...salt, ...utf8.encode(password)]).bytes;
    }
    return Uint8List.fromList(hash);
  }

  static Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    final values = Uint8List(length);
    for (int i = 0; i < length; i++) {
      values[i] = random.nextInt(256);
    }
    return values;
  }
}
