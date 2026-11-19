import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_database_service.dart';
import '../../../core/theme/icare_colors.dart';
import '../../onboarding/presentation/branch_onboarding_portal_screen.dart';
import '../../onboarding/presentation/credit_officer_portal_screen.dart';
import '../../shared/presentation/co_app_scaffold.dart';
import 'login_screen.dart';
import 'widgets/icare_brand_crest.dart';

/// Institutional Welcome Animation & Bootstrap Splash Screen for ICARE Core Banking.
///
/// Coordinates vault initialization, connectivity probing, and session restoration
/// concurrently with an emerald crest reveal that hands off seamlessly into `LoginScreen`
/// via Hero shared-element continuity. Respects system reduced-motion settings.
class SplashScreen extends ConsumerStatefulWidget {
  final Duration? minimumHoldOverride;
  final bool enableBootstrap;

  const SplashScreen({
    super.key,
    this.minimumHoldOverride,
    this.enableBootstrap = true,
  });

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introCtrl;
  late final AnimationController _orbitCtrl;

  late final Animation<double> _crestScale;
  late final Animation<double> _crestFade;
  late final Animation<double> _brandFade;
  late final Animation<Offset> _brandSlide;
  late final Animation<double> _footerFade;
  late final Animation<Offset> _footerSlide;

  final List<Timer> _activeTimers = <Timer>[];
  bool _disableAnimations = false;
  bool _bootstrapStarted = false;
  bool _isDisposed = false;

  String _statusMessage = 'Initializing secure vault...';
  double _progressValue = 0.16;

