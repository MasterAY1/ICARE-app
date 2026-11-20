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
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final systemModeHint =
        platformBrightness == Brightness.dark ? 'OS: Dark' : 'OS: Light';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;
        final threeAcross = constraints.maxWidth >= 280;
        final twoColAccents = constraints.maxWidth >= 280;

        final modeOptions = [
          _ThemeModePreviewTile(
            label: 'Light Slate',
            subtitle: 'Daylight',
            mode: ThemeMode.light,
            selected: settings.themeMode == ThemeMode.light,
            previewBg: const Color(0xFFF8FAFC),
            previewCard: Colors.white,
            previewHeader: settings.accentPreset.lightPrimary,
            compact: isCompact,
            onTap: () {
              _triggerHaptic();
              onThemeModeChanged(ThemeMode.light);
            },
          ),
          _ThemeModePreviewTile(
            label: 'Dark Vault',
            subtitle: 'Low glare',
            mode: ThemeMode.dark,
            selected: settings.themeMode == ThemeMode.dark,
            previewBg: const Color(0xFF090E1A),
            previewCard: const Color(0xFF111827),
            previewHeader: settings.accentPreset.darkPrimary,
            compact: isCompact,
            onTap: () {
              _triggerHaptic();
              onThemeModeChanged(ThemeMode.dark);
            },
          ),
          _ThemeModePreviewTile(
            label: 'System Auto',
            subtitle: systemModeHint,
            mode: ThemeMode.system,
            selected: settings.themeMode == ThemeMode.system,
            previewBg: const Color(0xFF334155),
            previewCard: const Color(0xFFF8FAFC),
            previewHeader: settings.accentPreset.lightPrimaryLight,
            isSplitPreview: true,
            compact: isCompact,
            onTap: () {
              _triggerHaptic();
              onThemeModeChanged(ThemeMode.system);
            },
          ),
        ];

        final accentTiles = IcareAccentPreset.values.map((preset) {
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
                constraints: const BoxConstraints(minHeight: 44),
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 10 : 12,
                  vertical: isCompact ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (tokens.isDark
                          ? preset.darkSoftBg
                          : preset.lightSoftBg)
                      : tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? primarySwatch : tokens.borderSubtle,
                    width: isSelected ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primarySwatch,
                        border: Border.all(
                          color: preset.lightAccent,
                          width: 1.8,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              size: 12, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        preset.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isCompact ? 11.5 : 12.5,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList();

        return IcareCard(
          padding: EdgeInsets.all(isCompact ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: tokens.brandSoftBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.brandSoftBorder),
                    ),
                    child: Icon(
                      Icons.palette_outlined,
                      size: 17,
                      color: tokens.brandSoftText,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Appearance & Theme',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
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
              const SizedBox(height: 12),

              Text(
                'Color Scheme',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: tokens.textMuted,
                ),
              ),
              const SizedBox(height: 8),

              if (threeAcross)
                Row(
                  children: [
                    Expanded(child: modeOptions[0]),
                    const SizedBox(width: 8),
                    Expanded(child: modeOptions[1]),
                    const SizedBox(width: 8),
                    Expanded(child: modeOptions[2]),
                  ],
                )
              else
                Column(
                  children: modeOptions
                      .map((o) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: o,
                          ))
                      .toList(),
                ),

              const SizedBox(height: 14),
              Text(
                'Accent Palette',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: tokens.textMuted,
                ),
              ),
              const SizedBox(height: 8),

              if (twoColAccents)
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: accentTiles[0]),
                        const SizedBox(width: 8),
                        Expanded(child: accentTiles[1]),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: accentTiles[2]),
                        const SizedBox(width: 8),
                        Expanded(child: accentTiles[3]),
                      ],
                    ),
                  ],
                )
              else
                Column(
                  children: accentTiles
                      .map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: t,
                          ))
                      .toList(),
                ),

              const SizedBox(height: 14),
              Divider(color: tokens.borderSubtle, height: 1),
              const SizedBox(height: 6),

              _ErgonomicToggleTile(
                icon: Icons.table_rows_outlined,
                title: 'Compact Density',
                subtitle: 'Tighter rows & controls',
                value: settings.compactDensity,
                onChanged: (v) {
                  _triggerHaptic();
                  onCompactDensityChanged(v);
                },
              ),
              Divider(color: tokens.borderSubtle, height: 1),
              _ErgonomicToggleTile(
                icon: Icons.motion_photos_off_outlined,
                title: 'Reduce Motion',
                subtitle: 'Fewer UI animations',
                value: settings.reduceMotion,
                onChanged: (v) {
                  _triggerHaptic();
                  onReduceMotionChanged(v);
                },
              ),
              Divider(color: tokens.borderSubtle, height: 1),
              _ErgonomicToggleTile(
                icon: Icons.vibration_outlined,
                title: 'Haptic Feedback',
                subtitle: 'Touch confirmation',
                value: settings.hapticsEnabled,
                onChanged: (v) {
                  onHapticsChanged(v);
                },
              ),
            ],
          ),
        );
      },
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
  final bool compact;
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
    this.compact = false,
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
          padding: EdgeInsets.all(compact ? 8 : 10),
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
              Container(
                height: compact ? 34 : 42,
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
                              padding: const EdgeInsets.all(5),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              color: const Color(0xFF090E1A),
                              padding: const EdgeInsets.all(5),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111827),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                      color: const Color(0xFF233046)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.all(5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 6,
                              width: 28,
                              decoration: BoxDecoration(
                                color: previewHeader,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: previewCard,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 11.5 : 12.5,
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
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
                    size: 15,
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tokens.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 11,
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
