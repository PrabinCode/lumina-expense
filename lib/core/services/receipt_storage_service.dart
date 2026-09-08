import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

final receiptStorageServiceProvider = Provider<ReceiptStorageService>((ref) {
  return ReceiptStorageService();
});

/// Service responsible for persistent local storage, path resolution, and
/// cleanup of receipt images.
class ReceiptStorageService {
  static const String receiptsFolderName = 'receipts';
  final Uuid _uuid = const Uuid();

  /// Returns the local directory where receipt images are stored.
  Future<Directory> getReceiptsDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory(p.join(docsDir.path, receiptsFolderName));
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }
    return receiptsDir;
  }

  /// Copies an image file into the app's persistent receipts directory.
  /// Returns a relative path (e.g. `receipts/receipt_<uuid>.jpg`) suitable for
  /// database storage and cross-platform/sandbox safety.
  Future<String> saveReceiptImage(File sourceFile) async {
    try {
      final dir = await getReceiptsDirectory();
      final ext = p.extension(sourceFile.path).isNotEmpty ? p.extension(sourceFile.path) : '.jpg';
      final fileName = 'receipt_${_uuid.v4()}$ext';
      final destFile = File(p.join(dir.path, fileName));

      await sourceFile.copy(destFile.path);
      return p.join(receiptsFolderName, fileName).replaceAll(r'\', '/');
    } catch (e, stack) {
      debugPrint('Error saving receipt image: $e\n$stack');
      rethrow;
    }
  }

  /// Resolves a stored relative or absolute path to a concrete [File].
  /// Handles iOS sandbox container path migration across app updates.
  Future<File?> resolveReceiptFile(String? receiptPath) async {
    if (receiptPath == null || receiptPath.trim().isEmpty) {
      return null;
    }

    final trimmed = receiptPath.trim();

    // If it's already an existing absolute path:
    final directFile = File(trimmed);
    if (await directFile.exists()) {
      return directFile;
    }

    // Resolve relative path against documents directory
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final normalized = trimmed.replaceAll(r'\', '/');

      String resolvedPath;
      if (normalized.startsWith('$receiptsFolderName/')) {
        resolvedPath = p.join(docsDir.path, normalized);
      } else {
        resolvedPath = p.join(docsDir.path, receiptsFolderName, p.basename(normalized));
      }

      final file = File(resolvedPath);
      return file;
    } catch (e) {
      debugPrint('Error resolving receipt file path "$receiptPath": $e');
      return null;
    }
  }

  /// Deletes the receipt file from disk when permanently removed or detached.
  Future<bool> deleteReceiptFile(String? receiptPath) async {
    if (receiptPath == null || receiptPath.trim().isEmpty) {
      return false;
    }
    try {
      final file = await resolveReceiptFile(receiptPath);
      if (file != null && await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting receipt file "$receiptPath": $e');
    }
    return false;
  }
}
