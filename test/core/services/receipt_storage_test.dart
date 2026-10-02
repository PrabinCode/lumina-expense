import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_expense/core/services/receipt_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ReceiptStorageService storageService;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('receipt_storage_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );
    storageService = ReceiptStorageService();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
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

    test('resolveReceiptFile rejects directory traversal attempts', () async {
      expect(await storageService.resolveReceiptFile('../../etc/passwd'), isNull);
      expect(await storageService.resolveReceiptFile('receipts/../../../boot.ini'), isNull);
      expect(await storageService.resolveReceiptFile('..\\..\\windows\\system32'), isNull);
    });

    test('saveReceiptImage saves image with standard .jpg extension and resolves file', () async {
      final tempDir = await Directory.systemTemp.createTemp('receipt_test');
      try {
        final sampleFile = File('${tempDir.path}/test_receipt.jpg');
        await sampleFile.writeAsBytes(List.filled(100, 42));

        final relativePath = await storageService.saveReceiptImage(sampleFile);
        expect(relativePath.startsWith('receipts/receipt_'), isTrue);
        expect(relativePath.endsWith('.jpg'), isTrue);

        final resolved = await storageService.resolveReceiptFile(relativePath);
        expect(resolved, isNotNull);
        expect(await resolved!.exists(), isTrue);

        final deleted = await storageService.deleteReceiptFile(relativePath);
        expect(deleted, isTrue);
        expect(await resolved.exists(), isFalse);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
