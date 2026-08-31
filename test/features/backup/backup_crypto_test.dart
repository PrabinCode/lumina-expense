import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/features/backup/services/backup_crypto_service.dart';

void main() {
  group('BackupCryptoService Tests', () {
    const rawJson = '{"version":1,"appName":"Lumina Expense","accounts":[{"name":"Main Wallet","balance":500.0}]}';
    const strongPassword = 'MySecretExpenseKey#2026';

    test('encrypt and decrypt roundtrip matches original JSON', () {
      final encrypted = BackupCryptoService.encryptJson(rawJson, strongPassword);

      expect(BackupCryptoService.isEncrypted(encrypted), isTrue);
      expect(encrypted.startsWith('LUMINA_ENC_V1:'), isTrue);

      final decrypted = BackupCryptoService.decryptJson(encrypted, strongPassword);
      expect(decrypted, equals(rawJson));
    });

    test('decrypting with wrong password throws FormatException', () {
      final encrypted = BackupCryptoService.encryptJson(rawJson, strongPassword);

      expect(
        () => BackupCryptoService.decryptJson(encrypted, 'WrongPassword123'),
        throwsA(isA<FormatException>()),
      );
    });

    test('isEncrypted returns false for raw JSON', () {
      expect(BackupCryptoService.isEncrypted(rawJson), isFalse);
    });
  });
}
