import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter/core/auth/auth_controller.dart';
import 'package:frontend_flutter/core/auth/auth_state.dart';
import 'package:frontend_flutter/core/auth/session_storage_base.dart';
import 'package:frontend_flutter/core/network/api_client.dart';
import 'package:frontend_flutter/core/offline/connectivity_service.dart';
import 'package:frontend_flutter/core/offline/offline_database_service.dart';
import 'package:frontend_flutter/core/theme/icare_theme.dart';
import 'package:frontend_flutter/core/theme/icare_theme_tokens.dart';
import 'package:frontend_flutter/core/theme/theme_controller.dart';
import 'package:frontend_flutter/features/profile/data/models/profile_models.dart';
import 'package:frontend_flutter/features/profile/data/profile_api_service.dart';
import 'package:frontend_flutter/features/profile/presentation/settings_profile_screen.dart';
import 'package:frontend_flutter/features/shared/presentation/co_app_scaffold.dart';
import 'package:frontend_flutter/features/shared/presentation/widgets/user_avatar_circle.dart';

class _InMemorySessionStorage implements SessionStorage {
  Map<String, String>? _stored;

  @override
  Future<void> saveSession(String token, String userJson) async {
    _stored = {'token': token, 'user': userJson};
  }

  @override
  Future<Map<String, String>?> getSession() async => _stored;

  @override
  Future<void> clearSession() async {
    _stored = null;
  }
}

class _FakeHttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      Uint8List.fromList(utf8.encode('{}')),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _QuietConnectivityService implements ConnectivityService {
  final StreamController<bool> _ctrl = StreamController<bool>.broadcast();
  bool _online;

  _QuietConnectivityService({bool isOnline = true}) : _online = isOnline;

  @override
  Stream<bool> get statusStream => _ctrl.stream;

  @override
  bool get isOnline => _online;

  @override
  void reportOffline() {
    _online = false;
    if (!_ctrl.isClosed) _ctrl.add(false);
  }

  @override
  void reportOnline() {
    _online = true;
    if (!_ctrl.isClosed) _ctrl.add(true);
  }

  @override
  Future<bool> checkActualConnection({bool forceImmediateOffline = false}) async {
    return _online;
  }

  @override
  void dispose() {
    _ctrl.close();
  }
}

class _FakeAuthController extends AuthController {
  _FakeAuthController(
    AuthUser user,
    ApiClient apiClient,
    OfflineDatabaseService offlineDb,
  ) : super(apiClient, offlineDb, _InMemorySessionStorage(), false) {
    state = AuthStateAuthenticated(user: user, token: 'test-jwt-token');
  }
}

class _FakeProfileApiService extends ProfileApiService {
  StaffProfileSnapshot snapshot;
  int fetchCalls = 0;
  int updateCalls = 0;
  int mfaSetupCalls = 0;
  String? lastActivatedMfaCode;
  String? lastUpdatedPhone;
  String? lastUpdatedBio;
  Map<String, dynamic>? lastUpdatedPreferences;
  String? lastCurrentPassword;
  String? lastNewPassword;

  _FakeProfileApiService({
    required ApiClient apiClient,
    required this.snapshot,
  }) : super(apiClient);

  @override
  Future<StaffProfileSnapshot> fetchProfile() async {
    fetchCalls++;
    return snapshot;
  }

