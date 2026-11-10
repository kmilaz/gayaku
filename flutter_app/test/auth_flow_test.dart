import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/screens/home_screen.dart';
import 'package:flutter_app/screens/login_screen.dart';
import 'package:flutter_app/screens/profile_screen.dart';
import 'package:flutter_app/screens/register_screen.dart';
import 'package:flutter_app/services/auth_service.dart';

/// Rejects every call, so the error path is exercised without a backend.
class _FailingAuthService implements AuthService {
  @override
  AuthUser? get currentUser => null;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async => throw const AuthException('Email atau password salah.');

  @override
  Future<AuthUser?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async => throw const AuthException('Email sudah terdaftar.');

  @override
  Future<void> signOut() async {}

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<AuthUser> updateDisplayName(String name) async =>
      throw const AuthException('Sesi habis, masuk ulang.');
}

void main() {
  // The service is a global so the screens stay widget-only; reset it so one
  // test cannot leak its backend into the next.
  tearDown(() => useAuthService(DemoAuthService()));

  testWidgets('Sign In shows the backend error and stays on login', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    useAuthService(_FailingAuthService());

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Email atau password salah.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Sign Up creates the account and opens Home', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    await tester.enterText(find.byType(TextField).at(0), 'Isabella');
    await tester.enterText(find.byType(TextField).at(1), 'isabella@gayaku.id');
    await tester.enterText(find.byType(TextField).at(2), 'rahasia123');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(authService.currentUser?.displayName, 'Isabella');
    expect(authService.currentUser?.email, 'isabella@gayaku.id');
  });

  testWidgets('Profile shows the signed-in user and logs out to Login', (
    WidgetTester tester,
  ) async {
    // Phone-height surface: the test font is wider than the real one and the
    // login header it returns to is height-driven, so 600px would overflow.
    tester.view.physicalSize = const Size(640, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await authService.signIn(
      email: 'isabella@gayaku.id',
      password: 'rahasia123',
    );

    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    expect(find.text('isabella'), findsOneWidget);

    await tester.ensureVisible(find.text('Log Out'));
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    expect(find.text('Konfirmasi Log Out'), findsOneWidget);

    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(authService.currentUser, isNull);
  });
}
