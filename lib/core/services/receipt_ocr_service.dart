import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'receipt_parser_service.dart';

final receiptOcrServiceProvider = Provider<ReceiptOcrService>((ref) {
  final parser = ref.watch(receiptParserServiceProvider);
  return ReceiptOcrService(parser: parser);
});

/// Result of an OCR scan operation.
class ReceiptOcrResult {
  final String rawText;
  final ParsedReceiptData parsedData;
  final bool isSuccess;
  final String? errorMessage;

  ReceiptOcrResult({
    required this.rawText,
    required this.parsedData,
    this.isSuccess = true,
    this.errorMessage,
  });

  factory ReceiptOcrResult.failure(String message) {
    return ReceiptOcrResult(
      rawText: '',
      parsedData: ParsedReceiptData(rawText: ''),
      isSuccess: false,
      errorMessage: message,
    );
  }
}

/// Service that runs Google ML Kit on-device Text Recognition on receipt images
/// and pipes the result through the heuristic parser.
class ReceiptOcrService {
  final ReceiptParserService _parser;

  ReceiptOcrService({ReceiptParserService? parser})
      : _parser = parser ?? ReceiptParserService();

  /// Checks if on-device OCR is supported on the current running platform.
  bool get isOcrSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Scans the image at [imageFilePath], extracts text via ML Kit on-device,
  /// and returns parsed financial data.
  Future<ReceiptOcrResult> processReceiptImage(String imageFilePath) async {
    if (!isOcrSupported) {
      return ReceiptOcrResult.failure(
        'On-device bill scanning is currently supported on Android and iOS.',
      );
    }

    final file = File(imageFilePath);
    if (!await file.exists()) {
      return ReceiptOcrResult.failure('Image file does not exist at $imageFilePath');
    }

    TextRecognizer? textRecognizer;
    try {
      final inputImage = InputImage.fromFilePath(imageFilePath);
      textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      final rawText = recognizedText.text;

      if (rawText.trim().isEmpty) {
        return ReceiptOcrResult.failure(
          'No text recognized in image. Please ensure the receipt is clear and well-lit.',
        );
      }

      // Reconstruct spatial lines by clustering TextLine bounding boxes into visual rows
      final spatialText = reconstructSpatialText(recognizedText);

      // Parse primarily with spatially reconstructed lines
      var parsed = _parser.parse(spatialText);

      // If amount was not found in spatial lines, cross-reference with raw text
      if (parsed.amount == null || parsed.date == null) {
        final rawParsed = _parser.parse(rawText);
        parsed = ParsedReceiptData(
          amount: parsed.amount ?? rawParsed.amount,
          date: parsed.date ?? rawParsed.date,
          merchantName: parsed.merchantName ?? rawParsed.merchantName,
          suggestedCategoryKeyword: parsed.suggestedCategoryKeyword ?? rawParsed.suggestedCategoryKeyword,
          rawText: '$spatialText\n---\n$rawText',
        );
      }

      debugPrint('[ReceiptOCR] Spatial reconstructed text:\n$spatialText');
      debugPrint('[ReceiptOCR] Parsed result: amount=${parsed.amount}, date=${parsed.date}, merchant=${parsed.merchantName}');

      return ReceiptOcrResult(
        rawText: spatialText,
        parsedData: parsed,
        isSuccess: true,
      );
    } catch (e, stack) {
      debugPrint('Error during receipt OCR processing: $e\n$stack');
      return ReceiptOcrResult.failure('Failed to scan receipt: $e');
    } finally {
      await textRecognizer?.close();
    }
  }

  /// Reconstructs receipt text by clustering TextLine bounding boxes into visual horizontal rows.
  String reconstructSpatialText(RecognizedText recognizedText) {
    final List<TextLine> allLines = [];
    for (final block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }

    if (allLines.isEmpty) {
      return recognizedText.text;
    }

    // Sort all lines from top to bottom
    allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    final List<List<TextLine>> rows = [];
    for (final line in allLines) {
      bool added = false;
      for (final row in rows) {
        final refBox = row.first.boundingBox;
        final lineBox = line.boundingBox;

        // Check vertical overlap between lines
        final overlapTop = math.max(refBox.top, lineBox.top);
        final overlapBottom = math.min(refBox.bottom, lineBox.bottom);
        final overlapHeight = overlapBottom - overlapTop;
        final minHeight = math.max(1.0, math.min(refBox.height, lineBox.height));

        // Lines that vertically overlap by at least 35% belong to the same row
        if (overlapHeight > 0 && overlapHeight >= (minHeight * 0.35)) {
          row.add(line);
          added = true;
          break;
        }
      }

      if (!added) {
        rows.add([line]);
      }
    }

    // Sort rows by their vertical position
    rows.sort((a, b) => a.first.boundingBox.top.compareTo(b.first.boundingBox.top));

    final buffer = StringBuffer();
    for (final row in rows) {
      // Sort elements left-to-right within the row
      row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      final rowStr = row.map((l) => l.text.trim()).where((t) => t.isNotEmpty).join('    ');
      if (rowStr.isNotEmpty) {
        buffer.writeln(rowStr);
      }
    }

    return buffer.toString();
  }
}
