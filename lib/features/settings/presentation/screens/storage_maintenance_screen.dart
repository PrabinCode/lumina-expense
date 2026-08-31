import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_maintenance_service.dart';
import '../../../../core/theme/app_colors.dart';

class StorageMaintenanceScreen extends ConsumerStatefulWidget {
  const StorageMaintenanceScreen({super.key});

  @override
  ConsumerState<StorageMaintenanceScreen> createState() => _StorageMaintenanceScreenState();
}

class _StorageMaintenanceScreenState extends ConsumerState<StorageMaintenanceScreen> {
  StorageStats? _stats;
  bool _isLoading = true;
  bool _isOptimizing = false;
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
                ? '✅ Optimization complete! Reclaimed ${_stats?.formatBytes(reclaimed) ?? "$reclaimed B"} of disk space.'
                : '✅ Database pages defragmented and index statistics updated.',
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
        ),
      );
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
                  // Storage Summary Card
                  Container(
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
                                _stats?.formatBytes(_stats!.totalSizeBytes) ?? '0 B',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricTile(
                                icon: Icons.storage_rounded,
                                label: 'SQLite DB',
                                value: _stats?.formatBytes(_stats!.databaseSizeBytes) ?? '0 B',
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricTile(
                                icon: Icons.folder_zip_outlined,
                                label: 'Cache & Exports',
                                value: _stats?.formatBytes(_stats!.cacheSizeBytes) ?? '0 B',
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions Section
                  const Text(
                    'Optimization & Diagnostics',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 12),

                  // VACUUM & ANALYZE Button
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _isOptimizing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            : const Icon(Icons.speed_rounded, color: AppColors.primary, size: 22),
                      ),
                      title: const Text('Optimize Database (VACUUM & ANALYZE)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Defragment SQLite pages, reclaim disk space, and refresh query indexes.', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: _isOptimizing ? null : _runOptimization,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // SQLite Integrity Check
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.verified_outlined, color: Colors.blue, size: 22),
                      ),
                      title: const Text('Check Database Integrity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(
                        _integrityStatus != null
                            ? 'PRAGMA Status: ${_integrityStatus == "ok" ? "PASSED (Healthy) ✅" : _integrityStatus}'
                            : 'Run low-level SQLite B-Tree and index validation.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _integrityStatus == "ok" ? AppColors.primary : null,
                          fontWeight: _integrityStatus != null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: _runIntegrityCheck,
                        child: const Text('Verify', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Cache Purge
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.cleaning_services_outlined, color: Colors.amber, size: 22),
                      ),
                      title: const Text('Clean Temporary Files & Cache', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('Purges temporary export files and share sheet staging folders.', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: _cleanCache,
                    ),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
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
