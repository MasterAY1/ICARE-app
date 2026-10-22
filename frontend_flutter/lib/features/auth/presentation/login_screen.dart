import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../onboarding/presentation/branch_onboarding_portal_screen.dart';
import '../../shared/presentation/co_app_scaffold.dart';

/// Screen 0: Modernized ICARE Core Banking Authentication Screen
/// Adheres strictly to the 6 Design Pillars, Zero-Tamper Presentation Sandbox,
/// and the Row-Text Wrapping & Anti-Clipping Invariant.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  String? _localValidationError;

  // Animation Controllers
  late final AnimationController _entranceController;
  late final AnimationController _shakeController;
  late final AnimationController _pressController;

  // Staggered Entrance Animations
  late final Animation<double> _brandFade;
  late final Animation<Offset> _brandSlide;
  late final Animation<double> _storyFade;
  late final Animation<Offset> _storySlide;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _inputsFade;
  late final Animation<Offset> _inputsSlide;
  late final Animation<double> _buttonFade;
  late final Animation<Offset> _buttonSlide;

  // Interactive Kinetic Animations
  late final Animation<double> _shakeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Staggered Entrance Choreography (900ms)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _brandFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );
    _brandSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    _storyFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.15, 0.60, curve: Curves.easeOutCubic),
      ),
    );
    _storySlide = Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.15, 0.60, curve: Curves.easeOutCubic),
      ),
    );

    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.25, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.25, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _inputsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.40, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    _inputsSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.40, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _buttonSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Button Press Scale Animation (80ms)
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );

    // 3. Horizontal Error Shake Sequence (350ms)
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _shakeController.dispose();
    _pressController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _triggerErrorShake(String message) {
    setState(() => _localValidationError = message);
    HapticFeedback.vibrate();
    _shakeController.forward(from: 0.0);
  }

  void _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _triggerErrorShake('Please enter both your username and password.');
      return;
    }

    setState(() => _localValidationError = null);

    await ref.read(authControllerProvider.notifier).login(
          username: username,
          password: password,
        );

    if (!mounted) return;
    final currentAuth = ref.read(authControllerProvider);
    if (currentAuth is AuthStateAuthenticated && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CoAppScaffold()),
      );
    }
  }

  void _fillDevCredentials(String username) {
    HapticFeedback.selectionClick();
    _usernameController.text = username;
    _passwordController.text = 'admin123';
    setState(() => _localValidationError = null);
    _passwordFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthStateAuthenticated && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CoAppScaffold()),
        );
      } else if (next is AuthStateError) {
        _triggerErrorShake(next.message);
      }
    });

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthStateLoading;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 980;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Ambient Institutional Deep Forest Emerald Mesh
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF022C22), // Deep Forest Emerald
                  Color(0xFF064E3B), // Core Primary Emerald
                  Color(0xFF0F766E), // Teal Emerald
                  Color(0xFF064E3B),
                  Color(0xFF022C22),
                ],
              ),
            ),
          ),

          // 2. Glowing Radial Mesh Orbs
          Positioned(
            top: -120,
            left: -120,
            child: Container(
              width: 520,
              height: 520,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            right: -140,
            child: Container(
              width: 540,
              height: 540,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0F766E).withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 3. Micro Ambient Star Dust Particles
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                children: [
                  _buildParticle(left: 0.12, top: 0.18, size: 3.0, color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                  _buildParticle(left: 0.28, top: 0.72, size: 2.5, color: const Color(0xFF34D399).withValues(alpha: 0.30)),
                  _buildParticle(left: 0.48, top: 0.32, size: 3.5, color: const Color(0xFF0F766E).withValues(alpha: 0.30)),
                  _buildParticle(left: 0.68, top: 0.82, size: 2.0, color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                  _buildParticle(left: 0.85, top: 0.14, size: 3.0, color: const Color(0xFF34D399).withValues(alpha: 0.25)),
                  _buildParticle(left: 0.58, top: 0.62, size: 2.5, color: const Color(0xFF0F766E).withValues(alpha: 0.30)),
                ],
              ),
            ),
          ),

          // 4. Main Responsive Content Canvas
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 20,
                  vertical: isDesktop ? 36 : 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Left Story & Values Presentation
                            Expanded(
                              flex: 11,
                              child: SlideTransition(
                                position: _storySlide,
                                child: FadeTransition(
                                  opacity: _storyFade,
                                  child: _buildStoryPanel(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 56),
                            // Right Frosted Glass Login Card
                            Expanded(
                              flex: 9,
                              child: _buildAnimatedLoginCard(isLoading, authState),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            // Centered Frosted Glass Login Card
                            _buildAnimatedLoginCard(isLoading, authState),
                            const SizedBox(height: 36),
                            // Compact Institutional Info Below
                            SlideTransition(
                              position: _storySlide,
                              child: FadeTransition(
                                opacity: _storyFade,
                                child: _buildMobileStorySection(),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticle({required double left, required double top, required double size, required Color color}) {
    return Align(
      alignment: FractionalOffset(left, top),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// Right Frosted Glass Card with Entrance & Kinetic Shake Choreography
  Widget _buildAnimatedLoginCard(bool isLoading, AuthState authState) {
    return SlideTransition(
      position: _cardSlide,
      child: FadeTransition(
        opacity: _cardFade,
        child: AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: child,
            );
          },
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: const Color(0xFF022C22).withValues(alpha: 0.40),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand Lockup with Entrance Animation
                      SlideTransition(
                        position: _brandSlide,
                        child: FadeTransition(
                          opacity: _brandFade,
                          child: Column(
                            children: [
                              // Institution Crest / Logo
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF022C22),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                      blurRadius: 24,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/icare_logo.png',
                                    width: 68,
                                    height: 68,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const Center(
                                      child: Text(
                                        'IC',
                                        style: TextStyle(
                                          color: Color(0xFF34D399),
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Core Platform Name
                              const Text(
                                'ICARE',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 4.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Core Banking Platform',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Decorative Emerald Hairline Divider
                      Center(
                        child: Container(
                          width: 48,
                          height: 2.5,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF0F766E)],
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Staggered Form Inputs
                      SlideTransition(
                        position: _inputsSlide,
                        child: FadeTransition(
                          opacity: _inputsFade,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Quick Dev Profiles Section
                              _buildDevCredentialChips(),
                              const SizedBox(height: 18),

                              // Username Input
                              _buildInputField(
                                label: 'Username / Operator ID',
                                controller: _usernameController,
                                focusNode: _usernameFocus,
                                hintText: 'e.g. OGI_CO1, BM_Ogijo, AM_Ogun',
                                prefixIcon: Icons.person_outline_rounded,
                                onSubmitted: (_) => _passwordFocus.requestFocus(),
                              ),
                              const SizedBox(height: 14),

                              // Password Input
                              _buildInputField(
                                label: 'Access Password',
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                hintText: 'Enter your access credentials',
                                prefixIcon: Icons.lock_outline_rounded,
                                isPassword: true,
                                obscureText: _obscurePassword,
                                onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                                onSubmitted: (_) => _handleLogin(),
                              ),
                              const SizedBox(height: 16),

                              // Error Banner (Anti-Clipping Invariant Enforced)
                              if (_localValidationError != null || authState is AuthStateError) ...[
                                _buildErrorNoticeBanner(
                                  _localValidationError ?? (authState as AuthStateError).message,
                                ),
                                const SizedBox(height: 16),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Submit Button & Onboarding Section
                      SlideTransition(
                        position: _buttonSlide,
                        child: FadeTransition(
                          opacity: _buttonFade,
                          child: Column(
                            children: [
                              // Kinetic Morphing Submit Button
                              _buildMorphingSubmitButton(isLoading),
                              const SizedBox(height: 14),

                              // Branch Onboarding Portal Link (Zero Clipping Enforced)
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const BranchOnboardingPortalScreen(token: ''),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.domain_add_outlined, size: 14, color: Color(0xFF94A3B8)),
                                      SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Have an Onboarding Token? Open Branch Portal',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF94A3B8),
                                            decoration: TextDecoration.underline,
                                            decorationColor: Color(0xFF64748B),
                                          ),
                                          textAlign: TextAlign.center,
                                          softWrap: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Security & Audit Footer Bar (Anti-Clipping Enforced)
                              Container(
                                padding: const EdgeInsets.only(top: 14),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Core Banking v2.4.0',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        softWrap: true,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.shield_outlined, size: 11, color: Color(0xFF10B981)),
                                        SizedBox(width: 4),
                                        Text(
                                          '256-Bit SSL Encrypted',
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
            ),
          ),
        ),
      ),
    );
  }

  /// Modern Input Field with Sunlight Contrast
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData prefixIcon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFE2E8F0),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: isPassword && obscureText,
          onSubmitted: onSubmitted,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: hintText,
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13.0,
              fontWeight: FontWeight.w400,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            prefixIcon: Icon(prefixIcon, size: 18, color: const Color(0xFF0F766E)),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: const Color(0xFF64748B),
                      size: 18,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF0F766E), width: 2.0),
            ),
          ),
        ),
      ],
    );
  }

  /// Quick Dev Credential Chips for Rapid Testing
  Widget _buildDevCredentialChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'QUICK DEV PROFILES',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              'Click to autofill',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildDevChip(label: 'Admin', username: 'admin'),
            _buildDevChip(label: 'BM (Ogijo)', username: 'BM_Ogijo'),
            _buildDevChip(label: 'CO (OGI_CO1)', username: 'OGI_CO1'),
            _buildDevChip(label: 'AM (Ogun)', username: 'AM_Ogun'),
          ],
        ),
      ],
    );
  }

  Widget _buildDevChip({required String label, required String username}) {
    return InkWell(
      onTap: () => _fillDevCredentials(username),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF34D399),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Error Notice Banner strictly adhering to the Row-Text Wrapping Invariant
  Widget _buildErrorNoticeBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB91C1C), size: 16),
          const SizedBox(width: 8),
          // MANDATORY ROW-TEXT WRAPPING INVARIANT:
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  /// Morphing Interactive Submit Button
  Widget _buildMorphingSubmitButton(bool isLoading) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: MouseRegion(
        cursor: isLoading ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: isLoading ? null : (_) => _pressController.forward(),
          onTapUp: isLoading
              ? null
              : (_) {
                  _pressController.reverse();
                  HapticFeedback.mediumImpact();
                  _handleLogin();
                },
          onTapCancel: () => _pressController.reverse(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            height: 48,
            width: isLoading ? 48 : double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF0F766E)],
              ),
              borderRadius: BorderRadius.circular(isLoading ? 24 : 10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      key: ValueKey('signin_idle'),
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sign In to Core Banking',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Left Story & Institutional Values Presentation (Desktop Web)
  Widget _buildStoryPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Foundation Pill Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.30),
              width: 1.0,
            ),
          ),
          child: const Text(
            'EST. 2006 • SOUTH-WEST NIGERIA',
            style: TextStyle(
              color: Color(0xFF34D399),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 22),

        // Headline
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.8,
              height: 1.2,
            ),
            children: [
              TextSpan(text: 'Empowering Communities,\n'),
              TextSpan(
                text: 'Growing Together',
                style: TextStyle(color: Color(0xFF34D399)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Slogan
        const Text(
          '"Building a better community through inspiration, motivation and empowerment"',
          style: TextStyle(
            color: Color(0xFF34D399),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 20),

        // Institutional Overview
        const Text(
          'ICARE (Initiative for Community Advancement, Relief and Empowerment) is dedicated to the intellectual and socio-economic advancement of its members. Operating across South-Western Nigeria, ICARE finances micro-credit programmes for traders and artisans, asset acquisition schemes, and community empowerment initiatives.',
          style: TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 13.0,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 20),

        // Gradient Divider
        Container(
          width: 48,
          height: 2,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Colors.transparent],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 18),

        // Vision Statement
        const Text(
          'OUR VISION',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'To be among the foremost catalysts in initiating and implementing sustainable programmes focused on empowering people for growth and self-reliance.',
          style: TextStyle(
            color: Color(0xFFE2E8F0),
            fontSize: 12.5,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 18),

        // Core Values
        const Text(
          'CORE VALUES',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ValuePill('Integrity'),
            _ValuePill('Commitment'),
            _ValuePill('Competence'),
            _ValuePill('Teamwork'),
          ],
        ),
        const SizedBox(height: 24),

        // Headquarters Address (Anti-Clipping Enforced)
        Container(
          padding: const EdgeInsets.only(top: 14),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
              SizedBox(width: 6),
              // Anti-Clipping Invariant:
              Expanded(
                child: Text(
                  'H.Q: 7 Ibifiele Street, Aiyegbami, Sagamu, Ogun State, Nigeria',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                  softWrap: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Compact Story Section for Mobile / Small Screens
  Widget _buildMobileStorySection() {
    return const Column(
      children: [
        Text(
          'Initiative for Community Advancement, Relief and Empowerment',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            _ValuePill('Integrity'),
            _ValuePill('Commitment'),
            _ValuePill('Competence'),
            _ValuePill('Teamwork'),
          ],
        ),
      ],
    );
  }
}

class _ValuePill extends StatelessWidget {
  final String label;
  const _ValuePill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFCBD5E1),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
