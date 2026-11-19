import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/icare_colors.dart';
import '../../../core/theme/icare_spacing.dart';
import '../../onboarding/presentation/branch_onboarding_portal_screen.dart';
import '../../onboarding/presentation/credit_officer_portal_screen.dart';
import '../../shared/presentation/co_app_scaffold.dart';
import 'widgets/auth_entry_components.dart';
import 'widgets/icare_brand_crest.dart';

/// Unified Institutional Authentication & Onboarding Entry Screen for ICARE Core Banking.
///
/// Supports four live workflows against existing backend APIs:
/// 1. Staff Sign-In (`POST /api/v1/auth/login`)
/// 2. First-Time Account Activation / Password Setup (`POST /api/v1/auth/change-initial-password`)
/// 3. Two-Factor Authentication Challenge (`POST /api/v1/auth/mfa/challenge`)
/// 4. Token-Gated Branch & Credit Officer Onboarding Access
class LoginScreen extends ConsumerStatefulWidget {
  final AuthEntryMode initialMode;

  const LoginScreen({
    super.key,
    this.initialMode = AuthEntryMode.signIn,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _mfaCodeController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _mfaCodeFocus = FocusNode();
  final FocusNode _newPasswordFocus = FocusNode();

  late AuthEntryMode _entryMode;

  bool _obscurePassword = true;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _localValidationError;

  late final AnimationController _entranceCtrl;
  late final AnimationController _shakeCtrl;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;

  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _entryMode = widget.initialMode;

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _cardFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOut,
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: Curves.easeOutCubic,
      ),
    );

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    _disableAnimations = reduced;

    if (reduced) {
      _entranceCtrl.value = 1.0;
    } else if (!_entranceCtrl.isCompleted && !_entranceCtrl.isAnimating) {
      _entranceCtrl.forward();
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    _mfaCodeController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _mfaCodeFocus.dispose();
    _newPasswordFocus.dispose();
    _entranceCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _triggerErrorShake(String message) {
    if (mounted) {
      setState(() => _localValidationError = message);
    }
    if (!_disableAnimations) {
      _shakeCtrl.forward(from: 0.0);
    }
  }

  void _clearChallengeInputs() {
    _mfaCodeController.clear();
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _obscureCurrentPassword = true;
    _obscureNewPassword = true;
    _obscureConfirmPassword = true;
  }

  Future<void> _handleLogin() async {
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text;

    if (username.isEmpty) {
      _triggerErrorShake('Please enter your staff username to continue.');
      _usernameFocus.requestFocus();
      return;
    }
    if (password.isEmpty) {
      _triggerErrorShake('Please enter your password to continue.');
      _passwordFocus.requestFocus();
      return;
    }

    setState(() => _localValidationError = null);
    await ref.read(authControllerProvider.notifier).login(
          username: username,
          password: password,
        );
  }

  Future<void> _handleMfaSubmit() async {
    final String code = _mfaCodeController.text.trim();
    if (code.isEmpty) {
      _triggerErrorShake(
          'Please enter your 6-digit verification or recovery code.');
      _mfaCodeFocus.requestFocus();
      return;
    }

    setState(() => _localValidationError = null);
    await ref
        .read(authControllerProvider.notifier)
        .submitMfaChallenge(code: code);
  }

  Future<void> _handleInitialPasswordSubmit() async {
    final String currentPassword = _currentPasswordController.text;
    final String newPassword = _newPasswordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();

    if (currentPassword.trim().isEmpty) {
      _triggerErrorShake('Please enter your temporary or current password.');
      return;
    }
    if (newPassword.length < 8) {
      _triggerErrorShake(
          'Your new password must be at least 8 characters long.');
      return;
    }
    if (newPassword == currentPassword.trim()) {
      _triggerErrorShake(
        'Your new password cannot match the temporary password.',
      );
      return;
    }
    if (newPassword != confirmPassword) {
      _triggerErrorShake('Password confirmation does not match.');
      return;
    }

    setState(() => _localValidationError = null);
    await ref.read(authControllerProvider.notifier).submitInitialPasswordChange(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
  }

  void _handleCancelChallenge() {
    _clearChallengeInputs();
    setState(() => _localValidationError = null);
    ref.read(authControllerProvider.notifier).cancelChallenge();
  }

  void _handleOnboardingTokenSubmit() {
    final String token = _tokenController.text.trim();
    if (token.isEmpty) {
      _triggerErrorShake(
        'Enter your onboarding token or select Branch Portal / Officer Portal below.',
      );
      return;
    }
    setState(() => _localValidationError = null);

    if (token.startsWith('onb_co_')) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CreditOfficerPortalScreen(coToken: token),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BranchOnboardingPortalScreen(token: token),
      ),
    );
  }

