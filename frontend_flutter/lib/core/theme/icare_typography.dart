import 'dart:ui';
import 'package:flutter/material.dart';
import 'icare_colors.dart';

/// ICARE Tabular Typography & Text Hierarchy
/// Enforces Tabular Figures for Financial Numbers to Prevent Layout Shifts and Text Wrapping
class IcareTypography {
  IcareTypography._();

  // Page Level Headers
  static const TextStyle pageTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: IcareColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle pageSubtitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: IcareColors.textMuted,
    letterSpacing: -0.1,
  );

  // Section Headers
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: IcareColors.textPrimary,
    letterSpacing: -0.15,
  );
  static const TextStyle h2 = sectionHeader;

  static const TextStyle sectionSubtitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: IcareColors.textMuted,
  );

  // Financial Number Typography (Tabular Figures)
  static const TextStyle heroFinancialNumber = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: IcareColors.textPrimary,
    letterSpacing: -0.4,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle metricValue = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: IcareColors.textPrimary,
    letterSpacing: -0.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle metricValueCompact = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: IcareColors.textPrimary,
    letterSpacing: -0.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle tableFinancialNumber = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: IcareColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // Card Labels & Metadata
  static const TextStyle cardLabel = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    color: IcareColors.textMuted,
    letterSpacing: 0.1,
  );

  static const TextStyle cardDelta = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: IcareColors.textSecondary,
  );

  // Badges & Status Pills
  static const TextStyle statusBadge = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  // Table Column Headers
  static const TextStyle tableHeader = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    color: IcareColors.textSecondary,
    letterSpacing: 0.2,
  );

  // Body & General Text
  static const TextStyle body = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: IcareColors.textSecondary,
    height: 1.4,
  );
  static const TextStyle bodyRegular = body;

  static const TextStyle bodyBold = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: IcareColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: IcareColors.textSecondary,
    height: 1.3,
  );
}
