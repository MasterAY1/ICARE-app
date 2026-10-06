import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/offline_database_service.dart';
import '../../../core/theme/icare_colors.dart';
import '../../../core/theme/icare_typography.dart';
import '../../shared/presentation/co_app_scaffold.dart';
import 'login_screen.dart';

/// Institutional Welcome Splash Screen for ICARE Core Banking.
/// Features a smooth brand animation, background offline database pre-warming,
/// and seamless transition to the authenticated portal or login screen.
/// Adheres strictly to Rule 10 (Zero Emojis, Corporate Aesthetic).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeIn,
    );

    _scaleAnim = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack),
    );

    _animCtrl.forward();

    _bootstrapApp();
  }

  Future<void> _bootstrapApp() async {
    // 1. Initialize local SQLite database in background
    try {
      final dbService = ref.read(offlineDatabaseServiceProvider);
      await dbService.database;
    } catch (_) {
      // Local DB initialization error handling
    }

    // 2. Pre-check live network connection
    try {
      final connService = ref.read(connectivityServiceProvider);
      await connService.checkActualConnection();
    } catch (_) {
      // Safe fallback
    }

    // 3. Try to restore active authenticated session if persisted
    try {
      await ref.read(authControllerProvider.notifier).restoreSession();
    } catch (_) {
      // Safe fallback
    }

    // 4. Minimum display duration for a polished user experience
    await Future.delayed(const Duration(milliseconds: 1600));

    if (!mounted) return;

    final authState = ref.read(authControllerProvider);
    final targetScreen = (authState is AuthStateAuthenticated)
        ? const CoAppScaffold()
        : const LoginScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, anim, secAnim) => targetScreen,
        transitionsBuilder: (context, anim, secAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IcareColors.canvas,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Branded Logo Container
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Image.asset(
                    'assets/icare_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.account_balance,
                        size: 48,
                        color: IcareColors.primary,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Corporate Branding Titles
                Text(
                  'ICARE',
                  style: IcareTypography.h2.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                    fontSize: 28,
                    color: IcareColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Growing Together',
                  style: IcareTypography.bodyRegular.copyWith(
                    color: const Color(0xFF065F46),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 36),

                // Institutional Progress Indicator
                SizedBox(
                  width: 140,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: IcareColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(IcareColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Initializing secure ledger...',
                  style: IcareTypography.caption.copyWith(
                    color: IcareColors.textLight,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
