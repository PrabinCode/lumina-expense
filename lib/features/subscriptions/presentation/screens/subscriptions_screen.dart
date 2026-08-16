import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../accounts/data/account_repository.dart';
import '../../../categories/data/category_repository.dart';
import '../../data/subscription_repository.dart';

class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddEditSubscriptionSheet({SubscriptionWithDetails? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddEditSubscriptionModal(existing: existing),
    );
  }

  void _confirmDelete(BuildContext context, SubscriptionWithDetails sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subscription?'),
        content: Text('Are you sure you want to delete "${sub.subscription.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(subscriptionRepositoryProvider).deleteSubscription(sub.subscription.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted "${sub.subscription.title}"')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _logPayment(BuildContext context, SubscriptionWithDetails sub) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Payment Now?'),
        content: Text(
          'This will record a ${CurrencyFormatter.format(sub.subscription.amount)} expense to ${sub.account.name} and advance the next due date.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(subscriptionRepositoryProvider).logSubscriptionPayment(sub.subscription.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Logged payment for "${sub.subscription.title}"')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Confirm & Log'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summaryAsync = ref.watch(subscriptionsSummaryStreamProvider);
    final allSubsAsync = ref.watch(allSubscriptionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions & Bills', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditSubscriptionSheet(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Bill / Sub'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Top Summary Banner
          summaryAsync.when(
            data: (summary) {
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? Colors.black : const Color(0xFF2563EB)).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Committed Monthly Burn',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${CurrencyFormatter.format(summary.totalMonthlyBurn)}/mo',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '${summary.activeCount} Active',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Annual Run Rate: ${CurrencyFormatter.format(summary.totalYearlyBurn)}/yr',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        if (summary.upcomingThisWeekCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${summary.upcomingThisWeekCount} Due this week',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Active'),
              Tab(text: 'Upcoming'),
              Tab(text: 'All / Paused'),
            ],
          ),

          // Subscriptions List
          Expanded(
            child: allSubsAsync.when(
              data: (subs) {
                if (subs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.subscriptions_outlined, size: 54, color: isDark ? Colors.grey[700] : Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text('No subscriptions yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          const Text(
                            'Track recurring bills, streaming services, gym memberships, and rent in one place.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final activeSubs = subs.where((s) => s.subscription.isActive).toList();
                final upcomingSubs = subs.where((s) => s.subscription.isActive && (s.isDueThisWeek || s.isOverdue)).toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSubList(activeSubs, isDark),
                    _buildSubList(upcomingSubs, isDark, emptyMessage: 'No upcoming bills due this week.'),
                    _buildSubList(subs, isDark),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubList(List<SubscriptionWithDetails> items, bool isDark, {String emptyMessage = 'No subscriptions found.'}) {
    if (items.isEmpty) {
      return Center(
        child: Text(emptyMessage, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        final sub = item.subscription;
        final cat = item.category;

        Color statusColor = AppColors.primary;
        String statusText;
        if (item.isOverdue) {
          statusColor = AppColors.expense;
          statusText = 'Overdue (${item.daysUntilDue.abs()}d ago)';
        } else if (item.isDueToday) {
          statusColor = AppColors.warning;
          statusText = 'Due Today';
        } else if (item.daysUntilDue <= 7) {
          statusColor = AppColors.warning;
          statusText = 'Due in ${item.daysUntilDue} days';
        } else {
          statusColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
          statusText = 'Due ${DateFormat('MMM d').format(sub.nextDueDate)}';
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: item.isOverdue
                  ? AppColors.expense.withValues(alpha: 0.5)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color(cat.color).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(IconHelper.getIcon(cat.icon), color: Color(cat.color), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sub.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!sub.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('PAUSED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '${item.account.name} • ${sub.frequency[0].toUpperCase()}${sub.frequency.substring(1)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        if (sub.autoLog) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.bolt_rounded, size: 14, color: AppColors.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(sub.amount),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sub.isActive)
                        InkWell(
                          onTap: () => _logPayment(context, item),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_rounded, size: 13, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text('Log', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                              ],
                            ),
                          ),
                        ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
                        padding: EdgeInsets.zero,
                        onSelected: (val) {
                          if (val == 'edit') {
                            _showAddEditSubscriptionSheet(existing: item);
                          } else if (val == 'toggle') {
                            ref.read(subscriptionRepositoryProvider).toggleSubscriptionActive(sub.id, !sub.isActive);
                          } else if (val == 'delete') {
                            _confirmDelete(context, item);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(sub.isActive ? 'Pause' : 'Resume'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddEditSubscriptionModal extends ConsumerStatefulWidget {
  final SubscriptionWithDetails? existing;

  const _AddEditSubscriptionModal({this.existing});

  @override
  ConsumerState<_AddEditSubscriptionModal> createState() => _AddEditSubscriptionModalState();
}

class _AddEditSubscriptionModalState extends ConsumerState<_AddEditSubscriptionModal> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  String? _selectedCategoryId;
  String? _selectedAccountId;
  String _frequency = 'monthly';
  DateTime _nextDueDate = DateTime.now().add(const Duration(days: 30));
  bool _autoLog = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleController = TextEditingController(text: e?.subscription.title ?? '');
    _amountController = TextEditingController(text: e != null ? e.subscription.amount.toStringAsFixed(2) : '');
    _notesController = TextEditingController(text: e?.subscription.notes ?? '');
    _selectedCategoryId = e?.category.id;
    _selectedAccountId = e?.account.id;
    _frequency = e?.subscription.frequency ?? 'monthly';
    _nextDueDate = e?.subscription.nextDueDate ?? DateTime.now().add(const Duration(days: 30));
    _autoLog = e?.subscription.autoLog ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a subscription title')),
      );
      return;
    }

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount greater than 0')),
      );
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account')),
      );
      return;
    }

    final repo = ref.read(subscriptionRepositoryProvider);

    if (widget.existing != null) {
      await repo.updateSubscription(
        RecurringTransactionsCompanion(
          id: drift.Value(widget.existing!.subscription.id),
          title: drift.Value(title),
          amount: drift.Value(amount),
          categoryId: drift.Value(_selectedCategoryId!),
          accountId: drift.Value(_selectedAccountId!),
          frequency: drift.Value(_frequency),
          nextDueDate: drift.Value(_nextDueDate),
          autoLog: drift.Value(_autoLog),
          notes: drift.Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
        ),
      );
    } else {
      const uuid = Uuid();
      await repo.createSubscription(
        RecurringTransactionsCompanion.insert(
          id: uuid.v4(),
          title: title,
          amount: amount,
          categoryId: _selectedCategoryId!,
          accountId: _selectedAccountId!,
          frequency: drift.Value(_frequency),
          nextDueDate: _nextDueDate,
          autoLog: drift.Value(_autoLog),
          notes: drift.Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider('expense'));

    // Set defaults if not yet selected
    accountsAsync.whenData((accounts) {
      if (_selectedAccountId == null && accounts.isNotEmpty) {
        _selectedAccountId = accounts.first.id;
      }
    });

    categoriesAsync.whenData((categories) {
      if (_selectedCategoryId == null && categories.isNotEmpty) {
        _selectedCategoryId = categories.first.id;
      }
    });

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.existing != null ? 'Edit Subscription' : 'Add Recurring Bill / Sub',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Title
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title (e.g. Netflix, Rent, Spotify)',
                filled: true,
                fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // Amount
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (\$)',
                prefixText: '\$ ',
                filled: true,
                fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // Frequency Picker
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: InputDecoration(
                labelText: 'Billing Cadence',
                filled: true,
                fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              items: const [
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'yearly', child: Text('Yearly / Annual')),
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'daily', child: Text('Daily')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _frequency = val);
              },
            ),
            const SizedBox(height: 12),

            // Account & Category Pickers Row
            Row(
              children: [
                Expanded(
                  child: accountsAsync.when(
                    data: (accounts) => DropdownButtonFormField<String>(
                      initialValue: _selectedAccountId,
                      decoration: InputDecoration(
                        labelText: 'Account',
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      items: accounts.map((a) {
                        return DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedAccountId = val),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: categoriesAsync.when(
                    data: (categories) => DropdownButtonFormField<String>(
                      initialValue: _selectedCategoryId,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      items: categories.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Row(
                            children: [
                              Icon(IconHelper.getIcon(c.icon), size: 14, color: Color(c.color)),
                              const SizedBox(width: 6),
                              Expanded(child: Text(c.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCategoryId = val),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Next Due Date
            Material(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _nextDueDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setState(() => _nextDueDate = picked);
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 18),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Next Due Date', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(
                            DateFormat('EEE, MMM d, yyyy').format(_nextDueDate),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Text('Change', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Auto-log switch
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-log on due date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text('Automatically records transaction when due date passes', style: TextStyle(fontSize: 11, color: Colors.grey)),
              value: _autoLog,
              activeTrackColor: AppColors.primary,
              onChanged: (val) => setState(() => _autoLog = val),
            ),
            const SizedBox(height: 12),

            // Notes
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                filled: true,
                fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  widget.existing != null ? 'Update Subscription' : 'Save Subscription',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
