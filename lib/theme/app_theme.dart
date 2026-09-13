import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central color + typography definitions for the app — a premium,
/// "royal" palette: deep regal purple paired with warm gold accents.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF6A3DE8);
  static const Color primaryDark = Color(0xFF351A6E);
  static const Color secondary = Color(0xFFB68A2E);
  static const Color accent = Color(0xFF8E5FF5);

  // The signature royal gold — used for highlights, glows, and premium CTAs.
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF1D98B);

  static const Color backgroundLight = Color(0xFFFAF6EF);
  static const Color backgroundDark = Color(0xFF120B1E);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1533);

  static const Color textPrimaryLight = Color(0xFF241933);
  static const Color textSecondaryLight = Color(0xFF6E6280);
  static const Color textPrimaryDark = Color(0xFFF3EEFA);
  static const Color textSecondaryDark = Color(0xFFB8ADC9);

  static const Color danger = Color(0xFFC0392B);
  static const Color success = Color(0xFF1F8A5F);
  static const Color warning = Color(0xFFD9A62E);

  static const List<Color> heroGradient = [primaryDark, primary, Color(0xFF9B6BF2)];
  static const List<Color> goldGradient = [Color(0xFF8A6215), gold, goldLight];

  // Role colors
  static const Color superAdmin = Color(0xFFA1266B);
  static const Color admin = Color(0xFF1B4B91);
  static const Color member = Color(0xFF1F8A5F);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.gold,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      onSurface: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
    );

    final bodyText = GoogleFonts.manropeTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).apply(
      bodyColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      displayColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
    );

    // An elegant serif for headings paired with the clean sans-serif body
    // font — the classic "premium" typography pairing.
    final displayColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textTheme = bodyText.copyWith(
      headlineMedium: GoogleFonts.playfairDisplay(
        textStyle: bodyText.headlineMedium,
        fontWeight: FontWeight.w700,
        color: displayColor,
      ),
      headlineSmall: GoogleFonts.playfairDisplay(
        textStyle: bodyText.headlineSmall,
        fontWeight: FontWeight.w700,
        color: displayColor,
      ),
      titleLarge: GoogleFonts.playfairDisplay(
        textStyle: bodyText.titleLarge,
        fontWeight: FontWeight.w700,
        color: displayColor,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceDark : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: AppColors.gold, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
        labelStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
        hintStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedForegroundColor: Colors.white,
          selectedBackgroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.gold.withValues(alpha: isDark ? 0.14 : 0.16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.textPrimaryLight,
      ),
      dividerTheme: DividerThemeData(color: AppColors.gold.withValues(alpha: isDark ? 0.14 : 0.18)),
    );
  }
}
