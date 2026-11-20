import 'package:flutter/material.dart';

/// Curated institutional banking accent palettes respecting strict contrast (>= 4.5:1).
enum IcareAccentPreset {
  emerald(
    keyName: 'emerald',
    label: 'Institutional Emerald',
    subtitle: 'Signature ICARE reserve palette',
    lightPrimary: Color(0xFF064E3B),
    lightPrimaryDark: Color(0xFF022C22),
    lightPrimaryLight: Color(0xFF047857),
    lightAccent: Color(0xFF8CC63F),
    lightSoftBg: Color(0xFFECFDF5),
    lightSoftBorder: Color(0xFFA7F3D0),
    lightSoftText: Color(0xFF065F46),
    darkPrimary: Color(0xFF10B981),
    darkPrimaryDark: Color(0xFF064E3B),
    darkPrimaryLight: Color(0xFF34D399),
    darkAccent: Color(0xFF8CC63F),
    darkSoftBg: Color(0xFF0B2920),
    darkSoftBorder: Color(0xFF115E46),
    darkSoftText: Color(0xFF6EE7B7),
  ),
  sapphire(
    keyName: 'sapphire',
    label: 'Sapphire Treasury',
    subtitle: 'High-contrast corporate blue',
    lightPrimary: Color(0xFF1E3A8A),
    lightPrimaryDark: Color(0xFF172554),
    lightPrimaryLight: Color(0xFF2563EB),
    lightAccent: Color(0xFF38BDF8),
    lightSoftBg: Color(0xFFEFF6FF),
    lightSoftBorder: Color(0xFFBFDBFE),
    lightSoftText: Color(0xFF1E40AF),
    darkPrimary: Color(0xFF3B82F6),
    darkPrimaryDark: Color(0xFF1E3A8A),
    darkPrimaryLight: Color(0xFF60A5FA),
    darkAccent: Color(0xFF38BDF8),
    darkSoftBg: Color(0xFF0F2147),
    darkSoftBorder: Color(0xFF1D4ED8),
    darkSoftText: Color(0xFF93C5FD),
  ),
  teal(
    keyName: 'teal',
    label: 'Teal Horizon',
    subtitle: 'Supervisory regional contrast',
    lightPrimary: Color(0xFF0F766E),
    lightPrimaryDark: Color(0xFF134E4A),
    lightPrimaryLight: Color(0xFF0D9488),
    lightAccent: Color(0xFF2DD4BF),
    lightSoftBg: Color(0xFFF0FDFA),
    lightSoftBorder: Color(0xFF99F6E4),
    lightSoftText: Color(0xFF115E59),
    darkPrimary: Color(0xFF14B8A6),
    darkPrimaryDark: Color(0xFF115E59),
    darkPrimaryLight: Color(0xFF2DD4BF),
    darkAccent: Color(0xFF5EEAD4),
    darkSoftBg: Color(0xFF0B2928),
    darkSoftBorder: Color(0xFF0F766E),
    darkSoftText: Color(0xFF5EEAD4),
  ),
  indigo(
    keyName: 'indigo',
    label: 'Executive Indigo',
    subtitle: 'Administrative governance tone',
    lightPrimary: Color(0xFF3730A3),
    lightPrimaryDark: Color(0xFF1E1B4B),
    lightPrimaryLight: Color(0xFF4F46E5),
    lightAccent: Color(0xFFA78BFA),
    lightSoftBg: Color(0xFFEEF2FF),
    lightSoftBorder: Color(0xFFC7D2FE),
    lightSoftText: Color(0xFF3730A3),
    darkPrimary: Color(0xFF6366F1),
    darkPrimaryDark: Color(0xFF312E81),
    darkPrimaryLight: Color(0xFF818CF8),
    darkAccent: Color(0xFFA78BFA),
    darkSoftBg: Color(0xFF1A1845),
    darkSoftBorder: Color(0xFF4338CA),
    darkSoftText: Color(0xFFA5B4FC),
  );

  final String keyName;
  final String label;
  final String subtitle;
  final Color lightPrimary;
  final Color lightPrimaryDark;
  final Color lightPrimaryLight;
  final Color lightAccent;
  final Color lightSoftBg;
  final Color lightSoftBorder;
  final Color lightSoftText;
  final Color darkPrimary;
  final Color darkPrimaryDark;
  final Color darkPrimaryLight;
  final Color darkAccent;
  final Color darkSoftBg;
  final Color darkSoftBorder;
  final Color darkSoftText;

