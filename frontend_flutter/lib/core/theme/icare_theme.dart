import 'package:flutter/material.dart';
import 'icare_colors.dart';
import 'icare_typography.dart';
import 'icare_spacing.dart';

/// ICARE Unified Design System Theme
class IcareTheme {
  IcareTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: IcareColors.canvas,
      colorScheme: const ColorScheme.light(
        primary: IcareColors.primary,
        onPrimary: Colors.white,
        secondary: IcareColors.accent,
        onSecondary: IcareColors.textPrimary,
        surface: IcareColors.surface,
        onSurface: IcareColors.textPrimary,
        error: IcareColors.statusDangerText,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: IcareColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: IcareSpacing.roundedMd,
          side: const BorderSide(color: IcareColors.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: IcareColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: IcareSpacing.roundedSm,
          borderSide: const BorderSide(color: IcareColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: IcareSpacing.roundedSm,
          borderSide: const BorderSide(color: IcareColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: IcareSpacing.roundedSm,
          borderSide: const BorderSide(color: IcareColors.borderFocus, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: IcareSpacing.roundedSm,
          borderSide: const BorderSide(color: IcareColors.statusDangerBorder, width: 1.5),
        ),
        labelStyle: const TextStyle(fontSize: 12.5, color: IcareColors.textMuted, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(fontSize: 12.5, color: IcareColors.textLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: IcareColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: IcareSpacing.roundedSm),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: IcareColors.textSecondary,
          side: const BorderSide(color: IcareColors.borderStrong),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: IcareSpacing.roundedSm),
          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: IcareColors.border,
        thickness: 1,
        space: 1,
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(IcareColors.canvas),
        headingTextStyle: IcareTypography.tableHeader,
        dataTextStyle: IcareTypography.body,
        horizontalMargin: 16,
        columnSpacing: 20,
      ),
    );
  }
}
