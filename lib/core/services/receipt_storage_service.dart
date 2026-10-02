import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final receiptStorageServiceProvider = Provider<ReceiptStorageService>((ref) {
  return ReceiptStorageService();
});

/// Background worker to resize and compress large images to JPEG format.
Uint8List? _compressReceiptImageBytes(Uint8List rawBytes) {
  try {
    final image = img.decodeImage(rawBytes);
    if (image == null) return null;

    img.Image processed = image;
    const maxW = 1280;
    const maxH = 1800;

    if (image.width > maxW || image.height > maxH) {
      final double widthRatio = maxW / image.width;
      final double heightRatio = maxH / image.height;
      final double scale = math.min(widthRatio, heightRatio);
      final int targetW = (image.width * scale).round();
      final int targetH = (image.height * scale).round();

      processed = img.copyResize(
        image,
        width: targetW,
        height: targetH,
        interpolation: img.Interpolation.linear,
      );
    }

    return Uint8List.fromList(img.encodeJpg(processed, quality: 78));
  } catch (e) {
    debugPrint('[ReceiptStorage] Background compression error: $e');
    return null;
  }
}

/// Service responsible for persistent local storage, path resolution, and
/// cleanup of receipt images.
class ReceiptStorageService {
  static const String receiptsFolderName = 'receipts';
  static const String androidMediaPackage = 'com.prabincode.luminaexpense';
  static const String _prefKeyMigrated = 'receipts_migrated_to_media_v1';
  final Uuid _uuid = const Uuid();

