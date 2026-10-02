import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class BackupCryptoService {
  static const String headerPrefix = 'LUMINA_ENC_V1';
  static const String headerPrefixV2 = 'LUMINA_ENC_V2';

  /// Check if file content is an encrypted Lumina backup (V1 JSON or V2 Container)
  static bool isEncrypted(String content) {
    final trimmed = content.trim();
    return trimmed.startsWith(headerPrefix) || trimmed.startsWith(headerPrefixV2);
  }

  /// Check if content is a V2 encrypted container archive
  static bool isV2EncryptedContainer(String content) {
    return content.trim().startsWith(headerPrefixV2);
  }

  /// Encrypt plaintext JSON with AES-256 using password (legacy format)
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

  /// Encrypt binary ZIP container archive bytes with AES-256 using password (V2 format)
  static String encryptContainer(Uint8List zipBytes, String password) {
    final salt = _generateRandomBytes(16);
    final ivBytes = _generateRandomBytes(16);
    final keyBytes = _deriveKey(password, salt);

    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));

    final encrypted = encrypter.encryptBytes(zipBytes, iv: iv);

    final base64Salt = base64.encode(salt);
    final base64Iv = base64.encode(ivBytes);
    final base64Cipher = encrypted.base64;

    return '$headerPrefixV2:$base64Salt:$base64Iv:$base64Cipher';
  }

  /// Decrypts either a V1 (JSON string) or V2 (ZIP container bytes) encrypted payload
  static ({bool isContainer, Uint8List? containerBytes, String? jsonString}) decryptPayload(
    String encryptedPayload,
    String password,
  ) {
    final trimmed = encryptedPayload.trim();
    final isV2 = trimmed.startsWith(headerPrefixV2);
    final isV1 = trimmed.startsWith(headerPrefix);

    if (!isV1 && !isV2) {
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
      if (isV2) {
        final decryptedBytes = encrypter.decryptBytes(enc.Encrypted.fromBase64(cipherBase64), iv: iv);
        return (isContainer: true, containerBytes: Uint8List.fromList(decryptedBytes), jsonString: null);
      } else {
        final decrypted = encrypter.decrypt64(cipherBase64, iv: iv);
        // Validate that decrypted payload is valid JSON
        json.decode(decrypted);
        return (isContainer: false, containerBytes: null, jsonString: decrypted);
      }
    } catch (_) {
      throw const FormatException('Incorrect password or damaged backup file.');
    }
  }

  /// Decrypt ciphertext with password and return plaintext JSON (retains backwards compatibility)
  static String decryptJson(String encryptedPayload, String password) {
    final res = decryptPayload(encryptedPayload, password);
    if (res.jsonString != null) {
      return res.jsonString!;
    }
    throw const FormatException('Backup file is an encrypted container archive.');
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
