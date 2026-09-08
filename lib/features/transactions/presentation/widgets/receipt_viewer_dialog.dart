import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/services/receipt_storage_service.dart';
import '../../../../core/theme/app_colors.dart';

class ReceiptViewerDialog extends ConsumerStatefulWidget {
  final String receiptPath;
  final String? title;

  const ReceiptViewerDialog({
    super.key,
    required this.receiptPath,
    this.title,
  });

  static Future<void> show(
    BuildContext context, {
    required String receiptPath,
    String? title,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => ReceiptViewerDialog(
        receiptPath: receiptPath,
        title: title,
      ),
    );
  }

  @override
  ConsumerState<ReceiptViewerDialog> createState() => _ReceiptViewerDialogState();
}

class _ReceiptViewerDialogState extends ConsumerState<ReceiptViewerDialog> {
  final TransformationController _transformController = TransformationController();
  TapDownDetails? _doubleTapDetails;
  File? _resolvedFile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    final storage = ref.read(receiptStorageServiceProvider);
    final file = await storage.resolveReceiptFile(widget.receiptPath);
    if (mounted) {
      setState(() {
        _resolvedFile = file;
        _isLoading = false;
      });
    }
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      final translation = Matrix4.translationValues(-position.dx * 1.5, -position.dy * 1.5, 0.0);
      final scale = Matrix4.diagonal3Values(2.5, 2.5, 1.0);
      _transformController.value = translation * scale;
    }
  }

  Future<void> _shareReceipt() async {
    if (_resolvedFile != null && await _resolvedFile!.exists()) {
      await Share.shareXFiles(
        [XFile(_resolvedFile!.path)],
        text: widget.title ?? 'Transaction Receipt',
      );
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
        children: [
          // Content Container
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _resolvedFile == null || !_resolvedFile!.existsSync()
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.broken_image_rounded,
                                size: 56,
                                color: Colors.white54,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Receipt image not found on device',
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : GestureDetector(
                          onDoubleTapDown: _handleDoubleTapDown,
                          onDoubleTap: _handleDoubleTap,
                          child: InteractiveViewer(
                            transformationController: _transformController,
                            minScale: 0.8,
                            maxScale: 5.0,
                            child: Center(
                              child: Image.file(
                                _resolvedFile!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Text(
                                    'Failed to display receipt image',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
          ),

          // Top App Bar Controls
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title ?? 'Receipt Bill',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_resolvedFile != null)
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      tooltip: 'Share Receipt',
                      onPressed: _shareReceipt,
                    ),
                ],
              ),
            ),
          ),

          // Bottom Hint
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Pinch to zoom • Double tap to expand',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
