import 'package:flutter/material.dart';

enum AppPaletteId {
  slate,
  catppuccin,
  tokyoNight,
  nord,
  forest,
  amoled,
}

class AppPalette {
  final AppPaletteId id;
  final String name;
  final String description;
  final Color primary;
  final Color secondary;
  final Color darkBg;
  final Color darkSurface;
  final Color darkSurfaceVariant;
  final Color darkBorder;
  final Color lightBg;
  final Color lightSurface;
  final Color lightSurfaceVariant;
  final Color lightBorder;
  final Color income;
  final Color expense;
  final Color transfer;
  final Color warning;

  const AppPalette({
    required this.id,
    required this.name,
    required this.description,
    required this.primary,
    required this.secondary,
    required this.darkBg,
    required this.darkSurface,
    required this.darkSurfaceVariant,
    required this.darkBorder,
    required this.lightBg,
    required this.lightSurface,
    required this.lightSurfaceVariant,
    required this.lightBorder,
    this.income = const Color(0xFF10B981),
    this.expense = const Color(0xFFEF4444),
    this.transfer = const Color(0xFF3B82F6),
    this.warning = const Color(0xFFF59E0B),
  });

  static const AppPalette slate = AppPalette(
    id: AppPaletteId.slate,
    name: 'Slate Emerald',
    description: 'Clean modern slate with emerald green finance accents',
    primary: Color(0xFF10B981),
    secondary: Color(0xFF6366F1),
    darkBg: Color(0xFF0F172A),
    darkSurface: Color(0xFF1E293B),
    darkSurfaceVariant: Color(0xFF334155),
    darkBorder: Color(0xFF334155),
    lightBg: Color(0xFFF8FAFC),
    lightSurface: Color(0xFFFFFFFF),
    lightSurfaceVariant: Color(0xFFF1F5F9),
    lightBorder: Color(0xFFE2E8F0),
  );

  static const AppPalette catppuccin = AppPalette(
    id: AppPaletteId.catppuccin,
    name: 'Catppuccin Mocha',
    description: 'Soothing warm pastel dark palette for high visual comfort',
    primary: Color(0xFFCBA6F7), // Mauve
    secondary: Color(0xFF89B4FA), // Blue
    darkBg: Color(0xFF1E1E2E), // Base
    darkSurface: Color(0xFF252538), // Mantle / Surface
    darkSurfaceVariant: Color(0xFF313244), // Surface 0
    darkBorder: Color(0xFF45475A), // Surface 1
    lightBg: Color(0xFFEFF1F5), // Latte Base
    lightSurface: Color(0xFFFFFFFF),
    lightSurfaceVariant: Color(0xFFE6E9EF),
    lightBorder: Color(0xFFCCD0DA),
    income: Color(0xFFA6E3A1), // Green
    expense: Color(0xFFF38BA8), // Red
    transfer: Color(0xFF89B4FA), // Blue
    warning: Color(0xFFF9E2AF), // Yellow
  );

  static const AppPalette tokyoNight = AppPalette(
    id: AppPaletteId.tokyoNight,
    name: 'Tokyo Night',
    description: 'Clean dark neon theme inspired by Tokyo neon lights',
    primary: Color(0xFF7AA2F7), // Blue
    secondary: Color(0xFFBB9AF7), // Purple
    darkBg: Color(0xFF1A1B26),
    darkSurface: Color(0xFF24283B),
    darkSurfaceVariant: Color(0xFF2F354F),
    darkBorder: Color(0xFF3B4261),
    lightBg: Color(0xFFF0F2F8),
    lightSurface: Color(0xFFFFFFFF),
    lightSurfaceVariant: Color(0xFFE5E9F5),
    lightBorder: Color(0xFFD5DCEE),
    income: Color(0xFF9ECE6A), // Neon Green
    expense: Color(0xFFF7768E), // Neon Red
    transfer: Color(0xFF7AA2F7),
    warning: Color(0xFFE0AF68),
  );

  static const AppPalette nord = AppPalette(
    id: AppPaletteId.nord,
    name: 'Nord Frost',
    description: 'Arctic, north-bluish clean and elegant color palette',
    primary: Color(0xFF88C0D0), // Frost Cyan
    secondary: Color(0xFF81A1C1), // Frost Blue
    darkBg: Color(0xFF2E3440), // Polar Night 0
    darkSurface: Color(0xFF3B4252), // Polar Night 1
    darkSurfaceVariant: Color(0xFF434C5E), // Polar Night 2
    darkBorder: Color(0xFF4C566A), // Polar Night 3
    lightBg: Color(0xFFECEFF4), // Snow Storm 0
    lightSurface: Color(0xFFFFFFFF),
    lightSurfaceVariant: Color(0xFFE5E9F0), // Snow Storm 1
    lightBorder: Color(0xFFD8DEE9), // Snow Storm 2
    income: Color(0xFFA3BE8C), // Aurora Green
    expense: Color(0xFFBF616A), // Aurora Red
    transfer: Color(0xFF88C0D0),
    warning: Color(0xFFEBCB8B), // Aurora Yellow
  );

  static const AppPalette forest = AppPalette(
    id: AppPaletteId.forest,
    name: 'Forest Emerald',
    description: 'Deep organic greens and warm amber finance theme',
    primary: Color(0xFF10B981),
    secondary: Color(0xFFF59E0B),
    darkBg: Color(0xFF062D24),
    darkSurface: Color(0xFF093D31),
    darkSurfaceVariant: Color(0xFF0C4D3E),
    darkBorder: Color(0xFF145E4C),
    lightBg: Color(0xFFF2FBF7),
    lightSurface: Color(0xFFFFFFFF),
    lightSurfaceVariant: Color(0xFFE1F6ED),
    lightBorder: Color(0xFFC7EEDB),
    income: Color(0xFF10B981),
    expense: Color(0xFFEF4444),
    transfer: Color(0xFF3B82F6),
    warning: Color(0xFFF59E0B),
  );

  static const AppPalette amoled = AppPalette(
    id: AppPaletteId.amoled,
    name: 'Pure Pitch Black',
    description: 'True #000000 black background for maximum OLED battery savings',
    primary: Color(0xFF10B981),
    secondary: Color(0xFF6366F1),
    darkBg: Color(0xFF000000),
    darkSurface: Color(0xFF121212),
    darkSurfaceVariant: Color(0xFF1E1E1E),
    darkBorder: Color(0xFF262626),
    lightBg: Color(0xFFF8FAFC),
    lightSurface: Color(0xFFFFFFFF),
    lightSurfaceVariant: Color(0xFFF1F5F9),
    lightBorder: Color(0xFFE2E8F0),
  );

  static const List<AppPalette> allPalettes = [
    slate,
    catppuccin,
    tokyoNight,
    nord,
    forest,
    amoled,
  ];

  static AppPalette getById(AppPaletteId id) {
    return allPalettes.firstWhere((p) => p.id == id, orElse: () => slate);
  }
}
