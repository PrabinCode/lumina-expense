import 'package:flutter/material.dart';

class IconHelper {
  static IconData getIcon(String? iconName) {
    switch (iconName) {
      // Categories
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'shopping_cart':
        return Icons.shopping_cart_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'receipt_long':
        return Icons.receipt_long_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'medical_services':
        return Icons.medical_services_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'spa':
        return Icons.spa_rounded;
      case 'flight':
        return Icons.flight_rounded;
      case 'payments':
        return Icons.payments_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'card_giftcard':
        return Icons.card_giftcard_rounded;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet_rounded;
      // Accounts
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'credit_card':
        return Icons.credit_card_rounded;
      case 'savings':
        return Icons.savings_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}
