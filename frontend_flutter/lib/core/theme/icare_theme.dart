import 'package:flutter/material.dart';
import 'icare_spacing.dart';
import 'icare_theme_tokens.dart';

/// ICARE Unified Fluid UI Design System Theme (Light, Dark & Accent Presets)
class IcareTheme {
  IcareTheme._();

  static ThemeData get lightTheme => buildTheme(brightness: Brightness.light);
  static ThemeData get darkTheme => buildTheme(brightness: Brightness.dark);

  static ThemeData buildTheme({
    required Brightness brightness,
    IcareAccentPreset accent = IcareAccentPreset.emerald,
    bool compactDensity = false,
  }) {
    final isDark = brightness == Brightness.dark;
    final tokens = isDark
        ? IcareSurfaceTokens.dark(accent)
        : IcareSurfaceTokens.light(accent);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: tokens.brandPrimary,
      onPrimary: Colors.white,
      secondary: tokens.brandAccent,
      onSecondary: isDark ? const Color(0xFF022C22) : tokens.textPrimary,
      error: tokens.dangerDot,
      onError: Colors.white,
      surface: tokens.surface,
      onSurface: tokens.textPrimary,
      surfaceContainerLowest: tokens.canvas,
      surfaceContainerLow: tokens.surfaceSubtle,
      surfaceContainer: tokens.surface,
      surfaceContainerHigh: tokens.surfaceElevated,
      surfaceContainerHighest: tokens.surfaceHover,
      outline: tokens.borderStrong,
      outlineVariant: tokens.borderSubtle,
    );

    final baseTextTheme = ThemeData(brightness: brightness).textTheme.apply(
          bodyColor: tokens.textSecondary,
          displayColor: tokens.textPrimary,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      visualDensity:
          compactDensity ? VisualDensity.compact : VisualDensity.standard,
      scaffoldBackgroundColor: tokens.canvas,
      canvasColor: tokens.surface,
      colorScheme: colorScheme,
      textTheme: baseTextTheme,
      extensions: <ThemeExtension<dynamic>>[tokens],
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? const Color(0xFF062C22) : tokens.brandPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: IcareSpacing.roundedMd,
          side: BorderSide(color: tokens.borderSubtle, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: tokens.borderSubtle, width: 1),
        ),
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: tokens.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontSize: 13,
          color: tokens.textSecondary,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: tokens.surfaceElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: tokens.borderSubtle),
        ),
        textStyle: TextStyle(color: tokens.textPrimary, fontSize: 13),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(tokens.surfaceElevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceSubtle,
        isDense: compactDensity,
        contentPadding: compactDensity
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: IcareSpacing.roundedSm,
          borderSide: BorderSide(color: tokens.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: IcareSpacing.roundedSm,
          borderSide: BorderSide(color: tokens.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: IcareSpacing.roundedSm,
          borderSide: BorderSide(color: tokens.brandPrimary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: IcareSpacing.roundedSm,
          borderSide: BorderSide(color: tokens.dangerBorder, width: 1.5),
        ),
        labelStyle: TextStyle(
          fontSize: 12.5,
          color: tokens.textMuted,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(fontSize: 12.5, color: tokens.textLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.brandPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: compactDensity
              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: IcareSpacing.roundedSm),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textSecondary,
          side: BorderSide(color: tokens.borderStrong),
          elevation: 0,
          padding: compactDensity
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: IcareSpacing.roundedSm),
          textStyle:
              const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.brandPrimary,
          textStyle:
              const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? tokens.textMuted : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return tokens.brandPrimary;
          return tokens.borderStrong;
        }),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(tokens.canvas),
        headingTextStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: tokens.textSecondary,
          letterSpacing: 0.2,
        ),
        dataTextStyle: TextStyle(
          fontSize: compactDensity ? 12 : 13,
          fontWeight: FontWeight.w400,
          color: tokens.textSecondary,
          height: 1.4,
        ),
        horizontalMargin: compactDensity ? 12 : 16,
        columnSpacing: compactDensity ? 14 : 20,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? tokens.surfaceElevated : const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
