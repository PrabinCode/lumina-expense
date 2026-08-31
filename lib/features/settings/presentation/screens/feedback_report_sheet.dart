import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/services/app_log_service.dart';
import '../../../../core/services/email_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../accounts/data/account_repository.dart';
import '../../../budgets/data/budget_repository.dart';
import '../../../debts/data/debt_repository.dart';
import '../../../goals/data/goal_repository.dart';
import '../../../subscriptions/data/subscription_repository.dart';
import '../../../transactions/data/transaction_repository.dart';

class FeedbackReportSheet extends ConsumerStatefulWidget {
  const FeedbackReportSheet({super.key});

  static void show(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const FeedbackReportSheet(),
    );
  }

  @override
  ConsumerState<FeedbackReportSheet> createState() => _FeedbackReportSheetState();
}

class _FeedbackReportSheetState extends ConsumerState<FeedbackReportSheet> {
  final _noteController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedCategory = 'Bug Report';
  String? _attachedImagePath;
  bool _includeDiagnostics = true;
  bool _showLogPreview = false;
  bool _isExporting = false;

  final List<Map<String, dynamic>> _categories = [
    {'label': 'Bug Report', 'icon': Icons.bug_report_rounded, 'color': AppColors.expense},
    {'label': 'Feature Idea', 'icon': Icons.lightbulb_rounded, 'color': AppColors.warning},
    {'label': 'Feedback', 'icon': Icons.chat_bubble_rounded, 'color': AppColors.primary},
    {'label': 'Data / Calc', 'icon': Icons.calculate_rounded, 'color': AppColors.transfer},
  ];

  @override
  void dispose() {
    _noteController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _attachedImagePath = result.files.single.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach image: $e')),
        );
      }
    }
  }

  Future<void> _sendFeedback() async {
    final notes = _noteController.text.trim();
    if (notes.isEmpty && _attachedImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your issue or attach a screenshot.')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      // Gather high-level non-sensitive stats for diagnosis
      final accounts = ref.read(accountsStreamProvider).valueOrNull?.length ?? 0;
      final transactions = ref.read(recentTransactionsStreamProvider).valueOrNull?.length ?? 0;
      final budgets = ref.read(currentMonthBudgetsProvider).valueOrNull?.length ?? 0;
      final debts = ref.read(debtsStreamProvider(null)).valueOrNull?.length ?? 0;
      final goals = ref.read(goalsSummaryStreamProvider).valueOrNull?.totalGoals ?? 0;
      final subscriptions = ref.read(subscriptionsSummaryStreamProvider).valueOrNull?.activeCount ?? 0;

      final diagnostics = _includeDiagnostics
          ? AppLogService.instance.getDiagnosticReport(
              accountsCount: accounts,
              transactionsCount: transactions,
              budgetsCount: budgets,
              debtsCount: debts,
              goalsCount: goals,
              subscriptionsCount: subscriptions,
            )
          : null;

      final subject = '[Lumina Expense v1.2.0] $_selectedCategory';
      final buffer = StringBuffer();
      buffer.writeln('Hi Prabin,');
      buffer.writeln();
      buffer.writeln('Category: $_selectedCategory');
      if (_emailController.text.trim().isNotEmpty) {
        buffer.writeln('Reply To: ${_emailController.text.trim()}');
      }
      buffer.writeln();
      buffer.writeln('--- User Description ---');
      buffer.writeln(notes.isEmpty ? '(Screenshot attached without extra description)' : notes);
      buffer.writeln();

      if (diagnostics != null) {
        buffer.writeln(diagnostics);
      }

      final body = buffer.toString();

      // Send email directly to Prabin with attachment if attached
      await EmailService.sendEmail(
        recipient: 'prabin@pcshrestha.com.np',
        subject: subject,
        body: body,
        attachmentPath: _attachedImagePath,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening email draft to Prabin...'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error preparing report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _exportDiagnosticsFile() async {
    setState(() => _isExporting = true);
    try {
      final accounts = ref.read(accountsStreamProvider).valueOrNull?.length ?? 0;
      final transactions = ref.read(recentTransactionsStreamProvider).valueOrNull?.length ?? 0;
      final budgets = ref.read(currentMonthBudgetsProvider).valueOrNull?.length ?? 0;
      final debts = ref.read(debtsStreamProvider(null)).valueOrNull?.length ?? 0;
      final goals = ref.read(goalsSummaryStreamProvider).valueOrNull?.totalGoals ?? 0;
      final subscriptions = ref.read(subscriptionsSummaryStreamProvider).valueOrNull?.activeCount ?? 0;

      final file = await AppLogService.instance.exportLogFile(
        accountsCount: accounts,
        transactionsCount: transactions,
        budgetsCount: budgets,
        debtsCount: debts,
        goalsCount: goals,
        subscriptionsCount: subscriptions,
      );

      final filesToShare = [XFile(file.path)];
      if (_attachedImagePath != null) {
        filesToShare.add(XFile(_attachedImagePath!));
      }

      await Share.shareXFiles(
        filesToShare,
        subject: '[Lumina Expense v1.2.0] Diagnostic Logs',
        text: 'Lumina Expense Diagnostic Report & Error Logs',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting logs: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
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

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.mark_email_read_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Feedback & Bug Report',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        'Direct support: prabin@pcshrestha.com.np',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Category Chips
            const Text(
              'Report Category',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat['label'];
                  final color = cat['color'] as Color;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(cat['icon'] as IconData, size: 16, color: isSelected ? Colors.white : color),
                      label: Text(cat['label'] as String),
                      selected: isSelected,
                      selectedColor: color,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(() => _selectedCategory = cat['label'] as String),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Feedback Text Field
            TextField(
              controller: _noteController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Message / Description',
                hintText: _selectedCategory == 'Bug Report'
                    ? 'What happened? What steps led to this issue?'
                    : 'Share your suggestions, idea, or questions...',
                hintStyle: const TextStyle(fontSize: 13),
                filled: true,
                fillColor: surfaceColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // Sender Contact Email (Optional)
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Your Email (Optional)',
                hintText: 'So Prabin can reply to you directly',
                prefixIcon: const Icon(Icons.alternate_email_rounded, size: 18),
                filled: true,
                fillColor: surfaceColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            // Screenshot Attachment Section
            const Text(
              'Attach Screenshot',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (_attachedImagePath != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_attachedImagePath!),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_rounded, size: 36),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _attachedImagePath!.split(Platform.pathSeparator).last,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Screenshot attached ready to send',
                            style: TextStyle(fontSize: 11, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                      onPressed: () => setState(() => _attachedImagePath = null),
                      tooltip: 'Remove Screenshot',
                    ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _pickScreenshot,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Add Screenshot from Device'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

            const SizedBox(height: 16),

            // Diagnostic & System Info Card
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Attach Diagnostic Info & Logs', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('100% privacy-safe: app version & error traces only (no financial amounts)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    value: _includeDiagnostics,
                    activeTrackColor: AppColors.primary,
                    onChanged: (val) => setState(() => _includeDiagnostics = val),
                  ),
                  if (_includeDiagnostics) ...[
                    const Divider(height: 1),
                    InkWell(
                      onTap: () => setState(() => _showLogPreview = !_showLogPreview),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _showLogPreview ? 'Hide Diagnostic Preview' : 'Preview Diagnostic Text',
                              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                            Icon(
                              _showLogPreview ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showLogPreview)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          AppLogService.instance.getDiagnosticReport(),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isExporting ? null : _exportDiagnosticsFile,
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share Log File'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _sendFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _isExporting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(_isExporting ? 'Preparing...' : 'Send to Prabin'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