  void _openBranchPortal() {
    setState(() => _localValidationError = null);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const BranchOnboardingPortalScreen(token: ''),
      ),
    );
  }

  void _openOfficerPortal() {
    setState(() => _localValidationError = null);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CreditOfficerPortalScreen(coToken: ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthStateAuthenticated) {
        _passwordController.clear();
        _clearChallengeInputs();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const CoAppScaffold()),
        );
      } else if (next is AuthStatePasswordChangeRequired) {
        if (previous is! AuthStatePasswordChangeRequired) {
          _clearChallengeInputs();
          if (_passwordController.text.isNotEmpty) {
            _currentPasswordController.text = _passwordController.text;
          }
          _localValidationError = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _newPasswordFocus.requestFocus();
          });
        } else if (next.errorMessage != null &&
            next.errorMessage != (previous).errorMessage) {
          if (!_disableAnimations) _shakeCtrl.forward(from: 0.0);
        }
      } else if (next is AuthStateMfaRequired) {
        if (previous is! AuthStateMfaRequired) {
          _mfaCodeController.clear();
          _localValidationError = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _mfaCodeFocus.requestFocus();
          });
        } else if (next.errorMessage != null &&
            next.errorMessage != (previous).errorMessage) {
          if (!_disableAnimations) _shakeCtrl.forward(from: 0.0);
        }
      } else if (next is AuthStateError) {
        if (!_disableAnimations) {
          _shakeCtrl.forward(from: 0.0);
        }
      }
    });

    final AuthState authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: IcareColors.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isSplitDesktop =
              constraints.maxWidth >= IcareSpacing.breakpointTablet;

          if (isSplitDesktop) {
            return _buildDesktopSplitLayout(authState, constraints);
          }
          return _buildMobileLayout(authState);
        },
      ),
    );
  }

  /// Desktop / Landscape Tablet Split Architecture:
  /// Deep Forest Emerald Story Canopy (left) + High-Clarity Slate Form Canvas (right).
  Widget _buildDesktopSplitLayout(
    AuthState authState,
    BoxConstraints constraints,
  ) {
    return Row(
      children: [
        // Left Brand Canopy
        Expanded(
          flex: 46,
          child: Container(
            height: constraints.maxHeight,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  IcareColors.primaryDark,
                  Color(0xFF043B2E),
                  IcareColors.primaryDark,
                ],
              ),
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(
                    painter:
                        IcareEmeraldBackdropPainter(alignmentYFactor: 0.26),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 32,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: _buildDesktopBrandPanel(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right High-Contrast Slate Form Workspace
        Expanded(
          flex: 54,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: 36,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 456),
                  child: _buildAnimatedEntryCard(authState),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Mobile / Compact Portrait Layout:
  /// Emerald Hero Crest Header seamlessly transitioning into crisp high-contrast sheet card.
  Widget _buildMobileLayout(AuthState authState) {
    return Container(
      color: IcareColors.canvas,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    IcareColors.primaryDark,
                    Color(0xFF054233),
                  ],
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: const Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(28),
                      ),
                      child: CustomPaint(
                        painter: IcareEmeraldBackdropPainter(
                          alignmentYFactor: 0.45,
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 14, 20, 20),
                      child: Column(
                        children: [
                          IcareBrandCrest(
                            size: 56,
                            heroTag: 'icare_brand_crest',
                            animateSweep: false,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'ICARE',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 3.0,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Core Banking & Field Operations',
                            textAlign: TextAlign.center,
                            softWrap: true,
                            style: TextStyle(
                              color: Color(0xFFA7F3D0),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      children: [
                        _buildAnimatedEntryCard(authState),
                        const SizedBox(height: 20),
                        _buildMobileInstitutionalFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBrandPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const IcareBrandCrest(
              size: 72,
              heroTag: 'icare_brand_crest',
              animateSweep: false,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFF34D399).withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Text(
                      'EST. 2006 • SOUTH-WEST NIGERIA',
                      style: TextStyle(
                        color: Color(0xFF6EE7B7),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ICARE Core Banking',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.7,
              height: 1.2,
            ),
            children: [
              TextSpan(text: 'Empowering Communities,\n'),
              TextSpan(
                text: 'Growing Together',
                style: TextStyle(color: Color(0xFF6EE7B7)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '"Building a better community through inspiration, motivation and empowerment"',
          style: TextStyle(
            color: Color(0xFFA7F3D0),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'ICARE (Initiative for Community Advancement, Relief and Empowerment) operates across South-Western Nigeria, supporting micro-credit programmes for traders and artisans, asset acquisition schemes, and community empowerment.',
          style: TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 13,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 22),
        Container(
          width: 52,
          height: 2,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [IcareColors.accent, Colors.transparent],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'OUR VISION',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'To be among the foremost catalysts in initiating and implementing sustainable programmes focused on empowering people for growth and self-reliance.',
          style: TextStyle(
            color: Color(0xFFE2E8F0),
            fontSize: 12.5,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 18),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _BrandValueChip('Integrity'),
            _BrandValueChip('Commitment'),
            _BrandValueChip('Competence'),
            _BrandValueChip('Teamwork'),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.only(top: 14),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 15,
                color: Color(0xFF6EE7B7),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Headquarters: 7 Ibifiele Street, Aiyegbami, Sagamu, Ogun State, Nigeria',
                  softWrap: true,
                  style: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedEntryCard(AuthState authState) {
    final bool isLoading = authState is AuthStateLoading ||
        (authState is AuthStateMfaRequired && authState.isSubmitting) ||
        (authState is AuthStatePasswordChangeRequired &&
            authState.isSubmitting);

    final bool isInChallengeState = authState is AuthStateMfaRequired ||
        authState is AuthStatePasswordChangeRequired;

    final Widget card = Container(
      decoration: BoxDecoration(
        color: IcareColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: IcareColors.border, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCardHeader(authState),
          if (!isInChallengeState) ...[
            const SizedBox(height: 18),
            IcareAuthModeSegmentedBar(
              activeMode: _entryMode,
              enabled: !isLoading,
              onModeChanged: (mode) {
                if (_entryMode == mode) return;
                setState(() {
                  _entryMode = mode;
                  _localValidationError = null;
                });
              },
            ),
          ],
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: _disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey<String>(_activeBodyKey(authState)),
              child: _buildActiveBody(authState, isLoading),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: IcareColors.border),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: IcareColors.primaryLight,
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Encrypted Staff Session & Audit Protected Workspace',
                    softWrap: true,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: IcareColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return FadeTransition(
      opacity: _cardFade,
      child: SlideTransition(
        position: _cardSlide,
        child: AnimatedBuilder(
          animation: _shakeCtrl,
          builder: (context, child) {
            final double dx = _disableAnimations
                ? 0.0
                : math.sin(_shakeCtrl.value * math.pi * 5) *
                    (1.0 - _shakeCtrl.value) *
                    8.0;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: card,
        ),
      ),
    );
  }

  Widget _buildCardHeader(AuthState authState) {
    String title;
    String subtitle;
    IconData badgeIcon;

    if (authState is AuthStateMfaRequired) {
      title = 'Two-Factor Verification';
      subtitle =
          'Enter your 6-digit authenticator or recovery code to continue.';
      badgeIcon = Icons.verified_user_outlined;
    } else if (authState is AuthStatePasswordChangeRequired) {
      title = 'First-Time Account Activation';
      subtitle = 'Replace your temporary password with a personal password.';
      badgeIcon = Icons.password_rounded;
    } else if (_entryMode == AuthEntryMode.onboardingAccess) {
      title = 'Branch & Officer Onboarding';
      subtitle =
          'Activate a newly provisioned branch or Credit Officer workspace.';
      badgeIcon = Icons.badge_outlined;
    } else {
      title = 'Staff Workspace Sign-In';
      subtitle = 'Access ledgers, client groups, and field collection tools.';
      badgeIcon = Icons.account_balance_outlined;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: IcareColors.statusSuccessBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: IcareColors.statusSuccessBorder),
          ),
          child: Icon(badgeIcon, size: 20, color: IcareColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                softWrap: true,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: IcareColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                softWrap: true,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: IcareColors.textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _activeBodyKey(AuthState authState) {
    if (authState is AuthStateMfaRequired) return 'state_mfa';
    if (authState is AuthStatePasswordChangeRequired) return 'state_pw_change';
    return _entryMode == AuthEntryMode.onboardingAccess
        ? 'mode_onboarding'
        : 'mode_signin';
  }

  String? _resolveErrorBanner(AuthState authState) {
    if (_localValidationError != null && _localValidationError!.isNotEmpty) {
      return _localValidationError;
    }
    if (authState is AuthStateError) return authState.message;
    if (authState is AuthStateMfaRequired) return authState.errorMessage;
    if (authState is AuthStatePasswordChangeRequired) {
      return authState.errorMessage;
    }
    return null;
  }

  Widget _buildActiveBody(AuthState authState, bool isLoading) {
    final String? errorMsg = _resolveErrorBanner(authState);

    if (authState is AuthStateMfaRequired) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoCallout(
            icon: Icons.security_rounded,
            title: 'Authenticator Verification Required',
            description: authState.username.isNotEmpty
                ? '${authState.username}: ${authState.message}'
                : authState.message,
          ),
          const SizedBox(height: 14),
          IcareAuthField(
            controller: _mfaCodeController,
            focusNode: _mfaCodeFocus,
            enabled: !isLoading,
            label: 'Verification / Recovery Code',
            hint: 'Enter 6-digit code',
            prefixIcon: Icons.pin_outlined,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            tabularDigits: true,
            onSubmitted: (_) => _handleMfaSubmit(),
          ),
          if (errorMsg != null) ...[
            const SizedBox(height: 14),
            _buildErrorBanner(errorMsg),
          ],
          const SizedBox(height: 18),
          IcareTactilePrimaryButton(
            isLoading: isLoading,
            label: 'Verify & Complete Sign-In',
            onPressed: _handleMfaSubmit,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: isLoading ? null : _handleCancelChallenge,
            child: const Text(
              'Cancel & Return to Sign-In',
              style: TextStyle(
                color: IcareColors.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    if (authState is AuthStatePasswordChangeRequired) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInfoCallout(
            icon: Icons.verified_user_outlined,
            title: 'Complete First-Time Activation',
            description: authState.username.isNotEmpty
                ? '${authState.username}: ${authState.message}'
                : authState.message,
          ),
          const SizedBox(height: 14),
          IcareAuthField(
            controller: _currentPasswordController,
            enabled: !isLoading,
            label: 'Temporary Password',
            hint: 'Enter your temporary password',
            prefixIcon: Icons.lock_clock_outlined,
            obscureText: _obscureCurrentPassword,
            onChanged: (_) => setState(() {}),
            suffixIcon: _visibilityButton(
              obscured: _obscureCurrentPassword,
              tooltip: 'Toggle temporary password visibility',
              onPressed: () {
                setState(
                  () => _obscureCurrentPassword = !_obscureCurrentPassword,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          IcareAuthField(
            controller: _newPasswordController,
            focusNode: _newPasswordFocus,
            enabled: !isLoading,
            label: 'New Personal Password',
            hint: 'Enter 8 or more characters',
            prefixIcon: Icons.lock_reset_rounded,
            obscureText: _obscureNewPassword,
            onChanged: (_) => setState(() {}),
            suffixIcon: _visibilityButton(
              obscured: _obscureNewPassword,
              tooltip: 'Toggle new password visibility',
              onPressed: () {
                setState(() => _obscureNewPassword = !_obscureNewPassword);
              },
            ),
          ),
          const SizedBox(height: 12),
          IcareAuthField(
            controller: _confirmPasswordController,
            enabled: !isLoading,
            label: 'Confirm New Password',
            hint: 'Re-enter new password',
            prefixIcon: Icons.check_circle_outline_rounded,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _handleInitialPasswordSubmit(),
            suffixIcon: _visibilityButton(
              obscured: _obscureConfirmPassword,
              tooltip: 'Toggle confirmation password visibility',
              onPressed: () {
                setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          PasswordRequirementsChecklist(
            currentPassword: _currentPasswordController.text,
            newPassword: _newPasswordController.text,
            confirmPassword: _confirmPasswordController.text,
          ),
          if (errorMsg != null) ...[
            const SizedBox(height: 14),
            _buildErrorBanner(errorMsg),
          ],
          const SizedBox(height: 18),
          IcareTactilePrimaryButton(
            isLoading: isLoading,
            label: 'Activate Account & Sign In',
            onPressed: _handleInitialPasswordSubmit,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: isLoading ? null : _handleCancelChallenge,
            child: const Text(
              'Cancel & Return to Sign-In',
              style: TextStyle(
                color: IcareColors.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    if (_entryMode == AuthEntryMode.onboardingAccess) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (errorMsg != null) ...[
            _buildErrorBanner(errorMsg),
            const SizedBox(height: 14),
          ],
          OnboardingAccessPanel(
            tokenController: _tokenController,
            onSubmitToken: _handleOnboardingTokenSubmit,
            onOpenBranchPortal: _openBranchPortal,
            onOpenOfficerPortal: _openOfficerPortal,
            onSwitchToSignIn: () {
              setState(() {
                _entryMode = AuthEntryMode.signIn;
                _localValidationError = null;
              });
            },
          ),
        ],
      );
    }

    // Default: Staff Sign-In
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IcareAuthField(
            controller: _usernameController,
            focusNode: _usernameFocus,
            enabled: !isLoading,
            label: 'Username or Staff ID',
            hint: 'Enter your staff username',
            prefixIcon: Icons.person_outline_rounded,
            autofillHints: const [AutofillHints.username],
          ),
          const SizedBox(height: 14),
          IcareAuthField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            enabled: !isLoading,
            label: 'Password',
            hint: 'Enter your password',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _handleLogin(),
            suffixIcon: _visibilityButton(
              obscured: _obscurePassword,
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
          if (errorMsg != null) ...[
            const SizedBox(height: 14),
            _buildErrorBanner(errorMsg),
          ],
          const SizedBox(height: 18),
          IcareTactilePrimaryButton(
            isLoading: isLoading,
            label: 'Sign In to Core Banking',
            onPressed: _handleLogin,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: isLoading
                  ? null
                  : () {
                      setState(() {
                        _entryMode = AuthEntryMode.onboardingAccess;
                        _localValidationError = null;
                      });
                    },
              icon: const Icon(
                Icons.vpn_key_outlined,
                size: 15,
                color: IcareColors.primary,
              ),
              label: const Text(
                'Have a Branch or Officer Onboarding Token?',
                style: TextStyle(
                  color: IcareColors.primary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _visibilityButton({
    required bool obscured,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(
        obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 18,
        color: IcareColors.textMuted,
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildInfoCallout({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IcareColors.statusSuccessBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: IcareColors.statusSuccessBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: IcareColors.statusSuccessText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  softWrap: true,
                  style: const TextStyle(
                    color: IcareColors.statusSuccessText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  softWrap: true,
                  style: const TextStyle(
                    color: IcareColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: IcareColors.statusDangerBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: IcareColors.statusDangerBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: IcareColors.statusDangerText,
              size: 17,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                softWrap: true,
                style: const TextStyle(
                  color: IcareColors.statusDangerText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileInstitutionalFooter() {
    return const Column(
      children: [
        Text(
          'Initiative for Community Advancement, Relief and Empowerment',
          textAlign: TextAlign.center,
          softWrap: true,
          style: TextStyle(
            color: IcareColors.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            _LightValueChip('Integrity'),
            _LightValueChip('Commitment'),
            _LightValueChip('Competence'),
            _LightValueChip('Teamwork'),
          ],
        ),
        SizedBox(height: 10),
        Text(
          'HQ: 7 Ibifiele Street, Aiyegbami, Sagamu, Ogun State',
          textAlign: TextAlign.center,
          softWrap: true,
          style: TextStyle(
            color: IcareColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _BrandValueChip extends StatelessWidget {
  final String label;
  const _BrandValueChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFE2E8F0),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LightValueChip extends StatelessWidget {
  final String label;
  const _LightValueChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: IcareColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: IcareColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: IcareColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
