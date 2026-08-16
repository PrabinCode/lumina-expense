import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../services/backup_restore_service.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isLoading = false;
  String _storagePath = '';
  List<BackupFileInfo> _localBackups = [];
  String _autoFrequency = 'off';
  int _maxBackups = 5;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final service = ref.read(backupRestoreServiceProvider);
    final path = await service.getBackupStorageDirectory();
    final backups = await service.listLocalBackups();
    final freq = await service.getAutoBackupFrequency();
    final maxF = await service.getMaxBackupFiles();

    if (mounted) {
      setState(() {
        _storagePath = path;
        _localBackups = backups;
        _autoFrequency = freq;
        _maxBackups = maxF;
      });
    }
  }

  Future<void> _handleChangeLocation() async {
    final service = ref.read(backupRestoreServiceProvider);
    final newPath = await service.pickAndSetStorageDirectory();
    if (newPath != null) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Storage location updated to:\n$newPath')),
        );
      }
    }
  }

  Future<void> _handleCreateBackup() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(backupRestoreServiceProvider);
      final path = await service.createBackup();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup created successfully!\nSaved to: $path'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create backup: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleExportCsv() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(backupRestoreServiceProvider);
      final path = await service.createCsvExport();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV Spreadsheet exported successfully!\nSaved to: $path'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleShareJson() async {
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

  Future<void> _handleShareCsv() async {
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

  Future<void> _confirmAndRestore(String filePath) async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(backupRestoreServiceProvider);
      final preview = await service.inspectBackupFile(filePath);

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Confirm Restore', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Backup Details:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('• ${preview.transactionCount} Transactions'),
                Text('• ${preview.accountCount} Accounts'),
                Text('• ${preview.categoryCount} Categories'),
                Text('• ${preview.budgetCount} Budgets'),
                Text('• ${preview.debtCount} Debts'),
                Text('• ${preview.goalCount} Goals'),
                Text('• ${preview.subscriptionCount} Subscriptions'),
                const SizedBox(height: 8),
                Text(
                  'Created on: ${DateFormat('MMM d, yyyy • hh:mm a').format(preview.exportDate)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                const Text(
                  '⚠️ Warning: Restoring will overwrite all current local data with this backup.',
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
        await service.restoreFromFile(filePath);
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

  Future<void> _handleRestoreFromFilePicker() async {
    setState(() => _isLoading = true);
    try {
      final inspected = await ref.read(backupRestoreServiceProvider).pickAndInspectBackup();
      if (inspected == null) {
        setState(() => _isLoading = false);
        return;
      }
      await _confirmAndRestore(inspected.filePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDeleteBackup(BackupFileInfo backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backup?'),
        content: Text('Are you sure you want to permanently delete "${backup.fileName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(backupRestoreServiceProvider).deleteBackup(backup.path);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup file deleted.')),
        );
      }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'Refresh backup list',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Mihon-Style Storage Location Card ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.folder_special_rounded, color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Storage Location',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Where local backups & exports are saved',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
                              label: const Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              onPressed: _handleChangeLocation,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _storagePath.isNotEmpty ? _storagePath : 'Default Storage Location',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── Actions Section (Create Backup / CSV) ───
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                          label: const Text('Create Backup', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          onPressed: _handleCreateBackup,
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.table_view_rounded, size: 20, color: Color(0xFF10B981)),
                        label: const Text('Export CSV', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        onPressed: _handleExportCsv,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 16, color: AppColors.transfer),
                          label: const Text('Share Backup JSON', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          onPressed: _handleShareJson,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.share_outlined, size: 16, color: Color(0xFF6366F1)),
                          label: const Text('Share CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          onPressed: _handleShareCsv,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ─── Local Backups in Storage (Mihon-style List) ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Saved Backups (${_localBackups.length})',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.file_open_outlined, size: 16),
                        label: const Text('Browse Other File...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        onPressed: _handleRestoreFromFilePicker,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_localBackups.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.withValues(alpha: 0.5)),
                          const SizedBox(height: 10),
                          const Text(
                            'No backups in this folder yet',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap "Create Backup" above to generate a snapshot.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  else
                    Material(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _localBackups.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final backup = _localBackups[index];
                          return ListTile(
                            onTap: () => _confirmAndRestore(backup.path),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.description_outlined, color: AppColors.primary, size: 22),
                            ),
                            title: Text(
                              backup.fileName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${backup.formattedDate} • ${backup.formattedSize}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.share_outlined, size: 18, color: Colors.grey),
                                  tooltip: 'Share Backup',
                                  onPressed: () {
                                    Share.shareXFiles(
                                      [XFile(backup.path)],
                                      subject: backup.fileName,
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expense),
                                  tooltip: 'Delete Backup',
                                  onPressed: () => _handleDeleteBackup(backup),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 24),

                  // ─── Automatic Backups & Retention ───
                  const Text('Automatic Backups & Retention', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),

                  Material(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          leading: const Icon(Icons.schedule_rounded, color: AppColors.primary),
                          title: const Text('Auto-Backup Frequency', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                            _autoFrequency == 'daily'
                                ? 'Daily'
                                : _autoFrequency == 'weekly'
                                    ? 'Weekly'
                                    : 'Off (Manual only)',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _autoFrequency,
                              items: const [
                                DropdownMenuItem(value: 'off', child: Text('Off', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'daily', child: Text('Daily', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'weekly', child: Text('Weekly', style: TextStyle(fontSize: 13))),
                              ],
                              onChanged: (val) async {
                                if (val != null) {
                                  final service = ref.read(backupRestoreServiceProvider);
                                  await service.setAutoBackupFrequency(val);
                                  setState(() => _autoFrequency = val);
                                }
                              },
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          leading: const Icon(Icons.auto_delete_outlined, color: AppColors.warning),
                          title: const Text('Max Backups to Keep', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: const Text('Auto-prunes oldest backups when limit is reached', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          trailing: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _maxBackups,
                              items: const [
                                DropdownMenuItem(value: 3, child: Text('3 files', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 5, child: Text('5 files', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 10, child: Text('10 files', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 20, child: Text('20 files', style: TextStyle(fontSize: 13))),
                              ],
                              onChanged: (val) async {
                                if (val != null) {
                                  final service = ref.read(backupRestoreServiceProvider);
                                  await service.setMaxBackupFiles(val);
                                  setState(() => _maxBackups = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── Developer & Demo Tools ───
                  const Text('Developer & Demo Tools', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),

                  Material(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: ListTile(
                      onTap: _handleSeedDemoData,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_fix_high_rounded, color: AppColors.secondary, size: 22),
                      ),
                      title: const Text('Populate Sample Demo Data', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: const Text('Quickly load sample transactions, budgets & debts for testing', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}
