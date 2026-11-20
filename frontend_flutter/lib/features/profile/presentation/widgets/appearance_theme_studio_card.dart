import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/icare_card.dart';

class AppearanceThemeStudioCard extends StatelessWidget {
  final AppAppearanceSettings settings;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<IcareAccentPreset> onAccentPresetChanged;
  final ValueChanged<bool> onCompactDensityChanged;
  final ValueChanged<bool> onReduceMotionChanged;
  final ValueChanged<bool> onHapticsChanged;
  final VoidCallback onResetDefaults;

  const AppearanceThemeStudioCard({
    super.key,
    required this.settings,
    required this.onThemeModeChanged,
    required this.onAccentPresetChanged,
    required this.onCompactDensityChanged,
    required this.onReduceMotionChanged,
    required this.onHapticsChanged,
    required this.onResetDefaults,
  });

  void _triggerHaptic() {
    if (settings.hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < 640;

    return IcareCard(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tokens.brandSoftBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.brandSoftBorder),
                ),
                child: Icon(
                  Icons.palette_outlined,
                  size: 18,
                  color: tokens.brandSoftText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance & Theme Studio',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Customize brightness, brand accent palette, and workspace density.',
                      softWrap: true,
                      style: TextStyle(fontSize: 12, color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  _triggerHaptic();
                  onResetDefaults();
                },
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Text(
            'Theme Mode',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          LayoutBuilder(
            builder: (context, constraints) {
              final threeAcross = constraints.maxWidth >= 480;
              final options = [
                _ThemeModePreviewTile(
                  label: 'Light Slate',
                  subtitle: 'Sunlight-ready',
                  mode: ThemeMode.light,
                  selected: settings.themeMode == ThemeMode.light,
                  previewBg: const Color(0xFFF8FAFC),
                  previewCard: Colors.white,
                  previewHeader: settings.accentPreset.lightPrimary,
                  onTap: () {
                    _triggerHaptic();
                    onThemeModeChanged(ThemeMode.light);
                  },
                ),
                _ThemeModePreviewTile(
                  label: 'Dark Vault',
                  subtitle: 'Low-glare contrast',
                  mode: ThemeMode.dark,
                  selected: settings.themeMode == ThemeMode.dark,
                  previewBg: const Color(0xFF090E1A),
                  previewCard: const Color(0xFF111827),
                  previewHeader: settings.accentPreset.darkPrimary,
                  onTap: () {
                    _triggerHaptic();
                    onThemeModeChanged(ThemeMode.dark);
                  },
                ),
                _ThemeModePreviewTile(
                  label: 'System Auto',
                  subtitle: 'Follows device',
                  mode: ThemeMode.system,
                  selected: settings.themeMode == ThemeMode.system,
                  previewBg: const Color(0xFF334155),
                  previewCard: const Color(0xFFF8FAFC),
                  previewHeader: settings.accentPreset.lightPrimaryLight,
                  isSplitPreview: true,
                  onTap: () {
                    _triggerHaptic();
                    onThemeModeChanged(ThemeMode.system);
                  },
                ),
              ];

              if (threeAcross) {
                return Row(
                  children: [
                    Expanded(child: options[0]),
                    const SizedBox(width: 10),
                    Expanded(child: options[1]),
                    const SizedBox(width: 10),
                    Expanded(child: options[2]),
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: options[0]),
                      const SizedBox(width: 10),
                      Expanded(child: options[1]),
                    ],
                  ),
                  const SizedBox(height: 10),
                  options[2],
                ],
              );
            },
          ),

          const SizedBox(height: 20),
          Text(
            'Institutional Accent Palette',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          LayoutBuilder(
            builder: (context, constraints) {
              final twoCol = constraints.maxWidth >= 460;
              final tiles = IcareAccentPreset.values.map((preset) {
                final isSelected = settings.accentPreset == preset;
                final primarySwatch =
                    tokens.isDark ? preset.darkPrimary : preset.lightPrimary;
                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: 'Accent theme ${preset.label}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      _triggerHaptic();
                      onAccentPresetChanged(preset);
                    },
                    child: AnimatedContainer(
                      duration: IcareMotion.resolve(context, IcareMotion.fast),
                      curve: IcareMotion.standardCurve,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (tokens.isDark
                                ? preset.darkSoftBg
                                : preset.lightSoftBg)
                            : tokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? primarySwatch
                              : tokens.borderSubtle,
                          width: isSelected ? 1.6 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primarySwatch,
                              border: Border.all(
                                color: preset.lightAccent,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    size: 13, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  preset.label,
                                  softWrap: true,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                                Text(
                                  preset.subtitle,
                                  softWrap: true,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: tokens.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList();

              if (!twoCol) {
                return Column(
                  children: tiles
                      .map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: t,
                          ))
                      .toList(),
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: tiles[0]),
                      const SizedBox(width: 10),
                      Expanded(child: tiles[1]),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: tiles[2]),
                      const SizedBox(width: 10),
                      Expanded(child: tiles[3]),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 18),
          Divider(color: tokens.borderSubtle, height: 1),
          const SizedBox(height: 10),

          _ErgonomicToggleTile(
            icon: Icons.table_rows_outlined,
            title: 'High-Density Tables & Compact Controls',
            subtitle: 'Tightens field heights and ledger rows for power users.',
            value: settings.compactDensity,
            onChanged: (v) {
              _triggerHaptic();
              onCompactDensityChanged(v);
            },
          ),
          Divider(color: tokens.borderSubtle, height: 1),
          _ErgonomicToggleTile(
            icon: Icons.motion_photos_off_outlined,
            title: 'Reduce Motion & Transitions',
            subtitle: 'Minimizes animations across drawers, cards, and skeletons.',
            value: settings.reduceMotion,
            onChanged: (v) {
              _triggerHaptic();
              onReduceMotionChanged(v);
            },
          ),
          Divider(color: tokens.borderSubtle, height: 1),
          _ErgonomicToggleTile(
            icon: Icons.vibration_outlined,
            title: 'Tactile Haptic Feedback',
            subtitle: 'Subtle haptic confirmation for mobile actions and saves.',
            value: settings.hapticsEnabled,
            onChanged: (v) {
              onHapticsChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _ThemeModePreviewTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final ThemeMode mode;
  final bool selected;
  final Color previewBg;
  final Color previewCard;
  final Color previewHeader;
  final bool isSplitPreview;
  final VoidCallback onTap;

  const _ThemeModePreviewTile({
    required this.label,
    required this.subtitle,
    required this.mode,
    required this.selected,
    required this.previewBg,
    required this.previewCard,
    required this.previewHeader,
    this.isSplitPreview = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Select theme mode $label',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: IcareMotion.resolve(context, IcareMotion.fast),
          curve: IcareMotion.standardCurve,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? tokens.brandSoftBg : tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? tokens.brandPrimary : tokens.borderSubtle,
              width: selected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Miniature UI Surface Preview
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: previewBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                clipBehavior: Clip.antiAlias,
                child: isSplitPreview
                    ? Row(
                        children: [
                          Expanded(
                            child: Container(
                              color: const Color(0xFFF8FAFC),
                              padding: const EdgeInsets.all(6),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              color: const Color(0xFF090E1A),
                              padding: const EdgeInsets.all(6),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111827),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF233046)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 7,
                              width: 36,
                              decoration: BoxDecoration(
                                color: previewHeader,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: previewCard,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 17,
                    color: selected ? tokens.brandPrimary : tokens.textLight,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErgonomicToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ErgonomicToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 19, color: tokens.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: tokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
