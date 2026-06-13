import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Semantic colour constants (theme-independent role colours) ──────────────
class AppColors {
  // Primary blue accent
  static const primary      = Color(0xFF3D5FE8);
  static const primaryLight = Color(0xFF6B84EE);
  static const primaryDark  = Color(0xFF2948D4);

  // Status
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger  = Color(0xFFEF4444);
  static const info    = Color(0xFF8B5CF6);

  // Role badges (same in both themes)
  static const superAdmin = Color(0xFFEC4899);
  static const admin      = Color(0xFF3D5FE8);
  static const faculty    = Color(0xFF8B5CF6);
  static const student    = Color(0xFF22C55E);

  // ── Static fallback constants (dark-mode values) ───────────────────────────
  // Used in places where BuildContext is unavailable (switch expressions, etc.)
  // The context extension (AppColorsContext) provides proper theme-aware values.
  static const textPrimary   = darkTextPrimary;
  static const textSecondary = darkTextSecondary;
  static const textMuted     = darkTextMuted;
  static const bgCard        = darkSurface;
  static const border        = darkBorder;

  // ── Light palette ─────────────────────────────────────────────────────────
  static const lightBg           = Color(0xFFF5F5F5);
  static const lightSurface      = Color(0xFFFFFFFF);
  static const lightSurfaceVar   = Color(0xFFEFEFEF);
  static const lightBorder       = Color(0xFFE5E7EB);
  static const lightTextPrimary  = Color(0xFF111827);
  static const lightTextSecondary= Color(0xFF6B7280);
  static const lightTextMuted    = Color(0xFF9CA3AF);

  // ── Dark palette ──────────────────────────────────────────────────────────
  static const darkBg            = Color(0xFF0A0F1E);
  static const darkSurface       = Color(0xFF111827);
  static const darkSurfaceVar    = Color(0xFF1A2235);
  static const darkBorder        = Color(0x1AFFFFFF);
  static const darkTextPrimary   = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFF94A3B8);
  static const darkTextMuted     = Color(0xFF475569);
}

// ── Helpers to pull colours from the active theme ───────────────────────────
extension AppColorsContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get bgColor         => isDark ? AppColors.darkBg          : AppColors.lightBg;
  Color get surfaceColor    => isDark ? AppColors.darkSurface      : AppColors.lightSurface;
  Color get surfaceVarColor => isDark ? AppColors.darkSurfaceVar   : AppColors.lightSurfaceVar;
  Color get borderColor     => isDark ? AppColors.darkBorder       : AppColors.lightBorder;
  Color get textPrimary     => isDark ? AppColors.darkTextPrimary  : AppColors.lightTextPrimary;
  Color get textSecondary   => isDark ? AppColors.darkTextSecondary: AppColors.lightTextSecondary;
  Color get textMuted       => isDark ? AppColors.darkTextMuted    : AppColors.lightTextMuted;
}

// ── Theme factory ────────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark  => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg          = isDark ? AppColors.darkBg           : AppColors.lightBg;
    final surface     = isDark ? AppColors.darkSurface       : AppColors.lightSurface;
    final surfaceVar  = isDark ? AppColors.darkSurfaceVar    : AppColors.lightSurfaceVar;
    final border      = isDark ? AppColors.darkBorder        : AppColors.lightBorder;
    final textPrimary = isDark ? AppColors.darkTextPrimary   : AppColors.lightTextPrimary;
    final textSecondary=isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textMuted   = isDark ? AppColors.darkTextMuted     : AppColors.lightTextMuted;

    final base = isDark ? ThemeData.dark() : ThemeData.light();

    return base.copyWith(
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary:    AppColors.primary,
        onPrimary:  Colors.white,
        secondary:  AppColors.info,
        onSecondary:Colors.white,
        surface:    surface,
        onSurface:  textPrimary,
        error:      AppColors.danger,
        onError:    Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor:    textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
        actionsIconTheme: IconThemeData(color: textMuted),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVar,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        labelStyle: TextStyle(color: textSecondary, fontSize: 13),
        hintStyle: TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurfaceVar : AppColors.lightTextPrimary,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: textMuted,
        indicatorColor: AppColors.primary,
        dividerColor: border,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVar,
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 12),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
      drawerTheme: DrawerThemeData(backgroundColor: surface),
    );
  }
}
