import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../services/backup_restore_service.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isLoading = false;

  Future<void> _handleExportJson() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(backupRestoreServiceProvider).exportBackupJson();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleExportCsv() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(backupRestoreServiceProvider).exportTransactionsCsv();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    try {
      final inspected = await ref.read(backupRestoreServiceProvider).pickAndInspectBackup();
      if (inspected == null) {
        setState(() => _isLoading = false);
        return;
      }

      if (!mounted) return;

      final preview = inspected.preview;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Confirm Restore', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Found valid backup file with:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('• ${preview.transactionCount} Transactions'),
                Text('• ${preview.accountCount} Accounts'),
                Text('• ${preview.categoryCount} Categories'),
                Text('• ${preview.budgetCount} Budgets'),
                Text('• ${preview.debtCount} Debts'),
                const SizedBox(height: 8),
                Text(
                  'Exported on: ${DateFormat('MMM d, yyyy HH:mm').format(preview.exportDate)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Warning: Restoring will replace your current data.',
                  style: TextStyle(fontSize: 12, color: AppColors.expense, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Replace & Restore'),
              ),
            ],
          );
        },
      );

      if (confirmed == true) {
        await ref.read(backupRestoreServiceProvider).restoreFromFile(inspected.filePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database restored successfully! ✓')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSeedDemoData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Sample Demo Data?'),
        content: const Text(
          'This will populate realistic transactions, categories, budgets, and debts for testing and demonstration.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      await ref.read(backupRestoreServiceProvider).seedDemoData();
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sample demo data generated successfully!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Privacy & Offline Assurance Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 28),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '100% Local & Private',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Your financial data is stored locally on this device. You own your data and can export it anytime.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text('Backup to Cloud / Storage', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),

                  _ActionTile(
                    title: 'Export Backup (JSON)',
                    subtitle: 'Save snapshot directly to Google Drive, Files, or send to yourself.',
                    icon: Icons.cloud_upload_outlined,
                    iconColor: AppColors.primary,
                    onTap: _handleExportJson,
                  ),

                  const SizedBox(height: 8),

                  _ActionTile(
                    title: 'Export to CSV (Excel / Sheets)',
                    subtitle: 'Export raw transaction spreadsheet for external calculations.',
                    icon: Icons.table_chart_outlined,
                    iconColor: AppColors.transfer,
                    onTap: _handleExportCsv,
                  ),

                  const SizedBox(height: 24),

                  const Text('Restore Data', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),

                  _ActionTile(
                    title: 'Restore from Backup File',
                    subtitle: 'Select a previously exported .json backup file to recover data.',
                    icon: Icons.settings_backup_restore_rounded,
                    iconColor: AppColors.warning,
                    onTap: _handleRestore,
                  ),

                  const SizedBox(height: 24),

                  const Text('Developer & Demo Tools', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),

                  _ActionTile(
                    title: 'Populate Demo Data',
                    subtitle: 'Quickly load sample transactions and budgets for screenshots/demo.',
                    icon: Icons.auto_fix_high_rounded,
                    iconColor: AppColors.secondary,
                    onTap: _handleSeedDemoData,
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      ),
    );
  }
}