  @override
  Future<({AuthUser user, String emergencyContact, String message})>
      updateProfile({
    String? phone,
    String? email,
    String? bio,
    String? emergencyContact,
    Map<String, dynamic>? preferences,
  }) async {
    updateCalls++;
    if (phone != null) lastUpdatedPhone = phone;
    if (bio != null) lastUpdatedBio = bio;
    if (preferences != null) {
      lastUpdatedPreferences = Map<String, dynamic>.from(preferences);
    }

    final updatedUser = snapshot.user.copyWith(
      phone: phone ?? snapshot.user.phone,
      email: email ?? snapshot.user.email,
      bio: bio ?? snapshot.user.bio,
      preferences: preferences ?? snapshot.user.preferences,
    );
    final updatedEmergency = emergencyContact ?? snapshot.emergencyContact;
    snapshot = StaffProfileSnapshot(
      user: updatedUser,
      emergencyContact: updatedEmergency,
      canSelfChangePassword: snapshot.canSelfChangePassword,
      remainingBackupCodes: snapshot.remainingBackupCodes,
      mfaEnrolledAt: snapshot.mfaEnrolledAt,
      recentActivity: snapshot.recentActivity,
    );

    return (
      user: updatedUser,
      emergencyContact: updatedEmergency,
      message: 'Profile preferences saved.',
    );
  }

  @override
  Future<MfaSetupBundle> initiateMfaSetup() async {
    mfaSetupCalls++;
    return const MfaSetupBundle(
      secret: 'JBSWY3DPEHPK3PXP',
      otpauthUri: 'otpauth://totp/ICARE:co_ade?secret=JBSWY3DPEHPK3PXP',
      backupCodes: ['ABCD-1234', 'EFGH-5678'],
    );
  }

  @override
  Future<String> activateMfa(String code) async {
    lastActivatedMfaCode = code;
    final updatedUser = snapshot.user.copyWith(mfaEnabled: true);
    snapshot = StaffProfileSnapshot(
      user: updatedUser,
      emergencyContact: snapshot.emergencyContact,
      canSelfChangePassword: snapshot.canSelfChangePassword,
      remainingBackupCodes: 8,
      mfaEnrolledAt: '2026-11-20T12:00:00Z',
      recentActivity: snapshot.recentActivity,
    );
    return 'Two-factor authentication enabled.';
  }

  @override
  Future<String> disableMfa(String password) async {
    final updatedUser = snapshot.user.copyWith(mfaEnabled: false);
    snapshot = StaffProfileSnapshot(
      user: updatedUser,
      emergencyContact: snapshot.emergencyContact,
      canSelfChangePassword: snapshot.canSelfChangePassword,
      remainingBackupCodes: 0,
      mfaEnrolledAt: null,
      recentActivity: snapshot.recentActivity,
    );
    return 'Two-factor authentication disabled.';
  }

  @override
  Future<({String message, String? accessToken, String? csrfToken})>
      changeOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
    return (
      message: 'Password updated successfully.',
      accessToken: 'refreshed-jwt-token',
      csrfToken: 'refreshed-csrf-token',
    );
  }
}

void _expectNoEmojis(WidgetTester tester) {
  final emojiPattern = RegExp(
    r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
    unicode: true,
  );
  for (final widget in tester.allWidgets) {
    if (widget is Text && widget.data != null) {
      expect(
        emojiPattern.hasMatch(widget.data!),
        isFalse,
        reason: 'Forbidden emoji found in UI text: "${widget.data}"',
      );
    }
  }
}

void _expectNoInternalIdentifiers(WidgetTester tester) {
  final internalPattern = RegExp(r'\b(BR-[A-Z]+-\d+|FP-\d+|Account 1000)\b');
  for (final widget in tester.allWidgets) {
    if (widget is Text && widget.data != null) {
      expect(
        internalPattern.hasMatch(widget.data!),
        isFalse,
        reason: 'Internal code leaked in UI text: "${widget.data}"',
      );
    }
  }
}

AuthUser _buildCoUser({Map<String, dynamic> preferences = const {}}) {
  return AuthUser(
    id: 'user-co-01',
    username: 'co_ade',
    fullName: 'Adebayo Ogunleye',
    role: 'Credit Officer',
    branch: 'Ikeja',
    branchId: 'branch-ikeja-01',
    phone: '+234 801 234 5678',
    email: 'adebayo@icare.ng',
    bio: 'Ikeja Daily & Weekly Desk',
    mfaEnabled: false,
    createdAt: '2026-01-15T09:00:00Z',
    lastLogin: '2026-11-20T08:30:00Z',
    preferences: preferences,
  );
}

