import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/services/receipt_storage_service.dart';

void main() {
  late ReceiptStorageService storageService;

  setUp(() {
    storageService = ReceiptStorageService();
  });

  group('ReceiptStorageService', () {
    test('returns null when path is null, empty or whitespace', () async {
      expect(await storageService.resolveReceiptFile(null), isNull);
      expect(await storageService.resolveReceiptFile(''), isNull);
      expect(await storageService.resolveReceiptFile('   '), isNull);
    });

    test('deleteReceiptFile returns false when path is null or empty', () async {
      expect(await storageService.deleteReceiptFile(null), isFalse);
      expect(await storageService.deleteReceiptFile(''), isFalse);
    });
  });
}
