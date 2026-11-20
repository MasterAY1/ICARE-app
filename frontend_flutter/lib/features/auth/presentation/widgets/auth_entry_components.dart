import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/icare_theme_tokens.dart';

/// Supported authentication & activation modes inside the unified entry flow.
enum AuthEntryMode {
  signIn,
  onboardingAccess,
}

/// Reduced-motion-aware segmented mode selector between Staff Sign-In and Onboarding Access.
class IcareAuthModeSegmentedBar extends StatelessWidget {
  final AuthEntryMode activeMode;
  final ValueChanged<AuthEntryMode> onModeChanged;
  final bool enabled;

  const IcareAuthModeSegmentedBar({
    super.key,
    required this.activeMode,
    required this.onModeChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Duration animDuration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 220);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle, width: 1.0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double segmentWidth = (constraints.maxWidth) / 2;
          return Stack(
            children: [
              AnimatedAlign(
                duration: animDuration,
                curve: Curves.easeOutCubic,
                alignment: activeMode == AuthEntryMode.signIn
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: segmentWidth,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: tokens.brandPrimary.withValues(alpha: 0.35),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: tokens.isDark ? 0.24 : 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _SegmentButton(
                      label: 'Staff Sign-In',
                      icon: Icons.lock_outline_rounded,
                      selected: activeMode == AuthEntryMode.signIn,
                      enabled: enabled,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onModeChanged(AuthEntryMode.signIn);
                      },
                    ),
                  ),
                  Expanded(
                    child: _SegmentButton(
                      label: 'Onboarding Access',
                      icon: Icons.badge_outlined,
                      selected: activeMode == AuthEntryMode.onboardingAccess,
                      enabled: enabled,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onModeChanged(AuthEntryMode.onboardingAccess);
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final Color foreground =
        selected ? tokens.brandPrimary : tokens.textMuted;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Institutional high-contrast text input field built for bright sunlight & desktop web.
class IcareAuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputAction textInputAction;
  final TextInputType keyboardType;
  final Iterable<String>? autofillHints;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool tabularDigits;
  final bool enabled;

  const IcareAuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.textInputAction = TextInputAction.next,
    this.keyboardType = TextInputType.text,
    this.autofillHints,
    this.suffixIcon,
    this.focusNode,
    this.onSubmitted,
    this.onChanged,
    this.tabularDigits = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscureText,
          textInputAction: textInputAction,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          cursorColor: tokens.brandPrimary,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFeatures:
                tabularDigits ? const [FontFeature.tabularFigures()] : null,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: tokens.textLight,
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: enabled ? tokens.surface : tokens.surfaceHover,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            prefixIcon:
                Icon(prefixIcon, size: 18, color: tokens.brandPrimary),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: tokens.borderStrong, width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: tokens.borderStrong, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: tokens.brandPrimary, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tactile primary CTA button with immediate press micro-scale and loading pill morph.
class IcareTactilePrimaryButton extends StatefulWidget {
  final bool isLoading;
  final String label;
  final VoidCallback onPressed;
  final IconData trailingIcon;

  const IcareTactilePrimaryButton({
    super.key,
    required this.isLoading,
    required this.label,
    required this.onPressed,
    this.trailingIcon = Icons.arrow_forward_rounded,
  });

  @override
  State<IcareTactilePrimaryButton> createState() =>
      _IcareTactilePrimaryButtonState();
}

class _IcareTactilePrimaryButtonState extends State<IcareTactilePrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.985).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Duration morphDuration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 240);
    final Duration switchDuration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 180);

    return Semantics(
      button: true,
      enabled: !widget.isLoading,
      label: widget.label,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double targetWidth =
              widget.isLoading ? 52.0 : constraints.maxWidth;

          return Center(
            child: AnimatedBuilder(
              animation: _scaleAnim,
              builder: (context, child) {
                return Transform.scale(
                  scale: reduceMotion ? 1.0 : _scaleAnim.value,
                  child: child,
                );
              },
              child: MouseRegion(
                cursor: widget.isLoading
                    ? SystemMouseCursors.basic
                    : SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: widget.isLoading || reduceMotion
                      ? null
                      : (_) => _pressController.forward(),
                  onTapUp: widget.isLoading
                      ? null
                      : (_) {
                          if (!reduceMotion) {
                            _pressController.reverse();
                          }
                          HapticFeedback.mediumImpact();
                          widget.onPressed();
                        },
                  onTapCancel: () {
                    if (!reduceMotion) {
                      _pressController.reverse();
                    }
                  },
                  child: AnimatedContainer(
                    duration: morphDuration,
                    curve: Curves.easeInOutCubic,
                    height: 48,
                    width: targetWidth,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          IcareSurfaceTokens.of(context).brandPrimaryDark,
                          IcareSurfaceTokens.of(context).brandPrimary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(
                        widget.isLoading ? 24.0 : 10.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: IcareSurfaceTokens.of(context)
                              .brandPrimary
                              .withValues(alpha: 0.28),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: AnimatedSwitcher(
                      duration: switchDuration,
                      child: widget.isLoading
                          ? const SizedBox(
                              key: ValueKey('btn_loading'),
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              key: ValueKey('btn_idle_${widget.label}'),
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.label,
                                    softWrap: true,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  widget.trailingIcon,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Real-time accessible password criteria checklist matching backend policy.
class PasswordRequirementsChecklist extends StatelessWidget {
  final String currentPassword;
  final String newPassword;
  final String confirmPassword;

  const PasswordRequirementsChecklist({
    super.key,
    required this.currentPassword,
    required this.newPassword,
    required this.confirmPassword,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final String trimmed = newPassword.trim();
    final bool hasMinLength = trimmed.length >= 8;
    final bool differsFromTemp =
        trimmed.isNotEmpty && trimmed != currentPassword.trim();
    final bool matchesConfirm =
        trimmed.isNotEmpty && trimmed == confirmPassword.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVATION PASSWORD REQUIREMENTS',
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 6),
          _RequirementItem(
            label: 'At least 8 characters',
            met: hasMinLength,
          ),
          const SizedBox(height: 4),
          _RequirementItem(
            label: 'Different from your temporary password',
            met: differsFromTemp,
          ),
          const SizedBox(height: 4),
          _RequirementItem(
            label: 'Matches confirmation field',
            met: matchesConfirm,
          ),
        ],
      ),
    );
  }
}

class _RequirementItem extends StatelessWidget {
  final String label;
  final bool met;

  const _RequirementItem({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final Color iconColor =
        met ? tokens.successDot : tokens.textLight;
    final Color textColor =
        met ? tokens.successText : tokens.textMuted;

    return Row(
      children: [
        Icon(
          met
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 14,
          color: iconColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            softWrap: true,
            style: TextStyle(
              fontSize: 12,
              fontWeight: met ? FontWeight.w600 : FontWeight.w400,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Interactive Onboarding & Invitation Access hub routed directly to real portals.
class OnboardingAccessPanel extends StatelessWidget {
  final TextEditingController tokenController;
  final VoidCallback onSubmitToken;
  final VoidCallback onOpenBranchPortal;
  final VoidCallback onOpenOfficerPortal;
  final VoidCallback onSwitchToSignIn;

  const OnboardingAccessPanel({
    super.key,
    required this.tokenController,
    required this.onSubmitToken,
    required this.onOpenBranchPortal,
    required this.onOpenOfficerPortal,
    required this.onSwitchToSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IcareAuthField(
          controller: tokenController,
          label: 'Invitation Token',
          hint: 'e.g. onb_branch_... or onb_co_...',
          prefixIcon: Icons.vpn_key_outlined,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmitToken(),
        ),
        const SizedBox(height: 14),
        IcareTactilePrimaryButton(
          isLoading: false,
          label: 'Open Onboarding Workspace',
          trailingIcon: Icons.launch_rounded,
          onPressed: onSubmitToken,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _PortalShortcutButton(
                title: 'Branch Portal',
                subtitle: 'Branch token lookup',
                icon: Icons.apartment_rounded,
                onTap: onOpenBranchPortal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PortalShortcutButton(
                title: 'Officer Portal',
                subtitle: 'Credit officer workspace',
                icon: Icons.person_pin_outlined,
                onTap: onOpenOfficerPortal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: tokens.infoBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.infoBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: tokens.infoText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New staff with temporary credentials?',
                      softWrap: true,
                      style: TextStyle(
                        color: tokens.infoText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sign in on Staff Sign-In with your temporary password to activate your account and set your personal password.',
                      softWrap: true,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: onSwitchToSignIn,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          'Go to Staff Sign-In',
                          style: TextStyle(
                            color: tokens.infoText,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PortalShortcutButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _PortalShortcutButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    return OutlinedButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: tokens.surfaceSubtle,
        foregroundColor: tokens.textPrimary,
        side: BorderSide(color: tokens.borderSubtle),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tokens.brandPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: tokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