  const IcareAccentPreset({
    required this.keyName,
    required this.label,
    required this.subtitle,
    required this.lightPrimary,
    required this.lightPrimaryDark,
    required this.lightPrimaryLight,
    required this.lightAccent,
    required this.lightSoftBg,
    required this.lightSoftBorder,
    required this.lightSoftText,
    required this.darkPrimary,
    required this.darkPrimaryDark,
    required this.darkPrimaryLight,
    required this.darkAccent,
    required this.darkSoftBg,
    required this.darkSoftBorder,
    required this.darkSoftText,
  });

  static IcareAccentPreset fromKey(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final preset in IcareAccentPreset.values) {
      if (preset.keyName == normalized) {
        return preset;
      }
    }
    return IcareAccentPreset.emerald;
  }
}

/// Centralized FlutterCraft motion tokens respecting reduced-motion settings.
class IcareMotion {
  IcareMotion._();

  static const Duration immediate = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration route = Duration(milliseconds: 320);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve morphCurve = Curves.easeInOutCubic;
  static const Curve emphasizedCurve = Curves.fastOutSlowIn;

  static Duration resolve(BuildContext context, Duration preferred) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Duration.zero;
    }
    return preferred;
  }
}

/// Fluid UI System semantic tokens mapped across both Light and Dark themes.
@immutable
class IcareSurfaceTokens extends ThemeExtension<IcareSurfaceTokens> {
  final bool isDark;
  final Color canvas;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceSubtle;
  final Color surfaceHover;
  final Color surfaceGlass;
  final Color borderSubtle;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textLight;
  final Color brandPrimary;
  final Color brandPrimaryDark;
  final Color brandPrimaryLight;
  final Color brandAccent;
  final Color brandSoftBg;
  final Color brandSoftBorder;
  final Color brandSoftText;
  final Color successBg;
  final Color successText;
  final Color successBorder;
  final Color successDot;
  final Color warningBg;
  final Color warningText;
  final Color warningBorder;
  final Color warningDot;
  final Color dangerBg;
  final Color dangerText;
  final Color dangerBorder;
  final Color dangerDot;
  final Color infoBg;
  final Color infoText;
  final Color infoBorder;
  final Color infoDot;
  final Color neutralBg;
  final Color neutralText;
  final Color neutralBorder;
  final Color neutralDot;

  const IcareSurfaceTokens({
    required this.isDark,
    required this.canvas,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceSubtle,
    required this.surfaceHover,
    required this.surfaceGlass,
    required this.borderSubtle,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textLight,
    required this.brandPrimary,
    required this.brandPrimaryDark,
    required this.brandPrimaryLight,
    required this.brandAccent,
    required this.brandSoftBg,
    required this.brandSoftBorder,
    required this.brandSoftText,
    required this.successBg,
    required this.successText,
    required this.successBorder,
    required this.successDot,
    required this.warningBg,
    required this.warningText,
    required this.warningBorder,
    required this.warningDot,
    required this.dangerBg,
    required this.dangerText,
    required this.dangerBorder,
    required this.dangerDot,
    required this.infoBg,
    required this.infoText,
    required this.infoBorder,
    required this.infoDot,
    required this.neutralBg,
    required this.neutralText,
    required this.neutralBorder,
    required this.neutralDot,
  });

  factory IcareSurfaceTokens.light([IcareAccentPreset preset = IcareAccentPreset.emerald]) {
    return IcareSurfaceTokens(
      isDark: false,
      canvas: const Color(0xFFF8FAFC),
      surface: const Color(0xFFFFFFFF),
      surfaceElevated: const Color(0xFFFFFFFF),
      surfaceSubtle: const Color(0xFFF8FAFC),
      surfaceHover: const Color(0xFFF1F5F9),
      surfaceGlass: const Color(0xD9FFFFFF),
      borderSubtle: const Color(0xFFE2E8F0),
      borderStrong: const Color(0xFFCBD5E1),
      textPrimary: const Color(0xFF0F172A),
      textSecondary: const Color(0xFF334155),
      textMuted: const Color(0xFF64748B),
      textLight: const Color(0xFF94A3B8),
      brandPrimary: preset.lightPrimary,
      brandPrimaryDark: preset.lightPrimaryDark,
      brandPrimaryLight: preset.lightPrimaryLight,
      brandAccent: preset.lightAccent,
      brandSoftBg: preset.lightSoftBg,
      brandSoftBorder: preset.lightSoftBorder,
      brandSoftText: preset.lightSoftText,
      successBg: const Color(0xFFECFDF5),
      successText: const Color(0xFF065F46),
      successBorder: const Color(0xFFA7F3D0),
      successDot: const Color(0xFF10B981),
      warningBg: const Color(0xFFFFFBEB),
      warningText: const Color(0xFF92400E),
      warningBorder: const Color(0xFFFDE68A),
      warningDot: const Color(0xFFF59E0B),
      dangerBg: const Color(0xFFFEF2F2),
      dangerText: const Color(0xFF991B1B),
      dangerBorder: const Color(0xFFFECACA),
      dangerDot: const Color(0xFFEF4444),
      infoBg: const Color(0xFFEFF6FF),
      infoText: const Color(0xFF1E40AF),
      infoBorder: const Color(0xFFBFDBFE),
      infoDot: const Color(0xFF3B82F6),
      neutralBg: const Color(0xFFF1F5F9),
      neutralText: const Color(0xFF475569),
      neutralBorder: const Color(0xFFCBD5E1),
      neutralDot: const Color(0xFF64748B),
    );
  }

