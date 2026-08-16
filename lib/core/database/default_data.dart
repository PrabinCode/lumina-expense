class DefaultCategory {
  final String id;
  final String name;
  final String type; // 'expense' or 'income'
  final String icon;
  final int color;

  const DefaultCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
  });
}

class DefaultData {
  static const List<DefaultCategory> categories = [
    // Expense Categories
    DefaultCategory(
      id: 'cat_food_dining',
      name: 'Food & Dining',
      type: 'expense',
      icon: 'restaurant',
      color: 0xFFE65100, // Deep Orange
    ),
    DefaultCategory(
      id: 'cat_groceries',
      name: 'Groceries',
      type: 'expense',
      icon: 'shopping_cart',
      color: 0xFF2E7D32, // Dark Green
    ),
    DefaultCategory(
      id: 'cat_transportation',
      name: 'Transportation',
      type: 'expense',
      icon: 'directions_car',
      color: 0xFF0277BD, // Light Blue
    ),
    DefaultCategory(
      id: 'cat_housing_rent',
      name: 'Housing & Rent',
      type: 'expense',
      icon: 'home',
      color: 0xFF4527A0, // Deep Purple
    ),
    DefaultCategory(
      id: 'cat_utilities',
      name: 'Bills & Utilities',
      type: 'expense',
      icon: 'receipt_long',
      color: 0xFFC2185B, // Pink
    ),
    DefaultCategory(
      id: 'cat_entertainment',
      name: 'Entertainment',
      type: 'expense',
      icon: 'movie',
      color: 0xFF6A1B9A, // Purple
    ),
    DefaultCategory(
      id: 'cat_shopping',
      name: 'Shopping',
      type: 'expense',
      icon: 'shopping_bag',
      color: 0xFFAD1457, // Magenta
    ),
    DefaultCategory(
      id: 'cat_health_medical',
      name: 'Health & Medical',
      type: 'expense',
      icon: 'medical_services',
      color: 0xFFC62828, // Red
    ),
    DefaultCategory(
      id: 'cat_education',
      name: 'Education',
      type: 'expense',
      icon: 'school',
      color: 0xFF00695C, // Teal
    ),
    DefaultCategory(
      id: 'cat_personal_care',
      name: 'Personal Care',
      type: 'expense',
      icon: 'spa',
      color: 0xFF880E4F, // Dark Pink
    ),
    DefaultCategory(
      id: 'cat_travel',
      name: 'Travel & Holidays',
      type: 'expense',
      icon: 'flight',
      color: 0xFF00838F, // Cyan
    ),
    DefaultCategory(
      id: 'cat_misc_expense',
      name: 'Miscellaneous',
      type: 'expense',
      icon: 'more_horiz',
      color: 0xFF546E7A, // Blue Grey
    ),

    // Income Categories
    DefaultCategory(
      id: 'cat_salary',
      name: 'Salary',
      type: 'income',
      icon: 'payments',
      color: 0xFF2E7D32, // Green
    ),
    DefaultCategory(
      id: 'cat_freelance',
      name: 'Freelance & Projects',
      type: 'income',
      icon: 'work',
      color: 0xFF1565C0, // Blue
    ),
    DefaultCategory(
      id: 'cat_investments',
      name: 'Investments & Dividends',
      type: 'income',
      icon: 'trending_up',
      color: 0xFF00897B, // Teal
    ),
    DefaultCategory(
      id: 'cat_gifts',
      name: 'Gifts & Grants',
      type: 'income',
      icon: 'card_giftcard',
      color: 0xFF8E24AA, // Purple
    ),
    DefaultCategory(
      id: 'cat_other_income',
      name: 'Other Income',
      type: 'income',
      icon: 'account_balance_wallet',
      color: 0xFF37474F, // Slate
    ),
  ];

  static const defaultAccountId = 'acc_default_cash';
  static const defaultBankId = 'acc_default_bank';
}
