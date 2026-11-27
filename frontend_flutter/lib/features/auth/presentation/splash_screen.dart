import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_database_service.dart';
import '../../../core/theme/theme_controller.dart';
import '../../onboarding/presentation/branch_onboarding_portal_screen.dart';
import '../../onboarding/presentation/credit_officer_portal_screen.dart';
import '../../shared/presentation/co_app_scaffold.dart';
import 'login_screen.dart';

/// Animated Brand Introduction & Bootstrap Splash Screen for ICARE Core Banking.
///
/// Combines ICARE's crisp light brand canvas, halo rings, dual blue/green waves,
/// staggered crest/wordmark/motto reveal, 8-dot loader, and tap-to-continue
/// choreography with concurrent SQLite vault initialization, connectivity probing,
/// deep-link resolution, and staff session restoration.
class SplashScreen extends ConsumerStatefulWidget {
  final Duration? minimumHoldOverride;
  final bool enableBootstrap;
  final Duration duration;
  final Duration holdDuration;
  final bool allowTapToSkip;

  const SplashScreen({
    super.key,
    this.minimumHoldOverride,
    this.enableBootstrap = true,
    this.duration = const Duration(milliseconds: 4300),
    this.holdDuration = const Duration(milliseconds: 450),
    this.allowTapToSkip = true,
  });

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color icareBlue = Color(0xFF237DB8);
  static const Color icareMottoGreen = Color(0xFF58A923);
  static const Color ink = Color(0xFF172A43);

  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleOffset;
  late final Animation<double> _descriptionOpacity;
  late final Animation<double> _mottoOpacity;
  late final Animation<Offset> _mottoOffset;
  late final Animation<double> _loaderOpacity;

  Timer? _finishTimer;
  bool _disableAnimations = false;
  bool _bootstrapStarted = false;
  bool _bootstrapCompleted = false;
  bool _showcaseHoldElapsed = false;
  bool _skipRequested = false;
  bool _navigated = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _logoOpacity = _interval(0.00, 0.42, Curves.easeOut);
    _logoScale = Tween<double>(begin: 0.78, end: 1.0).animate(
      _interval(0.00, 0.56, Curves.easeOutBack),
    );

    _titleOpacity = _interval(0.28, 0.60, Curves.easeOut);
    _titleOffset = Tween<Offset>(
      begin: const Offset(0, 0.20),
      end: Offset.zero,
    ).animate(_interval(0.28, 0.62, Curves.easeOutCubic));

    _descriptionOpacity = _interval(0.43, 0.72, Curves.easeOut);
    _mottoOpacity = _interval(0.64, 0.91, Curves.easeOut);
    _mottoOffset = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(_interval(0.64, 0.92, Curves.easeOutCubic));

