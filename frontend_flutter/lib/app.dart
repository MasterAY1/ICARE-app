import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/auth_state.dart';
import 'core/theme/icare_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/onboarding/presentation/branch_onboarding_portal_screen.dart';
import 'features/onboarding/presentation/credit_officer_portal_screen.dart';

class IcareApp extends ConsumerWidget {
  const IcareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(themeControllerProvider);

    // Sync saved backend appearance preferences upon sign-in or session restoration
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthStateAuthenticated && previous is! AuthStateAuthenticated) {
        if (next.user.preferences.isNotEmpty) {
          ref.read(themeControllerProvider.notifier).applyRemotePreferences(next.user.preferences);
        }
      }
    });

    return MaterialApp(
      title: 'ICARE — Core Banking',
      debugShowCheckedModeBanner: false,
      theme: IcareTheme.buildTheme(
        brightness: Brightness.light,
        accent: appearance.accentPreset,
        compactDensity: appearance.compactDensity,
      ),
      darkTheme: IcareTheme.buildTheme(
        brightness: Brightness.dark,
        accent: appearance.accentPreset,
        compactDensity: appearance.compactDensity,
      ),
      themeMode: appearance.themeMode,
      themeAnimationDuration: appearance.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      builder: (context, child) {
        if (!appearance.reduceMotion || child == null) {
          return child ?? const SizedBox.shrink();
        }
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child,
        );
      },
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      onGenerateRoute: (settings) {
        final rawName = settings.name ?? '';
        final uri = Uri.tryParse(rawName);
        if (uri != null &&
            (uri.path.contains('onboarding') ||
                rawName.contains('onboarding') ||
                uri.queryParameters.containsKey('token') ||
                uri.fragment.contains('token'))) {
          String? token = uri.queryParameters['token'];
          String? officer = uri.queryParameters['officer'];
          bool isOfficerRoute = uri.path.contains('officer') || uri.fragment.contains('officer');

          if (uri.fragment.isNotEmpty) {
            final fragUri = Uri.tryParse(uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}');
            if (fragUri != null) {
              token ??= fragUri.queryParameters['token'];
              officer ??= fragUri.queryParameters['officer'];
            }
          }

          final cleanToken = token?.trim() ?? '';
          if (cleanToken.startsWith('onb_co_') || isOfficerRoute) {
            return MaterialPageRoute(
              builder: (_) => CreditOfficerPortalScreen(coToken: cleanToken),
              settings: settings,
            );
          }

          return MaterialPageRoute(
            builder: (_) => BranchOnboardingPortalScreen(
              token: cleanToken,
              initialOfficer: officer,
            ),
            settings: settings,
          );
        }
        return null;
      },
      home: const SplashScreen(),
    );
  }
}
