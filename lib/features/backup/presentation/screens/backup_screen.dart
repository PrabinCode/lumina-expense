import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/services/app_review_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sonner_toast.dart';
import '../../../accounts/data/account_repository.dart';
import '../../../budgets/data/budget_repository.dart';
import '../../../categories/data/category_repository.dart';
import '../../../debts/data/debt_repository.dart';
import '../../../goals/data/goal_repository.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../../recycle_bin/data/recycle_bin_repository.dart';
import '../../../subscriptions/data/subscription_repository.dart';
import '../../../transactions/data/transaction_repository.dart';
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
  bool _includeReceipts = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final service = ref.read(backupRestoreServiceProvider);
      final path = await service.getBackupStorageDirectory();
      final backups = await service.listLocalBackups();
      final freq = await service.getAutoBackupFrequency();
      final maxF = await service.getMaxBackupFiles();
      final lastAuto = await service.getLastAutoBackupTime();
      final incReceipts = await service.getIncludeReceipts();

      if (mounted) {
        setState(() {
          _storagePath = path;
          _localBackups = backups;
          _autoFrequency = freq;
          _maxBackups = maxF;
          _lastAutoBackupTime = lastAuto;
          _includeReceipts = incReceipts;
        });
      }
    } catch (e) {
      debugPrint('Error loading backup screen data: $e');
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
        Sonner.success('Auto-Backup Completed', description: 'Saved to: $path');
      }
    } catch (e) {
      if (mounted) {
        Sonner.error('Auto-Backup Failed', description: e.toString());
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
        Sonner.success('Storage Location Updated', description: newPath);
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

  Future<List<String>?> _promptProfileSelectionForBackup(List<UserProfile> profiles) async {
    if (profiles.length <= 1) return null;

    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BackupProfileSelectionSheet(profiles: profiles),
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
                  subtitle: const Text('Password-protected AES-256 archive (includes receipts)', style: TextStyle(fontSize: 12)),
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
                    child: const Icon(Icons.archive_outlined, color: AppColors.primary),
                  ),
                  title: const Text('Full Backup Archive (.lumina)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Complete database + receipt photos archive', style: TextStyle(fontSize: 12)),
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

    final profiles = await ref.read(allProfilesProvider.future);
    List<String>? selectedProfileIds;
    if (profiles.length > 1) {
      if (!mounted) return;
      selectedProfileIds = await _promptProfileSelectionForBackup(profiles);
      if (selectedProfileIds == null) return;
    }

    String? password;
    if (choice == 'encrypted') {
      if (!mounted) return;
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
      final path = await service.createBackup(
        password: password,
        selectedProfileIds: selectedProfileIds,
      );
      await _loadData();
      ref.read(appReviewServiceProvider).recordBackupCompleted();
      if (mounted) {
        Sonner.success(
          choice == 'encrypted' ? 'Encrypted Backup Created' : 'Backup Created',
          description: 'Saved to: $path',
        );
      }
    } catch (e) {
      if (mounted) {
        Sonner.error('Backup Creation Failed', description: e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleExportExcel() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(backupRestoreServiceProvider);
      final path = await service.createExcelExport();
      if (mounted) {
        Sonner.success('Excel Workbook Exported', description: 'Saved to: $path');
      }
    } catch (e) {
      if (mounted) {
        Sonner.error('Excel Export Failed', description: e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleShareExcel() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(backupRestoreServiceProvider).exportExcelWorkbook();
    } catch (e) {
      if (mounted) {
        Sonner.error('Excel Share Failed', description: e.toString());
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
        Sonner.success('CSV Exported', description: 'Saved to: $path');
      }
    } catch (e) {
      if (mounted) {
        Sonner.error('CSV Export Failed', description: e.toString());
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
                    child: const Icon(Icons.archive_outlined, color: AppColors.primary),
                  ),
                  title: const Text('Full Backup Archive (.lumina)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Complete database + receipt photos archive', style: TextStyle(fontSize: 12)),
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

    final profiles = await ref.read(allProfilesProvider.future);
    List<String>? selectedProfileIds;
    if (profiles.length > 1) {
      if (!mounted) return;
      selectedProfileIds = await _promptProfileSelectionForBackup(profiles);
      if (selectedProfileIds == null) return;
    }

    String? password;
    if (choice == 'encrypted') {
      if (!mounted) return;
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
            selectedProfileIds: selectedProfileIds,
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
        Sonner.error('CSV Export Failed', description: e.toString());
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

      final selection = await showModalBottomSheet<RestoreSelection>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _RestoreConfirmSheet(
          preview: preview,
          isEncrypted: password != null,
        ),
      );

      if (selection != null) {
        await service.restoreFromFile(
          filePath,
          password: password,
          selectedProfileIds: selection.selectedProfileIds,
          strategy: selection.strategy,
        );

        // Fetch valid profiles from database after restore
        final allProfiles = await ref.read(profileRepositoryProvider).getAllProfiles();
        UserProfile targetProfile = allProfiles.firstWhere((p) => p.isDefault, orElse: () => allProfiles.first);
        if (allProfiles.isNotEmpty) {
          final currentActiveId = ref.read(activeProfileIdProvider);
          final currentExists = allProfiles.any((p) => p.id == currentActiveId);
          if (currentExists) {
            final txCount = await ref.read(profileRepositoryProvider).getTransactionCountForProfile(currentActiveId);
            if (txCount > 0) {
              targetProfile = allProfiles.firstWhere((p) => p.id == currentActiveId);
            } else {
              UserProfile? populatedProfile;
              for (final p in allProfiles) {
                final count = await ref.read(profileRepositoryProvider).getTransactionCountForProfile(p.id);
                if (count > 0) {
                  populatedProfile = p;
                  break;
                }
              }
              targetProfile = populatedProfile ?? targetProfile;
            }
          } else {
            UserProfile? populatedProfile;
            for (final p in allProfiles) {
              final count = await ref.read(profileRepositoryProvider).getTransactionCountForProfile(p.id);
              if (count > 0) {
                populatedProfile = p;
                break;
              }
            }
            targetProfile = populatedProfile ?? targetProfile;
          }

          // Force set active profile and synchronize currency
          await ref.read(activeProfileIdProvider.notifier).setActiveProfileId(targetProfile.id, force: true);
        }

        // Invalidate all app providers
        ref.invalidate(allProfilesProvider);
        ref.invalidate(activeProfileIdProvider);
        ref.invalidate(activeProfileProvider);
        ref.invalidate(transactionRepositoryProvider);
        ref.invalidate(recentTransactionsStreamProvider);
        ref.invalidate(currentMonthSummaryStreamProvider);
        ref.invalidate(accountRepositoryProvider);
        ref.invalidate(budgetRepositoryProvider);
        ref.invalidate(categoryRepositoryProvider);
        ref.invalidate(debtRepositoryProvider);
        ref.invalidate(goalRepositoryProvider);
        ref.invalidate(subscriptionRepositoryProvider);
        ref.invalidate(recycleBinRepositoryProvider);
        ref.invalidate(currencyProvider);

        await _loadData();

        if (mounted) {
          final restoredTxCount = allProfiles.isNotEmpty
              ? await ref.read(profileRepositoryProvider).getTransactionCountForProfile(targetProfile.id)
              : 0;
          Sonner.success(
            'Database Restored Successfully',
            description: 'Active profile: ${targetProfile.name} • $restoredTxCount transactions loaded',
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
          Sonner.error('Restore Error', description: e.toString());
        }
      }

    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _handleRestoreFromFilePicker() async {
    try {
      final filePath = await ref.read(backupRestoreServiceProvider).pickBackupFilePath();
      if (filePath == null) return;
      await _confirmAndRestore(filePath);
    } catch (e) {
      if (mounted) {
        Sonner.error('File Error', description: e.toString());
      }
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
        Sonner.success('Backup file deleted');
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
      final defProfile = await ref.read(profileRepositoryProvider).getDefaultProfile();
      if (defProfile != null) {
        await ref.read(activeProfileIdProvider.notifier).setActiveProfileId(defProfile.id, force: true);
      }
      ref.invalidate(allProfilesProvider);
      ref.invalidate(activeProfileIdProvider);
      ref.invalidate(activeProfileProvider);
      ref.invalidate(transactionRepositoryProvider);
      ref.invalidate(recentTransactionsStreamProvider);
      ref.invalidate(currentMonthSummaryStreamProvider);
      ref.invalidate(accountRepositoryProvider);
      ref.invalidate(budgetRepositoryProvider);
      ref.invalidate(categoryRepositoryProvider);
      ref.invalidate(debtRepositoryProvider);
      ref.invalidate(goalRepositoryProvider);
      ref.invalidate(subscriptionRepositoryProvider);
      ref.invalidate(recycleBinRepositoryProvider);
      ref.invalidate(currencyProvider);
      await _loadData();
      if (mounted) {
        setState(() => _isLoading = false);
        Sonner.success(
          'Sample Data Populated',
          description: '4 accounts, 25+ transactions, budgets & goals loaded',
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

                  // ─── Actions Section (Create Backup / Excel / CSV) ───
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
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                          ),
                          icon: const Icon(Icons.table_chart_rounded, size: 20, color: Color(0xFF10B981)),
                          label: const Text('Export Excel (.xlsx)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF10B981))),
                          onPressed: _handleExportExcel,
                        ),
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
                          icon: const Icon(Icons.share_rounded, size: 15, color: Color(0xFF10B981)),
                          label: const Text('Share Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          onPressed: _handleShareExcel,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 15, color: AppColors.transfer),
                          label: const Text('Share Backup', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          onPressed: _handleShareJson,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.table_view_rounded, size: 15, color: Color(0xFF6366F1)),
                          label: const Text('Export CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          onPressed: _handleExportCsv,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.share_outlined, size: 15, color: Color(0xFF6366F1)),
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
                    children: [
                      Expanded(
                        child: Text(
                          'Saved Backups (${_localBackups.length})',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.file_open_outlined, size: 15),
                        label: const Text('Browse File...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                                if (backup.isContainer) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.pink.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('ZIP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.pink)),
                                  ),
                                ],
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
                    children: [
                      const Expanded(
                        child: Text(
                          'Automatic Backups & Retention',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.play_circle_outline_rounded, size: 15, color: Color(0xFF6366F1)),
                        label: const Text('Run Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
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
                        const Divider(height: 1),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          secondary: const Icon(Icons.photo_library_outlined, color: Colors.pinkAccent),
                          title: const Text('Include Receipt Photos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: const Text('Bundle attached receipt images in new backups (.lumina / .lumina.enc)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          value: _includeReceipts,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) async {
                            final service = ref.read(backupRestoreServiceProvider);
                            await service.setIncludeReceipts(val);
                            setState(() => _includeReceipts = val);
                          },
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

class RestoreSelection {
  final List<String> selectedProfileIds;
  final RestoreStrategy strategy;

  const RestoreSelection({
    required this.selectedProfileIds,
    required this.strategy,
  });
}

class _RestoreConfirmSheet extends ConsumerStatefulWidget {
  final BackupPreview preview;
  final bool isEncrypted;

  const _RestoreConfirmSheet({
    required this.preview,
    required this.isEncrypted,
  });

  @override
  ConsumerState<_RestoreConfirmSheet> createState() => _RestoreConfirmSheetState();
}

class _RestoreConfirmSheetState extends ConsumerState<_RestoreConfirmSheet> {
  late Set<String> _selectedProfileIds;
  RestoreStrategy _strategy = RestoreStrategy.cleanSlate;

  @override
  void initState() {
    super.initState();
    _selectedProfileIds = widget.preview.profiles.map((p) => p.id).toSet();
  }

  void _toggleAllProfiles() {
    setState(() {
      if (_selectedProfileIds.length == widget.preview.profiles.length) {
        _selectedProfileIds.clear();
      } else {
        _selectedProfileIds = widget.preview.profiles.map((p) => p.id).toSet();
      }
    });
  }

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
    final profiles = widget.preview.profiles;
    final isCleanSlate = _strategy == RestoreStrategy.cleanSlate;
    final currentProfiles = ref.watch(allProfilesProvider).valueOrNull ?? [];

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
                      color: (widget.isEncrypted ? Colors.amber : AppColors.primary).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.isEncrypted ? Icons.lock_open_rounded : Icons.settings_backup_restore_rounded,
                      color: widget.isEncrypted ? Colors.amber : AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Restore Backup',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Created on ${DateFormat('MMM d, yyyy • hh:mm a').format(widget.preview.exportDate)}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Text('Archive Overview:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatPill(context, Icons.receipt_long_rounded, 'Transactions', widget.preview.transactionCount, AppColors.primary),
                  _buildStatPill(context, Icons.account_balance_wallet_rounded, 'Accounts', widget.preview.accountCount, Colors.indigo),
                  _buildStatPill(context, Icons.category_rounded, 'Categories', widget.preview.categoryCount, Colors.teal),
                  _buildStatPill(context, Icons.pie_chart_rounded, 'Budgets', widget.preview.budgetCount, Colors.orange),
                  _buildStatPill(context, Icons.handshake_rounded, 'Debts', widget.preview.debtCount, Colors.purple),
                  _buildStatPill(context, Icons.savings_rounded, 'Goals', widget.preview.goalCount, Colors.pink),
                  _buildStatPill(context, Icons.calendar_month_rounded, 'Subscriptions', widget.preview.subscriptionCount, Colors.cyan),
                  if (widget.preview.hasImages || widget.preview.receiptCount > 0)
                    _buildStatPill(
                      context,
                      Icons.photo_library_rounded,
                      widget.preview.receiptCount == 1 ? 'Receipt (${widget.preview.formattedReceiptSize})' : 'Receipts (${widget.preview.formattedReceiptSize})',
                      widget.preview.receiptCount,
                      Colors.pinkAccent,
                    ),
                ],
              ),

              // ─── Device vs Backup Profiles Context Banner ───
              if (currentProfiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.devices_rounded, size: 20, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Device: ${currentProfiles.length} Profile${currentProfiles.length > 1 ? "s" : ""} on Phone (${currentProfiles.map((p) => p.name).join(", ")})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profiles.length != currentProfiles.length
                                  ? 'This backup contains ${profiles.length} profile${profiles.length > 1 ? "s" : ""} (${profiles.map((p) => p.name).join(", ")}). To preserve your existing profiles on this device, select "Merge Data" below.'
                                  : 'This backup contains ${profiles.length} profile${profiles.length > 1 ? "s" : ""} (${profiles.map((p) => p.name).join(", ")}).',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white70 : Colors.black87,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (profiles.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profiles in Backup (${_selectedProfileIds.length}/${profiles.length})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    if (profiles.length > 1)
                      TextButton(
                        onPressed: _toggleAllProfiles,
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        child: Text(
                          _selectedProfileIds.length == profiles.length ? 'Deselect All' : 'Select All',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.28),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: profiles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final p = profiles[index];
                      final isChecked = _selectedProfileIds.contains(p.id);
                      final profileColor = Color(p.color);
                      final existsLocally = currentProfiles.any((lp) => lp.id == p.id);
                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isChecked) {
                              _selectedProfileIds.remove(p.id);
                            } else {
                              _selectedProfileIds.add(p.id);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isChecked ? profileColor : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: profileColor.withValues(alpha: 0.15),
                                child: Icon(IconHelper.getProfileIcon(p.icon), size: 18, color: profileColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            p.name,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: profileColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            p.currency,
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: profileColor),
                                          ),
                                        ),
                                        if (existsLocally) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'On Device',
                                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.green),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          '${p.accountCount} accounts • ',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                        Text(
                                          '${p.transactionCount} transactions',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: p.transactionCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                            color: p.transactionCount > 0
                                                ? (isDark ? Colors.tealAccent : Colors.teal)
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Checkbox(
                                value: isChecked,
                                activeColor: profileColor,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedProfileIds.add(p.id);
                                    } else {
                                      _selectedProfileIds.remove(p.id);
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const Text('Restore Strategy:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _strategy = RestoreStrategy.cleanSlate),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCleanSlate
                              ? AppColors.expense.withValues(alpha: 0.12)
                              : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCleanSlate ? AppColors.expense : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.cleaning_services_rounded,
                              size: 20,
                              color: isCleanSlate ? AppColors.expense : Colors.grey,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Clean Slate',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isCleanSlate ? AppColors.expense : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Replace local data',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _strategy = RestoreStrategy.merge),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: !isCleanSlate
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: !isCleanSlate ? AppColors.primary : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.merge_type_rounded,
                              size: 20,
                              color: !isCleanSlate ? AppColors.primary : Colors.grey,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Merge Data',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: !isCleanSlate ? AppColors.primary : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Keep existing profiles',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isCleanSlate ? AppColors.expense : AppColors.primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isCleanSlate ? AppColors.expense : AppColors.primary).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isCleanSlate ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                      color: isCleanSlate ? AppColors.expense : AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isCleanSlate
                            ? (currentProfiles.length > profiles.length
                                ? 'Clean Slate: All current data on this device (${currentProfiles.length} profiles: ${currentProfiles.map((p) => p.name).join(", ")}) will be wiped and replaced with the selected backup profile(s).'
                                : 'Clean Slate: All current data on this device will be cleared and replaced by the selected profiles.')
                            : (currentProfiles.isNotEmpty
                                ? 'Merge Mode: Selected profiles and their records will be imported without deleting your existing profiles (${currentProfiles.map((p) => p.name).join(", ")}).'
                                : 'Merge Mode: Selected profiles and their records will be imported without deleting your existing profiles.'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isCleanSlate ? AppColors.expense : AppColors.primary,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCleanSlate ? AppColors.expense : AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _selectedProfileIds.isEmpty
                    ? null
                    : () {
                        Navigator.pop(
                          context,
                          RestoreSelection(
                            selectedProfileIds: _selectedProfileIds.toList(),
                            strategy: _strategy,
                          ),
                        );
                      },
                child: Text(
                  _selectedProfileIds.isEmpty
                      ? 'Select at least 1 profile'
                      : 'Restore (${_selectedProfileIds.length} ${_selectedProfileIds.length == 1 ? 'Profile' : 'Profiles'})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
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

class _BackupProfileSelectionSheet extends StatefulWidget {
  final List<UserProfile> profiles;

  const _BackupProfileSelectionSheet({required this.profiles});

  @override
  State<_BackupProfileSelectionSheet> createState() => _BackupProfileSelectionSheetState();
}

class _BackupProfileSelectionSheetState extends State<_BackupProfileSelectionSheet> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.profiles.map((p) => p.id).toSet();
  }

  void _toggleAll() {
    setState(() {
      if (_selectedIds.length == widget.profiles.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = widget.profiles.map((p) => p.id).toSet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                  child: const Icon(Icons.group_work_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Profiles to Back Up',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Choose which profiles to include in this backup',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _toggleAll,
                  child: Text(
                    _selectedIds.length == widget.profiles.length ? 'Deselect All' : 'Select All',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.profiles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final profile = widget.profiles[index];
                  final isChecked = _selectedIds.contains(profile.id);
                  final profileColor = Color(profile.color);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isChecked) {
                          _selectedIds.remove(profile.id);
                        } else {
                          _selectedIds.add(profile.id);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isChecked ? profileColor : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: profileColor.withValues(alpha: 0.15),
                            child: Icon(
                              IconHelper.getProfileIcon(profile.icon),
                              size: 18,
                              color: profileColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        profile.name,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (profile.isDefault) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('Default', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Currency: ${profile.currency}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Checkbox(
                            value: isChecked,
                            activeColor: profileColor,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedIds.add(profile.id);
                                } else {
                                  _selectedIds.remove(profile.id);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () => Navigator.pop(context, _selectedIds.toList()),
              child: Text(
                'Continue with ${_selectedIds.length} ${_selectedIds.length == 1 ? "Profile" : "Profiles"}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