  @override
  void initState() {
    super.initState();

    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );

    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _crestScale = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );
    _crestFade = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.0, 0.42, curve: Curves.easeOut),
    );

    _brandFade = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.24, 0.78, curve: Curves.easeOut),
    );
    _brandSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.24, 0.82, curve: Curves.easeOutCubic),
      ),
    );

    _footerFade = CurvedAnimation(
      parent: _introCtrl,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );
    _footerSlide = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    _disableAnimations = reduced;

    if (reduced) {
      _introCtrl.value = 1.0;
      _orbitCtrl.stop();
    } else {
      if (!_introCtrl.isCompleted && !_introCtrl.isAnimating) {
        _introCtrl.forward();
      }
      if (!_orbitCtrl.isAnimating) {
        _orbitCtrl.repeat();
      }
    }

    if (widget.enableBootstrap && !_bootstrapStarted) {
      _bootstrapStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) {
          _bootstrapApp();
        }
      });
    }
  }

  Future<void> _waitCancellable(Duration duration) {
    if (duration <= Duration.zero || _isDisposed || !mounted) {
      return Future<void>.value();
    }
    final Completer<void> completer = Completer<void>();
    late final Timer timer;
    timer = Timer(duration, () {
      _activeTimers.remove(timer);
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    _activeTimers.add(timer);
    return completer.future;
  }

  Future<void> _bootstrapApp() async {
    final Stopwatch stopwatch = Stopwatch()..start();

    // 1. Ensure Offline SQLite vault store is ready
    try {
      final dbService = ref.read(offlineDatabaseServiceProvider);
      await dbService.database;
    } catch (_) {
      // Offline database fallback runs silently on Web or unsupported hosts
    }

    if (!mounted || _isDisposed) return;
    setState(() {
      _progressValue = 0.44;
      _statusMessage = 'Verifying network connection...';
    });

    // 2. Probe network reachability cleanly
    bool isOnline = false;
    try {
      final connService = ref.read(connectivityServiceProvider);
      isOnline = await connService.checkActualConnection();
    } catch (_) {
      isOnline = false;
    }

    if (!mounted || _isDisposed) return;
    setState(() {
      _progressValue = 0.72;
      _statusMessage = isOnline
          ? 'Synchronizing core session...'
          : 'Restoring offline vault session...';
    });

    // 3. Restore authenticated staff session if present
    try {
      await ref.read(authControllerProvider.notifier).restoreSession();
    } catch (_) {
      // Unauthenticated users cleanly proceed to LoginScreen
    }

    if (!mounted || _isDisposed) return;
    setState(() {
      _progressValue = 1.0;
      _statusMessage = 'Workspace ready';
    });

    // Ensure crisp, dignified reveal duration without gratuitous startup blocking
    final Duration minFloor = widget.minimumHoldOverride ??
        (_disableAnimations
            ? const Duration(milliseconds: 220)
            : const Duration(milliseconds: 900));
    final Duration remaining = minFloor - stopwatch.elapsed;
    if (remaining > Duration.zero) {
      await _waitCancellable(remaining);
    }

    // Brief settle pause on 100% progress only when full motion is active
    if (!_disableAnimations && mounted && !_isDisposed) {
      await _waitCancellable(const Duration(milliseconds: 160));
    }

    if (!mounted || _isDisposed) return;

    final Widget targetScreen = _resolveTargetScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionDuration: _disableAnimations
            ? const Duration(milliseconds: 150)
            : const Duration(milliseconds: 520),
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
      return const CoAppScaffold();
    }
    return const LoginScreen();
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (final Timer timer in List<Timer>.from(_activeTimers)) {
      timer.cancel();
    }
    _activeTimers.clear();
    _introCtrl.dispose();
    _orbitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final bool compactHeight = screenSize.height < 640;

    return Scaffold(
      backgroundColor: IcareColors.primaryDark,
      body: Stack(
        children: [
          // Deep Forest Emerald Vault Backdrop
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    IcareColors.primaryDark,
                    Color(0xFF043B2E),
                    Color(0xFF02261D),
                  ],
                ),
              ),
              child: CustomPaint(
                painter: IcareEmeraldBackdropPainter(alignmentYFactor: 0.42),
              ),
            ),
          ),

          // Main Centered Welcome Canvas
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 420,
                        minHeight: math.max(0, constraints.maxHeight - 48),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top Institutional Overline
                          FadeTransition(
                            opacity: _brandFade,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFF34D399)
                                      .withValues(alpha: 0.25),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 7,
                                    height: 7,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: IcareColors.accent,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'CORE BANKING & FIELD OPERATIONS',
                                      softWrap: true,
                                      style: TextStyle(
                                        color: Color(0xFFA7F3D0),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: compactHeight ? 24 : 40),

                          // Central Hero Crest & Brand Typography
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FadeTransition(
                                opacity: _crestFade,
                                child: ScaleTransition(
                                  scale: _crestScale,
                                  child: SizedBox(
                                    width: 164,
                                    height: 164,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (!_disableAnimations)
                                          AnimatedBuilder(
                                            animation: _orbitCtrl,
                                            builder: (context, _) {
                                              return CustomPaint(
                                                size: const Size(164, 164),
                                                painter: _VaultOrbitPainter(
                                                  progress: _orbitCtrl.value,
                                                ),
                                              );
                                            },
                                          ),
                                        const IcareBrandCrest(
                                          size: 108,
                                          heroTag: 'icare_brand_crest',
                                          animateSweep: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: compactHeight ? 18 : 26),
                              FadeTransition(
                                opacity: _brandFade,
                                child: SlideTransition(
                                  position: _brandSlide,
                                  child: Column(
                                    children: [
                                      const Text(
                                        'ICARE',
                                        style: TextStyle(
                                          fontSize: 38,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 7.0,
                                          height: 1.05,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Empowering Communities, Growing Together',
                                        textAlign: TextAlign.center,
                                        softWrap: true,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFFA7F3D0),
                                          letterSpacing: 0.25,
                                        ),
                                      ),
                                      const SizedBox(height: 28),
                                      _buildProgressIndicator(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: compactHeight ? 24 : 40),

                          // Institutional Footer
                          FadeTransition(
                            opacity: _footerFade,
                            child: SlideTransition(
                              position: _footerSlide,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.verified_user_outlined,
                                    size: 13,
                                    color: Color(0xFF6EE7B7),
                                  ),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Initiative for Community Advancement, Relief and Empowerment',
                                      textAlign: TextAlign.center,
                                      softWrap: true,
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.15,
                                      ),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final Duration barDuration =
        _disableAnimations ? Duration.zero : const Duration(milliseconds: 360);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Startup progress ${(100 * _progressValue).round()} percent',
          value: '${(100 * _progressValue).round()}%',
          child: Container(
            width: 220,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.centerLeft,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return AnimatedContainer(
                  duration: barDuration,
                  curve: Curves.easeOutCubic,
                  width: constraints.maxWidth * _progressValue.clamp(0.0, 1.0),
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [IcareColors.accent, Color(0xFF34D399)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF34D399),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: AnimatedSwitcher(
                duration: _disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                child: Text(
                  _statusMessage,
                  key: ValueKey<String>(_statusMessage),
                  softWrap: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Subtle expanding concentric ring painter framing the central brand crest.
class _VaultOrbitPainter extends CustomPainter {
  final double progress;

  const _VaultOrbitPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    const double minR = 56.0;
    const double maxR = 80.0;

    for (int i = 0; i < 2; i++) {
      final double phase = (progress + i * 0.5) % 1.0;
      final double radius = minR + (maxR - minR) * phase;
      final double alpha = (1.0 - phase) * 0.28;

      final Paint p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..color = const Color(0xFF34D399).withValues(alpha: alpha);

      canvas.drawCircle(center, radius, p);
    }

    // Subtle directional sweep arc
    final double sweepAngle = progress * 2 * math.pi;
    final Paint arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = IcareColors.accent.withValues(alpha: 0.45);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 62.0),
      sweepAngle,
      math.pi * 0.45,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _VaultOrbitPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