AuthUser _buildBmUser({bool mfaEnabled = true}) {
  return AuthUser(
    id: 'user-bm-01',
    username: 'bm_ngozi',
    fullName: 'Ngozi Kalu',
    role: 'Branch Manager',
    branch: 'Surulere',
    branchId: 'branch-surulere-01',
    phone: '+234 809 876 5432',
    email: 'ngozi@icare.ng',
    bio: 'Surulere Branch Operations',
    mfaEnabled: mfaEnabled,
    isMiscSavingsManager: true,
    createdAt: '2025-11-01T10:00:00Z',
    lastLogin: '2026-11-20T07:45:00Z',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeController & IcareSurfaceTokens Theme Engine', () {
    test('ThemeController updates state and persists across SharedPreferences', () async {
      final controller = ThemeController(autoLoad: false);

      expect(controller.state.themeMode, ThemeMode.light);
      expect(controller.state.accentPreset, IcareAccentPreset.emerald);
      expect(controller.state.compactDensity, isFalse);
      expect(controller.state.reduceMotion, isFalse);
      expect(controller.state.hapticsEnabled, isTrue);

      await controller.setThemeMode(ThemeMode.dark);
      await controller.setAccentPreset(IcareAccentPreset.sapphire);
      await controller.setCompactDensity(true);
      await controller.setReduceMotion(true);
      await controller.setHapticsEnabled(false);

      expect(controller.state.themeMode, ThemeMode.dark);
      expect(controller.state.accentPreset, IcareAccentPreset.sapphire);
      expect(controller.state.compactDensity, isTrue);
      expect(controller.state.reduceMotion, isTrue);
      expect(controller.state.hapticsEnabled, isFalse);

      // Re-hydrate from storage in a fresh ThemeController instance.
      final reloaded = ThemeController(autoLoad: false);
      await reloaded.loadFromStorage();

      expect(reloaded.state.isLoaded, isTrue);
      expect(reloaded.state.themeMode, ThemeMode.dark);
      expect(reloaded.state.accentPreset, IcareAccentPreset.sapphire);
      expect(reloaded.state.compactDensity, isTrue);
      expect(reloaded.state.reduceMotion, isTrue);
      expect(reloaded.state.hapticsEnabled, isFalse);

      // Resetting restores institutional defaults and updates storage.
      await reloaded.resetToDefaults();
      expect(reloaded.state.themeMode, ThemeMode.light);
      expect(reloaded.state.accentPreset, IcareAccentPreset.emerald);
      expect(reloaded.state.compactDensity, isFalse);
      expect(reloaded.state.reduceMotion, isFalse);
      expect(reloaded.state.hapticsEnabled, isTrue);
    });

    test('applyRemotePreferences hydrates server preferences cleanly', () async {
      final controller = ThemeController(autoLoad: false);

      await controller.applyRemotePreferences({});
      expect(controller.state.themeMode, ThemeMode.light);

      await controller.applyRemotePreferences({
        'theme_mode': 'dark',
        'accent_preset': 'indigo',
        'compact_density': true,
        'reduce_motion': true,
        'haptics_enabled': false,
      });

      expect(controller.state.themeMode, ThemeMode.dark);
      expect(controller.state.accentPreset, IcareAccentPreset.indigo);
      expect(controller.state.compactDensity, isTrue);
      expect(controller.state.reduceMotion, isTrue);
      expect(controller.state.hapticsEnabled, isFalse);
    });

    test('IcareTheme provides IcareSurfaceTokens across Light/Dark & all 4 presets', () {
      for (final preset in IcareAccentPreset.values) {
        final lightTheme = IcareTheme.buildTheme(
          brightness: Brightness.light,
          accent: preset,
          compactDensity: false,
        );
        final darkTheme = IcareTheme.buildTheme(
          brightness: Brightness.dark,
          accent: preset,
          compactDensity: true,
        );

        final lightTokens = lightTheme.extension<IcareSurfaceTokens>();
        final darkTokens = darkTheme.extension<IcareSurfaceTokens>();

        expect(lightTokens, isNotNull);
        expect(darkTokens, isNotNull);
        expect(lightTokens!.isDark, isFalse);
        expect(darkTokens!.isDark, isTrue);
        expect(lightTokens.brandPrimary, preset.lightPrimary);
        expect(darkTokens.brandPrimary, preset.darkPrimary);
        expect(darkTokens.brandPrimaryDark, preset.darkPrimaryDark);
        expect(lightTheme.visualDensity, VisualDensity.standard);
        expect(darkTheme.visualDensity, VisualDensity.compact);
      }
    });
  });

  group('SettingsProfileScreen & CoAppScaffold Integration', () {
    testWidgets(
      'Credit Officer on mobile renders SettingsProfileScreen, enforces supervisor password policy, toggles Dark Mode, activates 2FA, and saves details without overflow or emojis',
      (WidgetTester tester) async {
        final conn = _QuietConnectivityService(isOnline: true);
        final offlineDb = OfflineDatabaseService(useMemoryStore: true);
        final apiClient = ApiClient(
          connectivityService: conn,
          offlineDb: offlineDb,
          adapter: _FakeHttpAdapter(),
          isWebOverride: false,
        );
        final coUser = _buildCoUser();
        final authController = _FakeAuthController(coUser, apiClient, offlineDb);
        final fakeProfileApi = _FakeProfileApiService(
          apiClient: apiClient,
          snapshot: StaffProfileSnapshot(
            user: coUser,
            emergencyContact: 'Mrs. Ogunleye (+234 802 111 2222)',
            canSelfChangePassword: false,
            remainingBackupCodes: 0,
            recentActivity: const [
              LoginActivityItemModel(
                loginTime: '2026-11-20T08:30:00Z',
                status: 'SUCCESS',
                deviceName: 'Field Tablet',
                browser: 'Chrome',
                operatingSystem: 'Android',
              ),
            ],
          ),
        );

        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              connectivityServiceProvider.overrideWithValue(conn),
              offlineDatabaseServiceProvider.overrideWithValue(offlineDb),
              apiClientProvider.overrideWithValue(apiClient),
              authControllerProvider.overrideWith((_) => authController),
              profileApiServiceProvider.overrideWithValue(fakeProfileApi),
              themeControllerProvider.overrideWith(
                (_) => ThemeController(autoLoad: false),
              ),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                final appearance = ref.watch(themeControllerProvider);
                return MaterialApp(
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
                  home: const Scaffold(
                    body: SingleChildScrollView(
                      padding: EdgeInsets.all(14),
                      child: SettingsProfileScreen(),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(fakeProfileApi.fetchCalls, 1);
        expect(find.text('Adebayo Ogunleye'), findsWidgets);
        expect(find.text('@co_ade'), findsOneWidget);
        expect(find.text('Credit Officer'), findsWidgets);
        expect(find.text('Supervisor-Managed Password Policy'), findsOneWidget);
        expect(find.text('Update Password'), findsNothing);
        expect(find.text('Two-Factor Authentication: Not Enrolled'), findsOneWidget);

        // Live Theme Switch: Light Slate -> Dark Vault & Accent -> Sapphire Treasury.
        await tester.ensureVisible(find.text('Dark Vault'));
        await tester.tap(find.text('Dark Vault'));
        await tester.pumpAndSettle();
        expect(container.read(themeControllerProvider).themeMode, ThemeMode.dark);

        await tester.ensureVisible(find.text('Sapphire Treasury'));
        await tester.tap(find.text('Sapphire Treasury'));
        await tester.pumpAndSettle();
        expect(
          container.read(themeControllerProvider).accentPreset,
          IcareAccentPreset.sapphire,
        );
        expect(fakeProfileApi.lastUpdatedPreferences?['theme_mode'], 'dark');
        expect(
          fakeProfileApi.lastUpdatedPreferences?['accent_preset'],
          'sapphire',
        );

        // Initiate and activate 2FA setup.
        await tester.ensureVisible(find.text('Enable 2FA'));
        await tester.tap(find.text('Enable 2FA'));
        await tester.pumpAndSettle();
        expect(fakeProfileApi.mfaSetupCalls, 1);
        expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);
        expect(find.text('ABCD-1234'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextField, '6-Digit TOTP Code'),
          '123456',
        );
        await tester.ensureVisible(find.text('Activate 2FA'));
        await tester.tap(find.text('Activate 2FA'));
        await tester.pumpAndSettle();
        expect(fakeProfileApi.lastActivatedMfaCode, '123456');
        expect(find.text('Two-Factor Authentication: Enabled'), findsOneWidget);

        // Edit personal bio and persist details.
        final bioField =
            find.widgetWithText(TextFormField, 'Personal Bio & Desk Note');
        await tester.ensureVisible(bioField);
        await tester.enterText(bioField, 'Updated Ikeja field note');
        await tester.pump();
        expect(find.text('Unsaved'), findsOneWidget);

        await tester.ensureVisible(find.text('Save Personal Details'));
        await tester.tap(find.text('Save Personal Details'));
        await tester.pumpAndSettle();
        expect(fakeProfileApi.lastUpdatedBio, 'Updated Ikeja field note');
        expect(find.text('Unsaved'), findsNothing);

        expect(tester.takeException(), isNull);
        _expectNoEmojis(tester);
        _expectNoInternalIdentifiers(tester);
      },
    );

    testWidgets(
      'Branch Manager on desktop renders two-column studio in Dark Mode and supports self password rotation',
      (WidgetTester tester) async {
        final conn = _QuietConnectivityService(isOnline: true);
        final offlineDb = OfflineDatabaseService(useMemoryStore: true);
        final apiClient = ApiClient(
          connectivityService: conn,
          offlineDb: offlineDb,
          adapter: _FakeHttpAdapter(),
          isWebOverride: false,
        );
        final bmUser = _buildBmUser(mfaEnabled: true);
        final authController = _FakeAuthController(bmUser, apiClient, offlineDb);
        final fakeProfileApi = _FakeProfileApiService(
          apiClient: apiClient,
          snapshot: StaffProfileSnapshot(
            user: bmUser,
            emergencyContact: 'Chuka Kalu (+234 805 000 1122)',
            canSelfChangePassword: true,
            remainingBackupCodes: 2,
            mfaEnrolledAt: '2026-10-01T10:00:00Z',
          ),
        );

        final themeCtrl = ThemeController(autoLoad: false);
        await themeCtrl.setThemeMode(ThemeMode.dark);
        await themeCtrl.setAccentPreset(IcareAccentPreset.teal);

        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              connectivityServiceProvider.overrideWithValue(conn),
              offlineDatabaseServiceProvider.overrideWithValue(offlineDb),
              apiClientProvider.overrideWithValue(apiClient),
              authControllerProvider.overrideWith((_) => authController),
              profileApiServiceProvider.overrideWithValue(fakeProfileApi),
              themeControllerProvider.overrideWith((_) => themeCtrl),
            ],
            child: MaterialApp(
              theme: IcareTheme.buildTheme(
                brightness: Brightness.dark,
                accent: IcareAccentPreset.teal,
              ),
              home: const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: SettingsProfileScreen(),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Ngozi Kalu'), findsWidgets);
        expect(find.text('Branch Manager'), findsWidgets);
        expect(find.text('Designated Misc Manager'), findsOneWidget);
        expect(find.text('2FA Active'), findsOneWidget);
        expect(find.text('2 recovery backup codes remaining'), findsOneWidget);
        expect(find.text('Supervisor-Managed Password Policy'), findsNothing);
        expect(find.text('Update Password'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextField, 'Current Password'),
          'OldPass@123',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'New Password'),
          'NewSecurePass@2026',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Confirm New Password'),
          'NewSecurePass@2026',
        );
        await tester.ensureVisible(find.text('Update Password'));
        await tester.tap(find.text('Update Password'));
        await tester.pumpAndSettle();

        expect(fakeProfileApi.lastCurrentPassword, 'OldPass@123');
        expect(fakeProfileApi.lastNewPassword, 'NewSecurePass@2026');
        expect(tester.takeException(), isNull);
        _expectNoEmojis(tester);
        _expectNoInternalIdentifiers(tester);
      },
    );

    testWidgets(
      'CoAppScaffold exposes Settings & Profile in desktop sidebar and mobile AppBar avatar across roles',
      (WidgetTester tester) async {
        final conn = _QuietConnectivityService(isOnline: true);
        final offlineDb = OfflineDatabaseService(useMemoryStore: true);
        final apiClient = ApiClient(
          connectivityService: conn,
          offlineDb: offlineDb,
          adapter: _FakeHttpAdapter(),
          isWebOverride: false,
        );
        final coUser = _buildCoUser();
        final authController = _FakeAuthController(coUser, apiClient, offlineDb);
        final fakeProfileApi = _FakeProfileApiService(
          apiClient: apiClient,
          snapshot: StaffProfileSnapshot(
            user: coUser,
            canSelfChangePassword: false,
          ),
        );

        // 1. Desktop (1280x800): sidebar displays Settings & Profile and switches view on tap.
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              connectivityServiceProvider.overrideWithValue(conn),
              offlineDatabaseServiceProvider.overrideWithValue(offlineDb),
              apiClientProvider.overrideWithValue(apiClient),
              authControllerProvider.overrideWith((_) => authController),
              profileApiServiceProvider.overrideWithValue(fakeProfileApi),
              themeControllerProvider.overrideWith(
                (_) => ThemeController(autoLoad: false),
              ),
              activeCoPageProvider.overrideWith((_) => 'Placeholder'),
            ],
            child: MaterialApp(
              theme: IcareTheme.lightTheme,
              home: const CoAppScaffold(),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Settings & Profile'), findsOneWidget);

        await tester.tap(find.text('Settings & Profile'));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsProfileScreen), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 2. Mobile (390x844): AppBar avatar opens Settings & Profile cleanly.
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              connectivityServiceProvider.overrideWithValue(conn),
              offlineDatabaseServiceProvider.overrideWithValue(offlineDb),
              apiClientProvider.overrideWithValue(apiClient),
              authControllerProvider.overrideWith(
                (_) => _FakeAuthController(
                  _buildBmUser(mfaEnabled: false),
                  apiClient,
                  offlineDb,
                ),
              ),
              profileApiServiceProvider.overrideWithValue(
                _FakeProfileApiService(
                  apiClient: apiClient,
                  snapshot: StaffProfileSnapshot(
                    user: _buildBmUser(mfaEnabled: false),
                    canSelfChangePassword: true,
                  ),
                ),
              ),
              themeControllerProvider.overrideWith(
                (_) => ThemeController(autoLoad: false),
              ),
              activeCoPageProvider.overrideWith((_) => 'Placeholder'),
            ],
            child: MaterialApp(
              theme: IcareTheme.lightTheme,
              home: const CoAppScaffold(),
            ),
          ),
        );

        await tester.pumpAndSettle();
        final avatarFinder = find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(UserAvatarCircle),
        );
        expect(avatarFinder, findsOneWidget);

        await tester.tap(avatarFinder);
        await tester.pumpAndSettle();
        expect(find.byType(SettingsProfileScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        _expectNoEmojis(tester);
      },
    );
  });
}
