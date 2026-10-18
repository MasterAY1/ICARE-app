import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/auth_state.dart';
import 'core/theme/icare_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/onboarding/presentation/branch_onboarding_portal_screen.dart';
import 'features/shared/presentation/co_app_scaffold.dart';

class IcareApp extends ConsumerWidget {
  const IcareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'ICARE — Core Banking',
      debugShowCheckedModeBanner: false,
      theme: IcareTheme.lightTheme,
      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri != null &&
            (uri.path.contains('onboarding') ||
                uri.queryParameters.containsKey('token'))) {
          final token = uri.queryParameters['token'] ?? '';
          final officer = uri.queryParameters['officer'];
          return MaterialPageRoute(
            builder: (_) => BranchOnboardingPortalScreen(
              token: token,
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
