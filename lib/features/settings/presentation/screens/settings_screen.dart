import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../accounts/presentation/screens/accounts_screen.dart';
import '../../../backup/presentation/screens/backup_screen.dart';
import '../../../budgets/presentation/screens/budgets_screen.dart';
import '../../../debts/presentation/screens/debts_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTheme = ref.watch(themeModeProvider);

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
              const Text('Appearance & Theme', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
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
                    _ThemeSelectionTile(
                      title: 'System Default',
                      value: AppThemeMode.system,
                      selected: currentTheme == AppThemeMode.system,
                      onTap: () => ref.read(themeModeProvider.notifier).state = AppThemeMode.system,
                    ),
                    const Divider(height: 1),
                    _ThemeSelectionTile(
                      title: 'Light Mode',
                      value: AppThemeMode.light,
                      selected: currentTheme == AppThemeMode.light,
                      onTap: () => ref.read(themeModeProvider.notifier).state = AppThemeMode.light,
                    ),
                    const Divider(height: 1),
                    _ThemeSelectionTile(
                      title: 'Dark Mode (Slate)',
                      value: AppThemeMode.dark,
                      selected: currentTheme == AppThemeMode.dark,
                      onTap: () => ref.read(themeModeProvider.notifier).state = AppThemeMode.dark,
                    ),
                    const Divider(height: 1),
                    _ThemeSelectionTile(
                      title: 'AMOLED Pitch Black Mode',
                      value: AppThemeMode.amoled,
                      selected: currentTheme == AppThemeMode.amoled,
                      onTap: () => ref.read(themeModeProvider.notifier).state = AppThemeMode.amoled,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text('Data & Tools', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),

              _SettingsNavTile(
                title: 'Backup & Restore',
                subtitle: 'Export to Google Drive, Files, or restore',
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

              const SizedBox(height: 24),

              const Text('About & Creator Credit', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),

              // Creator Profile Card with Credits to Prabin Chandra Shrestha (pcshrestha.com.np)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFFFFFFFF), const Color(0xFFF8FAFC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.code_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Prabin Chandra Shrestha',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Senior Software Engineer • Kathmandu, Nepal',
                                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Architected with clean principles, 100% offline-first storage with Drift (SQLite), and state-of-the-art Riverpod architecture.',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.language_rounded, size: 16, color: AppColors.primary),
                          label: const Text('pcshrestha.com.np', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          onPressed: () => _launchUrl('https://pcshrestha.com.np'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.terminal_rounded, size: 16),
                          label: const Text('GitHub', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          onPressed: () => _launchUrl('https://github.com/PrabinCode'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.link_rounded, size: 16, color: Color(0xFF0077B5)),
                          label: const Text('LinkedIn', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          onPressed: () => _launchUrl('https://www.linkedin.com/in/pcshrestha/'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Lumina Expense v1.0.0 • 100% Offline • MIT License',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
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
}

class _ThemeSelectionTile extends StatelessWidget {
  final String title;
  final AppThemeMode value;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeSelectionTile({
    required this.title,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: selected ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20) : null,
      onTap: onTap,
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