  factory IcareSurfaceTokens.dark([IcareAccentPreset preset = IcareAccentPreset.emerald]) {
    return IcareSurfaceTokens(
      isDark: true,
      canvas: const Color(0xFF090E1A),
      surface: const Color(0xFF111827),
      surfaceElevated: const Color(0xFF182235),
      surfaceSubtle: const Color(0xFF161F30),
      surfaceHover: const Color(0xFF1E293B),
      surfaceGlass: const Color(0xCC111827),
      borderSubtle: const Color(0xFF233046),
      borderStrong: const Color(0xFF334155),
      textPrimary: const Color(0xFFF1F5F9),
      textSecondary: const Color(0xFFCBD5E1),
      textMuted: const Color(0xFF94A3B8),
      textLight: const Color(0xFF64748B),
      brandPrimary: preset.darkPrimary,
      brandPrimaryDark: preset.darkPrimaryDark,
      brandPrimaryLight: preset.darkPrimaryLight,
      brandAccent: preset.darkAccent,
      brandSoftBg: preset.darkSoftBg,
      brandSoftBorder: preset.darkSoftBorder,
      brandSoftText: preset.darkSoftText,
      successBg: const Color(0xFF062E22),
      successText: const Color(0xFF6EE7B7),
      successBorder: const Color(0xFF065F46),
      successDot: const Color(0xFF34D399),
      warningBg: const Color(0xFF2D1E07),
      warningText: const Color(0xFFFCD34D),
      warningBorder: const Color(0xFF78350F),
      warningDot: const Color(0xFFFBBF24),
      dangerBg: const Color(0xFF331115),
      dangerText: const Color(0xFFFCA5A5),
      dangerBorder: const Color(0xFF7F1D1D),
      dangerDot: const Color(0xFFF87171),
      infoBg: const Color(0xFF0F2147),
      infoText: const Color(0xFF93C5FD),
      infoBorder: const Color(0xFF1E40AF),
      infoDot: const Color(0xFF60A5FA),
      neutralBg: const Color(0xFF1E293B),
      neutralText: const Color(0xFFCBD5E1),
      neutralBorder: const Color(0xFF334155),
      neutralDot: const Color(0xFF94A3B8),
    );
  }

  static final IcareSurfaceTokens _fallbackLight = IcareSurfaceTokens.light();
  static final IcareSurfaceTokens _fallbackDark = IcareSurfaceTokens.dark();

  static IcareSurfaceTokens of(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<IcareSurfaceTokens>();
    if (ext != null) return ext;
    return theme.brightness == Brightness.dark ? _fallbackDark : _fallbackLight;
  }

