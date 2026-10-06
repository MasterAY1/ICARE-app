import 'package:flutter/material.dart';

/// ICARE Institutional Banking Palette
/// Strict compliance with Rule 10 Zero-Emoji & Corporate Aesthetic
class IcareColors {
  IcareColors._();

  // Core Brand Emeralds
  static const Color primary = Color(0xFF064E3B);       // Deep Forest Emerald
  static const Color primaryDark = Color(0xFF022C22);   // Midnight Emerald
  static const Color primaryLight = Color(0xFF047857);  // Vibrant Emerald
  static const Color accent = Color(0xFF8CC63F);        // Growth Lime

  // Neutrals & Surfaces
  static const Color canvas = Color(0xFFF8FAFC);        // Soft Background Canvas
  static const Color surface = Color(0xFFFFFFFF);       // Clean Card White
  static const Color surfaceSubtle = Color(0xFFF8FAFC); // Subtle Card White-Slate
  static const Color surfaceHover = Color(0xFFF1F5F9);  // Subtle Hover State

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);        // 1px Subtle Slate Border
  static const Color borderStrong = Color(0xFFCBD5E1);  // Field Input Border
  static const Color borderFocus = Color(0xFF2563EB);   // Active Focus Blue

  // High-Contrast Institutional Typography
  static const Color textPrimary = Color(0xFF0F172A);   // Deep Slate (Highest Contrast)
  static const Color textSecondary = Color(0xFF334155); // Slate Body
  static const Color textMuted = Color(0xFF64748B);     // Metadata & Subtitles
  static const Color textLight = Color(0xFF94A3B8);     // Placeholders

  // Semantic Status Colors (Zero-Emoji Badge System)
  static const Color statusSuccessBg = Color(0xFFECFDF5);
  static const Color statusSuccessText = Color(0xFF065F46);
  static const Color statusSuccessBorder = Color(0xFFA7F3D0);
  static const Color statusSuccessDot = Color(0xFF10B981);

  static const Color statusWarningBg = Color(0xFFFFFBEB);
  static const Color statusWarningText = Color(0xFF92400E);
  static const Color statusWarningBorder = Color(0xFFFDE68A);
  static const Color statusWarningDot = Color(0xFFF59E0B);

  static const Color statusDangerBg = Color(0xFFFEF2F2);
  static const Color statusDangerText = Color(0xFF991B1B);
  static const Color statusDangerBorder = Color(0xFFFECACA);
  static const Color statusDangerDot = Color(0xFFEF4444);

  static const Color statusInfoBg = Color(0xFFEFF6FF);
  static const Color statusInfoText = Color(0xFF1E40AF);
  static const Color statusInfoBorder = Color(0xFFBFDBFE);
  static const Color statusInfoDot = Color(0xFF3B82F6);

  static const Color statusNeutralBg = Color(0xFFF1F5F9);
  static const Color statusNeutralText = Color(0xFF475569);
  static const Color statusNeutralBorder = Color(0xFFCBD5E1);
  static const Color statusNeutralDot = Color(0xFF64748B);

  // Financial Metrics Accent Lines
  static const Color metricPayoff = Color(0xFF16A34A);   // Green
  static const Color metricExcess = Color(0xFF2563EB);   // Blue
  static const Color metricPart = Color(0xFFD97706);     // Amber
  static const Color metricNotPaid = Color(0xFFDC2626);  // Red
  static const Color metricArrears = Color(0xFF991B1B);  // Dark Crimson
}
