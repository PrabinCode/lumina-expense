import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';
import 'app_palettes.dart';

enum AppThemeMode {
  system,
  light,
  dark,
  amoled,
}

class AppThemeState {
  final AppThemeMode mode;
  final AppPaletteId paletteId;

  const AppThemeState({
    this.mode = AppThemeMode.system,
    this.paletteId = AppPaletteId.slate,
  });

  AppPalette get palette => AppPalette.getById(paletteId);

  AppThemeState copyWith({
    AppThemeMode? mode,
    AppPaletteId? paletteId,
  }) {
    return AppThemeState(
      mode: mode ?? this.mode,
      paletteId: paletteId ?? this.paletteId,
    );
  }
}

class AppTheme {
  static ThemeData buildTheme({
    required AppPalette palette,
    required bool isDark,
    bool isAmoled = false,
  }) {
    final bgColor = isAmoled ? palette.darkBg : (isDark ? palette.darkBg : palette.lightBg);
    final surfaceColor = isAmoled ? palette.darkSurface : (isDark ? palette.darkSurface : palette.lightSurface);
    final borderColor = isAmoled ? palette.darkBorder : (isDark ? palette.darkBorder : palette.lightBorder);
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: palette.primary,
              secondary: palette.secondary,
              surface: surfaceColor,
              error: palette.expense,
            )
          : ColorScheme.light(
              primary: palette.primary,
              secondary: palette.secondary,
              surface: surfaceColor,
              error: palette.expense,
            ),
      scaffoldBackgroundColor: bgColor,
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: palette.primary.withValues(alpha: isDark ? 0.25 : 0.15),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.primary);
          }
          return TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary);
        }),
      ),
    );
  }

  static ThemeData get lightTheme => buildTheme(palette: AppPalette.slate, isDark: false);
  static ThemeData get darkTheme => buildTheme(palette: AppPalette.slate, isDark: true);
  static ThemeData get amoledTheme => buildTheme(palette: AppPalette.amoled, isDark: true, isAmoled: true);
}

class ThemeNotifier extends StateNotifier<AppThemeState> {
  static const _keyTheme = 'app_theme_mode';
  static const _keyPalette = 'app_theme_palette_id';

  ThemeNotifier() : super(const AppThemeState()) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIndex = prefs.getInt(_keyTheme);
      final savedPaletteStr = prefs.getString(_keyPalette);

      var mode = AppThemeMode.system;
      if (savedIndex != null && savedIndex >= 0 && savedIndex < AppThemeMode.values.length) {
        mode = AppThemeMode.values[savedIndex];
      }

      var paletteId = AppPaletteId.slate;
      if (savedPaletteStr != null) {
        for (final p in AppPaletteId.values) {
          if (p.name == savedPaletteStr) {
            paletteId = p;
            break;
          }
        }
      }

      state = AppThemeState(mode: mode, paletteId: paletteId);
    } catch (_) {}
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = state.copyWith(mode: mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyTheme, mode.index);
    } catch (_) {}
  }

  Future<void> setPalette(AppPaletteId paletteId) async {
    state = state.copyWith(paletteId: paletteId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPalette, paletteId.name);
    } catch (_) {}
  }
}

final themeStateProvider = StateNotifierProvider<ThemeNotifier, AppThemeState>((ref) {
  return ThemeNotifier();
});

final themeModeProvider = Provider<AppThemeMode>((ref) {
  return ref.watch(themeStateProvider).mode;
});
