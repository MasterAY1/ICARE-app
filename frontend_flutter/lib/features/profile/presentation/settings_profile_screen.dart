import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/errors/app_error_formatter.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_database_service.dart';
import '../../../core/offline/offline_sync_manager.dart';
import '../../../core/theme/icare_theme_tokens.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/image_picker_helper.dart';
import '../../../core/widgets/icare_skeleton_loader.dart';
import '../data/models/profile_models.dart';
import '../data/profile_api_service.dart';
import 'widgets/appearance_theme_studio_card.dart';
import 'widgets/device_session_activity_card.dart';
import 'widgets/profile_identity_hero_card.dart';
import 'widgets/profile_personal_details_card.dart';
import 'widgets/security_mfa_password_card.dart';
import 'package:frontend_flutter/core/theme/icare_motion.dart';

enum _ProfileSectionTab {
  all('All', Icons.grid_view_rounded),
  profile('Profile', Icons.badge_outlined),
  theme('Theme', Icons.palette_outlined),
  security('Security', Icons.security_outlined),
  device('Device', Icons.devices_outlined);

  final String label;
  final IconData icon;
  const _ProfileSectionTab(this.label, this.icon);
}

/// Unified Staff Profile & Settings Screen accessible to ALL ICARE roles.
/// Implements FlutterCraft Fluid UI, container-driven responsive layout,
/// concise mobile copy, and segmented section filtering.
class SettingsProfileScreen extends ConsumerStatefulWidget {
  final Future<void> Function()? onRequestSignOut;
  final VoidCallback? onOpenOutboxSync;

  const SettingsProfileScreen({
    super.key,
    this.onRequestSignOut,
    this.onOpenOutboxSync,
  });

  @override
  ConsumerState<SettingsProfileScreen> createState() =>
      _SettingsProfileScreenState();
}

