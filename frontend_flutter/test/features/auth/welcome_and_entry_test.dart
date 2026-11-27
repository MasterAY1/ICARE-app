import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter/core/auth/auth_controller.dart';
import 'package:frontend_flutter/core/auth/auth_state.dart';
import 'package:frontend_flutter/core/auth/session_storage_base.dart';
import 'package:frontend_flutter/core/network/api_client.dart';
import 'package:frontend_flutter/core/offline/connectivity_service.dart';
import 'package:frontend_flutter/core/offline/offline_database_service.dart';
import 'package:frontend_flutter/features/auth/presentation/login_screen.dart';
import 'package:frontend_flutter/features/auth/presentation/splash_screen.dart';
import 'package:frontend_flutter/features/auth/presentation/widgets/auth_entry_components.dart';

class _MemorySessionStorage implements SessionStorage {
  @override
  Future<void> clearSession() async {}

  @override
  Future<Map<String, String>?> getSession() async => null;

  @override
  Future<void> saveSession(String token, String userJson) async {}
}

class _FakeAuthController extends AuthController {
  String? lastLoginUsername;
  String? lastLoginPassword;
  String? lastMfaCode;
  String? lastNewPassword;
  bool cancelled = false;

  _FakeAuthController([AuthState? initial])
      : super(ApiClient(), null, _MemorySessionStorage(), false) {
    if (initial != null) {
      state = initial;
    }
  }

  void setTestState(AuthState next) {
    state = next;
  }

  @override
  Future<void> restoreSession() async {
    state = const AuthStateInitial();
  }

  @override
  Future<void> login({
    required String username,
    required String password,
  }) async {
    lastLoginUsername = username;
    lastLoginPassword = password;
    state = const AuthStateInitial();
  }

  @override
  Future<void> submitMfaChallenge({required String code}) async {
    lastMfaCode = code;
  }

  @override
  Future<void> submitInitialPasswordChange({
    required String currentPassword,
    required String newPassword,
  }) async {
    lastNewPassword = newPassword;
  }

  @override
  void cancelChallenge() {
    cancelled = true;
    state = const AuthStateInitial();
  }
}

class _SilentConnectivityService extends ConnectivityService {
  @override
  Future<bool> checkActualConnection({
    bool forceImmediateOffline = false,
  }) async {
    return false;
  }
}

final RegExp _emojiPattern = RegExp(
  r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
  unicode: true,
);

void _expectNoEmojis(WidgetTester tester) {
  final Iterable<Text> texts = tester.widgetList<Text>(find.byType(Text));
  for (final Text text in texts) {
    final String content = text.data ?? '';
    expect(
      _emojiPattern.hasMatch(content),
      isFalse,
      reason: 'Found forbidden emoji character in "$content"',
    );
  }
}