    _loaderOpacity = _interval(0.78, 1.0, Curves.easeIn);
  }

  Animation<double> _interval(double begin, double end, Curve curve) {
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, end, curve: curve),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    _disableAnimations = reduced;

    if (reduced) {
      _controller.value = 1.0;
    } else if (!_controller.isCompleted && !_controller.isAnimating) {
      _controller.forward();
    }

    if (widget.enableBootstrap && !_bootstrapStarted) {
      _bootstrapStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isDisposed) return;
        final Duration holdDelay = widget.minimumHoldOverride ??
            (_disableAnimations
                ? const Duration(milliseconds: 900)
                : widget.duration + widget.holdDuration);
        _scheduleHoldCompletion(holdDelay);
        _bootstrapApp();
      });
    }
  }

  void _scheduleHoldCompletion(Duration delay) {
    _finishTimer?.cancel();
    if (delay <= Duration.zero) {
      _showcaseHoldElapsed = true;
      _tryNavigate();
      return;
    }
    _finishTimer = Timer(delay, () {
      if (!mounted || _isDisposed) return;
      _showcaseHoldElapsed = true;
      _tryNavigate();
    });
  }

  void _handleTapToContinue() {
    if (!widget.allowTapToSkip || !widget.enableBootstrap || _isDisposed) {
      return;
    }
    if (!_skipRequested && mounted) {
      setState(() => _skipRequested = true);
    }
    if (_controller.value < 1.0 && !_disableAnimations) {
      _controller.value = 1.0;
    }
    _tryNavigate();
  }

  Future<void> _bootstrapApp() async {
    try {
      final dbService = ref.read(offlineDatabaseServiceProvider);
      await dbService.database;
    } catch (_) {
      // Offline database fallback runs silently on Web or unsupported hosts
    }

    try {
      final connService = ref.read(connectivityServiceProvider);
      await connService.checkActualConnection();
    } catch (_) {
      // Offline mode continues seamlessly if connectivity check throws
    }

    try {
      await ref.read(authControllerProvider.notifier).restoreSession();
    } catch (_) {
      // Unauthenticated users cleanly proceed to LoginScreen
    }

    if (!mounted || _isDisposed) return;
    _bootstrapCompleted = true;
    _tryNavigate();
  }

  void _tryNavigate() {
    if (!mounted || _isDisposed || _navigated) return;
    if (!_bootstrapCompleted) return;
    if (!_showcaseHoldElapsed && !_skipRequested) return;

    _navigated = true;
    _finishTimer?.cancel();

    final Widget targetScreen = _resolveTargetScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionDuration: _disableAnimations
            ? const Duration(milliseconds: 150)
            : const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final CurvedAnimation eased = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          if (_disableAnimations) {
            return FadeTransition(opacity: eased, child: child);
          }
          return FadeTransition(
            opacity: eased,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.02),
                end: Offset.zero,
              ).animate(eased),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Widget _resolveTargetScreen() {
    String? onboardingToken = Uri.base.queryParameters['token'];
    String? onboardingOfficer = Uri.base.queryParameters['officer'];
    bool isOfficerRoute = Uri.base.path.contains('officer');

    if (Uri.base.fragment.isNotEmpty) {
      final String frag = Uri.base.fragment;
      final Uri? fragUri = Uri.tryParse(frag.startsWith('/') ? frag : '/$frag');
      if (fragUri != null) {
        if ((onboardingToken == null || onboardingToken.isEmpty) &&
            fragUri.queryParameters.containsKey('token')) {
          onboardingToken = fragUri.queryParameters['token'];
        }
        if ((onboardingOfficer == null || onboardingOfficer.isEmpty) &&
            fragUri.queryParameters.containsKey('officer')) {
          onboardingOfficer = fragUri.queryParameters['officer'];
        }
        if (frag.contains('officer')) {
          isOfficerRoute = true;
        }
      }
    }

    final bool isExplicitOnboarding = Uri.base.path.contains('onboarding') ||
        Uri.base.fragment.contains('onboarding') ||
        (onboardingToken != null && onboardingToken.isNotEmpty);

    if (isExplicitOnboarding) {
      final String cleanToken = onboardingToken?.trim() ?? '';
      if (cleanToken.startsWith('onb_co_') || isOfficerRoute) {
        return CreditOfficerPortalScreen(coToken: cleanToken);
      }
      return BranchOnboardingPortalScreen(
        token: cleanToken,
        initialOfficer: onboardingOfficer?.trim(),
      );
    }

    final AuthState authState = ref.read(authControllerProvider);
    if (authState is AuthStateAuthenticated) {
      if (authState.user.preferences.isNotEmpty) {
        ref
            .read(themeControllerProvider.notifier)
            .applyRemotePreferences(authState.user.preferences);
      }
      return const CoAppScaffold();
    }
    return const LoginScreen();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _finishTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool compact = size.height < 700;
    final double logoWidth =
        (size.width * (compact ? 0.44 : 0.57)).clamp(156.0, 285.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.allowTapToSkip ? _handleTapToContinue : null,
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _IcareBackgroundPainter()),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      compact ? 16 : 24,
                      24,
                      widget.allowTapToSkip ? 44 : 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(
                          0,
                          constraints.maxHeight -
                              (compact ? 16 : 24) -
                              (widget.allowTapToSkip ? 44 : 24),
                        ),
                      ),
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FadeTransition(
                                  opacity: _logoOpacity,
                                  child: ScaleTransition(
                                    scale: _logoScale,
                                    child: Hero(
                                      tag: 'icare_brand_crest',
                                      child: Semantics(
                                        label: 'ICARE Institutional Crest',
                                        image: true,
                                        child: Container(
                                          width: logoWidth,
                                          height: logoWidth,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                            boxShadow: [
                                              BoxShadow(
                                                color: icareBlue.withValues(
                                                  alpha: 0.13,
                                                ),
                                                blurRadius: 30,
                                                spreadRadius: 2,
                                                offset: const Offset(0, 12),
                                              ),
                                            ],
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: Image.asset(
                                            'assets/icare_logo.png',
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Icon(
                                                Icons.volunteer_activism_rounded,
                                                size: logoWidth * 0.56,
                                                color: icareBlue,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: compact ? 15 : 22),
                                FadeTransition(
                                  opacity: _titleOpacity,
                                  child: SlideTransition(
                                    position: _titleOffset,
                                    child: Text(
                                      'ICARE',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: icareBlue,
                                        fontSize: compact ? 34 : 40,
                                        height: 1,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 5.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                FadeTransition(
                                  opacity: _descriptionOpacity,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 340),
                                    child: const Text(
                                      'Initiative for Community Advancement,\n'
                                      'Relief and Empowerment',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: ink,
                                        fontSize: 14,
                                        height: 1.45,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.05,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: compact ? 14 : 24),
                                FadeTransition(
                                  opacity: _mottoOpacity,
                                  child: SlideTransition(
                                    position: _mottoOffset,
                                    child: Text(
                                      'Growing Together',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: icareMottoGreen,
                                        fontSize: compact ? 22 : 25,
                                        fontWeight: FontWeight.w800,
                                        fontStyle: FontStyle.italic,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: compact ? 24 : 34),
                                FadeTransition(
                                  opacity: _loaderOpacity,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _IcareLoader(
                                        animate: !_disableAnimations,
                                      ),
                                      if (_skipRequested &&
                                          !_bootstrapCompleted) ...[
                                        const SizedBox(height: 10),
                                        const Text(
                                          'Preparing workspace...',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.allowTapToSkip)
              Positioned(
                bottom: 18,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: FadeTransition(
                    opacity: _loaderOpacity,
                    child: const Text(
                      'TAP TO CONTINUE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF8A99A8),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IcareLoader extends StatefulWidget {
  final bool animate;

  const _IcareLoader({this.animate = true});

  @override
  State<_IcareLoader> createState() => _IcareLoaderState();
}

class _IcareLoaderState extends State<_IcareLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _IcareLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) {
      if (widget.animate) {
        if (!_controller.isAnimating) {
          _controller.repeat();
        }
      } else {
        _controller.stop();
        _controller.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          children: List.generate(8, (index) {
            final double angle = index * math.pi / 4;
            return Transform.translate(
              offset: Offset(
                10 * math.cos(angle),
                10 * math.sin(angle),
              ),
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _SplashScreenState.icareBlue.withValues(
                      alpha: 0.25 + (index / 8) * 0.75,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _IcareBackgroundPainter extends CustomPainter {
  const _IcareBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height * 0.43);

    final Paint haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _SplashScreenState.icareBlue.withValues(alpha: 0.045);

    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        center,
        size.width * (0.36 + i * 0.105),
        haloPaint,
      );
    }

    final Paint blue = Paint()..color = const Color(0xFF1683C7);
    final Paint blueDark = Paint()..color = const Color(0xFF0868AD);
    final Paint green = Paint()..color = const Color(0xFF78C928);
    final Paint greenLight = Paint()..color = const Color(0xFF9BD83B);

    Path wave(double y, double rise, bool fromLeft) {
      final Path path = Path();
      if (fromLeft) {
        path
          ..moveTo(0, y)
          ..cubicTo(
            size.width * 0.18,
            y - rise,
            size.width * 0.30,
            y + rise * 0.8,
            size.width * 0.52,
            size.height,
          )
          ..lineTo(0, size.height)
          ..close();
      } else {
        path
          ..moveTo(size.width, y)
          ..cubicTo(
            size.width * 0.82,
            y - rise,
            size.width * 0.70,
            y + rise * 0.8,
            size.width * 0.48,
            size.height,
          )
          ..lineTo(size.width, size.height)
          ..close();
      }
      return path;
    }

    final double y = size.height * 0.91;
    canvas.drawPath(wave(y, size.height * 0.055, true), blueDark);
    canvas.drawPath(wave(y + 10, size.height * 0.045, true), blue);
    canvas.drawPath(wave(y, size.height * 0.055, false), green);
    canvas.drawPath(wave(y + 10, size.height * 0.045, false), greenLight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
