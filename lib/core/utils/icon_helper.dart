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

  static IconData getCategoryIcon(String? iconName) => getIcon(iconName);

  static IconData getProfileIcon(String? iconName) {
    switch (iconName) {
      case 'person':
        return Icons.person_rounded;
      case 'work':
      case 'business':
      case 'office':
        return Icons.business_center_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'laptop':
      case 'freelance':
        return Icons.laptop_mac_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'store':
      case 'shopping_bag':
        return Icons.storefront_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'family':
        return Icons.family_restroom_rounded;
      case 'travel':
      case 'flight':
        return Icons.flight_takeoff_rounded;
      case 'pets':
        return Icons.pets_rounded;
      case 'fitness':
      case 'gym':
        return Icons.fitness_center_rounded;
      case 'heart':
      case 'favorite':
        return Icons.favorite_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'car':
      case 'directions_car':
        return Icons.directions_car_rounded;
      default:
        return Icons.person_rounded;
    }
  }
}