Widget _wrapWithHost({
  required Widget child,
  required _FakeAuthController authController,
  ConnectivityService? connectivityService,
  Size viewport = const Size(390, 844),
  bool disableAnimations = false,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith((ref) => authController),
      offlineDatabaseServiceProvider.overrideWithValue(
        OfflineDatabaseService(useMemoryStore: true),
      ),
      if (connectivityService != null)
        connectivityServiceProvider.overrideWith((ref) {
          ref.onDispose(connectivityService.dispose);
          return connectivityService;
        }),
    ],
    child: MediaQuery(
      data: MediaQueryData(
        size: viewport,
        disableAnimations: disableAnimations,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        home: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ICARE Welcome Animation & Unified Entry UI', () {
    testWidgets(
        'SplashScreen renders institutional welcome and obeys reduced motion', (
      WidgetTester tester,
    ) async {
      final _FakeAuthController auth = _FakeAuthController();

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrapWithHost(
          authController: auth,
          disableAnimations: true,
          child: const SplashScreen(enableBootstrap: false),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('ICARE Institutional Crest'), findsOneWidget);
      expect(find.text('ICARE'), findsOneWidget);
      expect(
        find.text(
          'Initiative for Community Advancement,\nRelief and Empowerment',
        ),
        findsOneWidget,
      );
      expect(find.text('Growing Together'), findsOneWidget);
      expect(find.text('TAP TO CONTINUE'), findsOneWidget);
      _expectNoEmojis(tester);
    });

    testWidgets(
        'SplashScreen renders cleanly on compact screens and large text scale without overflow',
        (
      WidgetTester tester,
    ) async {
      final _FakeAuthController auth = _FakeAuthController();

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrapWithHost(
          authController: auth,
          viewport: const Size(360, 640),
          disableAnimations: true,
          textScale: 1.25,
          child: const SplashScreen(enableBootstrap: false),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('ICARE'), findsOneWidget);
      expect(find.text('Growing Together'), findsOneWidget);
      _expectNoEmojis(tester);
    });

    testWidgets(
        'SplashScreen supports tap-to-continue once bootstrap completes', (
      WidgetTester tester,
    ) async {
      final _FakeAuthController auth = _FakeAuthController();
      final _SilentConnectivityService conn = _SilentConnectivityService();

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrapWithHost(
          authController: auth,
          connectivityService: conn,
          disableAnimations: false,
          child: const SplashScreen(
            minimumHoldOverride: Duration(seconds: 10),
            enableBootstrap: true,
          ),
        ),
      );

      // Allow post-frame bootstrap to complete while 10s showcase timer is active
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(SplashScreen), findsOneWidget);

      // Tapping skips remaining showcase wait and routes into LoginScreen cleanly
      await tester.tap(find.byType(SplashScreen));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Staff Workspace Sign-In'), findsOneWidget);
      _expectNoEmojis(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets(
        'SplashScreen completes bootstrap and transitions smoothly into LoginScreen',
        (
      WidgetTester tester,
    ) async {
      final _FakeAuthController auth = _FakeAuthController();
      final _SilentConnectivityService conn = _SilentConnectivityService();

      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrapWithHost(
          authController: auth,
          connectivityService: conn,
          disableAnimations: false,
          child: const SplashScreen(
            minimumHoldOverride: Duration(milliseconds: 20),
            enableBootstrap: true,
          ),
        ),
      );

      // Flush post-frame bootstrap, 20ms floor, 160ms settle, and Hero route transition
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Staff Workspace Sign-In'), findsOneWidget);
      _expectNoEmojis(tester);

      // Unmount ProviderScope cleanly so connectivity heartbeat cancels
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets(
        'LoginScreen desktop split renders cleanly with zero overflows and validates input',
        (
      WidgetTester tester,
    ) async {
      final _FakeAuthController auth = _FakeAuthController();

      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrapWithHost(
          authController: auth,
          viewport: const Size(1280, 820),
          textScale: 1.25,
          child: const LoginScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('EST. 2006 • SOUTH-WEST NIGERIA'), findsOneWidget);
      expect(find.text('Staff Workspace Sign-In'), findsOneWidget);
      expect(find.text('Sign In to Core Banking'), findsOneWidget);
      _expectNoEmojis(tester);

      // Empty submit displays inline validation error banner
      await tester.tap(find.text('Sign In to Core Banking'));
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.text('Please enter your staff username to continue.'),
        findsOneWidget,
      );
      expect(auth.lastLoginUsername, isNull);
    });

    testWidgets(
        'LoginScreen mobile layout switches between Staff Sign-In and Onboarding Access',
        (
      WidgetTester tester,
    ) async {
      final _FakeAuthController auth = _FakeAuthController();

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrapWithHost(
          authController: auth,
          viewport: const Size(390, 844),
          textScale: 1.25,
          child: const LoginScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(IcareAuthModeSegmentedBar), findsOneWidget);
      expect(find.text('Core Banking & Field Operations'), findsOneWidget);

      // Switch to Onboarding Access mode
      await tester.tap(find.text('Onboarding Access'));
      await tester.pumpAndSettle();

      expect(find.text('Branch & Officer Onboarding'), findsOneWidget);
      expect(find.byType(OnboardingAccessPanel), findsOneWidget);
      expect(find.text('Branch Portal'), findsOneWidget);
      expect(find.text('Officer Portal'), findsOneWidget);

      // Empty onboarding token shows helpful validation message
      await tester.ensureVisible(find.text('Open Onboarding Workspace'));
      await tester.tap(find.text('Open Onboarding Workspace'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.text(
          'Enter your onboarding token or select Branch Portal / Officer Portal below.',
        ),
        findsOneWidget,
      );

      // Switch back via inline helper link
      await tester.ensureVisible(find.text('Go to Staff Sign-In'));
      await tester.tap(find.text('Go to Staff Sign-In'));
      await tester.pumpAndSettle();

      expect(find.text('Staff Workspace Sign-In'), findsOneWidget);
      _expectNoEmojis(tester);
    });

    testWidgets(
        'LoginScreen handles MFA challenge and First-Time Activation password rules',
        (
      WidgetTester tester,
    ) async {
      final _FakeAuthController auth = _FakeAuthController();

      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrapWithHost(
          authController: auth,
          viewport: const Size(430, 900),
          child: const LoginScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      // Trigger MFA challenge state
      auth.setTestState(
        const AuthStateMfaRequired(
          mfaToken: 'mfa_tok_123',
          username: 'co_ada',
          message: 'Enter authenticator code.',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Two-Factor Verification'), findsOneWidget);
      expect(find.byType(IcareAuthModeSegmentedBar), findsNothing);
      expect(find.text('Verify & Complete Sign-In'), findsOneWidget);

      // Cancel returns cleanly to Sign-In
      await tester.ensureVisible(find.text('Cancel & Return to Sign-In'));
      await tester.tap(find.text('Cancel & Return to Sign-In'));
      await tester.pumpAndSettle();

      expect(auth.cancelled, isTrue);
      expect(find.text('Staff Workspace Sign-In'), findsOneWidget);

      // Trigger First-Time Activation / Forced Password Rotation state
      auth.setTestState(
        const AuthStatePasswordChangeRequired(
          tempToken: 'pw_tok_456',
          username: 'co_ada',
          message: 'Please set a personal password before accessing ICARE.',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('First-Time Account Activation'), findsOneWidget);
      expect(find.byType(PasswordRequirementsChecklist), findsOneWidget);
      expect(find.text('At least 8 characters'), findsOneWidget);

      // Enter temporary + new + matching confirm passwords
      final Finder textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3));

      await tester.enterText(textFields.at(0), 'TempPass1');
      await tester.enterText(textFields.at(1), 'SecureStaff99');
      await tester.enterText(textFields.at(2), 'SecureStaff99');
      await tester.pump();

      await tester.ensureVisible(find.text('Activate Account & Sign In'));
      await tester.tap(find.text('Activate Account & Sign In'));
      await tester.pump();

      expect(auth.lastNewPassword, 'SecureStaff99');
      _expectNoEmojis(tester);
    });
  });
}
