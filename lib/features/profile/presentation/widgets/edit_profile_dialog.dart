import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../data/profile_repository.dart';
import '../../providers/profile_providers.dart';

class EditProfileDialog extends ConsumerStatefulWidget {
  final UserProfile? profileToEdit;

  const EditProfileDialog({super.key, this.profileToEdit});

  static Future<bool?> show(BuildContext context, {UserProfile? profileToEdit}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditProfileDialog(profileToEdit: profileToEdit),
    );
  }

  @override
  ConsumerState<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late String _selectedIcon;
  late int _selectedColor;
  late String _selectedCurrency;
  bool _seedDefaults = true;
  bool _isLoading = false;

  static const List<Map<String, dynamic>> _templates = [
    {'name': 'Personal', 'icon': 'person', 'color': 0xFF6366F1},
    {'name': 'Office', 'icon': 'business', 'color': 0xFF2563EB},
    {'name': 'Home', 'icon': 'home', 'color': 0xFF10B981},
    {'name': 'Freelance', 'icon': 'laptop', 'color': 0xFF8B5CF6},
    {'name': 'Side Hustle', 'icon': 'store', 'color': 0xFFF59E0B},
    {'name': 'Travel', 'icon': 'flight', 'color': 0xFF06B6D4},
  ];

  static const List<String> _availableIcons = [
    'person',
    'business',
    'home',
    'laptop',
    'store',
    'wallet',
    'savings',
    'family',
    'flight',
    'school',
    'pets',
    'fitness',
    'heart',
    'star',
    'car',
  ];

  static const List<int> _availableColors = [
    0xFF6366F1, // Indigo
    0xFF10B981, // Emerald
    0xFF2563EB, // Blue
    0xFF8B5CF6, // Purple
    0xFFF59E0B, // Amber
    0xFFEC4899, // Pink
    0xFF06B6D4, // Cyan
    0xFFEF4444, // Red
    0xFF14B8A6, // Teal
    0xFFF97316, // Orange
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.profileToEdit;
    _nameController = TextEditingController(text: p?.name ?? '');
    _emailController = TextEditingController(text: p?.email ?? '');
    _selectedIcon = p?.icon ?? 'person';
    _selectedColor = p?.color ?? 0xFF6366F1;
    _selectedCurrency = p?.currency ?? ref.read(currencyProvider).code;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _applyTemplate(Map<String, dynamic> template) {
    setState(() {
      _nameController.text = template['name'] as String;
      _selectedIcon = template['icon'] as String;
      _selectedColor = template['color'] as int;
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final repo = ref.read(profileRepositoryProvider);

    try {
      if (widget.profileToEdit == null) {
        // Create new profile
        final newProfile = await repo.createProfile(
          name: _nameController.text.trim(),
          email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
          icon: _selectedIcon,
          color: _selectedColor,
          currency: _selectedCurrency,
          seedDefaults: _seedDefaults,
        );

        // Switch to newly created profile
        await ref.read(activeProfileIdProvider.notifier).setActiveProfileId(newProfile.id);
      } else {
        // Update existing profile
        final existing = widget.profileToEdit!;
        await repo.updateProfile(
          UserProfilesCompanion(
            id: drift.Value(existing.id),
            name: drift.Value(_nameController.text.trim()),
            email: drift.Value(_emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null),
            icon: drift.Value(_selectedIcon),
            color: drift.Value(_selectedColor),
            currency: drift.Value(_selectedCurrency),
            isDefault: drift.Value(existing.isDefault),
            createdAt: drift.Value(existing.createdAt),
          ),
        );

        // If active profile was updated, sync active currency
        if (ref.read(activeProfileIdProvider) == existing.id) {
          final matchedCurrency = supportedCurrencies.firstWhere(
            (c) => c.code == _selectedCurrency,
            orElse: () => supportedCurrencies.first,
          );
          await ref.read(currencyProvider.notifier).setCurrency(matchedCurrency);
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDelete() async {
    final profile = widget.profileToEdit;
    if (profile == null) return;

    final repo = ref.read(profileRepositoryProvider);
    final allProfiles = await repo.getAllProfiles();
    if (allProfiles.length <= 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot delete the only remaining profile.')),
        );
      }
      return;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: AppColors.expense),
            const SizedBox(width: 8),
            Text('Delete "${profile.name}"?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete profile "${profile.name}"?\n\n'
          '⚠️ This will permanently remove all accounts, categories, transactions, budgets, goals, debts, and subscriptions belonging to this profile.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Profile'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await repo.deleteProfile(profile.id);

      // Check if we need to switch active profile
      final remaining = await repo.getAllProfiles();
      await ref.read(activeProfileIdProvider.notifier).checkAndFallbackIfDeleted(remaining);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile "${profile.name}" deleted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.profileToEdit != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
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
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(_selectedColor).withValues(alpha: 0.15),
                      child: Icon(
                        IconHelper.getProfileIcon(_selectedIcon),
                        color: Color(_selectedColor),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEditing ? 'Edit Profile' : 'Create New Profile',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                if (!isEditing) ...[
                  const SizedBox(height: 14),
                  const Text('Quick Presets:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _templates.map((tpl) {
                        final isSelected = _nameController.text == tpl['name'];
                        final color = Color(tpl['color'] as int);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: Icon(IconHelper.getProfileIcon(tpl['icon'] as String), size: 16, color: color),
                            label: Text(tpl['name'] as String),
                            backgroundColor: isSelected ? color.withValues(alpha: 0.2) : null,
                            side: BorderSide(color: isSelected ? color : Colors.grey.withValues(alpha: 0.3)),
                            onPressed: () => _applyTemplate(tpl),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  autofocus: !isEditing,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Profile Name *',
                    hintText: 'e.g. Personal, Office, Home, Side Project',
                    prefixIcon: const Icon(Icons.badge_rounded),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a profile name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address (Optional)',
                    hintText: 'e.g. personal@lumina.io',
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),

                const SizedBox(height: 14),
                // Currency Selector
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Profile Currency',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCurrency,
                      isDense: true,
                      isExpanded: true,
                      items: supportedCurrencies.map((c) {
                        return DropdownMenuItem<String>(
                          value: c.code,
                          child: Text('${c.name} (${c.symbol}) - ${c.code}', style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCurrency = val);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Text('Choose Icon:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _availableIcons.map((iconName) {
                    final isSelected = _selectedIcon == iconName;
                    return InkWell(
                      onTap: () => setState(() => _selectedIcon = iconName),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(_selectedColor).withValues(alpha: 0.2)
                              : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Color(_selectedColor) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          IconHelper.getProfileIcon(iconName),
                          size: 22,
                          color: isSelected ? Color(_selectedColor) : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                const Text('Choose Accent Color:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _availableColors.map((colorValue) {
                    final isSelected = _selectedColor == colorValue;
                    return InkWell(
                      onTap: () => setState(() => _selectedColor = colorValue),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Color(colorValue),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Color(colorValue).withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),

                if (!isEditing) ...[
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: CheckboxListTile(
                      value: _seedDefaults,
                      title: const Text('Seed starter accounts & categories', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Creates Cash, Bank, and common spending categories', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      onChanged: (val) => setState(() => _seedDefaults = val ?? true),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(_selectedColor),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isLoading ? null : _handleSave,
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          isEditing ? 'Save Changes' : 'Create Profile',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),

                if (isEditing) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.expense,
                      side: const BorderSide(color: AppColors.expense),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete Profile'),
                    onPressed: _isLoading ? null : _handleDelete,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