class _SettingsProfileScreenState extends ConsumerState<SettingsProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  bool _isLoading = true;
  String? _loadError;
  bool _isSavingProfile = false;
  bool _isUploadingAvatar = false;
  bool _isMfaBusy = false;
  bool _isPasswordBusy = false;
  bool _hasUnsavedChanges = false;
  bool _hydratedFieldsOnce = false;
  _ProfileSectionTab _activeTab = _ProfileSectionTab.all;

  StaffProfileSnapshot? _snapshot;
  MfaSetupBundle? _pendingMfaBundle;

  @override
  void initState() {
    super.initState();
    _phoneCtrl.addListener(_markDirty);
    _emailCtrl.addListener(_markDirty);
    _emergencyCtrl.addListener(_markDirty);
    _bioCtrl.addListener(_markDirty);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadProfile();
      }
    });
  }

  void _markDirty() {
    if (_hydratedFieldsOnce && !_hasUnsavedChanges && mounted) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _emergencyCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    final tokens = IcareSurfaceTokens.of(context);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? tokens.dangerDot
            : (tokens.isDark ? tokens.brandPrimaryDark : tokens.brandPrimary),
      ),
    );
  }

  Future<void> _loadProfile({bool forceHydrateFields = true}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = _snapshot == null;
      _loadError = null;
    });

    try {
      final api = ref.read(profileApiServiceProvider);
      final snap = await api.fetchProfile();
      if (!mounted) return;

      _hydratedFieldsOnce = false;
      if (forceHydrateFields || !_hasUnsavedChanges) {
        _phoneCtrl.text = snap.user.phone;
        _emailCtrl.text = snap.user.email;
        _emergencyCtrl.text = snap.emergencyContact;
        _bioCtrl.text = snap.user.bio;
        _hasUnsavedChanges = false;
      }
      _hydratedFieldsOnce = true;

      setState(() {
        _snapshot = snap;
        _isLoading = false;
      });

      await ref
          .read(authControllerProvider.notifier)
          .updateAuthenticatedUser(snap.user);
      if (snap.user.preferences.isNotEmpty) {
        await ref
            .read(themeControllerProvider.notifier)
            .applyRemotePreferences(snap.user.preferences);
      }
    } catch (e) {
      if (!mounted) return;
      final authState = ref.read(authControllerProvider);
      if (authState is AuthStateAuthenticated) {
        if (!_hydratedFieldsOnce) {
          _phoneCtrl.text = authState.user.phone;
          _emailCtrl.text = authState.user.email;
          _bioCtrl.text = authState.user.bio;
          _hydratedFieldsOnce = true;
          _hasUnsavedChanges = false;
        }
      }
      setState(() {
        _isLoading = false;
        _loadError = AppErrorDetails.from(e).message;
      });
    }
  }

  Future<void> _handlePickAndUploadAvatar() async {
    try {
      final picked = await IcareAvatarPicker.pickProfilePhoto(context);
      if (picked == null || !mounted) return;

      if (picked.bytes.length > 5 * 1024 * 1024) {
        _showSnack('Profile photo must be under 5 MB.', isError: true);
        return;
      }

      setState(() => _isUploadingAvatar = true);
      final api = ref.read(profileApiServiceProvider);
      final result = await api.uploadAvatar(
        bytes: picked.bytes,
        fileName: picked.fileName,
      );
      if (!mounted) return;

      if (ref.read(themeControllerProvider).hapticsEnabled) {
        HapticFeedback.mediumImpact();
      }

      final currentAuth = ref.read(authControllerProvider);
      if (currentAuth is AuthStateAuthenticated) {
        final updated = currentAuth.user.copyWith(avatarUrl: result.avatarUrl);
        await ref
            .read(authControllerProvider.notifier)
            .updateAuthenticatedUser(updated);
      }

      _showSnack('${result.message} (${result.sizeKb} KB)');
      await _loadProfile(forceHydrateFields: false);
    } catch (e) {
      _showSnack(AppErrorDetails.from(e).message, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _handleRemoveAvatar() async {
    final confirm = await showIcareDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Profile Photo'),
        content: const Text(
          'Revert your avatar to account initials?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove Photo'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final api = ref.read(profileApiServiceProvider);
      final updatedUser = await api.removeAvatar();
      if (!mounted) return;
      await ref
          .read(authControllerProvider.notifier)
          .updateAuthenticatedUser(updatedUser);
      await _loadProfile(forceHydrateFields: false);
      _showSnack('Profile photograph removed.');
    } catch (e) {
      _showSnack(AppErrorDetails.from(e).message, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _handleSavePersonalDetails() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSavingProfile = true);
    try {
      final api = ref.read(profileApiServiceProvider);
      final prefsJson =
          ref.read(themeControllerProvider).toPreferencesJson();
      final res = await api.updateProfile(
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        emergencyContact: _emergencyCtrl.text.trim(),
        preferences: prefsJson,
      );
      if (!mounted) return;

      if (ref.read(themeControllerProvider).hapticsEnabled) {
        HapticFeedback.mediumImpact();
      }

      await ref
          .read(authControllerProvider.notifier)
          .updateAuthenticatedUser(res.user);

      setState(() {
        _hasUnsavedChanges = false;
        _snapshot = _snapshot != null
            ? StaffProfileSnapshot(
                user: res.user,
                emergencyContact: res.emergencyContact,
                canSelfChangePassword: _snapshot!.canSelfChangePassword,
                remainingBackupCodes: _snapshot!.remainingBackupCodes,
                mfaEnrolledAt: _snapshot!.mfaEnrolledAt,
                recentActivity: _snapshot!.recentActivity,
              )
            : null;
      });
      _showSnack(res.message);
    } catch (e) {
      _showSnack(AppErrorDetails.from(e).message, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _syncPreferencesToServer() async {
    try {
      final isOnline = ref.read(isOnlineProvider);
      if (!isOnline) return;
      final api = ref.read(profileApiServiceProvider);
      final res = await api.updateProfile(
        preferences: ref.read(themeControllerProvider).toPreferencesJson(),
      );
      if (!mounted) return;
      await ref
          .read(authControllerProvider.notifier)
          .updateAuthenticatedUser(res.user);
    } catch (_) {}
  }

  Future<void> _handleInitiateMfa() async {
    setState(() => _isMfaBusy = true);
    try {
      final api = ref.read(profileApiServiceProvider);
      final bundle = await api.initiateMfaSetup();
      if (!mounted) return;
      setState(() => _pendingMfaBundle = bundle);
    } catch (e) {
      _showSnack(AppErrorDetails.from(e).message, isError: true);
    } finally {
      if (mounted) setState(() => _isMfaBusy = false);
    }
  }

  Future<void> _handleActivateMfa(String code) async {
    final clean = code.trim();
    if (clean.length < 6) {
      _showSnack('Enter the 6-digit code from your authenticator app.',
          isError: true);
      return;
    }
    setState(() => _isMfaBusy = true);
    try {
      final api = ref.read(profileApiServiceProvider);
      final msg = await api.activateMfa(clean);
      if (!mounted) return;
      if (ref.read(themeControllerProvider).hapticsEnabled) {
        HapticFeedback.mediumImpact();
      }
      setState(() => _pendingMfaBundle = null);
      await _loadProfile(forceHydrateFields: false);
      _showSnack(msg);
    } catch (e) {
      _showSnack(AppErrorDetails.from(e).message, isError: true);
    } finally {
      if (mounted) setState(() => _isMfaBusy = false);
    }
  }

  Future<void> _handleDisableMfa(String password) async {
    setState(() => _isMfaBusy = true);
    try {
      final api = ref.read(profileApiServiceProvider);
      final msg = await api.disableMfa(password);
      if (!mounted) return;
      await _loadProfile(forceHydrateFields: false);
      _showSnack(msg);
    } catch (e) {
      _showSnack(AppErrorDetails.from(e).message, isError: true);
    } finally {
      if (mounted) setState(() => _isMfaBusy = false);
    }
  }

  Future<bool> _handleChangePassword(
      String currentPassword, String newPassword) async {
    setState(() => _isPasswordBusy = true);
    try {
      final api = ref.read(profileApiServiceProvider);
      final res = await api.changeOwnPassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (!mounted) return false;
      final currentAuth = ref.read(authControllerProvider);
      if (currentAuth is AuthStateAuthenticated) {
        await ref.read(authControllerProvider.notifier).updateAuthenticatedUser(
              currentAuth.user,
              refreshedBearerToken: res.accessToken,
              refreshedCsrfToken: res.csrfToken,
            );
      }
      if (ref.read(themeControllerProvider).hapticsEnabled) {
        HapticFeedback.mediumImpact();
      }
      _showSnack(res.message);
      return true;
    } catch (e) {
      _showSnack(AppErrorDetails.from(e).message, isError: true);
      return false;
    } finally {
      if (mounted) setState(() => _isPasswordBusy = false);
    }
  }

  Future<void> _handleClearReadCache() async {
    final confirm = await showIcareDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Offline Read Cache'),
        content: const Text(
          'Remove cached dashboards and lists? Pending offline outbox items stay preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear Read Cache'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ref
          .read(offlineDatabaseServiceProvider)
          .clearSessionStorage(clearOutbox: false);
      _showSnack('Read cache cleared. Outbox preserved.');
    } catch (e) {
      _showSnack('Could not clear read cache: ${AppErrorDetails.from(e).message}', isError: true);
    }
  }

  Widget _buildMobileSectionBar(IcareSurfaceTokens tokens, bool haptics) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _ProfileSectionTab.values.map((tab) {
            final selected = _activeTab == tab;
            final activeBg =
                tokens.isDark ? tokens.brandPrimaryDark : tokens.brandPrimary;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Semantics(
                button: true,
                selected: selected,
                label: '${tab.label} section',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    if (haptics) HapticFeedback.selectionClick();
                    setState(() => _activeTab = tab);
                  },
                  child: AnimatedContainer(
                    duration: IcareMotion.resolve(context, IcareMotion.fast),
                    curve: IcareMotion.standardCurve,
                    constraints: const BoxConstraints(minHeight: 38),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? activeBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.icon,
                          size: 15,
                          color: selected ? Colors.white : tokens.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                            color:
                                selected ? Colors.white : tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    if (authState is! AuthStateAuthenticated) {
      return const SizedBox.shrink();
    }

    final appearance = ref.watch(themeControllerProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final pendingOutbox = ref.watch(pendingOutboxCountProvider);
    final tokens = IcareSurfaceTokens.of(context);

    final user = _snapshot?.user ?? authState.user;
    final canChangePw = _snapshot?.canSelfChangePassword ??
        !{
          'co',
          'credit officer',
          'officer',
          'credit_officer',
        }.contains(user.role.trim().toLowerCase());

    if (_isLoading && _snapshot == null) {
      return const IcareFormSkeleton(fieldCount: 4);
    }

    final personalDetailsCard = ProfilePersonalDetailsCard(
      user: user,
      phoneController: _phoneCtrl,
      emailController: _emailCtrl,
      emergencyController: _emergencyCtrl,
      bioController: _bioCtrl,
      formKey: _formKey,
      isSaving: _isSavingProfile,
      hasUnsavedChanges: _hasUnsavedChanges,
      onSave: _handleSavePersonalDetails,
    );

    final themeStudioCard = AppearanceThemeStudioCard(
      settings: appearance,
      onThemeModeChanged: (m) async {
        await ref.read(themeControllerProvider.notifier).setThemeMode(m);
        _syncPreferencesToServer();
      },
      onAccentPresetChanged: (p) async {
        await ref.read(themeControllerProvider.notifier).setAccentPreset(p);
        _syncPreferencesToServer();
      },
      onCompactDensityChanged: (v) async {
        await ref.read(themeControllerProvider.notifier).setCompactDensity(v);
        _syncPreferencesToServer();
      },
      onReduceMotionChanged: (v) async {
        await ref.read(themeControllerProvider.notifier).setReduceMotion(v);
        _syncPreferencesToServer();
      },
      onHapticsChanged: (v) async {
        await ref.read(themeControllerProvider.notifier).setHapticsEnabled(v);
        _syncPreferencesToServer();
      },
      onResetDefaults: () async {
        await ref.read(themeControllerProvider.notifier).resetToDefaults();
        _syncPreferencesToServer();
        _showSnack('Theme preferences reset to default.');
      },
    );

    final securityCard = SecurityMfaPasswordCard(
      mfaEnabled: user.mfaEnabled,
      mfaEnrolledAt: _snapshot?.mfaEnrolledAt,
      remainingBackupCodes: _snapshot?.remainingBackupCodes ?? 0,
      canSelfChangePassword: canChangePw,
      isMfaBusy: _isMfaBusy,
      isPasswordBusy: _isPasswordBusy,
      pendingMfaBundle: _pendingMfaBundle,
      onInitiateMfaSetup: _handleInitiateMfa,
      onCancelMfaSetup: () => setState(() => _pendingMfaBundle = null),
      onActivateMfa: _handleActivateMfa,
      onDisableMfa: _handleDisableMfa,
      onChangePassword: _handleChangePassword,
    );

    final deviceCard = DeviceSessionActivityCard(
      isOnline: isOnline,
      pendingOutboxCount: pendingOutbox,
      recentActivity: _snapshot?.recentActivity ?? const [],
      onOpenOutboxSync: widget.onOpenOutboxSync,
      onClearLocalCache: _handleClearReadCache,
      onSignOut: () => widget.onRequestSignOut?.call(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTwoColumn = constraints.maxWidth >= 880;
        final showProfile = _activeTab == _ProfileSectionTab.all ||
            _activeTab == _ProfileSectionTab.profile;
        final showTheme = _activeTab == _ProfileSectionTab.all ||
            _activeTab == _ProfileSectionTab.theme;
        final showSecurity = _activeTab == _ProfileSectionTab.all ||
            _activeTab == _ProfileSectionTab.security;
        final showDevice = _activeTab == _ProfileSectionTab.all ||
            _activeTab == _ProfileSectionTab.device;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loadError != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: tokens.warningBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tokens.warningBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: tokens.warningText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Showing cached profile ($_loadError)',
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.warningText,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _loadProfile(forceHydrateFields: false),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],

            // 1. Compact Profile Hero Card
            ProfileIdentityHeroCard(
              user: user,
              isUploadingAvatar: _isUploadingAvatar,
              onPickAvatar: _handlePickAndUploadAvatar,
              onRemoveAvatar: _handleRemoveAvatar,
              isOnline: isOnline,
            ),
            const SizedBox(height: 12),

            // 2. Container-Responsive Layout
            if (isTwoColumn)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        personalDetailsCard,
                        const SizedBox(height: 16),
                        securityCard,
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        themeStudioCard,
                        const SizedBox(height: 16),
                        deviceCard,
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              _buildMobileSectionBar(tokens, appearance.hapticsEnabled),
              const SizedBox(height: 12),
              if (showTheme) ...[
                themeStudioCard,
                const SizedBox(height: 12),
              ],
              if (showProfile) ...[
                personalDetailsCard,
                const SizedBox(height: 12),
              ],
              if (showSecurity) ...[
                securityCard,
                const SizedBox(height: 12),
              ],
              if (showDevice) deviceCard,
            ],
          ],
        );
      },
    );
  }
}
