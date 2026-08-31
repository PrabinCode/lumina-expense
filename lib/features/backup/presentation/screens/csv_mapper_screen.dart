import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../accounts/data/account_repository.dart';
import '../../services/import_wizard_service.dart';

class CsvMapperScreen extends ConsumerStatefulWidget {
  const CsvMapperScreen({super.key});

  @override
  ConsumerState<CsvMapperScreen> createState() => _CsvMapperScreenState();
}

class _CsvMapperScreenState extends ConsumerState<CsvMapperScreen> {
  String? _filePath;
  String? _fileName;
  List<String> _headers = [];
  List<List<dynamic>> _dataRows = [];
  CsvColumnMapping _mapping = CsvColumnMapping();
  CsvImportPreview? _preview;
  String? _selectedAccountId;
  bool _autoCreateCategories = true;
  bool _isLoading = false;

  Future<void> _pickCsvFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );

    if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
      final path = result.files.single.path!;
      final name = result.files.single.name;

      setState(() => _isLoading = true);
      try {
        final service = ref.read(importWizardServiceProvider);
        final parsed = await service.parseRawCsv(path);
        final autoMapping = service.autoDetectMapping(parsed.headers);

        final preview = service.generatePreview(
          headers: parsed.headers,
          rows: parsed.rows,
          mapping: autoMapping,
        );

        final accounts = await ref.read(accountsStreamProvider.future);
        final defaultAccId = accounts.isNotEmpty ? accounts.first.id : null;

        setState(() {
          _filePath = path;
          _fileName = name;
          _headers = parsed.headers;
          _dataRows = parsed.rows;
          _mapping = autoMapping;
          _preview = preview;
          _selectedAccountId = defaultAccId;
          _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to read CSV: $e')),
          );
        }
      }
    }
  }

  void _updatePreview() {
    if (_filePath == null || _headers.isEmpty) return;
    final service = ref.read(importWizardServiceProvider);
    final preview = service.generatePreview(
      headers: _headers,
      rows: _dataRows,
      mapping: _mapping,
    );
    setState(() => _preview = preview);
  }

  Future<void> _executeImport() async {
    if (_preview == null || _preview!.parsedItems.isEmpty || _selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure mapping and select a destination account.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final service = ref.read(importWizardServiceProvider);
      final count = await service.executeImport(
        items: _preview!.parsedItems,
        defaultAccountId: _selectedAccountId!,
        autoCreateCategories: _autoCreateCategories,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Successfully imported $count transactions into your account!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accountsAsync = ref.watch(accountsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CSV & App Import Wizard'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step 1: Select CSV File
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(16),
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
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.table_view_rounded, color: Color(0xFF10B981), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _fileName ?? 'No CSV File Selected',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _filePath != null
                                        ? '${_dataRows.length} data rows found'
                                        : 'Import from Bank CSV, Cashew, Ivy Wallet, or Monefy',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _pickCsvFile,
                              child: Text(_filePath != null ? 'Replace' : 'Browse CSV'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (_headers.isNotEmpty && _preview != null) ...[
                    const SizedBox(height: 20),

                    // Step 2: Column Mapping Configuration
                    const Text(
                      'Column Mapping (Auto-Detected)',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Column(
                        children: [
                          _buildColumnDropdown(
                            label: 'Date Column *',
                            selectedIndex: _mapping.dateIndex,
                            onChanged: (idx) {
                              if (idx != null) {
                                _mapping.dateIndex = idx;
                                _updatePreview();
                              }
                            },
                          ),
                          const Divider(height: 16),
                          _buildColumnDropdown(
                            label: 'Title / Description *',
                            selectedIndex: _mapping.titleIndex,
                            onChanged: (idx) {
                              if (idx != null) {
                                _mapping.titleIndex = idx;
                                _updatePreview();
                              }
                            },
                          ),
                          const Divider(height: 16),
                          _buildColumnDropdown(
                            label: 'Amount Column *',
                            selectedIndex: _mapping.amountIndex,
                            onChanged: (idx) {
                              if (idx != null) {
                                _mapping.amountIndex = idx;
                                _updatePreview();
                              }
                            },
                          ),
                          const Divider(height: 16),
                          _buildColumnDropdown(
                            label: 'Category Column (Optional)',
                            selectedIndex: _mapping.categoryIndex ?? -1,
                            allowNone: true,
                            onChanged: (idx) {
                              _mapping.categoryIndex = (idx == -1) ? null : idx;
                              _updatePreview();
                            },
                          ),
                          const Divider(height: 16),
                          _buildColumnDropdown(
                            label: 'Account Column (Optional)',
                            selectedIndex: _mapping.accountIndex ?? -1,
                            allowNone: true,
                            onChanged: (idx) {
                              _mapping.accountIndex = (idx == -1) ? null : idx;
                              _updatePreview();
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Destination Account & Settings
                    const Text(
                      'Destination & Category Settings',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: Column(
                        children: [
                          accountsAsync.when(
                            data: (accounts) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Default Account', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                DropdownButton<String>(
                                  value: _selectedAccountId,
                                  items: accounts.map((a) {
                                    return DropdownMenuItem(value: a.id, child: Text(a.name));
                                  }).toList(),
                                  onChanged: (val) => setState(() => _selectedAccountId = val),
                                ),
                              ],
                            ),
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                          const Divider(height: 16),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Auto-Create Missing Categories', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: const Text('Automatically creates categories detected in CSV', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            value: _autoCreateCategories,
                            activeTrackColor: AppColors.primary,
                            onChanged: (val) => setState(() => _autoCreateCategories = val),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Step 3: Dry-Run Preview Card
                    const Text(
                      'Dry-Run Import Preview',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_preview!.totalRows} Transactions Ready',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                '${_preview!.detectedCategories.length} Categories detected',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text('Total Inflow: +${CurrencyFormatter.format(_preview!.totalIncome)}', style: const TextStyle(color: AppColors.income, fontWeight: FontWeight.w600, fontSize: 12)),
                              const SizedBox(width: 14),
                              Text('Total Outflow: -${CurrencyFormatter.format(_preview!.totalExpense)}', style: const TextStyle(color: AppColors.expense, fontWeight: FontWeight.w600, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text('First 5 Items Sample:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 6),
                          ...(_preview!.parsedItems.take(5).map((item) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Text(DateFormat('MM/dd').format(item.date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(item.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  Text(
                                    '${item.type == "income" ? "+" : "-"}${CurrencyFormatter.format(item.amount)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: item.type == 'income' ? AppColors.income : AppColors.expense,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Step 4: Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.download_rounded),
                        label: Text(
                          'Import ${_preview!.totalRows} Transactions',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: _executeImport,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildColumnDropdown({
    required String label,
    required int selectedIndex,
    required ValueChanged<int?> onChanged,
    bool allowNone = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        DropdownButton<int>(
          value: (selectedIndex >= 0 && selectedIndex < _headers.length) ? selectedIndex : (allowNone ? -1 : 0),
          items: [
            if (allowNone)
              const DropdownMenuItem(value: -1, child: Text('None / Ignored', style: TextStyle(fontSize: 13, color: Colors.grey))),
            ..._headers.asMap().entries.map((entry) {
              return DropdownMenuItem(
                value: entry.key,
                child: Text(
                  'Col ${entry.key + 1}: ${entry.value}',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