  @override
  IcareSurfaceTokens copyWith({
    bool? isDark,
    Color? canvas,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceSubtle,
    Color? surfaceHover,
    Color? surfaceGlass,
    Color? borderSubtle,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textLight,
    Color? brandPrimary,
    Color? brandPrimaryDark,
    Color? brandPrimaryLight,
    Color? brandAccent,
    Color? brandSoftBg,
    Color? brandSoftBorder,
    Color? brandSoftText,
    Color? successBg,
    Color? successText,
    Color? successBorder,
    Color? successDot,
    Color? warningBg,
    Color? warningText,
    Color? warningBorder,
    Color? warningDot,
    Color? dangerBg,
    Color? dangerText,
    Color? dangerBorder,
    Color? dangerDot,
    Color? infoBg,
    Color? infoText,
    Color? infoBorder,
    Color? infoDot,
    Color? neutralBg,
    Color? neutralText,
    Color? neutralBorder,
    Color? neutralDot,
  }) {
    return IcareSurfaceTokens(
      isDark: isDark ?? this.isDark,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      surfaceGlass: surfaceGlass ?? this.surfaceGlass,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textLight: textLight ?? this.textLight,
      brandPrimary: brandPrimary ?? this.brandPrimary,
      brandPrimaryDark: brandPrimaryDark ?? this.brandPrimaryDark,
      brandPrimaryLight: brandPrimaryLight ?? this.brandPrimaryLight,
      brandAccent: brandAccent ?? this.brandAccent,
      brandSoftBg: brandSoftBg ?? this.brandSoftBg,
      brandSoftBorder: brandSoftBorder ?? this.brandSoftBorder,
      brandSoftText: brandSoftText ?? this.brandSoftText,
      successBg: successBg ?? this.successBg,
      successText: successText ?? this.successText,
      successBorder: successBorder ?? this.successBorder,
      successDot: successDot ?? this.successDot,
      warningBg: warningBg ?? this.warningBg,
      warningText: warningText ?? this.warningText,
      warningBorder: warningBorder ?? this.warningBorder,
      warningDot: warningDot ?? this.warningDot,
      dangerBg: dangerBg ?? this.dangerBg,
      dangerText: dangerText ?? this.dangerText,
      dangerBorder: dangerBorder ?? this.dangerBorder,
      dangerDot: dangerDot ?? this.dangerDot,
      infoBg: infoBg ?? this.infoBg,
      infoText: infoText ?? this.infoText,
      infoBorder: infoBorder ?? this.infoBorder,
      infoDot: infoDot ?? this.infoDot,
      neutralBg: neutralBg ?? this.neutralBg,
      neutralText: neutralText ?? this.neutralText,
      neutralBorder: neutralBorder ?? this.neutralBorder,
      neutralDot: neutralDot ?? this.neutralDot,
    );
  }

  @override
  IcareSurfaceTokens lerp(ThemeExtension<IcareSurfaceTokens>? other, double t) {
    if (other is! IcareSurfaceTokens) return this;
    return IcareSurfaceTokens(
      isDark: t < 0.5 ? isDark : other.isDark,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
      surfaceGlass: Color.lerp(surfaceGlass, other.surfaceGlass, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textLight: Color.lerp(textLight, other.textLight, t)!,
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      brandPrimaryDark: Color.lerp(brandPrimaryDark, other.brandPrimaryDark, t)!,
      brandPrimaryLight: Color.lerp(brandPrimaryLight, other.brandPrimaryLight, t)!,
      brandAccent: Color.lerp(brandAccent, other.brandAccent, t)!,
      brandSoftBg: Color.lerp(brandSoftBg, other.brandSoftBg, t)!,
      brandSoftBorder: Color.lerp(brandSoftBorder, other.brandSoftBorder, t)!,
      brandSoftText: Color.lerp(brandSoftText, other.brandSoftText, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      successBorder: Color.lerp(successBorder, other.successBorder, t)!,
      successDot: Color.lerp(successDot, other.successDot, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      warningBorder: Color.lerp(warningBorder, other.warningBorder, t)!,
      warningDot: Color.lerp(warningDot, other.warningDot, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      dangerText: Color.lerp(dangerText, other.dangerText, t)!,
      dangerBorder: Color.lerp(dangerBorder, other.dangerBorder, t)!,
      dangerDot: Color.lerp(dangerDot, other.dangerDot, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
      infoText: Color.lerp(infoText, other.infoText, t)!,
      infoBorder: Color.lerp(infoBorder, other.infoBorder, t)!,
      infoDot: Color.lerp(infoDot, other.infoDot, t)!,
      neutralBg: Color.lerp(neutralBg, other.neutralBg, t)!,
      neutralText: Color.lerp(neutralText, other.neutralText, t)!,
      neutralBorder: Color.lerp(neutralBorder, other.neutralBorder, t)!,
      neutralDot: Color.lerp(neutralDot, other.neutralDot, t)!,
    );
  }
}

/// Convenient BuildContext extension for Fluid UI semantic surface & text tokens.
extension IcareThemeContextExt on BuildContext {
  IcareSurfaceTokens get icareTokens => IcareSurfaceTokens.of(this);
  bool get icareIsDark => icareTokens.isDark;
}
