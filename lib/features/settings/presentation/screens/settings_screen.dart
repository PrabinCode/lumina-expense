import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/currency_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../accounts/presentation/screens/accounts_screen.dart';
import '../../../app_lock/data/app_lock_service.dart';
import '../../../backup/presentation/screens/backup_screen.dart';
import '../../../budgets/presentation/screens/budgets_screen.dart';
import '../../../categories/presentation/screens/categories_screen.dart';
import '../../../debts/presentation/screens/debts_screen.dart';
import '../../../goals/presentation/screens/goals_screen.dart';
import '../../../health/presentation/screens/financial_health_screen.dart';
import '../../../subscriptions/presentation/screens/subscriptions_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _userName = '';
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_profile_name') ?? '';
      _userEmail = prefs.getString('user_profile_email') ?? '';
    });
  }

  Future<void> _editUserProfile() async {
    final nameController = TextEditingController(text: _userName);
    final emailController = TextEditingController(text: _userEmail);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit User Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  hintText: 'e.g. Alex Smith',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'e.g. alex@example.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      final prefs = await SharedPreferences.getInstance();
      final name = nameController.text.trim();
      final email = emailController.text.trim();
      await prefs.setString('user_profile_name', name);
      await prefs.setString('user_profile_email', email);
      setState(() {
        _userName = name;
        _userEmail = email;
      });
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  void _showUpdateCheckDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.system_update_alt_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Text('App Update', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Installed Version: v1.1.0', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text(
                'Lumina Expense is 100% offline-first. You can check the latest releases, change logs, and download updated APKs on GitHub.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                _launchUrl('https://github.com/PrabinCode/lumina-expense/releases');
              },
              child: const Text('View Releases on GitHub'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTheme = ref.watch(themeModeProvider);
    final activeCurrency = ref.watch(currencyProvider);
    final lockService = ref.watch(appLockServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Preferences'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── User Profile Card ───
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'L',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName.isNotEmpty ? _userName : 'Lumina User',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _userEmail.isNotEmpty ? _userEmail : 'Personal Offline Vault',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: _editUserProfile,
                      tooltip: 'Edit Profile',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ─── Preferences (Theme & Currency) ───
              const Text('Appearance & Currency', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
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
                    // Compact Theme Dropdown Tile
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.palette_outlined, color: AppColors.primary, size: 20),
                      ),
                      title: const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(
                        _getThemeLabel(currentTheme),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      trailing: DropdownButtonHideUnderline(
                        child: DropdownButton<AppThemeMode>(
                          value: currentTheme,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          items: const [
                            DropdownMenuItem(value: AppThemeMode.system, child: Text('System Default', style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: AppThemeMode.light, child: Text('Light Mode', style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: AppThemeMode.dark, child: Text('Dark Slate', style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: AppThemeMode.amoled, child: Text('AMOLED Black', style: TextStyle(fontSize: 13))),
                          ],
                          onChanged: (mode) {
                            if (mode != null) {
                              ref.read(themeModeProvider.notifier).setTheme(mode);
                            }
                          },
                        ),
                      ),
                    ),

                    const Divider(height: 1),

                    // Global Base Currency Dropdown Tile
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.monetization_on_outlined, color: Color(0xFF10B981), size: 20),
                      ),
                      title: const Text('Base Currency', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(
                        '${activeCurrency.flag} ${activeCurrency.name} (${activeCurrency.symbol})',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: DropdownButtonHideUnderline(
                        child: DropdownButton<AppCurrency>(
                          value: supportedCurrencies.firstWhere(
                            (c) => c.code == activeCurrency.code,
                            orElse: () => supportedCurrencies.first,
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          items: supportedCurrencies.map((currency) {
                            return DropdownMenuItem(
                              value: currency,
                              child: Text(
                                '${currency.flag} ${currency.code} (${currency.symbol})',
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (currency) {
                            if (currency != null) {
                              ref.read(currencyProvider.notifier).setCurrency(currency);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ─── Security & Privacy ───
              const Text('Security & Privacy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
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
                    SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      secondary: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 20),
                      ),
                      title: const Text('Biometric App Lock', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(
                        lockService.isEnabled ? 'Enabled • ${lockService.timeout.label}' : 'Protect with Face ID / Fingerprint / PIN',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      value: lockService.isEnabled,
                      activeTrackColor: AppColors.primary,
                      onChanged: (val) async {
                        await lockService.setEnabled(val);
                      },
                    ),

                    if (lockService.isEnabled) ...[
                      const Divider(height: 1),

                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.timer_outlined, color: AppColors.warning, size: 20),
                        ),
                        title: const Text('Lock After', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                          lockService.timeout.label,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                        onTap: () => _showTimeoutPicker(context, lockService),
                      ),

                      const Divider(height: 1),

                      SwitchListTile.adaptive(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        secondary: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.visibility_off_rounded, color: AppColors.secondary, size: 20),
                        ),
                        title: const Text('Privacy Shield', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text(
                          'Hide content in app switcher',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        value: lockService.privacyShieldEnabled,
                        activeTrackColor: AppColors.primary,
                        onChanged: (val) async {
                          await lockService.setPrivacyShield(val);
                        },
                      ),

                      const Divider(height: 1),

                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.expense.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.lock_outline_rounded, color: AppColors.expense, size: 20),
                        ),
                        title: const Text('Lock Now', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text(
                          'Immediately lock the app',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                        onTap: () => lockService.lock(),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ─── Data & Tools ───
              const Text('Data & Tools', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),

              _SettingsNavTile(
                title: 'Categories & Reordering',
                subtitle: 'Add, edit, delete & drag to reorder categories',
                icon: Icons.category_outlined,
                iconColor: const Color(0xFFF97316),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
              ),
              const SizedBox(height: 8),

              _SettingsNavTile(
                title: 'Financial Health Score',
                subtitle: 'Smart insights & spending analysis',
                icon: Icons.favorite_border_rounded,
                iconColor: AppColors.expense,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialHealthScreen())),
              ),
              const SizedBox(height: 8),

              _SettingsNavTile(
                title: 'Backup & Restore',
                subtitle: 'Export to Device, Google Drive, or restore',
                icon: Icons.cloud_sync_outlined,
                iconColor: AppColors.primary,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen())),
              ),
              const SizedBox(height: 8),

              _SettingsNavTile(
                title: 'Accounts & Wallets',
                subtitle: 'Manage bank accounts, cash wallets & cards',
                icon: Icons.account_balance_wallet_outlined,
                iconColor: AppColors.transfer,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen())),
              ),
              const SizedBox(height: 8),

              _SettingsNavTile(
                title: 'Monthly Budgets',
                subtitle: 'Category spending caps and alerts',
                icon: Icons.track_changes_outlined,
                iconColor: AppColors.warning,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetsScreen())),
              ),
              const SizedBox(height: 8),

              _SettingsNavTile(
                title: 'Debts & Loans (IOUs)',
                subtitle: 'Money lent to others or borrowed',
                icon: Icons.handshake_outlined,
                iconColor: AppColors.secondary,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtsScreen())),
              ),
              const SizedBox(height: 8),

              _SettingsNavTile(
                title: 'Savings & Sinking Goals',
                subtitle: 'Track milestone targets, vacations & funds',
                icon: Icons.savings_outlined,
                iconColor: const Color(0xFF10B981),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen())),
              ),
              const SizedBox(height: 8),

              _SettingsNavTile(
                title: 'Subscriptions & Bills',
                subtitle: 'Track recurring commitments and monthly burn',
                icon: Icons.subscriptions_outlined,
                iconColor: const Color(0xFF3B82F6),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionsScreen())),
              ),

              const SizedBox(height: 20),

              // ─── Streamlined About & Creator Credit ───
              const Text('About', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),

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
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.code_rounded, color: AppColors.primary, size: 22),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Prabin Chandra Shrestha',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Senior Software Engineer',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.language_rounded, size: 14, color: AppColors.primary),
                          label: const Text('pcshrestha.com.np', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          onPressed: () => _launchUrl('https://pcshrestha.com.np'),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Lumina Expense v1.1.0',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                        InkWell(
                          onTap: () => _showUpdateCheckDialog(context),
                          child: const Row(
                            children: [
                              Icon(Icons.system_update_alt_rounded, size: 14, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text(
                                'Check for Updates',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  String _getThemeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'System Default';
      case AppThemeMode.light:
        return 'Light Mode';
      case AppThemeMode.dark:
        return 'Dark Slate';
      case AppThemeMode.amoled:
        return 'AMOLED Black';
    }
  }

  void _showTimeoutPicker(BuildContext context, AppLockService lockService) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Auto-Lock After',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              ...LockTimeout.values.map((timeout) {
                final isSelected = lockService.timeout == timeout;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  title: Text(
                    timeout.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.primary : null,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                      : null,
                  onTap: () {
                    lockService.setTimeout(timeout);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsNavTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _SettingsNavTile({
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      ),
    );
  }
}
