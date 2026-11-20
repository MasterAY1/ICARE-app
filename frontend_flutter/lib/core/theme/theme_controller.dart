import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'icare_theme_tokens.dart';

/// Immutable user appearance & ergonomics state synchronized across device and backend.
@immutable
class AppAppearanceSettings {
  final ThemeMode themeMode;
  final IcareAccentPreset accentPreset;
  final bool compactDensity;
  final bool reduceMotion;
  final bool hapticsEnabled;
  final bool isLoaded;

  const AppAppearanceSettings({
    this.themeMode = ThemeMode.light,
    this.accentPreset = IcareAccentPreset.emerald,
    this.compactDensity = false,
    this.reduceMotion = false,
    this.hapticsEnabled = true,
    this.isLoaded = false,
  });

  String get themeModeKey {
    switch (themeMode) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
    }
  }

  static ThemeMode parseThemeMode(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  AppAppearanceSettings copyWith({
    ThemeMode? themeMode,
    IcareAccentPreset? accentPreset,
    bool? compactDensity,
    bool? reduceMotion,
    bool? hapticsEnabled,
    bool? isLoaded,
  }) {
    return AppAppearanceSettings(
      themeMode: themeMode ?? this.themeMode,
      accentPreset: accentPreset ?? this.accentPreset,
      compactDensity: compactDensity ?? this.compactDensity,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  Map<String, dynamic> toPreferencesJson() {
    return {
      'theme_mode': themeModeKey,
      'accent_preset': accentPreset.keyName,
      'compact_density': compactDensity,
      'reduce_motion': reduceMotion,
      'haptics_enabled': hapticsEnabled,
    };
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, AppAppearanceSettings>((ref) {
  return ThemeController();
});

class ThemeController extends StateNotifier<AppAppearanceSettings> {
  static const String _kThemeModeKey = 'icare_pref_theme_mode';
  static const String _kAccentKey = 'icare_pref_accent_preset';
  static const String _kCompactKey = 'icare_pref_compact_density';
  static const String _kReduceMotionKey = 'icare_pref_reduce_motion';
  static const String _kHapticsKey = 'icare_pref_haptics_enabled';

  ThemeController({bool autoLoad = true}) : super(const AppAppearanceSettings()) {
    if (autoLoad) {
      loadFromStorage();
    }
  }

  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = AppAppearanceSettings.parseThemeMode(prefs.getString(_kThemeModeKey));
      final accent = IcareAccentPreset.fromKey(prefs.getString(_kAccentKey));
      final compact = prefs.getBool(_kCompactKey) ?? false;
      final reduceMotion = prefs.getBool(_kReduceMotionKey) ?? false;
      final haptics = prefs.getBool(_kHapticsKey) ?? true;
      if (!mounted) return;
      state = state.copyWith(
        themeMode: mode,
        accentPreset: accent,
        compactDensity: compact,
        reduceMotion: reduceMotion,
        hapticsEnabled: haptics,
        isLoaded: true,
      );
    } catch (_) {
      if (mounted) {
        state = state.copyWith(isLoaded: true);
      }
    }
  }

  Future<void> _persistToStorage(AppAppearanceSettings next) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString(_kThemeModeKey, next.themeModeKey),
        prefs.setString(_kAccentKey, next.accentPreset.keyName),
        prefs.setBool(_kCompactKey, next.compactDensity),
        prefs.setBool(_kReduceMotionKey, next.reduceMotion),
        prefs.setBool(_kHapticsKey, next.hapticsEnabled),
      ]);
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final next = state.copyWith(themeMode: mode, isLoaded: true);
    state = next;
    await _persistToStorage(next);
  }

  Future<void> setAccentPreset(IcareAccentPreset preset) async {
    final next = state.copyWith(accentPreset: preset, isLoaded: true);
    state = next;
    await _persistToStorage(next);
  }

  Future<void> setCompactDensity(bool value) async {
    final next = state.copyWith(compactDensity: value, isLoaded: true);
    state = next;
    await _persistToStorage(next);
  }

  Future<void> setReduceMotion(bool value) async {
    final next = state.copyWith(reduceMotion: value, isLoaded: true);
    state = next;
    await _persistToStorage(next);
  }

  Future<void> setHapticsEnabled(bool value) async {
    final next = state.copyWith(hapticsEnabled: value, isLoaded: true);
    state = next;
    await _persistToStorage(next);
  }

  /// Hydrates theme preferences received from backend `UserInfo.preferences`.
  Future<void> applyRemotePreferences(Map<String, dynamic> remotePrefs) async {
    if (remotePrefs.isEmpty) return;
    final next = AppAppearanceSettings(
      themeMode: remotePrefs.containsKey('theme_mode')
          ? AppAppearanceSettings.parseThemeMode(remotePrefs['theme_mode']?.toString())
          : state.themeMode,
      accentPreset: remotePrefs.containsKey('accent_preset')
          ? IcareAccentPreset.fromKey(remotePrefs['accent_preset']?.toString())
          : state.accentPreset,
      compactDensity: remotePrefs['compact_density'] is bool
          ? remotePrefs['compact_density'] as bool
          : state.compactDensity,
      reduceMotion: remotePrefs['reduce_motion'] is bool
          ? remotePrefs['reduce_motion'] as bool
          : state.reduceMotion,
      hapticsEnabled: remotePrefs['haptics_enabled'] is bool
          ? remotePrefs['haptics_enabled'] as bool
          : state.hapticsEnabled,
      isLoaded: true,
    );
    state = next;
    await _persistToStorage(next);
  }

  Future<void> resetToDefaults() async {
    const next = AppAppearanceSettings(isLoaded: true);
    state = next;
    await _persistToStorage(next);
  }
}
