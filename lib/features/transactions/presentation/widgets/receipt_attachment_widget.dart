import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/receipt_ocr_service.dart';
import '../../../../core/services/receipt_parser_service.dart';
import '../../../../core/services/receipt_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sonner_toast.dart';
import 'receipt_viewer_dialog.dart';

class ReceiptAttachmentWidget extends ConsumerStatefulWidget {
  final String? receiptPath;
  final ValueChanged<String?> onReceiptChanged;
  final void Function(ParsedReceiptData data, String imagePath)? onReceiptScanned;
  final String? transactionTitle;
  final bool autoOpenScanner;

  const ReceiptAttachmentWidget({
    super.key,
    required this.receiptPath,
    required this.onReceiptChanged,
    this.onReceiptScanned,
    this.transactionTitle,
    this.autoOpenScanner = false,
  });

  @override
  ConsumerState<ReceiptAttachmentWidget> createState() => _ReceiptAttachmentWidgetState();
}

class _ReceiptAttachmentWidgetState extends ConsumerState<ReceiptAttachmentWidget> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  File? _resolvedThumbnailFile;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
    if (widget.autoOpenScanner && widget.receiptPath == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pickAndProcessReceipt(source: ImageSource.camera, runOcr: true);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant ReceiptAttachmentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.receiptPath != widget.receiptPath) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    if (widget.receiptPath == null || widget.receiptPath!.isEmpty) {
      if (mounted) {
        setState(() => _resolvedThumbnailFile = null);
      }
      return;
    }

    final storage = ref.read(receiptStorageServiceProvider);
    final file = await storage.resolveReceiptFile(widget.receiptPath);
    if (mounted) {
      setState(() => _resolvedThumbnailFile = file);
    }
  }

  Future<void> _pickAndProcessReceipt({required ImageSource source, required bool runOcr}) async {
    try {
      final pickedXFile = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );

      if (pickedXFile == null) return;

      setState(() => _isProcessing = true);

      final storage = ref.read(receiptStorageServiceProvider);
      final savedRelativePath = await storage.saveReceiptImage(File(pickedXFile.path));
      final resolvedFile = await storage.resolveReceiptFile(savedRelativePath);

      widget.onReceiptChanged(savedRelativePath);
      await _loadThumbnail();

      if (runOcr && resolvedFile != null) {
        final ocrService = ref.read(receiptOcrServiceProvider);
        if (ocrService.isOcrSupported) {
          final result = await ocrService.processReceiptImage(resolvedFile.path);
          if (result.isSuccess) {
            HapticFeedback.mediumImpact();
            widget.onReceiptScanned?.call(result.parsedData, savedRelativePath);
            if (result.parsedData.amount != null && result.parsedData.amount! > 0) {
              Sonner.success(
                'Bill Scanned!',
                description: 'Detected: ${result.parsedData.amount!.toStringAsFixed(2)}. Details auto-filled.',
              );
            } else {
              Sonner.info(
                'Receipt Attached',
                description: 'Bill attached. Total amount not found — please enter manually.',
              );
            }
          } else if (result.errorMessage != null) {
            Sonner.info(
              'Receipt Attached',
              description: result.errorMessage,
            );
          }
        }
      } else {
        Sonner.success('Receipt Attached');
      }
    } catch (e) {
      Sonner.error('Receipt Error', description: e.toString());
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showCaptureOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ocrService = ref.read(receiptOcrServiceProvider);
    final hasOcr = ocrService.isOcrSupported;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Attach or Scan Receipt',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  hasOcr
                      ? '100% on-device OCR extracts amount, date, and merchant.'
                      : 'Attach bill image directly to this transaction.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                if (hasOcr) ...[
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.document_scanner_rounded, color: AppColors.primary),
                    ),
                    title: const Text('Scan Bill with Camera (OCR)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Auto-fills amount, date & title', style: TextStyle(fontSize: 12)),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _pickAndProcessReceipt(source: ImageSource.camera, runOcr: true);
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.photo_library_rounded, color: AppColors.secondary),
                    ),
                    title: const Text('Scan from Photo Library (OCR)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Extracts data from existing receipt photo', style: TextStyle(fontSize: 12)),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _pickAndProcessReceipt(source: ImageSource.gallery, runOcr: true);
                    },
                  ),
                  const Divider(height: 16),
                ],
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.image_outlined, color: Colors.grey),
                  ),
                  title: const Text('Attach Image Only (No OCR)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _pickAndProcessReceipt(source: ImageSource.gallery, runOcr: false);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content;

    // 1. Loading / OCR Processing State
    if (_isProcessing) {
      content = Container(
        key: const ValueKey('receipt_processing'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Scanning receipt & reading details on-device...',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else if (widget.receiptPath != null && widget.receiptPath!.isNotEmpty) {
      // 2. Receipt Attached State
      content = Container(
        key: const ValueKey('receipt_attached'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            // Thumbnail
            GestureDetector(
              onTap: () {
                ReceiptViewerDialog.show(
                  context,
                  receiptPath: widget.receiptPath!,
                  title: widget.transactionTitle,
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: _resolvedThumbnailFile != null && _resolvedThumbnailFile!.existsSync()
                      ? Image.file(
                          _resolvedThumbnailFile!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: Colors.grey.withValues(alpha: 0.2),
                            child: const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.primary),
                          ),
                        )
                      : Container(
                          color: Colors.grey.withValues(alpha: 0.2),
                          child: const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.primary),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 13, color: AppColors.income),
                      SizedBox(width: 4),
                      Text(
                        'Receipt Attached',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      ReceiptViewerDialog.show(
                        context,
                        receiptPath: widget.receiptPath!,
                        title: widget.transactionTitle,
                      );
                    },
                    child: const Text(
                      'Tap to view / zoom receipt',
                      style: TextStyle(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            // Retake / Scan new
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 19, color: Colors.grey),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              tooltip: 'Replace receipt',
              onPressed: () => _showCaptureOptions(context),
            ),
            const SizedBox(width: 6),
            // Delete / Remove
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 19, color: AppColors.expense),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              tooltip: 'Remove receipt',
              onPressed: () {
                widget.onReceiptChanged(null);
                Sonner.info('Receipt removed');
              },
            ),
          ],
        ),
      );
    } else {
      // 3. Empty State (Call to Action)
      content = Semantics(
        key: const ValueKey('receipt_empty'),
        button: true,
        label: 'Scan bill or attach receipt',
        hint: 'Auto-fills amount, date, and merchant using on-device OCR',
        child: Material(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _showCaptureOptions(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.document_scanner_rounded, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Scan Bill or Attach Receipt',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'OCR',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                  const Icon(Icons.add_photo_alternate_outlined, size: 18, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: content,
    );
  }
}
