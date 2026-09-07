import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/services/app_review_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../services/backup_restore_service.dart';
import 'csv_mapper_screen.dart';

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
  DateTime? _lastAutoBackupTime;
  String _backupFilter = 'all'; // 'all', 'manual', 'auto'

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
    final lastAuto = await service.getLastAutoBackupTime();

    if (mounted) {
      setState(() {
        _storagePath = path;
        _localBackups = backups;
        _autoFrequency = freq;
        _maxBackups = maxF;
        _lastAutoBackupTime = lastAuto;
      });
    }
  }

  Future<void> _handleRunAutoBackupNow() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(backupRestoreServiceProvider);
      final path = await service.createBackup(isAuto: true);
      final now = DateTime.now();
      await service.recordAutoBackupTimestamp(now);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Automatic backup executed!\nSaved to: $path'),
            backgroundColor: const Color(0xFF6366F1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto-backup failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Future<String?> _promptPasswordDialog({
    required String title,
    required String description,
    bool isNew = false,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PasswordPromptSheet(
        title: title,
        description: description,
        isNew: isNew,
      ),
    );
  }

  Future<void> _handleCreateBackup() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.backup_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Choose Backup Type',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_rounded, color: Colors.amber),
                  ),
                  title: const Text('Encrypted Backup (.lumina.enc)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Password-protected with AES-256 encryption', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () => Navigator.pop(ctx, 'encrypted'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.file_copy_outlined, color: AppColors.primary),
                  ),
                  title: const Text('Standard JSON Backup (.json)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Standard plain JSON export', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () => Navigator.pop(ctx, 'plain'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null) return;

    String? password;
    if (choice == 'encrypted') {
      password = await _promptPasswordDialog(
        title: 'Encrypt Backup',
        description: 'Set a password to cipher-lock your financial database archive with AES-256.',
        isNew: true,
      );
      if (password == null || password.trim().isEmpty) return;
    }

    setState(() => _isLoading = true);
    try {
      final service = ref.read(backupRestoreServiceProvider);
      final path = await service.createBackup(password: password);
      await _loadData();
      ref.read(appReviewServiceProvider).recordBackupCompleted();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${choice == "encrypted" ? "🔒 Encrypted backup" : "Backup"} created successfully!\nSaved to: $path'),
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
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.share_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Export Backup Snapshot',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose format for sharing or transferring your backup:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_rounded, color: Colors.amber),
                  ),
                  title: const Text('Encrypted Backup (.lumina.enc)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('AES-256 password encrypted (safest for sharing)', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () => Navigator.pop(ctx, 'encrypted'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.file_copy_outlined, color: AppColors.primary),
                  ),
                  title: const Text('Standard Plain JSON (.json)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Unencrypted plain JSON snapshot', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () => Navigator.pop(ctx, 'plain'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null) return;

    String? password;
    if (choice == 'encrypted') {
      password = await _promptPasswordDialog(
        title: 'Set Backup Password',
        description: 'Enter a password to encrypt the shared backup file.',
        isNew: true,
      );
      if (password == null || password.trim().isEmpty) return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(backupRestoreServiceProvider).exportBackupJson(
            password: password,
          );
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

  Future<void> _confirmAndRestore(String filePath, {String? password}) async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(backupRestoreServiceProvider);
      final preview = await service.inspectBackupFile(filePath, password: password);

      if (!mounted) return;

      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _RestoreConfirmSheet(
          preview: preview,
          isEncrypted: password != null,
        ),
      );

      if (confirmed == true) {
        await service.restoreFromFile(filePath, password: password);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database restored successfully! ✓')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('PASSWORD_REQUIRED') || e.toString().contains('Incorrect password')) {
          final pwd = await _promptPasswordDialog(
            title: 'Enter Backup Password',
            description: 'This backup archive is encrypted. Enter your password to decrypt.',
          );
          if (pwd != null && pwd.isNotEmpty) {
            await _confirmAndRestore(filePath, password: pwd);
            return;
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restore error: $e')),
          );
        }
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
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 8),
            Text('Populate Sample Data'),
          ],
        ),
        content: const Text(
          'This will generate a rich, authentic showcase dataset:\n\n'
          '• 4 Accounts (Checking, Cash, High-Yield Savings, Credit Card)\n'
          '• 25+ Categorized Transactions across the last 30 days\n'
          '• Itemized Split Transactions (Costco Superstore & Weekend Trip)\n'
          '• 5 Monthly Category Budgets with active progress\n'
          '• 4 Financial Savings Goals with target dates\n'
          '• 4 Debt / Loan (IOU) tracking records\n'
          '• 5 Recurring Subscriptions (Netflix, Spotify, Fiber Internet, etc.)',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Populate Data'),
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
          const SnackBar(
            content: Text('🎉 Rich demo data populated: 4 accounts, 25+ transactions, splits, budgets, goals & subscriptions!'),
            duration: Duration(seconds: 4),
          ),
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
                  // ─── Storage Location Card ───
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
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.input_rounded, size: 18, color: AppColors.primary),
                      label: const Text('Import from CSV / External Apps (Migration Wizard)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CsvMapperScreen())),
                    ),
                  ),

                  const SizedBox(height: 24),


                  // ─── Local Backups in Storage ───
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
                  const SizedBox(height: 6),

                  // Filter Chips
                  if (_localBackups.isNotEmpty) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text('All (${_localBackups.length})'),
                            selected: _backupFilter == 'all',
                            onSelected: (_) => setState(() => _backupFilter = 'all'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            avatar: const Icon(Icons.fingerprint_rounded, size: 14),
                            label: Text('Manual (${_localBackups.where((b) => !b.isAuto).length})'),
                            selected: _backupFilter == 'manual',
                            selectedColor: AppColors.income.withValues(alpha: 0.2),
                            onSelected: (_) => setState(() => _backupFilter = 'manual'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            avatar: const Icon(Icons.schedule_rounded, size: 14),
                            label: Text('Automatic (${_localBackups.where((b) => b.isAuto).length})'),
                            selected: _backupFilter == 'auto',
                            selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                            onSelected: (_) => setState(() => _backupFilter = 'auto'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  () {
                    final displayedBackups = _backupFilter == 'all'
                        ? _localBackups
                        : (_backupFilter == 'auto'
                            ? _localBackups.where((b) => b.isAuto).toList()
                            : _localBackups.where((b) => !b.isAuto).toList());

                    if (displayedBackups.isEmpty) {
                      return Container(
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
                            Text(
                              _localBackups.isEmpty ? 'No backups in this folder yet' : 'No backups matching this filter',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _localBackups.isEmpty
                                  ? 'Tap "Create Backup" above to generate a snapshot.'
                                  : 'Switch category tab or create a new backup.',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return Material(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayedBackups.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final backup = displayedBackups[index];
                          return ListTile(
                            onTap: () => _confirmAndRestore(backup.path),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: backup.isEncrypted
                                    ? Colors.amber.withValues(alpha: 0.15)
                                    : (backup.isAuto
                                        ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                                        : AppColors.primary.withValues(alpha: 0.15)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                backup.isEncrypted
                                    ? Icons.lock_outline_rounded
                                    : (backup.isAuto ? Icons.schedule_rounded : Icons.description_outlined),
                                color: backup.isEncrypted
                                    ? Colors.amber
                                    : (backup.isAuto ? const Color(0xFF6366F1) : AppColors.primary),
                                size: 22,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    backup.fileName,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: backup.isAuto
                                        ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                                        : AppColors.income.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    backup.isAuto ? 'AUTO' : 'MANUAL',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: backup.isAuto ? const Color(0xFF6366F1) : AppColors.income,
                                    ),
                                  ),
                                ),
                                if (backup.isEncrypted) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('AES-256', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
                                  ),
                                ],
                              ],
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
                    );
                  }(),

                  const SizedBox(height: 24),

                  // ─── Automatic Backups & Retention ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Automatic Backups & Retention', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      TextButton.icon(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.play_circle_outline_rounded, size: 16, color: Color(0xFF6366F1)),
                        label: const Text('Run Auto-Backup Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                        onPressed: _handleRunAutoBackupNow,
                      ),
                    ],
                  ),
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: const Icon(Icons.schedule_rounded, color: AppColors.primary),
                          title: const Text('Auto-Backup Frequency', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _autoFrequency == 'daily'
                                    ? 'Runs every 24 hours on launch/resume'
                                    : _autoFrequency == 'weekly'
                                        ? 'Runs every 7 days on launch/resume'
                                        : 'Off (Manual backups only)',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _lastAutoBackupTime != null
                                    ? 'Last run: ${DateFormat('MMM d, yyyy • hh:mm a').format(_lastAutoBackupTime!)}'
                                    : 'Last run: Never executed yet',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primary),
                              ),
                            ],
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: const Icon(Icons.auto_delete_outlined, color: AppColors.warning),
                          title: const Text('Max Backups to Keep', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: const Text('Only auto-backups are pruned. Manual backups are never deleted automatically.', style: TextStyle(fontSize: 12, color: Colors.grey)),
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

class _PasswordPromptSheet extends StatefulWidget {
  final String title;
  final String description;
  final bool isNew;

  const _PasswordPromptSheet({
    required this.title,
    required this.description,
    this.isNew = false,
  });

  @override
  State<_PasswordPromptSheet> createState() => _PasswordPromptSheetState();
}

class _PasswordPromptSheetState extends State<_PasswordPromptSheet> {
  final _controller = TextEditingController();
  bool _obscureText = true;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      setState(() => _errorText = 'Password cannot be empty');
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lock_outline_rounded, color: Colors.amber, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.description,
                style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                obscureText: _obscureText,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: widget.isNew ? 'Set Backup Password' : 'Enter Password',
                  prefixIcon: const Icon(Icons.password_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                  errorText: _errorText,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isNew ? AppColors.primary : Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _submit,
                child: Text(
                  widget.isNew ? 'Encrypt & Save' : 'Unlock',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestoreConfirmSheet extends StatelessWidget {
  final BackupPreview preview;
  final bool isEncrypted;

  const _RestoreConfirmSheet({
    required this.preview,
    required this.isEncrypted,
  });

  Widget _buildStatPill(BuildContext context, IconData icon, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isEncrypted ? Colors.amber : AppColors.primary).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isEncrypted ? Icons.lock_open_rounded : Icons.settings_backup_restore_rounded,
                      color: isEncrypted ? Colors.amber : AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Confirm Restore',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Created on ${DateFormat('MMM d, yyyy • hh:mm a').format(preview.exportDate)}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Text('Backup Contains:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatPill(context, Icons.receipt_long_rounded, 'Transactions', preview.transactionCount, AppColors.primary),
                  _buildStatPill(context, Icons.account_balance_wallet_rounded, 'Accounts', preview.accountCount, Colors.indigo),
                  _buildStatPill(context, Icons.category_rounded, 'Categories', preview.categoryCount, Colors.teal),
                  _buildStatPill(context, Icons.pie_chart_rounded, 'Budgets', preview.budgetCount, Colors.orange),
                  _buildStatPill(context, Icons.handshake_rounded, 'Debts', preview.debtCount, Colors.purple),
                  _buildStatPill(context, Icons.savings_rounded, 'Goals', preview.goalCount, Colors.pink),
                  _buildStatPill(context, Icons.calendar_month_rounded, 'Subscriptions', preview.subscriptionCount, Colors.cyan),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.expense.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Restoring will overwrite all current local data with this backup archive.',
                        style: TextStyle(fontSize: 13, color: AppColors.expense, fontWeight: FontWeight.w600, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.expense,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Replace & Restore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
