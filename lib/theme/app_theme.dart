import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central color definitions for the app's single, consistent design
/// system — a premium "royal" identity: Royal Navy as the main brand color,
/// Champagne Gold used sparingly as an accent, on a Warm Ivory canvas.
/// Target visual balance: ~70% ivory/white, ~25% navy, ~5% gold.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0B1F3A); // Royal Navy
  static const Color primaryDark = Color(
    0xFF071527,
  ); // Deeper navy (gradients, pressed states)
  static const Color secondary = Color(0xFF132D4A); // Secondary Navy
  static const Color accent = Color(
    0xFF2C4870,
  ); // Sapphire — a lighter navy accent

  static const Color gold = Color(0xFFC9A227); // Champagne Gold — use sparingly
  static const Color goldDark = Color(0xFF9C7B1D);
  static const Color goldLight = Color(0xFFE9D7A3);

  static const Color backgroundLight = Color(0xFFF8F6F0); // Warm Ivory
  static const Color backgroundDark = Color(0xFF0A1524);
  static const Color surfaceLight = Color(0xFFFFFFFF); // Card
  static const Color surfaceDark = Color(0xFF13233A);

  static const Color textPrimaryLight = Color(0xFF17202A);
  static const Color textSecondaryLight = Color(0xFF667085);
  static const Color textPrimaryDark = Color(0xFFF3F1EA);
  static const Color textSecondaryDark = Color(0xFFA6B0C0);

  static const Color border = Color(0xFFE4E7EC);
  static const Color borderDark = Color(0xFF283449);

  static const Color danger = Color(0xFFB42318);
  static const Color success = Color(0xFF16805C);
  static const Color warning = Color(0xFFB7791F);

  static const List<Color> heroGradient = [primaryDark, primary, secondary];
  static const List<Color> goldGradient = [goldDark, gold, goldLight];

  // Role colors — kept in the same navy/gold/wine family as the rest of the UI.
  static const Color superAdmin = Color(0xFF7A2048); // Deep wine
  static const Color admin = Color(0xFF2C4870); // Sapphire navy
  static const Color member = Color(0xFF16805C); // Success green
}

/// The app's 8px base spacing scale. Use these instead of ad-hoc numbers so
/// spacing stays consistent across every screen.
class AppSpacing {
  AppSpacing._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Centralized corner radii for the app's premium card/button/input look.
class AppRadius {
  AppRadius._();

  static const double input = 12;
  static const double card = 16;
  static const double button = 12;
  static const double dialog = 16;
}

/// Breakpoints used to adapt layouts across mobile, tablet and desktop/web
/// while keeping the same visual identity everywhere.
class AppBreakpoints {
  AppBreakpoints._();

  static const double tablet = 720;
  static const double desktop = 1080;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;
}

/// Many "brand" colors (primary navy, secondary navy, sapphire accent) are
/// tuned to pop against the light Ivory background and go near-invisible as
/// an icon/chip tint on the app's dark background, which is itself a very
/// close navy. Route icon/accent colors picked from [AppColors] through this
/// so they lighten automatically in dark mode instead of blending into it.
Color onSurfaceAccent(BuildContext context, Color color) {
  if (Theme.of(context).brightness != Brightness.dark) return color;
  return Color.lerp(color, Colors.white, 0.45) ?? color;
}

/// Semantic text styles matching the app's typography scale (Plus Jakarta
/// Sans throughout). Prefer these over ad-hoc TextStyles for anything that
/// matches one of these roles.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get pageTitle =>
      GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w700);
  static TextStyle get sectionHeading =>
      GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600);
  static TextStyle get cardTitle =>
      GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600);
  static TextStyle get body =>
      GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w400);
  static TextStyle get label =>
      GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500);
  static TextStyle get small =>
      GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w400);
  static TextStyle get button =>
      GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600);
  static TextStyle get importantAmount =>
      GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w700);
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
      onSurface: isDark
          ? AppColors.textPrimaryDark
          : AppColors.textPrimaryLight,
    );

    // One typeface across the whole app (Web, Android & iOS) — Plus Jakarta
    // Sans — so every platform reads as the same product.
    final bodyText =
        GoogleFonts.plusJakartaSansTextTheme(
          isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
        ).apply(
          bodyColor: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
          displayColor: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        );

    final textTheme = bodyText.copyWith(
      headlineSmall: GoogleFonts.plusJakartaSans(
        textStyle: bodyText.headlineSmall,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        textStyle: bodyText.titleLarge,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        textStyle: bodyText.titleMedium,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        textStyle: bodyText.titleSmall,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        textStyle: bodyText.bodyMedium,
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        textStyle: bodyText.labelLarge,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        textStyle: bodyText.labelMedium,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        textStyle: bodyText.bodySmall,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark
            ? AppColors.textPrimaryDark
            : AppColors.textPrimaryLight,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceDark : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
        labelStyle: TextStyle(
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
        hintStyle: TextStyle(
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.textPrimaryLight,
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.borderDark : AppColors.border,
      ),
    );
  }
}
