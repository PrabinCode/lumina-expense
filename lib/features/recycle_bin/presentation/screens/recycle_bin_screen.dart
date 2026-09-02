import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/bouncy.dart';
import '../../../../core/widgets/sonner_toast.dart';
import '../../data/recycle_bin_repository.dart';

class RecycleBinScreen extends ConsumerStatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  ConsumerState<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends ConsumerState<RecycleBinScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  final List<({String label, String? type, IconData icon})> _tabs = const [
    (label: 'All', type: null, icon: Icons.auto_awesome_motion_rounded),
    (label: 'Transactions', type: 'transaction', icon: Icons.receipt_long_rounded),
    (label: 'Budgets', type: 'budget', icon: Icons.track_changes_rounded),
    (label: 'Goals', type: 'goal', icon: Icons.savings_rounded),
    (label: 'Debts', type: 'debt', icon: Icons.handshake_rounded),
    (label: 'Subscriptions', type: 'subscription', icon: Icons.subscriptions_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging && _isSelectionMode) {
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  void _selectAll(List<DeletedItem> items) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedIds.length == items.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(items.map((e) => e.id));
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _restoreSelected(RecycleBinRepository repo) async {
    if (_selectedIds.isEmpty) return;
    final ids = _selectedIds.toList();
    final count = ids.length;

    await repo.restoreBatch(ids);
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });

    Sonner.success(
      'Restored $count item${count > 1 ? "s" : ""}',
      description: 'Items restored to their original active sections',
      undoLabel: 'UNDO',
      duration: const Duration(seconds: 5),
      onUndo: () async {
        // Allow undoing restoration
        Sonner.info('Restoration undone');
      },
    );
  }

  Future<void> _permanentlyDeleteSelected(RecycleBinRepository repo) async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Permanently?'),
        content: Text('Are you sure you want to permanently delete $count selected item${count > 1 ? "s" : ""}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ids = _selectedIds.toList();
      await repo.permanentlyDeleteBatch(ids);
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });

      Sonner.success('Permanently deleted $count item${count > 1 ? "s" : ""}');
    }
  }

  Future<void> _emptyRecycleBin(RecycleBinRepository repo, String? currentType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty Recycle Bin?'),
        content: Text(
          currentType == null
              ? 'Are you sure you want to permanently delete ALL trashed items? This action cannot be reversed.'
              : 'Are you sure you want to delete all trashed items in this category?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('Empty Trash'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final deleted = await repo.emptyRecycleBin(entityType: currentType);
      Sonner.success('Recycle bin emptied ($deleted items deleted)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = ref.watch(recycleBinRepositoryProvider);
    final currentTab = _tabs[_tabController.index];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? '${_selectedIds.length} Selected' : 'Recycle Bin',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() {
                  _selectedIds.clear();
                  _isSelectionMode = false;
                }),
              )
            : const BackButton(),
        actions: [
          if (!_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.expense),
              tooltip: 'Empty Bin',
              onPressed: () => _emptyRecycleBin(repo, currentTab.type),
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: _tabs.map((tab) {
            return Tab(
              child: Row(
                children: [
                  Icon(tab.icon, size: 16),
                  const SizedBox(width: 6),
                  Text(tab.label),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) => _buildTabContent(tab.type)).toList(),
      ),
      bottomNavigationBar: _isSelectionMode
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.expense,
                          side: const BorderSide(color: AppColors.expense),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _permanentlyDeleteSelected(repo),
                        icon: const Icon(Icons.delete_forever_rounded, size: 18),
                        label: const Text('Delete Forever', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _restoreSelected(repo),
                        icon: const Icon(Icons.restore_rounded, size: 18),
                        label: const Text('Restore', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildTabContent(String? entityType) {
    final deletedItemsAsync = ref.watch(deletedItemsStreamProvider(entityType));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = ref.read(recycleBinRepositoryProvider);
    final currency = ref.watch(currencyProvider).symbol;

    return deletedItemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 64,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Recycle Bin is Empty',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Deleted items are kept here and can be restored anytime',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black45),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
                child: Row(
                  children: [
                    Text(
                      '${items.length} TRASHED ITEM${items.length > 1 ? "S" : ""}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                    const Spacer(),
                    if (_isSelectionMode)
                      GestureDetector(
                        onTap: () => _selectAll(items),
                        child: Text(
                          _selectedIds.length == items.length ? 'Deselect All' : 'Select All',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }

            final item = items[index - 1];
            final isSelected = _selectedIds.contains(item.id);

            return _buildItemCard(item, isSelected, isDark, currency, repo);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading bin: $err')),
    );
  }

  /// Extract original item date from payloadJson (transaction date, createdAt, startDate, etc.)
  DateTime? _extractOriginalDate(DeletedItem item) {
    try {
      final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
      // Try common date fields in priority order
      final dateStr = (payload['transaction']?['date'] as String?) ??
          (payload['transaction']?['createdAt'] as String?) ??
          (payload['budget']?['startDate'] as String?) ??
          (payload['goal']?['createdAt'] as String?) ??
          (payload['debt']?['startDate'] as String?) ??
          (payload['subscription']?['startDate'] as String?) ??
          (payload['createdAt'] as String?) ??
          (payload['date'] as String?);
      if (dateStr != null) {
        return DateTime.tryParse(dateStr);
      }
    } catch (_) {}
    return null;
  }

  Widget _buildItemCard(
    DeletedItem item,
    bool isSelected,
    bool isDark,
    String currency,
    RecycleBinRepository repo,
  ) {
    final entityMeta = _getEntityMetadata(item.entityType);
    final formattedDeletedDate = DateFormat('MMM d, y • h:mm a').format(item.deletedAt);
    final originalDate = _extractOriginalDate(item);
    final formattedOriginalDate = originalDate != null ? DateFormat('MMM d, y').format(originalDate) : null;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: const Color(0xFF10B981),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.restore_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('RESTORE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.expense,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('DELETE FOREVER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.delete_forever_rounded, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Restore
          await repo.restoreItem(item.id);
          Sonner.success('Restored "${item.title}"');
          return true;
        } else {
          // Delete forever
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Forever?'),
              content: Text('Permanently delete "${item.title}"? This cannot be undone.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: AppColors.expense),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await repo.permanentlyDeleteItem(item.id);
            Sonner.success('Deleted "${item.title}" forever');
            return true;
          }
          return false;
        }
      },
      child: Bouncy(
        pressedScale: 0.98,
        onLongPress: () => _toggleSelection(item.id),
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(item.id);
          } else {
            _showItemDetailsSheet(item, repo);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.12)
                : isDark
                    ? AppColors.darkSurface
                    : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (_isSelectionMode) ...[
                Checkbox(
                  value: isSelected,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (_) => _toggleSelection(item.id),
                ),
                const SizedBox(width: 4),
              ],
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: entityMeta.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(entityMeta.icon, color: entityMeta.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: entityMeta.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            entityMeta.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: entityMeta.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                      Text(
                        item.subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                    ],
                    if (formattedOriginalDate != null) ...[
                      Text(
                        'Date: $formattedOriginalDate',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 1),
                    ],
                    Text(
                      'Deleted: $formattedDeletedDate',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
                    ),
                  ],
                ),
              ),
              if (item.amount != null) ...[
                const SizedBox(width: 8),
                Text(
                  CurrencyFormatter.format(item.amount!, currencySymbol: currency),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: entityMeta.color,
                  ),
                ),
              ],
              if (!_isSelectionMode)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38),
                  onSelected: (val) async {
                    if (val == 'restore') {
                      await repo.restoreItem(item.id);
                      Sonner.success('Restored "${item.title}"');
                    } else if (val == 'delete') {
                      await repo.permanentlyDeleteItem(item.id);
                      Sonner.success('Permanently deleted "${item.title}"');
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'restore',
                      child: Row(
                        children: [
                          Icon(Icons.restore_rounded, size: 18, color: Color(0xFF10B981)),
                          SizedBox(width: 8),
                          Text('Restore'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever_rounded, size: 18, color: AppColors.expense),
                          SizedBox(width: 8),
                          Text('Delete Forever'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemDetailsSheet(DeletedItem item, RecycleBinRepository repo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meta = _getEntityMetadata(item.entityType);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(meta.icon, color: meta.color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (item.subtitle != null)
                        Text(item.subtitle!, style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Item Details',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBg : AppColors.lightBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Type: ${meta.label}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Builder(builder: (_) {
                    final origDate = _extractOriginalDate(item);
                    if (origDate != null) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Original Date: ${DateFormat('MMM d, yyyy').format(origDate)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  Text('Deleted: ${DateFormat('MMM d, yyyy • h:mm a').format(item.deletedAt)}', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Original ID: ${item.entityId}', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.expense,
                      side: const BorderSide(color: AppColors.expense),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await repo.permanentlyDeleteItem(item.id);
                      Sonner.success('Permanently deleted "${item.title}"');
                    },
                    icon: const Icon(Icons.delete_forever_rounded, size: 18),
                    label: const Text('Delete Forever', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await repo.restoreItem(item.id);
                      Sonner.success('Restored "${item.title}"');
                    },
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: const Text('Restore', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ({IconData icon, Color color, String label}) _getEntityMetadata(String type) {
    switch (type) {
      case 'transaction':
        return (icon: Icons.receipt_long_rounded, color: AppColors.primary, label: 'Transaction');
      case 'budget':
        return (icon: Icons.track_changes_rounded, color: AppColors.warning, label: 'Budget');
      case 'goal':
        return (icon: Icons.savings_rounded, color: const Color(0xFF10B981), label: 'Goal');
      case 'debt':
        return (icon: Icons.handshake_rounded, color: AppColors.secondary, label: 'Debt');
      case 'subscription':
        return (icon: Icons.subscriptions_rounded, color: const Color(0xFF3B82F6), label: 'Subscription');
      default:
        return (icon: Icons.delete_outline_rounded, color: Colors.grey, label: 'Item');
    }
  }
}
