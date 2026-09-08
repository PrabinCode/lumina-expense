import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_maintenance_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../backup/services/backup_restore_service.dart';

class StorageMaintenanceScreen extends ConsumerStatefulWidget {
  const StorageMaintenanceScreen({super.key});

  @override
  ConsumerState<StorageMaintenanceScreen> createState() => _StorageMaintenanceScreenState();
}

class _StorageMaintenanceScreenState extends ConsumerState<StorageMaintenanceScreen> {
  StorageStats? _stats;
  bool _isLoading = true;
  bool _isOptimizing = false;
  bool _isSeeding = false;
  String? _integrityStatus;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final service = ref.read(databaseMaintenanceServiceProvider);
    final stats = await service.getStorageStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  Future<void> _runOptimization() async {
    setState(() => _isOptimizing = true);
    final service = ref.read(databaseMaintenanceServiceProvider);
    final reclaimed = await service.runVacuumAndAnalyze();
    await _loadStats();
    if (mounted) {
      setState(() => _isOptimizing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reclaimed > 0
                ? '✅ WAL Checkpointed & VACUUM complete! Reclaimed ${_stats?.formatBytes(reclaimed) ?? "$reclaimed B"}.'
                : '✅ WAL truncated, database defragmented, and query statistics updated.',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _runIntegrityCheck() async {
    final service = ref.read(databaseMaintenanceServiceProvider);
    final status = await service.checkIntegrity();
    if (mounted) {
      setState(() => _integrityStatus = status);
    }
  }

  Future<void> _cleanCache() async {
    final service = ref.read(databaseMaintenanceServiceProvider);
    final purged = await service.cleanCache();
    await _loadStats();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ Cache cleared! Purged ${_stats?.formatBytes(purged) ?? "$purged B"}.'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _cleanOrphanedReceipts() async {
    final service = ref.read(databaseMaintenanceServiceProvider);
    final result = await service.cleanOrphanedReceipts();
    await _loadStats();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.purgedCount > 0
                ? '🧹 Cleaned ${result.purgedCount} orphaned receipt image(s) (${_stats?.formatBytes(result.purgedBytes) ?? ""}).'
                : '✨ No orphaned receipt images found. Storage is clean.',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _emptyRecycleBin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty Recycle Bin?'),
        content: const Text(
          'This will permanently delete all soft-deleted transactions, budgets, debts, and goals. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Empty Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final service = ref.read(databaseMaintenanceServiceProvider);
      final count = await service.emptyRecycleBin();
      await _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ Emptied recycle bin ($count items permanently removed).'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  Future<void> _populateDemoData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_fix_high_rounded, color: AppColors.income),
            SizedBox(width: 8),
            Text('Populate Sample Demo Data?'),
          ],
        ),
        content: const Text(
          'This will seed a comprehensive, realistic 4-month history of an active power-user:\n\n'
          '• Multiple Wallets (Checking, Savings, Cash, Credit Card)\n'
          '• Multi-month Salaries, Living Expenses & Transfers\n'
          '• 5 Multi-item Split Transactions (Costco, Target, Trips)\n'
          '• Realistic Category Budgets (Healthy, Warning & Exceeded)\n'
          '• Active & Achieved Savings Goals with deposit histories\n'
          '• Settled & Open Debts (IOUs)\n'
          '• Recurring Bills & Subscriptions\n\n'
          'Existing data will be preserved alongside sample records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.income),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Populate Demo Data'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isSeeding = true);
      try {
        final backupService = ref.read(backupRestoreServiceProvider);
        await backupService.seedDemoData();
        await _loadStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Robust 4-month sample demo data successfully loaded!'),
              backgroundColor: AppColors.income,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to populate demo data: $e'),
              backgroundColor: AppColors.expense,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSeeding = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage & Maintenance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Storage Stats',
            onPressed: _loadStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Storage Summary Card with Segmented Bar
                  _buildStorageSummaryCard(isDark),
                  const SizedBox(height: 24),

                  // Actions Section
                  const Text(
                    'Optimization & Cleanup',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 12),

                  // WAL Checkpoint & VACUUM Button
                  _buildActionCard(
                    isDark: isDark,
                    icon: Icons.speed_rounded,
                    iconColor: AppColors.primary,
                    title: 'Optimize Database (WAL Checkpoint & VACUUM)',
                    subtitle: 'Truncates WAL log, defragments SQLite pages, and recalculates index statistics.',
                    trailing: _isOptimizing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: _isOptimizing ? null : _runOptimization,
                  ),
                  const SizedBox(height: 8),

                  // SQLite Integrity Check
                  _buildActionCard(
                    isDark: isDark,
                    icon: Icons.verified_outlined,
                    iconColor: const Color(0xFF3B82F6),
                    title: 'Check Database Integrity',
                    subtitle: _integrityStatus != null
                        ? 'PRAGMA Status: ${_integrityStatus == "ok" ? "PASSED (Healthy) ✅" : _integrityStatus}'
                        : 'Run low-level SQLite B-Tree and index validation.',
                    subtitleColor: _integrityStatus == "ok" ? AppColors.income : null,
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: _runIntegrityCheck,
                      child: const Text('Verify', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Receipt Photos & Orphaned Cleanup
                  _buildActionCard(
                    isDark: isDark,
                    icon: Icons.photo_library_outlined,
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Receipt Photos & Attachments',
                    subtitle: '${_stats?.receiptCount ?? 0} photos (${_stats?.formatBytes(_stats!.receiptsSizeBytes) ?? "0 B"})\n'
                        '${(_stats?.orphanedReceiptCount ?? 0) > 0 ? "⚠️ ${_stats!.orphanedReceiptCount} orphaned images found without linked transactions." : "✨ All receipt files are cleanly linked."}',
                    trailing: (_stats?.orphanedReceiptCount ?? 0) > 0
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.amber.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: _cleanOrphanedReceipts,
                            child: const Text('Clean Orphans', style: TextStyle(fontSize: 11)),
                          )
                        : const Icon(Icons.check_circle_outline_rounded, color: AppColors.income, size: 20),
                    onTap: (_stats?.orphanedReceiptCount ?? 0) > 0 ? _cleanOrphanedReceipts : null,
                  ),
                  const SizedBox(height: 8),

                  // Empty Recycle Bin
                  _buildActionCard(
                    isDark: isDark,
                    icon: Icons.delete_sweep_outlined,
                    iconColor: AppColors.expense,
                    title: 'Empty Recycle Bin',
                    subtitle: '${_stats?.recycleBinCount ?? 0} soft-deleted items awaiting permanent purge.',
                    trailing: (_stats?.recycleBinCount ?? 0) > 0
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: AppColors.expense,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: _emptyRecycleBin,
                            child: const Text('Empty', style: TextStyle(fontSize: 12)),
                          )
                        : const Icon(Icons.done_all_rounded, color: Colors.grey, size: 20),
                    onTap: (_stats?.recycleBinCount ?? 0) > 0 ? _emptyRecycleBin : null,
                  ),
                  const SizedBox(height: 8),

                  // Cache Purge
                  _buildActionCard(
                    isDark: isDark,
                    icon: Icons.cleaning_services_outlined,
                    iconColor: Colors.amber,
                    title: 'Clean Temporary Files & Cache',
                    subtitle: 'Purges temporary export staging files and app cache buffers.',
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: _cleanCache,
                  ),
                  const SizedBox(height: 24),

                  // Demo & Utilities Section
                  const Text(
                    'Demo Data & Utilities',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 12),

                  _buildActionCard(
                    isDark: isDark,
                    icon: Icons.auto_fix_high_rounded,
                    iconColor: AppColors.income,
                    title: 'Populate Realistic Demo Data',
                    subtitle: 'Generates 4-month realistic active user dataset with split transactions, debts, goals, and budgets.',
                    trailing: _isSeeding
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.income),
                          )
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: AppColors.income,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: _isSeeding ? null : _populateDemoData,
                            child: const Text('Populate', style: TextStyle(fontSize: 12)),
                          ),
                    onTap: _isSeeding ? null : _populateDemoData,
                  ),
                  const SizedBox(height: 24),

                  // Database Records Inventory
                  const Text(
                    'Database Records Inventory',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Column(
                      children: [
                        _buildRow('Transactions Recorded', '${_stats?.transactionCount ?? 0}'),
                        const Divider(height: 16),
                        _buildRow('Wallets / Accounts', '${_stats?.accountCount ?? 0}'),
                        const Divider(height: 16),
                        _buildRow('Custom Categories', '${_stats?.categoryCount ?? 0}'),
                        const Divider(height: 16),
                        _buildRow('Active Budgets', '${_stats?.budgetCount ?? 0}'),
                        const Divider(height: 16),
                        _buildRow('Debts & Loans (IOUs)', '${_stats?.debtCount ?? 0}'),
                        const Divider(height: 16),
                        _buildRow('Savings Goals', '${_stats?.goalCount ?? 0}'),
                        const Divider(height: 16),
                        _buildRow('Subscriptions & Bills', '${_stats?.subscriptionCount ?? 0}'),
                        const Divider(height: 16),
                        _buildRow('Recycle Bin (Deleted Items)', '${_stats?.recycleBinCount ?? 0}'),
                        const Divider(height: 16),
                        _buildRow('Receipt Photos on Disk', '${_stats?.receiptCount ?? 0}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildStorageSummaryCard(bool isDark) {
    final stats = _stats;
    final totalBytes = stats?.totalSizeBytes ?? 0;
    final dbBytes = stats?.databaseSizeBytes ?? 0;
    final receiptsBytes = stats?.receiptsSizeBytes ?? 0;
    final cacheBytes = stats?.cacheSizeBytes ?? 0;

    final dbRatio = totalBytes > 0 ? (dbBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
    final receiptsRatio = totalBytes > 0 ? (receiptsBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
    final cacheRatio = totalBytes > 0 ? (cacheBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [Colors.white, const Color(0xFFF1F5F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Disk Storage Footprint',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  stats?.formatBytes(totalBytes) ?? '0 B',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Visual Storage Breakdown Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (dbRatio > 0)
                    Expanded(
                      flex: (dbRatio * 1000).round().clamp(1, 1000),
                      child: Container(color: const Color(0xFF3B82F6)),
                    ),
                  if (receiptsRatio > 0)
                    Expanded(
                      flex: (receiptsRatio * 1000).round().clamp(1, 1000),
                      child: Container(color: const Color(0xFF8B5CF6)),
                    ),
                  if (cacheRatio > 0)
                    Expanded(
                      flex: (cacheRatio * 1000).round().clamp(1, 1000),
                      child: Container(color: const Color(0xFFF59E0B)),
                    ),
                  if (totalBytes == 0)
                    Expanded(
                      child: Container(color: Colors.grey.withValues(alpha: 0.3)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Bar Legend
          Row(
            children: [
              _buildLegendDot(const Color(0xFF3B82F6), 'DB ${(dbRatio * 100).toStringAsFixed(0)}%'),
              const SizedBox(width: 12),
              _buildLegendDot(const Color(0xFF8B5CF6), 'Receipts ${(receiptsRatio * 100).toStringAsFixed(0)}%'),
              const SizedBox(width: 12),
              _buildLegendDot(const Color(0xFFF59E0B), 'Cache ${(cacheRatio * 100).toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Metric Tiles Row
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.storage_rounded,
                  label: 'SQLite DB',
                  value: stats?.formatBytes(dbBytes) ?? '0 B',
                  sub: (stats?.walSizeBytes ?? 0) > 0 ? '+${stats!.formatBytes(stats.walSizeBytes)} WAL' : 'Indexed',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.photo_library_outlined,
                  label: 'Receipts',
                  value: stats?.formatBytes(receiptsBytes) ?? '0 B',
                  sub: '${stats?.receiptCount ?? 0} files',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.folder_zip_outlined,
                  label: 'Cache',
                  value: stats?.formatBytes(cacheBytes) ?? '0 B',
                  sub: 'Temp files',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Color? subtitleColor,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: subtitleColor ?? Colors.grey.shade600,
            fontWeight: subtitleColor != null ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _buildRow(String title, String count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        Text(count, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
