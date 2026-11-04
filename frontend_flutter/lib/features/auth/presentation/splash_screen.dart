import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_database_service.dart';
import '../../../core/theme/icare_colors.dart';
import '../../../core/theme/icare_typography.dart';
import '../../shared/presentation/co_app_scaffold.dart';
import '../../onboarding/presentation/branch_onboarding_portal_screen.dart';
import '../../onboarding/presentation/credit_officer_portal_screen.dart';
import 'login_screen.dart';

/// Institutional Welcome Splash Screen for ICARE Core Banking.
/// Features a high-end kinetic brand animation with a floating, living logo,
/// dynamic radar halo waves, specular sheen reflections, smooth progressive
/// bootstrap status updates, and zero UI regressions.
/// Adheres strictly to Rule 10 (Zero Emojis, Institutional Aesthetic).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Choreographed animation controllers
  late AnimationController _introCtrl;     // Staggered entrance (1200ms)
  late AnimationController _ambientCtrl;   // Continuous floating & micro-tilt (2600ms loop)
  late AnimationController _radarCtrl;     // Concentric security wave rings (2200ms loop)
  late AnimationController _sheenCtrl;     // Specular shine pass across logo (3200ms loop)
  late AnimationController _exitCtrl;      // Outro launch forward pulse (350ms)

  // Staggered intro animations
  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _logoFade;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleSpacing;
  late Animation<double> _subtitleFade;
  late Animation<Offset> _subtitleSlide;
  late Animation<double> _progressFade;
  late Animation<Offset> _progressSlide;

  // Real-time bootstrap feedback state
  double _progressValue = 0.18;
  String _statusMessage = 'Getting things ready...';

  @override
  void initState() {
    super.initState();

    // 1. Entrance Controller (1200ms)
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _logoRotation = Tween<double>(begin: -0.16, end: 0.0).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.0, 0.60, curve: Curves.easeOutCubic),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.0, 0.40, curve: Curves.easeIn),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.35, 0.75, curve: Curves.easeIn),
      ),
    );

    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.35, 0.80, curve: Curves.easeOutCubic),
      ),
    );

    _titleSpacing = Tween<double>(begin: 1.5, end: 3.5).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.50, 0.88, curve: Curves.easeIn),
      ),
    );

    _subtitleSlide = Tween<Offset>(begin: const Offset(0, 0.30), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.50, 0.90, curve: Curves.easeOutCubic),
      ),
    );

    _progressFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.65, 1.0, curve: Curves.easeIn),
      ),
    );

    _progressSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Ambient Continuous Controller (Gentle Floating & Breathing)
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    // 3. Radar Halo Controller (Concentric Outward Security Waves)
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // 4. Specular Sheen Pass Controller
    _sheenCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat();

    // 5. Exit Launch Forward Controller
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _introCtrl.forward();
    _bootstrapApp();
  }

  Future<void> _bootstrapApp() async {
    // Stage 1: Initialize local SQLite database in background
    try {
      final dbService = ref.read(offlineDatabaseServiceProvider);
      await dbService.database;
      if (mounted) {
        setState(() {
          _progressValue = 0.45;
          _statusMessage = 'Loading your records...';
        });
      }
    } catch (_) {
      // Local DB initialization safe fallback
    }

    // Stage 2: Pre-check live network connection
    try {
      final connService = ref.read(connectivityServiceProvider);
      await connService.checkActualConnection();
      if (mounted) {
        setState(() {
          _progressValue = 0.72;
          _statusMessage = 'Connecting securely...';
        });
      }
    } catch (_) {
      // Safe fallback
    }

    // Stage 3: Try to restore active authenticated session if persisted
    try {
      await ref.read(authControllerProvider.notifier).restoreSession();
      if (mounted) {
        setState(() {
          _progressValue = 0.94;
          _statusMessage = 'Checking your account...';
        });
      }
    } catch (_) {
      // Safe fallback
    }

    // Stage 4: Minimum display duration for a polished, seamless experience
    await Future.delayed(const Duration(milliseconds: 1400));

    if (mounted) {
      setState(() {
        _progressValue = 1.00;
        _statusMessage = 'Almost ready...';
      });
    }

    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;

    // Trigger smooth launch exit pulse
    await _exitCtrl.forward();
    if (!mounted) return;

    // Stage 5: Inspect URL parameters / hash fragments for public branch onboarding link
    String? onboardingToken = Uri.base.queryParameters['token'];
    String? officerName = Uri.base.queryParameters['officer'];
    bool isOfficerRoute = Uri.base.path.contains('officer');

    if (Uri.base.fragment.isNotEmpty) {
      final fragment = Uri.base.fragment;
      final fragUri = Uri.tryParse(fragment.startsWith('/') ? fragment : '/$fragment');
      if (fragUri != null) {
        if ((onboardingToken == null || onboardingToken.isEmpty) && fragUri.queryParameters.containsKey('token')) {
          onboardingToken = fragUri.queryParameters['token'];
        }
        if ((officerName == null || officerName.isEmpty) && fragUri.queryParameters.containsKey('officer')) {
          officerName = fragUri.queryParameters['officer'];
        }
        if (fragUri.path.contains('officer')) {
          isOfficerRoute = true;
        }
      }
    }

    final isExplicitOnboarding = Uri.base.path.contains('onboarding') ||
        Uri.base.fragment.contains('onboarding') ||
        (onboardingToken != null && onboardingToken.isNotEmpty);

    Widget targetScreen;
    if (isExplicitOnboarding) {
      final cleanToken = onboardingToken?.trim() ?? '';
      if (cleanToken.startsWith('onb_co_') || isOfficerRoute) {
        targetScreen = CreditOfficerPortalScreen(coToken: cleanToken);
      } else {
        targetScreen = BranchOnboardingPortalScreen(
          token: cleanToken,
          initialOfficer: officerName,
        );
      }
    } else {
      final authState = ref.read(authControllerProvider);
      targetScreen = (authState is AuthStateAuthenticated)
          ? const CoAppScaffold()
          : const LoginScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, anim, secAnim) => targetScreen,
        transitionsBuilder: (context, anim, secAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _ambientCtrl.dispose();
    _radarCtrl.dispose();
    _sheenCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IcareColors.canvas,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Subtle Ambient Radial Background Glow
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientCtrl,
              builder: (context, child) {
                final pulseAlpha = 0.04 + (math.sin(_ambientCtrl.value * math.pi) * 0.03);
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.1),
                      radius: 0.85,
                      colors: [
                        const Color(0xFF10B981).withValues(alpha: pulseAlpha * 1.5),
                        const Color(0xFF0F766E).withValues(alpha: pulseAlpha),
                        IcareColors.canvas,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Centered Animated Brand Assembly
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_introCtrl, _exitCtrl]),
              builder: (context, child) {
                // Exit transition scaling & opacity
                final exitScale = 1.0 + (_exitCtrl.value * 0.08);
                final exitOpacity = (1.0 - _exitCtrl.value).clamp(0.0, 1.0);

                return Opacity(
                  opacity: exitOpacity,
                  child: Transform.scale(
                    scale: exitScale,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Kinetic Living Logo Container
                  _buildKineticLogo(),

                  const SizedBox(height: 28),

                  // Corporate Logotype ("ICARE")
                  _buildAnimatedTitle(),

                  const SizedBox(height: 8),

                  // Brand Tagline ("Growing Together")
                  _buildAnimatedSubtitle(),

                  const SizedBox(height: 38),

                  // Sleek Modern Progress Track & Status Feedback
                  _buildProgressSection(),
                ],
              ),
            ),
          ),

          // 3. Bottom Institutional Trust Footer
          Positioned(
            bottom: 24,
            child: FadeTransition(
              opacity: _progressFade,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 13,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ICARE Microfinance • Safe, Secure & Reliable',
                    style: IcareTypography.caption.copyWith(
                      color: const Color(0xFF94A3B8),
                      fontSize: 11,
                      letterSpacing: 0.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the dynamic, moving circular logo with spring entry, continuous sinusoidal
  /// floating, micro 3D perspective tilt, concentric radar waves, and specular shine sweep.
  Widget _buildKineticLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_introCtrl, _ambientCtrl, _radarCtrl, _sheenCtrl]),
      builder: (context, _) {
        // Floating translation (-6.5px to +6.5px)
        final floatY = math.sin(_ambientCtrl.value * 2 * math.pi) * 6.5;

        // Subtle 3D perspective rotation around X & Y axis
        final tiltX = math.sin(_ambientCtrl.value * 2 * math.pi) * 0.045;
        final tiltY = math.cos(_ambientCtrl.value * 2 * math.pi) * 0.035;

        // Micro-breathing scale (1.00 to 1.025)
        final breath = 1.0 + (math.sin(_ambientCtrl.value * 2 * math.pi) * 0.015);

        // Dynamic shadow blur & offset reacting to altitude
        final shadowOffset = 10.0 - (floatY * 0.6);
        final shadowBlur = 24.0 - (floatY * 1.2);
        final shadowAlpha = (0.16 + (floatY * 0.008)).clamp(0.08, 0.24);

        // Entrance values
        final entranceScale = _logoScale.value;
        final entranceRotation = _logoRotation.value;
        final entranceOpacity = _logoFade.value;

        return Opacity(
          opacity: entranceOpacity,
          child: Transform.translate(
            offset: Offset(0.0, floatY),
            child: Transform.scale(
              scale: entranceScale * breath,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // subtle perspective depth
                  ..rotateZ(entranceRotation)
                  ..rotateX(tiltX)
                  ..rotateY(tiltY),
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                  // Radar Halo Pulsing Rings (Security Beacon)
                  CustomPaint(
                    size: const Size(140, 140),
                    painter: _RadarWavePainter(
                      progress: _radarCtrl.value,
                      color: const Color(0xFF10B981),
                    ),
                  ),

                  // Ambient Backlight Glow
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F766E).withValues(alpha: shadowAlpha),
                          blurRadius: shadowBlur,
                          spreadRadius: 2,
                          offset: Offset(0, shadowOffset),
                        ),
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          blurRadius: 36,
                          spreadRadius: 4,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  ),

                  // The Logo Circle with Specular Sheen Pass
                  Container(
                    width: 116,
                    height: 116,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.white,
                        width: 3.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF022C22).withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Base Logo Asset
                          Image.asset(
                            'assets/icare_logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.account_balance,
                                size: 54,
                                color: IcareColors.primary,
                              );
                            },
                          ),

                          // Specular Sheen Sweep (Sleek light passing over the emblem)
                          _buildSpecularSheen(),
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
    );
  },
);
  }

  /// Builds a specular diagonal shimmer light that sweeps across the logo surface
  Widget _buildSpecularSheen() {
    final sheenProgress = _sheenCtrl.value;
    // Map 0..1 to an offset from -150 to 250 across the 116px container
    final sheenOffset = -120.0 + (sheenProgress * 300.0);

    return Transform.translate(
      offset: Offset(sheenOffset, -sheenOffset * 0.3),
      child: Transform.rotate(
        angle: 0.45, // ~25 degrees diagonal
        child: Container(
          width: 36,
          height: 160,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.0),
                Colors.white.withValues(alpha: 0.35),
                Colors.white.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the "ICARE" title with staggered slide-up, fade, and expanding letter-spacing
  Widget _buildAnimatedTitle() {
    return AnimatedBuilder(
      animation: _introCtrl,
      builder: (context, child) {
        return FadeTransition(
          opacity: _titleFade,
          child: SlideTransition(
            position: _titleSlide,
            child: Text(
              'ICARE',
              style: IcareTypography.h2.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: _titleSpacing.value,
                fontSize: 30,
                color: IcareColors.primaryDark,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the "Growing Together" tagline with smooth delayed slide and fade
  Widget _buildAnimatedSubtitle() {
    return FadeTransition(
      opacity: _subtitleFade,
      child: SlideTransition(
        position: _subtitleSlide,
        child: Text(
          'Growing Together',
          style: IcareTypography.bodyRegular.copyWith(
            color: const Color(0xFF047857),
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  /// Builds the progress section with capsule track, gradient fill, and animated status text
  Widget _buildProgressSection() {
    return FadeTransition(
      opacity: _progressFade,
      child: SlideTransition(
        position: _progressSlide,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modern Rounded Capsule Progress Track
            Container(
              width: 170,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(100),
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: _progressValue),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: value.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF0F766E),
                                Color(0xFF10B981),
                                Color(0xFF34D399),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.45),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Animated Status Text with Pulsing Activity Dot
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing Green Live Dot
                AnimatedBuilder(
                  animation: _ambientCtrl,
                  builder: (context, _) {
                    final dotAlpha = 0.5 + (math.sin(_ambientCtrl.value * math.pi) * 0.5);
                    return Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF10B981).withValues(alpha: dotAlpha),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: dotAlpha * 0.6),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),

                // Smooth Cross-Fade Status Message
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, anim) {
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.2),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    _statusMessage,
                    key: ValueKey<String>(_statusMessage),
                    style: IcareTypography.caption.copyWith(
                      color: IcareColors.textLight,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for concentric radar security waves radiating from behind the logo
class _RadarWavePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color color;

  _RadarWavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const minRadius = 54.0;
    const maxRadius = 88.0;

    // Wave 1
    final radius1 = minRadius + (progress * (maxRadius - minRadius));
    final alpha1 = (1.0 - progress).clamp(0.0, 1.0) * 0.28;
    final paint1 = Paint()
      ..color = color.withValues(alpha: alpha1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(center, radius1, paint1);

    // Wave 2 (Phase offset by 0.5)
    final progress2 = (progress + 0.5) % 1.0;
    final radius2 = minRadius + (progress2 * (maxRadius - minRadius));
    final alpha2 = (1.0 - progress2).clamp(0.0, 1.0) * 0.28;
    final paint2 = Paint()
      ..color = color.withValues(alpha: alpha2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, radius2, paint2);
  }

  @override
  bool shouldRepaint(covariant _RadarWavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