  /// Returns the legacy documents receipts directory (used for fallback & migration)
  Future<Directory> getLegacyDocumentsReceiptsDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(docsDir.path, receiptsFolderName));
  }

  /// Returns the local directory where receipt images are stored.
  /// On Android, uses the app-specific media directory (`Android/media/<package>/receipts`).
  /// On other platforms or if media dir is inaccessible, falls back to `<documents>/receipts`.
  Future<Directory> getReceiptsDirectory() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final mediaDir = Directory('/storage/emulated/0/Android/media/$androidMediaPackage/$receiptsFolderName');
        if (!await mediaDir.exists()) {
          await mediaDir.create(recursive: true);
        }
        // Test writability
        final testFile = File(p.join(mediaDir.path, '.write_test'));
        await testFile.writeAsString('ok');
        await testFile.delete();
        return mediaDir;
      } catch (e) {
        debugPrint('[ReceiptStorage] Android media directory inaccessible, falling back to docs: $e');
      }
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory(p.join(docsDir.path, receiptsFolderName));
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }
    return receiptsDir;
  }

  /// Safe one-time migration: moves existing receipt photos from internal docs folder
  /// to the external Android media folder with copy-and-verify integrity checks.
  Future<int> migrateLegacyReceiptsIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefKeyMigrated) == true) {
        return 0;
      }

      final activeDir = await getReceiptsDirectory();
      final legacyDir = await getLegacyDocumentsReceiptsDirectory();

      // If active directory is the legacy directory (e.g. desktop/iOS/fallback), mark done
      if (p.canonicalize(activeDir.path) == p.canonicalize(legacyDir.path)) {
        await prefs.setBool(_prefKeyMigrated, true);
        return 0;
      }

      if (!await legacyDir.exists()) {
        await prefs.setBool(_prefKeyMigrated, true);
        return 0;
      }

      int migratedCount = 0;
      await for (final entity in legacyDir.list(followLinks: false)) {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          final targetFile = File(p.join(activeDir.path, fileName));

          final srcLen = await entity.length();
          await entity.copy(targetFile.path);

          // Verify copy integrity
          if (await targetFile.exists() && await targetFile.length() == srcLen) {
            await entity.delete();
            migratedCount++;
          } else {
            debugPrint('[ReceiptStorage] Migration integrity check failed for $fileName');
          }
        }
      }

      await prefs.setBool(_prefKeyMigrated, true);
      debugPrint('[ReceiptStorage] Successfully migrated $migratedCount legacy receipt images to ${activeDir.path}');
      return migratedCount;
    } catch (e, stack) {
      debugPrint('[ReceiptStorage] Error during legacy receipt migration: $e\n$stack');
      return 0;
    }
  }

  /// Copies or optimizes an image file into the app's persistent receipts directory.
  /// If the image is already lightweight (<= 450 KB JPEG), it is copied directly via fast path.
  /// If the file is large (> 450 KB) or non-JPEG, it is compressed and resized in a background isolate.
  /// Returns a relative path (e.g. `receipts/receipt_<uuid>.jpg`) suitable for
  /// database storage and cross-platform/sandbox safety.
  Future<String> saveReceiptImage(File sourceFile) async {
    try {
      final dir = await getReceiptsDirectory();
      final fileName = 'receipt_${_uuid.v4()}.jpg';
      final destFile = File(p.join(dir.path, fileName));

      final fileLength = await sourceFile.length();
      final ext = p.extension(sourceFile.path).toLowerCase();
      final isJpeg = ext == '.jpg' || ext == '.jpeg';

      // Fast-path: Image was already compressed by image_picker and is <= 450 KB
      if (isJpeg && fileLength <= 450 * 1024) {
        await sourceFile.copy(destFile.path);
      } else {
        // Fallback optimization: Large image or non-JPEG format from gallery
        try {
          final rawBytes = await sourceFile.readAsBytes();
          final compressedBytes = await compute(_compressReceiptImageBytes, rawBytes);
          if (compressedBytes != null && compressedBytes.isNotEmpty) {
            await destFile.writeAsBytes(compressedBytes);
          } else {
            // Graceful fallback to direct copy if decompression fails
            await sourceFile.copy(destFile.path);
          }
        } catch (e) {
          debugPrint('[ReceiptStorage] Secondary compression failed, falling back to direct copy: $e');
          await sourceFile.copy(destFile.path);
        }
      }

      return p.join(receiptsFolderName, fileName).replaceAll(r'\', '/');
    } catch (e, stack) {
      debugPrint('Error saving receipt image: $e\n$stack');
      rethrow;
    }
  }

  /// Resolves a stored relative or absolute path to a concrete [File].
  /// Handles iOS sandbox container path migration across app updates.
  /// Enforces sandbox boundary verification, dual active/legacy lookup, and prevents directory traversal vulnerabilities.
  Future<File?> resolveReceiptFile(String? receiptPath) async {
    if (receiptPath == null || receiptPath.trim().isEmpty) {
      return null;
    }

    final trimmed = receiptPath.trim();

    // Reject directory traversal attempts
    if (trimmed.contains('..')) {
      debugPrint('[ReceiptStorage] Blocked directory traversal attempt: $receiptPath');
      return null;
    }

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final receiptsDir = await getReceiptsDirectory();
      final legacyReceiptsDir = await getLegacyDocumentsReceiptsDirectory();

      final canonicalDocs = p.canonicalize(docsDir.path);
      final canonicalReceipts = p.canonicalize(receiptsDir.path);
      final canonicalLegacy = p.canonicalize(legacyReceiptsDir.path);

      // If it's already an existing absolute path, ensure it's inside allowed app storage
      final directFile = File(trimmed);
      if (p.isAbsolute(trimmed)) {
        final canonicalDirect = p.canonicalize(directFile.path);
        if (canonicalDirect.startsWith(canonicalDocs) ||
            canonicalDirect.startsWith(canonicalReceipts) ||
            canonicalDirect.startsWith(canonicalLegacy)) {
          if (await directFile.exists()) {
            return directFile;
          }
        } else {
          debugPrint('[ReceiptStorage] Blocked path outside app sandbox: $trimmed');
          return null;
        }
      }

      // Resolve relative path against receipts / documents directory
      final normalized = trimmed.replaceAll(r'\', '/');
      final fileName = p.basename(normalized);
      if (fileName.isEmpty) return null;

      // 1. Check primary active receipts directory
      final activeFile = File(p.join(receiptsDir.path, fileName));
      if (await activeFile.exists()) {
        return activeFile;
      }

      // 2. Dual-lookup fallback: check legacy documents receipts directory
      final legacyFile = File(p.join(legacyReceiptsDir.path, fileName));
      if (await legacyFile.exists()) {
        return legacyFile;
      }

      // If file doesn't exist yet, return active destination file
      return activeFile;
    } catch (e) {
      debugPrint('Error resolving receipt file path "$receiptPath": $e');
      return null;
    }
  }

  /// Deletes the receipt file from disk when permanently removed or detached.
  /// Enforces that only files strictly within the receipts folder or app documents are deletable.
  Future<bool> deleteReceiptFile(String? receiptPath) async {
    if (receiptPath == null || receiptPath.trim().isEmpty) {
      return false;
    }
    try {
      final file = await resolveReceiptFile(receiptPath);
      if (file == null) return false;

      final receiptsDir = await getReceiptsDirectory();
      final legacyReceiptsDir = await getLegacyDocumentsReceiptsDirectory();
      final canonicalReceipts = p.canonicalize(receiptsDir.path);
      final canonicalLegacy = p.canonicalize(legacyReceiptsDir.path);
      final canonicalTarget = p.canonicalize(file.path);

      // Verify target is inside active or legacy receipts folder
      if (!canonicalTarget.startsWith(canonicalReceipts) && !canonicalTarget.startsWith(canonicalLegacy)) {
        debugPrint('[ReceiptStorage] Blocked deletion attempt outside receipts directory: ${file.path}');
        return false;
      }

      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting receipt file "$receiptPath": $e');
    }
    return false;
  }
}
